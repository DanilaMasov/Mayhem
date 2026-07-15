create or replace function public.mayhem_jsonb_has_private_note_key(value jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  item record;
begin
  if jsonb_typeof(value) = 'object' then
    for item in select key, value from jsonb_each(value)
    loop
      if lower(replace(item.key, '_', '')) in (
        'note', 'notebody', 'privatenote', 'privatenotebody'
      ) or public.mayhem_jsonb_has_private_note_key(item.value) then
        return true;
      end if;
    end loop;
  elsif jsonb_typeof(value) = 'array' then
    for item in select null::text as key, array_item.element as value
      from jsonb_array_elements(value) as array_item(element)
    loop
      if public.mayhem_jsonb_has_private_note_key(item.value) then
        return true;
      end if;
    end loop;
  end if;
  return false;
end;
$$;

create or replace function public.mayhem_is_canonical_event_v2(value text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select value = any (array[
    'onboarding_started', 'calibration_answered', 'safety_boundary_accepted',
    'onboarding_completed', 'feed_batch_received', 'feed_item_impressed',
    'feed_item_opened', 'feed_item_skipped', 'feed_item_saved',
    'challenge_accepted', 'challenge_route_selected', 'challenge_deferred',
    'challenge_abandoned', 'challenge_attempted', 'challenge_completed',
    'reflection_submitted', 'momentum_day_earned', 'momentum_shield_granted',
    'momentum_shield_consumed', 'rank_unlocked', 'season_joined',
    'season_day_completed', 'boss_participated', 'artifact_unlocked',
    'account_linked', 'privacy_preference_changed'
  ]);
$$;

create or replace function public.mayhem_rank_dev_v1(
  p_total_xp bigint,
  p_initiation_xp bigint,
  p_expression_xp bigint,
  p_connection_xp bigint,
  p_presence_xp bigint
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  threshold record;
  result jsonb := jsonb_build_object('family', 'spark', 'tier', 1);
begin
  for threshold in
    select * from (values
      ('spark', 1, 0, 0),
      ('spark', 2, 250, 0),
      ('spark', 3, 600, 0),
      ('mover', 1, 1000, 100),
      ('mover', 2, 1500, 150),
      ('mover', 3, 2200, 200),
      ('catalyst', 1, 3000, 300),
      ('catalyst', 2, 4000, 400),
      ('catalyst', 3, 5200, 500),
      ('maverick', 1, 6700, 650),
      ('maverick', 2, 8500, 800),
      ('maverick', 3, 10500, 1000),
      ('icon', 1, 13000, 1200),
      ('icon', 2, 16000, 1500),
      ('icon', 3, 20000, 1800),
      ('mayhem', 1, 25000, 2200)
    ) as ladder(family, tier, total_xp, minimum_trait_xp)
    order by total_xp
  loop
    exit when p_total_xp < threshold.total_xp or
      least(p_initiation_xp, p_expression_xp, p_connection_xp, p_presence_xp) <
        threshold.minimum_trait_xp;
    result := jsonb_build_object(
      'family', threshold.family,
      'tier', threshold.tier
    );
  end loop;
  return result || jsonb_build_object('configRevision', 'rank_config_dev_v1');
end;
$$;

create or replace function public.mayhem_reward_xp_dev_v1(
  p_base_xp integer,
  p_outcome text,
  p_route text,
  p_advanced_approved boolean,
  p_reflection_submitted boolean,
  p_prior_terminal_attempts integer
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  reward_percent integer := case when p_outcome = 'completed' then 100 else 60 end;
  repeat_percent integer := case
    when p_prior_terminal_attempts <= 0 then 100
    when p_prior_terminal_attempts = 1 then 75
    else 50
  end;
begin
  if p_base_xp < 0 or p_outcome not in ('attempted', 'completed') then
    raise exception 'invalid reward input';
  end if;
  if p_reflection_submitted then
    reward_percent := reward_percent + 10;
  end if;
  if p_route = 'advanced' and p_advanced_approved then
    reward_percent := reward_percent + 10;
  end if;
  return (p_base_xp * reward_percent * repeat_percent + 5000) / 10000;
end;
$$;

create or replace function public.mayhem_difficulty_delta_dev_v1(
  p_outcome text,
  p_felt text,
  p_skip_reason text default null
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case p_skip_reason
    when 'tooEasy' then 0.25
    when 'tooIntense' then -0.40
    when 'notMySituation' then 0.0
    when 'notInterested' then 0.0
    when 'unsafeOrUncomfortable' then 0.0
    else case
      when p_outcome = 'completed' and p_felt = 'easierThanExpected' then 0.30
      when p_outcome = 'attempted' and p_felt = 'easierThanExpected' then 0.15
      when p_outcome = 'completed' and p_felt = 'aboutAsExpected' then 0.15
      when p_outcome = 'attempted' and p_felt = 'aboutAsExpected' then 0.05
      when p_outcome = 'completed' and p_felt = 'harderThanExpected' then 0.05
      when p_outcome = 'attempted' and p_felt = 'harderThanExpected' then -0.15
      when p_outcome = 'completed' and p_felt = 'stoppedEarly' then -0.10
      when p_outcome = 'attempted' and p_felt = 'stoppedEarly' then -0.30
      else null
    end
  end;
$$;

create or replace function public.mayhem_apply_momentum_dev_v1(
  p_user_id uuid,
  p_local_date date,
  p_earned_at_utc timestamptz,
  p_timezone_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  state public.user_momentum%rowtype;
  gap integer;
  next_days integer := 1;
  next_shields integer;
  next_protected date[];
begin
  insert into public.user_momentum (user_id) values (p_user_id)
  on conflict (user_id) do nothing;
  select * into state from public.user_momentum
    where user_id = p_user_id for update;
  if state.last_earned_local_date = p_local_date then
    return;
  end if;
  if state.last_earned_at_utc is not null and
     p_earned_at_utc - state.last_earned_at_utc < interval '20 hours' then
    update public.user_momentum set
      pending_local_date = p_local_date,
      pending_earned_at_utc = p_earned_at_utc,
      pending_timezone_id = p_timezone_id,
      projection_revision = projection_revision + 1,
      updated_at = now()
    where user_id = p_user_id;
    update public.user_progress set
      projection_revision = projection_revision + 1,
      updated_at = now()
    where user_id = p_user_id;
    return;
  end if;
  next_shields := state.shields_available;
  next_protected := state.protected_local_dates;
  if state.last_earned_local_date is not null then
    gap := p_local_date - state.last_earned_local_date;
    if gap <= 0 then return; end if;
    if gap = 1 then
      next_days := state.current_days + 1;
    elsif gap = 2 and next_shields > 0 then
      next_days := state.current_days + 1;
      next_shields := next_shields - 1;
      next_protected := array_append(next_protected, state.last_earned_local_date + 1);
    end if;
  end if;
  if next_days % 7 = 0 and next_shields < 2 then
    next_shields := next_shields + 1;
  end if;
  update public.user_momentum set
    current_days = next_days,
    longest_days = greatest(longest_days, next_days),
    shields_available = next_shields,
    last_earned_local_date = p_local_date,
    last_earned_at_utc = p_earned_at_utc,
    last_earned_timezone_id = p_timezone_id,
    protected_local_dates = next_protected,
    pending_local_date = null,
    pending_earned_at_utc = null,
    pending_timezone_id = null,
    policy_revision = 'momentum_policy_dev_v1',
    projection_revision = projection_revision + 1,
    updated_at = now()
  where user_id = p_user_id;
  update public.user_progress set
    projection_revision = projection_revision + 1,
    updated_at = now()
  where user_id = p_user_id;
end;
$$;

create or replace function public.mayhem_progress_payload(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'totalXp', p.total_xp,
    'traitXp', jsonb_build_object(
      'initiation', p.initiation_xp,
      'expression', p.expression_xp,
      'connection', p.connection_xp,
      'presence', p.presence_xp
    ),
    'rank', jsonb_build_object(
      'family', p.rank_family,
      'tier', p.rank_tier,
      'configRevision', p.rank_config_revision
    ),
    'rewardPolicyRevision', p.reward_policy_revision,
    'completedCount', p.completed_count,
    'attemptedCount', p.attempted_count,
    'projectionRevision', p.projection_revision,
    'updatedAt', p.updated_at,
    'ownedArtifacts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'artifactId', a.artifact_id,
        'seasonId', a.season_id,
        'seasonRevision', a.season_revision,
        'bossEventId', a.boss_event_id,
        'unlockedAt', a.unlocked_at
      ) order by a.unlocked_at, a.artifact_id)
      from public.user_artifacts a where a.user_id = p_user_id
    ), '[]'::jsonb),
    'difficulty', coalesce((
      select jsonb_object_agg(d.trait, jsonb_build_object(
        'rating', d.rating,
        'confidence', d.confidence,
        'observations', d.observations,
        'recommendedIntensity', d.recommended_intensity,
        'algorithmRevision', d.algorithm_revision,
        'updatedAt', d.updated_at
      )) from public.user_difficulty_profiles d where d.user_id = p_user_id
    ), '{}'::jsonb),
    'momentum', coalesce((
      select jsonb_build_object(
        'currentDays', m.current_days,
        'longestDays', m.longest_days,
        'shieldsAvailable', m.shields_available,
        'lastEarnedLocalDate', m.last_earned_local_date,
        'lastEarnedAtUtc', m.last_earned_at_utc,
        'lastEarnedTimezoneId', m.last_earned_timezone_id,
        'protectedLocalDates', m.protected_local_dates,
        'pendingLocalDate', m.pending_local_date,
        'pendingEarnedAtUtc', m.pending_earned_at_utc,
        'pendingTimezoneId', m.pending_timezone_id,
        'policyRevision', m.policy_revision,
        'projectionRevision', m.projection_revision
      ) from public.user_momentum m where m.user_id = p_user_id
    ), jsonb_build_object(
      'currentDays', 0, 'longestDays', 0, 'shieldsAvailable', 0,
      'protectedLocalDates', '[]'::jsonb,
      'policyRevision', 'momentum_policy_dev_v1', 'projectionRevision', 0
    ))
  )
  from public.user_progress p
  where p.user_id = p_user_id;
$$;

create or replace function public.register_installation(
  p_installation_id uuid,
  p_local_user_id text,
  p_platform text,
  p_app_version text,
  p_capabilities jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_owner uuid;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if length(trim(p_local_user_id)) < 8 or length(trim(p_local_user_id)) > 128 or
     p_platform not in ('ios', 'android', 'test') or
     length(trim(p_app_version)) > 64 or jsonb_typeof(p_capabilities) <> 'object' then
    raise exception 'invalid installation registration';
  end if;
  select user_id into v_owner from public.user_installations
    where installation_id = p_installation_id;
  if v_owner is not null and v_owner <> v_user_id then
    raise exception 'installation belongs to another account';
  end if;
  insert into public.user_installations (
    installation_id, user_id, local_user_id, platform, app_version,
    capabilities, created_at, last_seen_at
  ) values (
    p_installation_id, v_user_id, trim(p_local_user_id), p_platform,
    trim(p_app_version), p_capabilities, now(), now()
  ) on conflict (installation_id) do update set
    local_user_id = excluded.local_user_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    capabilities = excluded.capabilities,
    last_seen_at = now();
  insert into public.user_progress (user_id) values (v_user_id)
    on conflict (user_id) do nothing;
  insert into public.user_momentum (user_id) values (v_user_id)
    on conflict (user_id) do nothing;
  return jsonb_build_object(
    'installationId', p_installation_id,
    'remoteUserId', v_user_id,
    'registeredAt', now()
  );
end;
$$;

create or replace function public.get_content_manifest(p_locale text default 'ru')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_manifest public.content_manifests%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into v_manifest
  from public.content_manifests
  where locale = p_locale and active and generated_at <= now()
  order by revision desc
  limit 1;
  if not found then
    return jsonb_build_object(
      'manifestRevision', 0,
      'locale', p_locale,
      'generatedAt', now(),
      'items', '[]'::jsonb
    );
  end if;
  return jsonb_build_object(
    'manifestRevision', v_manifest.revision,
    'locale', v_manifest.locale,
    'generatedAt', v_manifest.generated_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'contentId', c.content_id,
        'revision', c.revision,
        'type', c.content_type,
        'checksum', c.checksum,
        'publishedAt', c.published_at,
        'startsAt', c.starts_at,
        'endsAt', c.ends_at
      ) order by item.position)
      from public.content_manifest_items item
      join public.content_item_revisions c
        on c.content_id = item.content_id
       and c.revision = item.content_revision
       and c.locale = item.locale
      where item.manifest_id = v_manifest.manifest_id
        and c.published_at <= now()
        and (c.starts_at is null or c.starts_at <= now())
        and (c.ends_at is null or c.ends_at > now())
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.get_content_revisions(p_requests jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if jsonb_typeof(p_requests) <> 'array' or jsonb_array_length(p_requests) > 100 then
    raise exception 'revision requests must be an array with at most 100 items';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'contentId', c.content_id,
      'revision', c.revision,
      'locale', c.locale,
      'type', c.content_type,
      'payload', c.payload,
      'safety', c.safety,
      'media', c.media,
      'checksum', c.checksum,
      'active', c.active,
      'publishedAt', c.published_at,
      'startsAt', c.starts_at,
      'endsAt', c.ends_at
    ) order by c.content_id, c.revision)
    from jsonb_array_elements(p_requests) request
    join public.content_item_revisions c
      on c.content_id = request ->> 'contentId'
     and c.revision = (request ->> 'revision')::integer
     and c.locale = request ->> 'locale'
    where c.published_at <= now()
      and (c.starts_at is null or c.starts_at <= now())
      and (c.ends_at is null or c.ends_at > now())
      and exists (
        select 1
        from public.content_manifest_items item
        join public.content_manifests manifest
          on manifest.manifest_id = item.manifest_id
         and manifest.locale = item.locale
        where item.content_id = c.content_id
          and item.content_revision = c.revision
          and item.locale = c.locale
          and manifest.active
          and manifest.generated_at <= now()
      )
  ), '[]'::jsonb);
