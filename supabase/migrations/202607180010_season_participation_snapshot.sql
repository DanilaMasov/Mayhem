-- R3 cross-device Season participation projection.

create or replace function public.get_active_season()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_season public.seasons%rowtype;
  v_payload jsonb;
  v_social public.social_proof_aggregates%rowtype;
  v_social_config jsonb;
  v_participation public.season_participation%rowtype;
  v_completed_days jsonb := '[]'::jsonb;
  v_boss_participated_at timestamptz;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  select * into v_season from public.seasons s
    where s.active and s.starts_at <= now() and s.ends_at > now()
    order by s.starts_at desc
    limit 1;
  if not found then return null; end if;

  v_payload := v_season.payload - 'socialProof';
  v_social_config := v_season.payload -> 'socialProof';
  if jsonb_typeof(v_social_config) = 'object' then
    select * into v_social from public.social_proof_aggregates a
      where a.aggregate_key = v_social_config ->> 'aggregateKey'
        and a.season_id = v_season.season_id
        and a.season_revision = v_season.revision
        and a.boss_event_id = v_season.payload #>> '{boss,bossEventId}'
        and a.value >= a.threshold
        and a.threshold >= 20
        and a.window_starts_at <= now() and a.window_ends_at > now();
    if found then
      v_payload := jsonb_set(v_payload, '{socialProof}', jsonb_build_object(
        'aggregateKey', v_social.aggregate_key,
        'value', v_social.value,
        'threshold', v_social.threshold,
        'windowStartsAt', v_social.window_starts_at,
        'windowEndsAt', v_social.window_ends_at
      ));
    end if;
  end if;

  select * into v_participation from public.season_participation p
    where p.season_id = v_season.season_id and p.user_id = v_user_id;
  if found then
    select coalesce(jsonb_agg(c.day order by c.day), '[]'::jsonb)
      into v_completed_days
      from public.season_day_completions c
      where c.season_id = v_season.season_id and c.user_id = v_user_id;
    select p.participated_at into v_boss_participated_at
      from public.boss_participation p
      where p.boss_event_id = v_season.payload #>> '{boss,bossEventId}'
        and p.user_id = v_user_id;
  end if;

  return jsonb_build_object(
    'seasonId', v_season.season_id,
    'revision', v_season.revision,
    'title', v_season.title,
    'startsAt', v_season.starts_at,
    'endsAt', v_season.ends_at,
    'payload', v_payload,
    'participation', case when v_participation.season_id is null then null
      else jsonb_build_object(
        'seasonId', v_season.season_id,
        'seasonRevision', v_season.revision,
        'joinedAt', v_participation.joined_at,
        'completedDays', v_completed_days,
        'bossParticipatedAt', v_boss_participated_at
      )
    end
  );
end;
$$;
