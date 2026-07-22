-- Introduce a reversible competitive rating alongside permanent XP. Existing
-- v1 ranks are mapped to the equivalent v2 score floor without losing XP.

alter table public.user_progress
  add column rating_score integer not null default 1000
    check (rating_score between 0 and 5000),
  add column peak_rating_score integer not null default 1000
    check (peak_rating_score between 0 and 5000),
  add column rating_model_revision text not null
    default 'rating_model_dev_v1';

update public.user_progress
set rating_score = case (rank_family, rank_tier)
    when ('spark', 1) then 1000
    when ('spark', 2) then 1125
    when ('spark', 3) then 1250
    when ('mover', 1) then 1400
    when ('mover', 2) then 1550
    when ('mover', 3) then 1700
    when ('catalyst', 1) then 1875
    when ('catalyst', 2) then 2050
    when ('catalyst', 3) then 2250
    when ('maverick', 1) then 2475
    when ('maverick', 2) then 2700
    when ('maverick', 3) then 2950
    when ('icon', 1) then 3225
    when ('icon', 2) then 3525
    when ('icon', 3) then 3850
    when ('mayhem', 1) then 4200
    else 1000
  end,
  peak_rating_score = case (rank_family, rank_tier)
    when ('spark', 1) then 1000
    when ('spark', 2) then 1125
    when ('spark', 3) then 1250
    when ('mover', 1) then 1400
    when ('mover', 2) then 1550
    when ('mover', 3) then 1700
    when ('catalyst', 1) then 1875
    when ('catalyst', 2) then 2050
    when ('catalyst', 3) then 2250
    when ('maverick', 1) then 2475
    when ('maverick', 2) then 2700
    when ('maverick', 3) then 2950
    when ('icon', 1) then 3225
    when ('icon', 2) then 3525
    when ('icon', 3) then 3850
    when ('mayhem', 1) then 4200
    else 1000
  end;

alter table public.user_progress
  alter column rank_config_revision set default 'rank_config_dev_v2';