end;
$$;

create or replace function public.get_progress_projection()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  insert into public.user_progress (user_id) values (v_user_id)
    on conflict (user_id) do nothing;
  insert into public.user_momentum (user_id) values (v_user_id)
    on conflict (user_id) do nothing;
  return public.mayhem_progress_payload(v_user_id);
end;
$$;

create or replace function public.get_active_season()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_season public.seasons%rowtype;
  v_payload jsonb;
  v_social public.social_proof_aggregates%rowtype;
  v_social_config jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
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
  return jsonb_build_object(
    'seasonId', v_season.season_id,
    'revision', v_season.revision,
    'title', v_season.title,
    'startsAt', v_season.starts_at,
    'endsAt', v_season.ends_at,
    'payload', v_payload
  );
end;
$$;

create or replace function public.get_bootstrap_payload(
  p_installation_id uuid,
  p_environment text default 'production',
  p_locale text default 'ru'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_local_user_id text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  select local_user_id into v_local_user_id from public.user_installations
    where installation_id = p_installation_id and user_id = v_user_id;
  if v_local_user_id is null then raise exception 'installation is not registered'; end if;
  return jsonb_build_object(
    'identity', jsonb_build_object(
      'remoteUserId', v_user_id,
      'localUserId', v_local_user_id,
      'installationId', p_installation_id
    ),
    'flags', coalesce((
      select jsonb_agg(jsonb_build_object(
        'key', f.flag_key,
        'enabled', f.enabled,
        'requiredCapabilityKey', f.required_capability_key,
        'requiredCapabilityRevision', f.required_capability_revision,
        'config', f.config,
        'updatedAt', f.updated_at
      ) order by f.flag_key)
      from public.feature_flags f
      where f.environment = p_environment and f.cohort = 'all'
    ), '[]'::jsonb),
    'projection', public.mayhem_progress_payload(v_user_id),
    'activeSeason', public.get_active_season(),
    'feed', (
      select jsonb_build_object(
        'batchId', b.batch_id, 'algorithmRevision', b.algorithm_revision,
        'createdAt', b.created_at, 'expiresAt', b.expires_at
      ) from public.feed_batches b
      where b.user_id = v_user_id and (b.expires_at is null or b.expires_at > now())
      order by b.created_at desc limit 1
    ),
    'contentManifest', public.get_content_manifest(p_locale),
    'serverTime', now()
  );
end;
$$;

create or replace function public.get_feed_batch(
  p_locale text default 'ru',
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_batch_id uuid := gen_random_uuid();
  item record;
  v_assignment_json jsonb;
  v_position integer := 0;
  v_items jsonb := '[]'::jsonb;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if p_limit < 1 or p_limit > 20 then raise exception 'feed limit must be between 1 and 20'; end if;
  insert into public.feed_batches (
    batch_id, user_id, locale, algorithm_revision, expires_at
  ) values (
    v_batch_id, v_user_id, p_locale, 'feed_rules_dev_v1', now() + interval '24 hours'
  );
  for item in
    select c.content_id, c.revision, c.locale, c.content_type
    from public.content_manifests manifest
    join public.content_manifest_items manifest_item
      on manifest_item.manifest_id = manifest.manifest_id
     and manifest_item.locale = manifest.locale
    join public.content_item_revisions c
      on c.content_id = manifest_item.content_id
     and c.revision = manifest_item.content_revision
     and c.locale = manifest_item.locale
    where manifest.locale = p_locale and manifest.active
      and manifest.generated_at <= now() and c.published_at <= now()
      and (c.starts_at is null or c.starts_at <= now())
      and (c.ends_at is null or c.ends_at > now())
    order by hashtextextended(v_user_id::text || c.content_id || c.revision::text, 0)
    limit p_limit
  loop
    insert into public.feed_assignments (
      batch_id, user_id, content_id, content_revision, locale, position,
      assignment_reason, expires_at
    ) values (
      v_batch_id, v_user_id, item.content_id, item.revision, item.locale,
      v_position, 'rule_based_diversity_v1', now() + interval '24 hours'
    ) returning jsonb_build_object(
      'assignmentId', assignment_id,
      'contentId', content_id,
      'contentRevision', content_revision,
      'locale', locale,
      'position', position,
      'assignmentReason', assignment_reason,
      'expiresAt', expires_at
    ) into v_assignment_json;
    v_items := v_items || jsonb_build_array(v_assignment_json);
    v_position := v_position + 1;
  end loop;
  if v_position <> p_limit then
    raise exception 'insufficient active content for requested feed batch';
  end if;
  return jsonb_build_object(
    'batchId', v_batch_id,
    'algorithmRevision', 'feed_rules_dev_v1',
    'createdAt', now(),
    'expiresAt', now() + interval '24 hours',
    'assignments', v_items
  );
end;
$$;

create or replace function public.mayhem_apply_season_event_v1(
  p_user_id uuid,
  p_event_type text,
  p_payload jsonb,
  p_content_id text,
  p_content_revision integer,
  p_occurred_at timestamptz
)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_season public.seasons%rowtype;
  v_boss public.boss_events%rowtype;
  v_season_id text := p_payload ->> 'seasonId';
  v_boss_event_id text := p_payload ->> 'bossEventId';
  v_route text := p_payload ->> 'route';
  v_day integer;
  v_artifact jsonb;
  v_social_config jsonb;
  v_social_key text;
  v_social_threshold integer;
  v_social_starts_at timestamptz;
  v_social_ends_at timestamptz;
  v_participation_inserted integer := 0;
begin
  if p_occurred_at > now() + interval '5 minutes' then
    return 'permanent_schema';
  end if;
  if p_event_type = 'artifact_unlocked' then
    return 'invalid_transition';
  end if;
  if v_season_id is null or
     coalesce(p_payload ->> 'seasonRevision', '') !~ '^[1-9][0-9]*$' then
    return 'permanent_schema';
  end if;
  select * into v_season from public.seasons
    where season_id = v_season_id
      and revision = (p_payload ->> 'seasonRevision')::integer
      and active
      and p_occurred_at >= starts_at and p_occurred_at < ends_at
      and now() < ends_at + interval '72 hours';
  if not found then return 'invalid_transition'; end if;

  if p_event_type = 'season_joined' then
    insert into public.season_participation (season_id, user_id, joined_at)
      values (v_season.season_id, p_user_id, p_occurred_at)
      on conflict (season_id, user_id) do nothing;
    return 'accepted';
  end if;
  if not exists (
    select 1 from public.season_participation
    where season_id = v_season.season_id and user_id = p_user_id
      and joined_at <= p_occurred_at
  ) then return 'invalid_transition'; end if;

  if p_event_type = 'season_day_completed' then
    if coalesce(p_payload ->> 'day', '') !~ '^[1-7]$' then
      return 'permanent_schema';
    end if;
    v_day := (p_payload ->> 'day')::integer;
    if p_occurred_at < v_season.starts_at + make_interval(days => v_day - 1) then
      return 'invalid_transition';
    end if;
    insert into public.season_day_completions (
      season_id, user_id, day, completed_at
    ) values (
      v_season.season_id, p_user_id, v_day, p_occurred_at
    ) on conflict (season_id, user_id, day) do nothing;
    update public.season_participation set completed_days = (
      select count(*) from public.season_day_completions
      where season_id = v_season.season_id and user_id = p_user_id
    ) where season_id = v_season.season_id and user_id = p_user_id;
    return 'accepted';
  end if;

  if p_event_type = 'boss_participated' then
    if v_boss_event_id is null or
       v_route not in ('normal', 'low_pressure', 'advanced') then
      return 'permanent_schema';
    end if;
    select * into v_boss from public.boss_events
      where boss_event_id = v_boss_event_id
        and season_id = v_season.season_id
        and content_id = p_content_id
        and content_revision = p_content_revision
        and p_occurred_at >= starts_at and p_occurred_at < ends_at
        and now() < ends_at + interval '72 hours';
    if not found then return 'invalid_transition'; end if;
    if (v_route = 'normal' and not (v_boss.payload ? 'normalRoute')) or
       (v_route = 'low_pressure' and not (v_boss.payload ? 'lowPressureRoute')) or
       (v_route = 'advanced' and (
         not (v_boss.payload ? 'advancedRoute') or
         coalesce(v_boss.payload ->> 'advancedRouteSafetyApproved', 'false') <> 'true'
       )) then return 'invalid_transition'; end if;

    if jsonb_typeof(v_season.payload -> 'artifacts') <> 'array' then
      return 'invalid_transition';
    end if;
    if jsonb_array_length(v_season.payload -> 'artifacts') = 0 or exists (
      select 1 from jsonb_array_elements(v_season.payload -> 'artifacts') artifact
      where jsonb_typeof(artifact) <> 'object'
        or length(trim(coalesce(artifact ->> 'artifactId', ''))) not between 1 and 128
        or length(trim(coalesce(artifact ->> 'title', ''))) not between 1 and 160
    ) or (
         select count(*) from jsonb_array_elements(v_season.payload -> 'artifacts')
       ) <> (
         select count(distinct artifact ->> 'artifactId')
         from jsonb_array_elements(v_season.payload -> 'artifacts') artifact
    ) then return 'invalid_transition'; end if;

    v_social_config := v_season.payload -> 'socialProof';
    if v_social_config is not null then
      if jsonb_typeof(v_social_config) <> 'object' or
         length(trim(coalesce(v_social_config ->> 'aggregateKey', ''))) not between 1 and 128 or
         coalesce(v_social_config ->> 'threshold', '') !~ '^[1-9][0-9]*$' then
        return 'invalid_transition';
      end if;
      begin
        v_social_key := v_social_config ->> 'aggregateKey';
        v_social_threshold := (v_social_config ->> 'threshold')::integer;
        v_social_starts_at := (v_social_config ->> 'windowStartsAt')::timestamptz;
        v_social_ends_at := (v_social_config ->> 'windowEndsAt')::timestamptz;
      exception when others then
        return 'invalid_transition';
      end;
      if v_social_threshold < 20 or
         v_social_starts_at is null or v_social_ends_at is null or
         v_social_starts_at < v_season.starts_at or
         v_social_ends_at > v_season.ends_at or
         v_social_starts_at >= v_social_ends_at then
        return 'invalid_transition';
      end if;
      perform pg_advisory_xact_lock(hashtextextended('social:' || v_social_key, 0));
      if exists (
        select 1 from public.social_proof_aggregates a
        where a.aggregate_key = v_social_key and (
          a.season_id <> v_season.season_id or
          a.season_revision <> v_season.revision or
          a.boss_event_id <> v_boss.boss_event_id or
          a.threshold <> v_social_threshold or
          a.window_starts_at <> v_social_starts_at or
          a.window_ends_at <> v_social_ends_at
        )
      ) then return 'invalid_transition'; end if;
    end if;

    insert into public.boss_participation (
      boss_event_id, user_id, participated_at
    ) values (
      v_boss.boss_event_id, p_user_id, p_occurred_at
    ) on conflict (boss_event_id, user_id) do nothing;
    get diagnostics v_participation_inserted = row_count;
    for v_artifact in
      select value from jsonb_array_elements(v_season.payload -> 'artifacts')
    loop
      insert into public.user_artifacts (
        artifact_id, user_id, season_id, season_revision, boss_event_id, unlocked_at
      ) values (
        v_artifact ->> 'artifactId', p_user_id, v_season.season_id,
        v_season.revision, v_boss.boss_event_id, p_occurred_at
      ) on conflict (artifact_id, user_id) do nothing;
    end loop;
    if v_social_config is not null then
      insert into public.social_proof_aggregates (
        aggregate_key, season_id, season_revision, boss_event_id, value, threshold,
        window_starts_at, window_ends_at, updated_at
      ) values (
        v_social_key, v_season.season_id, v_season.revision,
        v_boss.boss_event_id, v_participation_inserted,
        v_social_threshold, v_social_starts_at, v_social_ends_at, now()
      ) on conflict (aggregate_key) do update set
        value = public.social_proof_aggregates.value + excluded.value,
        updated_at = excluded.updated_at;
    end if;
    return 'accepted';
  end if;
  return 'permanent_schema';
end;
$$;

create or replace function public.ingest_events_v2(
  p_installation_id uuid,
  p_events jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  event jsonb;
  v_event_id uuid;
  v_event_type text;
  v_sequence bigint;
  v_assignment_id uuid;
  v_attempt_id uuid;
  v_assignment public.feed_assignments%rowtype;
  v_attempt public.challenge_attempts%rowtype;
  v_content public.content_item_revisions%rowtype;
  v_payload jsonb;
  v_outcome text;
  v_felt text;
  v_route text;
  v_trait text;
  v_reward integer;
  v_prior integer;
  v_reflection boolean;
  v_delta numeric;
  v_rank jsonb;
  v_disposition text;
  v_occurred_at timestamptz;
  v_timezone_offset integer;
  v_content_revision integer;
  v_results jsonb := '[]'::jsonb;
  v_accepted_ids jsonb := '[]'::jsonb;
  v_previous_sequence bigint := 0;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 100 then
    raise exception 'events must be an array with at most 100 items';
  end if;
  if not exists (
    select 1 from public.user_installations
    where installation_id = p_installation_id and user_id = v_user_id
  ) then raise exception 'installation is not registered'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  for event in select value from jsonb_array_elements(p_events)
  loop
    begin
      if jsonb_typeof(event) <> 'object' then raise exception 'event must be an object'; end if;
      v_event_id := (event ->> 'eventId')::uuid;
      v_event_type := event ->> 'eventType';
      v_sequence := (event ->> 'clientSequence')::bigint;
      v_assignment_id := nullif(event ->> 'assignmentId', '')::uuid;
      v_attempt_id := nullif(event ->> 'attemptId', '')::uuid;
      v_payload := coalesce(event -> 'payload', '{}'::jsonb);
      v_occurred_at := (event ->> 'occurredAtUtc')::timestamptz;
      v_timezone_offset := (event ->> 'timezoneOffsetMinutes')::integer;
      v_content_revision := nullif(event ->> 'contentRevision', '')::integer;
      if (event ->> 'schemaVersion')::integer <> 2 or
         (event ->> 'installationId')::uuid <> p_installation_id or
         v_sequence <= v_previous_sequence or
         not public.mayhem_is_canonical_event_v2(v_event_type) or
         v_occurred_at is null or
         length(trim(coalesce(event ->> 'timezoneId', ''))) = 0 or
         v_timezone_offset not between -840 and 840 or
         jsonb_typeof(v_payload) <> 'object' or
         public.mayhem_jsonb_has_private_note_key(v_payload) or
         octet_length(v_payload::text) > 65536 then
        raise exception 'event schema validation failed';
      end if;
      v_previous_sequence := v_sequence;
    exception when others then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'eventId', event ->> 'eventId', 'accepted', false,
        'disposition', 'permanent_schema'
      ));
      continue;
    end;

    if exists (
      select 1 from public.user_events
      where (user_id = v_user_id and event_id = v_event_id) or
            (installation_id = p_installation_id and client_sequence = v_sequence)
    ) then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'eventId', v_event_id, 'accepted', true,
        'disposition', 'duplicate_event'
      ));
      v_accepted_ids := v_accepted_ids || jsonb_build_array(v_event_id);
      continue;
    end if;

    v_disposition := 'accepted';
    if v_assignment_id is not null then
      select * into v_assignment from public.feed_assignments
        where assignment_id = v_assignment_id and user_id = v_user_id;
      if not found then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'unknown_assignment'
        ));
        continue;
      end if;
      if (event ->> 'contentId') is distinct from v_assignment.content_id or
         v_content_revision is distinct from
           v_assignment.content_revision then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      if exists (
        select 1 from public.content_item_revisions c
        where c.content_id = v_assignment.content_id and c.locale = v_assignment.locale
          and c.revision > v_assignment.content_revision and c.active
      ) then v_disposition := 'stale_content_but_valid_assignment'; end if;
    end if;

    if v_event_type in (
      'feed_item_impressed', 'feed_item_opened', 'feed_item_skipped',
      'feed_item_saved'
    ) then
      if v_assignment_id is null or v_attempt_id is not null then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      if v_event_type = 'feed_item_skipped' and
         coalesce(v_payload ->> 'reason', '') not in (
           'notNow', 'tooIntense', 'wrongContext', 'notRelevant'
         ) then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'permanent_schema'
        ));
        continue;
      end if;
    end if;

    if v_event_type = 'challenge_accepted' then
      if v_assignment_id is null or v_attempt_id is null then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      v_route := coalesce(v_payload ->> 'route', 'normal');
      begin
        insert into public.challenge_attempts (
          attempt_id, user_id, assignment_id, content_id, content_revision,
          selected_route, status, accepted_at
        ) values (
          v_attempt_id, v_user_id, v_assignment_id, v_assignment.content_id,
          v_assignment.content_revision, v_route, 'active',
          v_occurred_at
        );
      exception when unique_violation then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end;
    elsif v_event_type in ('challenge_attempted', 'challenge_completed') then
      if v_assignment_id is null or v_attempt_id is null then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      select * into v_attempt from public.challenge_attempts
        where attempt_id = v_attempt_id and user_id = v_user_id for update;
      if not found then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'unknown_assignment'
        ));
        continue;
      end if;
      if v_attempt.status <> 'active' or v_attempt.assignment_id <> v_assignment_id then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      select * into v_content from public.content_item_revisions
        where content_id = v_attempt.content_id
          and revision = v_attempt.content_revision
          and locale = v_assignment.locale;
      v_outcome := case when v_event_type = 'challenge_completed' then 'completed' else 'attempted' end;
      v_felt := v_payload ->> 'felt';
      v_route := v_attempt.selected_route;
      v_trait := coalesce(v_content.payload ->> 'primaryTrait', 'presence');
      if v_trait not in ('initiation', 'expression', 'connection', 'presence') then
        v_trait := 'presence';
      end if;
      v_delta := public.mayhem_difficulty_delta_dev_v1(v_outcome, v_felt, null);
      if v_delta is null then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'permanent_schema'
        ));
        continue;
      end if;
      select count(*) into v_prior from public.challenge_attempts
        where user_id = v_user_id and content_id = v_attempt.content_id
          and content_revision = v_attempt.content_revision
          and attempt_id <> v_attempt_id and status in ('attempted', 'completed')
          and resolved_at >= v_occurred_at - interval '7 days';
      select exists (
        select 1 from jsonb_array_elements(p_events) candidate
        where candidate ->> 'eventType' = 'reflection_submitted'
          and candidate ->> 'attemptId' = v_attempt_id::text
          and not public.mayhem_jsonb_has_private_note_key(
            coalesce(candidate -> 'payload', '{}'::jsonb)
          )
      ) into v_reflection;
      v_reward := public.mayhem_reward_xp_dev_v1(
        coalesce((v_content.payload ->> 'baseXp')::integer, 0),
        v_outcome, v_route,
        coalesce((v_content.safety ->> 'advancedRouteSafetyApproved')::boolean, false),
        v_reflection, v_prior
      );
      update public.challenge_attempts set
        status = v_outcome,
        resolved_at = v_occurred_at,
        reward_xp = v_reward,
        reward_policy_revision = 'reward_policy_dev_v1',
        updated_at = now()
      where attempt_id = v_attempt_id and user_id = v_user_id;
      insert into public.user_progress (user_id) values (v_user_id)
        on conflict (user_id) do nothing;
      update public.user_progress set
        total_xp = total_xp + v_reward,
        initiation_xp = initiation_xp + case when v_trait = 'initiation' then v_reward else 0 end,
        expression_xp = expression_xp + case when v_trait = 'expression' then v_reward else 0 end,
        connection_xp = connection_xp + case when v_trait = 'connection' then v_reward else 0 end,
        presence_xp = presence_xp + case when v_trait = 'presence' then v_reward else 0 end,
        completed_count = completed_count + case when v_outcome = 'completed' then 1 else 0 end,
        attempted_count = attempted_count + case when v_outcome = 'attempted' then 1 else 0 end,
        reward_policy_revision = 'reward_policy_dev_v1',
        projection_revision = projection_revision + 1,
        updated_at = now()
      where user_id = v_user_id;
      insert into public.user_difficulty_profiles (
        user_id, trait, rating, confidence, observations,
        recommended_intensity, algorithm_revision
      ) values (
        v_user_id, v_trait, greatest(1, least(5, 2 + v_delta)), 0.08, 1,
        round(greatest(1, least(5, 2 + v_delta))), 'difficulty_model_dev_v1'
      ) on conflict (user_id, trait) do update set
        rating = greatest(1, least(5, public.user_difficulty_profiles.rating + v_delta)),
        confidence = least(1, public.user_difficulty_profiles.confidence + 0.08),
        observations = public.user_difficulty_profiles.observations + 1,
        recommended_intensity = round(greatest(1, least(5, public.user_difficulty_profiles.rating + v_delta))),
        algorithm_revision = 'difficulty_model_dev_v1',
        updated_at = now();
      select public.mayhem_rank_dev_v1(
        total_xp, initiation_xp, expression_xp, connection_xp, presence_xp
      ) into v_rank from public.user_progress where user_id = v_user_id;
      update public.user_progress set
        rank_family = v_rank ->> 'family',
        rank_tier = (v_rank ->> 'tier')::integer,
        rank_config_revision = v_rank ->> 'configRevision'
      where user_id = v_user_id;
    elsif v_event_type in ('challenge_deferred', 'challenge_abandoned') then
      if v_assignment_id is null or v_attempt_id is null then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      update public.challenge_attempts set
        status = case when v_event_type = 'challenge_deferred' then 'deferred' else 'abandoned' end,
        resolved_at = v_occurred_at,
        updated_at = now()
      where attempt_id = v_attempt_id and user_id = v_user_id
        and assignment_id = v_assignment_id and status = 'active';
      if not found then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
    elsif v_event_type = 'momentum_day_earned' then
      if v_attempt_id is null or not exists (
        select 1 from public.challenge_attempts a
        join public.content_item_revisions c
          on c.content_id = a.content_id and c.revision = a.content_revision
        where a.user_id = v_user_id and a.attempt_id = v_attempt_id
          and coalesce((c.payload ->> 'momentumEligible')::boolean, false)
      ) then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      perform public.mayhem_apply_momentum_dev_v1(
        v_user_id,
        (v_payload ->> 'localDate')::date,
        v_occurred_at,
        event ->> 'timezoneId'
      );
    end if;

    if v_event_type in (
      'season_joined', 'season_day_completed', 'boss_participated',
      'artifact_unlocked'
    ) then
      if v_assignment_id is not null or v_attempt_id is not null then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', 'invalid_transition'
        ));
        continue;
      end if;
      v_disposition := public.mayhem_apply_season_event_v1(
        v_user_id,
        v_event_type,
        v_payload,
        nullif(event ->> 'contentId', ''),
        v_content_revision,
        v_occurred_at
      );
      if v_disposition <> 'accepted' then
        v_results := v_results || jsonb_build_array(jsonb_build_object(
          'eventId', v_event_id, 'accepted', false,
          'disposition', v_disposition
        ));
        continue;
      end if;
    end if;

    insert into public.user_events (
      event_id, user_id, installation_id, client_sequence, schema_version,
      event_type, assignment_id, attempt_id, content_id, content_revision,
      occurred_at_utc, timezone_id, timezone_offset_minutes, payload
    ) values (
      v_event_id, v_user_id, p_installation_id, v_sequence, 2,
      v_event_type, v_assignment_id, v_attempt_id,
      nullif(event ->> 'contentId', ''),
      v_content_revision,
      v_occurred_at,
      event ->> 'timezoneId',
      v_timezone_offset,
      v_payload
    );
    v_results := v_results || jsonb_build_array(jsonb_build_object(
      'eventId', v_event_id, 'accepted', true, 'disposition', v_disposition
    ));
    v_accepted_ids := v_accepted_ids || jsonb_build_array(v_event_id);
  end loop;
  return jsonb_build_object(
    'acceptedIds', v_accepted_ids,
    'results', v_results,
    'projection', public.mayhem_progress_payload(v_user_id),
    'serverTime', now()
  );
