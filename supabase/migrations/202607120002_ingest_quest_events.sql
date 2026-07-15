create or replace function public.ingest_quest_events(
  p_installation_id uuid,
  p_events jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_event jsonb;
  v_event_id uuid;
  v_event_key text;
  v_event_type text;
  v_quest_id text;
  v_modifier_id text;
  v_payload jsonb;
  v_created_at timestamptz;
  v_quest public.quests_pool_cloud%rowtype;
  v_stats public.user_stats_cloud%rowtype;
  v_expected_xp integer;
  v_expected_energy integer;
  v_energy_before integer;
  v_regen_ticks integer;
  v_completion_key text;
  v_variant text;
  v_inserted integer;
  v_accepted jsonb := '[]'::jsonb;
  v_rejected jsonb := '{}'::jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;
  if p_installation_id is null then
    raise exception 'installation_id is required';
  end if;
  if jsonb_typeof(p_events) <> 'array' then
    raise exception 'events must be an array';
  end if;
  if jsonb_array_length(p_events) > 100 then
    raise exception 'event batch exceeds 100 records';
  end if;

  insert into public.user_installations (installation_id, user_id)
  values (p_installation_id, v_user_id)
  on conflict (installation_id) do update
    set last_seen_at = now()
    where public.user_installations.user_id = excluded.user_id;
  if not found then
    raise exception 'installation belongs to another user';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  insert into public.user_stats_cloud (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  for v_event in
    select item.value
    from jsonb_array_elements(p_events) as item(value)
    order by item.value->>'createdAt', item.value->>'id'
  loop
    v_event_key := coalesce(nullif(v_event->>'id', ''), 'invalid_' || floor(random() * 1000000)::text);
    begin
      if jsonb_typeof(v_event) <> 'object' then
        raise exception 'event must be an object';
      end if;
      if octet_length(v_event::text) > 65536 then
        raise exception 'event exceeds 64 KiB';
      end if;

      v_event_id := (v_event->>'id')::uuid;
      v_event_type := v_event->>'eventType';
      v_quest_id := nullif(v_event->>'questId', '');
      v_payload := coalesce(v_event->'payload', '{}'::jsonb);
      v_created_at := (v_event->>'createdAt')::timestamptz;
      v_modifier_id := coalesce(
        nullif(v_event->>'modifierId', ''),
        nullif(v_payload->>'modifierId', '')
      );

      if v_event_type not in (
        'quest_started',
        'quest_completed',
        'quest_deferred',
        'reflection_submitted',
        'guide_opened',
        'npc_training_completed',
        'dice_rolled',
        'onboarding_step_completed'
      ) then
        raise exception 'unknown event type: %', coalesce(v_event_type, '<null>');
      end if;
      if jsonb_typeof(v_payload) <> 'object' then
        raise exception 'payload must be an object';
      end if;
      if v_created_at > now() + interval '5 minutes' then
        raise exception 'event timestamp is too far in the future';
      end if;
      if v_created_at < now() - interval '90 days' then
        raise exception 'event timestamp is older than 90 days';
      end if;
      if v_modifier_id is not null and v_modifier_id not in (
        'whisper', 'drama', 'capybara', 'robot', 'echo'
      ) then
        raise exception 'unknown modifier: %', v_modifier_id;
      end if;

      if exists (
        select 1 from public.quest_events_cloud
        where user_id = v_user_id and id = v_event_id
      ) then
        v_accepted := v_accepted || jsonb_build_array(v_event_id::text);
        continue;
      end if;

      if v_event_type = 'onboarding_step_completed' then
        if v_quest_id <> 'onboarding' then
          raise exception 'onboarding event has invalid quest_id';
        end if;
      else
        select * into v_quest
        from public.quests_pool_cloud
        where id = v_quest_id and safety_reviewed = true;
        if not found then
          raise exception 'unknown or unreviewed quest: %', coalesce(v_quest_id, '<null>');
        end if;
      end if;

      v_expected_xp := 0;
      v_expected_energy := 0;

      if v_event_type in ('quest_completed', 'quest_deferred') then
        if not exists (
          select 1 from public.quest_events_cloud
          where user_id = v_user_id
            and quest_id = v_quest_id
            and event_type = 'quest_started'
            and created_at between v_created_at - interval '24 hours'
                               and v_created_at + interval '5 minutes'
        ) then
          raise exception '% requires quest_started in the previous 24 hours', v_event_type;
        end if;
      end if;

      if v_event_type = 'quest_deferred' then
        if coalesce((v_payload->>'energyDelta')::integer, 0) <> 0 then
          raise exception 'quest_deferred energyDelta must be zero';
        end if;
      end if;

      if v_event_type = 'quest_completed' then
        v_completion_key := nullif(v_payload->>'completionKey', '');
        if v_completion_key is null then
          raise exception 'quest_completed completionKey is required';
        end if;
        if exists (
          select 1 from public.quest_events_cloud
          where user_id = v_user_id
            and quest_id = v_quest_id
            and event_type = 'quest_completed'
            and metadata->>'completionKey' = v_completion_key
        ) then
          raise exception 'quest already completed for key %', v_completion_key;
        end if;

        v_expected_xp := case v_quest.level
          when 1 then 40
          when 2 then 75
          when 3 then 140
        end;
        if v_quest.is_shadow then
          v_expected_xp := round(v_expected_xp * 0.5)::integer;
        elsif v_quest.is_boss then
          v_expected_xp := v_expected_xp * 2;
        end if;
        if coalesce((v_payload->>'npcTrained')::boolean, false) then
          if not exists (
            select 1 from public.quest_events_cloud
            where user_id = v_user_id
              and quest_id = v_quest_id
              and event_type = 'npc_training_completed'
              and created_at <= v_created_at + interval '5 minutes'
          ) then
            raise exception 'npcTrained reward requires npc_training_completed';
          end if;
          v_expected_xp := round(v_expected_xp * 1.1)::integer;
        end if;
        if coalesce((v_payload->>'xpDelta')::integer, 0) <> v_expected_xp then
          raise exception 'xpDelta does not match canonical reward';
        end if;

        v_expected_energy := case
          when v_quest.is_shadow then v_quest.reward_energy
          else -v_quest.energy_cost
        end;
        if coalesce((v_payload->>'energyDelta')::integer, 0) <> v_expected_energy then
          raise exception 'energyDelta does not match canonical quest cost';
        end if;

        select * into v_stats
        from public.user_stats_cloud
        where user_id = v_user_id
        for update;
        v_regen_ticks := greatest(
          0,
          floor(extract(epoch from (v_created_at - v_stats.energy_updated_at)) / 600)::integer
        );
        v_energy_before := least(100, v_stats.energy + v_regen_ticks);
        if v_energy_before + v_expected_energy < 0 then
          raise exception 'energy would become negative';
        end if;
      end if;

      insert into public.quest_events_cloud (
        id,
        user_id,
        installation_id,
        event_type,
        quest_id,
        modifier_id,
        xp_delta,
        energy_delta,
        metadata,
        created_at
      ) values (
        v_event_id,
        v_user_id,
        p_installation_id,
        v_event_type,
        v_quest_id,
        v_modifier_id,
        v_expected_xp,
        v_expected_energy,
        v_payload,
        v_created_at
      );

      if v_event_type = 'quest_completed' then
        update public.user_stats_cloud
        set xp_charisma = xp_charisma + case when v_quest.stat_type = 'charisma' then v_expected_xp else 0 end,
            xp_boldness = xp_boldness + case when v_quest.stat_type = 'boldness' then v_expected_xp else 0 end,
            xp_networking = xp_networking + case when v_quest.stat_type = 'networking' then v_expected_xp else 0 end,
            energy = least(100, v_energy_before + v_expected_energy),
            energy_updated_at = v_created_at,
            completed_offline_count = completed_offline_count + case when v_quest.is_shadow then 0 else 1 end,
            last_event_id = v_event_id,
            updated_at = now()
        where user_id = v_user_id;

        if v_quest.is_boss then
          v_variant := coalesce(nullif(v_payload->>'variant', ''), 'normal');
          if v_variant not in ('normal', 'low_pressure') then
            raise exception 'invalid boss variant';
          end if;
          if not exists (
            select 1 from public.daily_boss_quests
            where date = v_completion_key::date and quest_id = v_quest_id
          ) then
            raise exception 'boss quest does not match server daily boss';
          end if;
          insert into public.boss_quest_participants (
            boss_date, user_id, quest_id, variant, participated_at
          ) values (
            v_completion_key::date, v_user_id, v_quest_id, v_variant, v_created_at
          ) on conflict (boss_date, user_id) do nothing;
          get diagnostics v_inserted = row_count;
          if v_inserted = 1 then
            update public.daily_boss_quests
            set participants_count = participants_count + 1
            where date = v_completion_key::date;
          end if;
        end if;
      else
        update public.user_stats_cloud
        set last_event_id = v_event_id,
            updated_at = now()
        where user_id = v_user_id;
      end if;

      v_accepted := v_accepted || jsonb_build_array(v_event_id::text);
    exception when others then
      v_rejected := v_rejected || jsonb_build_object(v_event_key, sqlerrm);
    end;
  end loop;

  select * into v_stats
  from public.user_stats_cloud
  where user_id = v_user_id;

  return jsonb_build_object(
    'acceptedIds', v_accepted,
    'rejectedById', v_rejected,
    'stats', jsonb_build_object(
      'charisma', v_stats.xp_charisma,
      'boldness', v_stats.xp_boldness,
      'networking', v_stats.xp_networking,
      'energy', v_stats.energy,
      'completedOfflineCount', v_stats.completed_offline_count,
      'lastEventId', v_stats.last_event_id
    )
  );
end;
$$;

revoke all on function public.ingest_quest_events(uuid, jsonb) from public, anon;
grant execute on function public.ingest_quest_events(uuid, jsonb) to authenticated;