create or replace function public.mayhem_rank_dev_v2(
  p_rating_score integer,
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
  if p_rating_score < 0 or p_rating_score > 5000 then
    raise exception 'invalid rating score';
  end if;
  for threshold in
    select * from (values
      ('spark', 1, 1000, 0),
      ('spark', 2, 1125, 0),
      ('spark', 3, 1250, 0),
      ('mover', 1, 1400, 100),
      ('mover', 2, 1550, 150),
      ('mover', 3, 1700, 200),
      ('catalyst', 1, 1875, 300),
      ('catalyst', 2, 2050, 400),
      ('catalyst', 3, 2250, 500),
      ('maverick', 1, 2475, 650),
      ('maverick', 2, 2700, 800),
      ('maverick', 3, 2950, 1000),
      ('icon', 1, 3225, 1200),
      ('icon', 2, 3525, 1500),
      ('icon', 3, 3850, 1800),
      ('mayhem', 1, 4200, 2200)
    ) as ladder(family, tier, rating_score, minimum_trait_xp)
    order by rating_score
  loop
    exit when p_rating_score < threshold.rating_score or
      least(p_initiation_xp, p_expression_xp, p_connection_xp, p_presence_xp) <
        threshold.minimum_trait_xp;
    result := jsonb_build_object(
      'family', threshold.family,
      'tier', threshold.tier
    );
  end loop;
  return result || jsonb_build_object('configRevision', 'rank_config_dev_v2');
end;
$$;

create or replace function public.mayhem_rating_delta_dev_v1(
  p_outcome text,
  p_felt text,
  p_route text,
  p_intensity integer,
  p_repeat_percent integer
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  delta integer;
begin
  if p_outcome not in ('attempted', 'completed') or
     p_felt not in (
       'easierThanExpected', 'aboutAsExpected',
       'harderThanExpected', 'stoppedEarly'
     ) or
     p_route not in ('normal', 'lowPressure', 'advanced') or
     p_intensity not between 1 and 5 or
     p_repeat_percent not between 0 and 100 then
    raise exception 'invalid rating observation';
  end if;

  delta := case (p_outcome, p_felt)
    when ('completed', 'easierThanExpected') then 18
    when ('completed', 'aboutAsExpected') then 25
    when ('completed', 'harderThanExpected') then 32
    when ('completed', 'stoppedEarly') then 5
    when ('attempted', 'easierThanExpected') then 8
    when ('attempted', 'aboutAsExpected') then 3
    when ('attempted', 'harderThanExpected') then -12
    when ('attempted', 'stoppedEarly') then -22
  end;

  if delta > 0 then
    delta := delta + (p_intensity - 3) * 2;
    if p_route = 'advanced' then
      delta := round(delta * 1.15);
    elsif p_route = 'lowPressure' then
      delta := round(delta * 0.80);
    end if;
    delta := round(delta * p_repeat_percent / 100.0);
  elsif delta < 0 and p_route = 'lowPressure' then
    delta := round(delta * 0.50);
  end if;
  return delta;
end;
$$;

create or replace function public.mayhem_apply_rating_dev_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  attempt public.challenge_attempts%rowtype;
  content public.content_item_revisions%rowtype;
  outcome text;
  felt text;
  intensity integer;
  prior_terminal integer;
  repeat_percent integer;
  delta integer;
  next_rank jsonb;
begin
  if new.event_type not in ('challenge_attempted', 'challenge_completed') then
    return new;
  end if;

  select * into attempt
  from public.challenge_attempts
  where user_id = new.user_id and attempt_id = new.attempt_id;
  if not found then raise exception 'rating attempt is unavailable'; end if;

  select * into content
  from public.content_item_revisions
  where content_id = attempt.content_id
    and revision = attempt.content_revision
  order by case when locale = 'ru-RU' then 0 else 1 end, locale
  limit 1;
  if not found then raise exception 'rating content is unavailable'; end if;

  outcome := case
    when new.event_type = 'challenge_completed' then 'completed'
    else 'attempted'
  end;
  felt := new.payload ->> 'felt';
  intensity := coalesce((content.payload ->> 'intensity')::integer, 3);
  select count(*) into prior_terminal
  from public.challenge_attempts previous
  where previous.user_id = new.user_id
    and previous.content_id = attempt.content_id
    and previous.content_revision = attempt.content_revision
    and previous.attempt_id <> attempt.attempt_id
    and previous.status in ('attempted', 'completed')
    and previous.resolved_at >= new.occurred_at_utc - interval '7 days'
    and previous.resolved_at <= new.occurred_at_utc;
  repeat_percent := case
    when prior_terminal <= 0 then 100
    when prior_terminal = 1 then 75
    else 50
  end;
  delta := public.mayhem_rating_delta_dev_v1(
    outcome, felt, attempt.selected_route, intensity, repeat_percent
  );

  update public.user_progress
  set rating_score = greatest(0, least(5000, rating_score + delta)),
      peak_rating_score = greatest(
        peak_rating_score,
        greatest(0, least(5000, rating_score + delta))
      ),
      rating_model_revision = 'rating_model_dev_v1'
  where user_id = new.user_id;

  select public.mayhem_rank_dev_v2(
    rating_score, initiation_xp, expression_xp, connection_xp, presence_xp
  ) into next_rank
  from public.user_progress
  where user_id = new.user_id;
  update public.user_progress
  set rank_family = next_rank ->> 'family',
      rank_tier = (next_rank ->> 'tier')::integer,
      rank_config_revision = next_rank ->> 'configRevision'
  where user_id = new.user_id;
  return new;
end;
$$;

drop trigger if exists user_events_apply_rating_v1 on public.user_events;
create trigger user_events_apply_rating_v1
after insert on public.user_events
for each row execute function public.mayhem_apply_rating_dev_v1();

update public.user_progress progress
set rank_family = public.mayhem_rank_dev_v2(
      progress.rating_score,
      progress.initiation_xp,
      progress.expression_xp,
      progress.connection_xp,
      progress.presence_xp
    ) ->> 'family',
    rank_tier = (public.mayhem_rank_dev_v2(
      progress.rating_score,
      progress.initiation_xp,
      progress.expression_xp,
      progress.connection_xp,
      progress.presence_xp
    ) ->> 'tier')::integer,
    rank_config_revision = 'rank_config_dev_v2';

create or replace function public.mayhem_progress_payload(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'totalXp', p.total_xp,
    'ratingScore', p.rating_score,
    'peakRatingScore', p.peak_rating_score,
    'ratingModelRevision', p.rating_model_revision,
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

revoke all on function public.mayhem_rank_dev_v2(integer, bigint, bigint, bigint, bigint)
  from public, anon, authenticated;
revoke all on function public.mayhem_rating_delta_dev_v1(text, text, text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.mayhem_apply_rating_dev_v1()
  from public, anon, authenticated;
revoke all on function public.mayhem_progress_payload(uuid)
  from public, anon, authenticated;