end;
$$;

create or replace function public.delete_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_receipt_id uuid := gen_random_uuid();
  v_deleted_at timestamptz := now();
  v_receipt jsonb;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  select receipt into v_receipt from public.data_deletion_receipts
    where user_id = v_user_id;
  if found then return v_receipt; end if;
  v_receipt := jsonb_build_object(
    'receiptId', v_receipt_id,
    'remoteUserId', v_user_id,
    'deletedAt', v_deleted_at,
    'authIdentityDeleted', true
  );
  insert into public.data_deletion_receipts (
    user_id, receipt_id, deleted_at, receipt
  ) values (v_user_id, v_receipt_id, v_deleted_at, v_receipt);
  perform set_config('mayhem.allow_event_delete', 'on', true);
  delete from auth.users where id = v_user_id;
  if not found then raise exception 'account deletion was not confirmed'; end if;
  return v_receipt;
end;
$$;

revoke all on function public.mayhem_apply_momentum_dev_v1(uuid, date, timestamptz, text) from public;
revoke all on function public.mayhem_progress_payload(uuid) from public;
revoke all on function public.register_installation(uuid, text, text, text, jsonb) from public;
revoke all on function public.get_content_manifest(text) from public;
revoke all on function public.get_content_revisions(jsonb) from public;
revoke all on function public.get_progress_projection() from public;
revoke all on function public.get_active_season() from public;
revoke all on function public.get_bootstrap_payload(uuid, text, text) from public;
revoke all on function public.get_feed_batch(text, integer) from public;
revoke all on function public.mayhem_apply_season_event_v1(uuid, text, jsonb, text, integer, timestamptz) from public;
revoke all on function public.ingest_events_v2(uuid, jsonb) from public;
revoke all on function public.delete_my_data() from public;

grant execute on function public.register_installation(uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.get_content_manifest(text) to authenticated;
grant execute on function public.get_content_revisions(jsonb) to authenticated;
grant execute on function public.get_progress_projection() to authenticated;
grant execute on function public.get_active_season() to authenticated;
grant execute on function public.get_bootstrap_payload(uuid, text, text) to authenticated;
grant execute on function public.get_feed_batch(text, integer) to authenticated;
grant execute on function public.ingest_events_v2(uuid, jsonb) to authenticated;
grant execute on function public.delete_my_data() to authenticated;
