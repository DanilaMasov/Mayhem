-- Additive vNext backend baseline. Legacy tables remain available during rollout.

alter table public.user_installations
  add column if not exists local_user_id text,
  add column if not exists platform text,
  add column if not exists app_version text,
  add column if not exists capabilities jsonb not null default '{}'::jsonb,
  add column if not exists linked_at timestamptz;

create unique index if not exists user_installations_user_local_idx
  on public.user_installations (user_id, local_user_id)
  where local_user_id is not null;

create table public.content_item_revisions (
  content_id text not null,
  revision integer not null check (revision > 0),
  locale text not null,
  content_type text not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  safety jsonb not null check (jsonb_typeof(safety) = 'object'),
  media jsonb,
  checksum text not null check (checksum ~ '^[0-9a-f]{64}$'),
  active boolean not null default false,
  published_at timestamptz not null,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (content_id, revision, locale),
  check (media is null or jsonb_typeof(media) = 'object'),
  check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create index content_item_revisions_active_idx
  on public.content_item_revisions (locale, content_type, published_at desc)
  where active;

create table public.content_manifests (
  manifest_id uuid primary key default gen_random_uuid(),
  locale text not null,
  revision bigint not null check (revision > 0),
  checksum text not null check (checksum ~ '^[0-9a-f]{64}$'),
  generated_at timestamptz not null,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  unique (locale, revision),
  unique (manifest_id, locale)
);

create unique index content_manifests_one_active_locale_idx
  on public.content_manifests (locale)
  where active;

create table public.content_manifest_items (
  manifest_id uuid not null,
  locale text not null,
  position integer not null check (position >= 0),
  content_id text not null,
  content_revision integer not null check (content_revision > 0),
  primary key (manifest_id, position),
  unique (manifest_id, content_id),
  foreign key (manifest_id, locale)
    references public.content_manifests(manifest_id, locale) on delete cascade,
  foreign key (content_id, content_revision, locale)
    references public.content_item_revisions(content_id, revision, locale)
);

create table public.feed_batches (
  batch_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  locale text not null,
  algorithm_revision text not null,
  capability_revision integer not null default 1 check (capability_revision > 0),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  unique (user_id, batch_id)
);

create table public.feed_assignments (
  assignment_id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.feed_batches(batch_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null,
  content_revision integer not null check (content_revision > 0),
  locale text not null,
  position integer not null check (position >= 0),
  assignment_reason text not null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  assigned_at timestamptz not null default now(),
  expires_at timestamptz,
  unique (batch_id, position),
  unique (user_id, assignment_id),
  foreign key (content_id, content_revision, locale)
    references public.content_item_revisions(content_id, revision, locale)
);

create index feed_assignments_user_time_idx
  on public.feed_assignments (user_id, assigned_at desc);

create table public.challenge_attempts (
  attempt_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  assignment_id uuid not null references public.feed_assignments(assignment_id),
  content_id text not null,
  content_revision integer not null check (content_revision > 0),
  selected_route text not null check (selected_route in ('normal', 'low_pressure', 'advanced')),
  status text not null check (status in ('active', 'deferred', 'abandoned', 'attempted', 'completed')),
  accepted_at timestamptz not null,
  resolved_at timestamptz,
  reward_xp integer check (reward_xp is null or reward_xp >= 0),
  reward_policy_revision text,
  updated_at timestamptz not null default now(),
  unique (user_id, assignment_id),
  unique (user_id, attempt_id)
);

create unique index challenge_attempts_one_active_idx
  on public.challenge_attempts (user_id)
  where status = 'active';

create table public.user_events (
  event_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  installation_id uuid not null references public.user_installations(installation_id) on delete cascade,
  client_sequence bigint not null check (client_sequence > 0),
  schema_version integer not null check (schema_version = 2),
  event_type text not null,
  assignment_id uuid,
  attempt_id uuid,
  content_id text,
  content_revision integer,
  occurred_at_utc timestamptz not null,
  timezone_id text not null,
  timezone_offset_minutes integer not null check (timezone_offset_minutes between -840 and 840),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  received_at timestamptz not null default now(),
  primary key (user_id, event_id),
  unique (installation_id, client_sequence),
  check (
    (content_id is null and content_revision is null) or
    (content_id is not null and content_revision > 0)
  )
);

create index user_events_user_time_idx
  on public.user_events (user_id, occurred_at_utc, event_id);
create index user_events_attempt_idx
  on public.user_events (user_id, attempt_id, event_type);

create table public.user_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_xp bigint not null default 0 check (total_xp >= 0),
  initiation_xp bigint not null default 0 check (initiation_xp >= 0),
  expression_xp bigint not null default 0 check (expression_xp >= 0),
  connection_xp bigint not null default 0 check (connection_xp >= 0),
  presence_xp bigint not null default 0 check (presence_xp >= 0),
  rank_family text not null default 'spark',
  rank_tier integer not null default 1 check (rank_tier between 1 and 3),
  rank_config_revision text not null default 'rank_config_dev_v1',
  reward_policy_revision text not null default 'reward_policy_dev_v1',
  completed_count integer not null default 0 check (completed_count >= 0),
  attempted_count integer not null default 0 check (attempted_count >= 0),
  projection_revision bigint not null default 0 check (projection_revision >= 0),
  updated_at timestamptz not null default now()
);

create table public.user_difficulty_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  trait text not null check (trait in ('initiation', 'expression', 'connection', 'presence')),
  rating numeric(4, 2) not null default 2 check (rating between 1 and 5),
  confidence numeric(4, 3) not null default 0 check (confidence between 0 and 1),
  observations integer not null default 0 check (observations >= 0),
  recommended_intensity integer not null default 2 check (recommended_intensity between 1 and 5),
  algorithm_revision text not null default 'difficulty_model_dev_v1',
  updated_at timestamptz not null default now(),
  primary key (user_id, trait)
);

create table public.user_momentum (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_days integer not null default 0 check (current_days >= 0),
  longest_days integer not null default 0 check (longest_days >= current_days),
  shields_available integer not null default 0 check (shields_available between 0 and 2),
  last_earned_local_date date,
  last_earned_at_utc timestamptz,
  last_earned_timezone_id text,
  protected_local_dates date[] not null default '{}',
  pending_local_date date,
  pending_earned_at_utc timestamptz,
  pending_timezone_id text,
  policy_revision text not null default 'momentum_policy_dev_v1',
  projection_revision bigint not null default 0 check (projection_revision >= 0),
  updated_at timestamptz not null default now()
);

create table public.seasons (
  season_id text primary key,
  revision integer not null check (revision > 0),
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  active boolean not null default false,
  check (starts_at < ends_at)
);

create table public.season_participation (
  season_id text not null references public.seasons(season_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  completed_days integer not null default 0 check (completed_days >= 0),
  primary key (season_id, user_id)
);

create table public.season_day_completions (
  season_id text not null,
  user_id uuid not null,
  day integer not null check (day between 1 and 7),
  completed_at timestamptz not null,
  primary key (season_id, user_id, day),
  foreign key (season_id, user_id)
    references public.season_participation(season_id, user_id) on delete cascade
);

create table public.boss_events (
  boss_event_id text primary key,
  season_id text references public.seasons(season_id) on delete cascade,
  content_id text not null,
  content_revision integer not null check (content_revision > 0),
  locale text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  check (starts_at < ends_at),
  foreign key (content_id, content_revision, locale)
    references public.content_item_revisions(content_id, revision, locale)
);

create table public.boss_participation (
  boss_event_id text not null references public.boss_events(boss_event_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  participated_at timestamptz not null default now(),
  primary key (boss_event_id, user_id)
);

create table public.user_artifacts (
  artifact_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  season_id text not null references public.seasons(season_id) on delete cascade,
  season_revision integer not null check (season_revision > 0),
  boss_event_id text not null references public.boss_events(boss_event_id) on delete cascade,
  unlocked_at timestamptz not null,
  primary key (artifact_id, user_id)
);

create table public.social_proof_aggregates (
  aggregate_key text primary key,
  season_id text not null references public.seasons(season_id) on delete cascade,
  season_revision integer not null check (season_revision > 0),
  boss_event_id text not null references public.boss_events(boss_event_id) on delete cascade,
  value bigint not null check (value >= 0),
  threshold integer not null default 20 check (threshold >= 20),
  window_starts_at timestamptz not null,
  window_ends_at timestamptz not null,
  updated_at timestamptz not null default now(),
  check (window_starts_at < window_ends_at)
);

create table public.feature_flags (
  flag_key text not null,
  environment text not null default 'production',
  cohort text not null default 'all',
  enabled boolean not null default false,
  required_capability_key text,
  required_capability_revision integer,
  config jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (flag_key, environment, cohort),
  check (
    (required_capability_key is null and required_capability_revision is null) or
    (required_capability_key is not null and required_capability_revision > 0)
  )
);

create table public.data_deletion_receipts (
  user_id uuid primary key,
  receipt_id uuid not null unique,
  deleted_at timestamptz not null,
  receipt jsonb not null check (jsonb_typeof(receipt) = 'object')
);

create or replace function public.reject_vnext_immutable_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' and current_setting('mayhem.allow_event_delete', true) = 'on' then
    return old;
  end if;
  raise exception '% is immutable', tg_table_name;
end;
$$;

create trigger content_item_revisions_immutable
before update or delete on public.content_item_revisions
for each row execute function public.reject_vnext_immutable_mutation();

create trigger user_events_append_only
before update or delete on public.user_events
for each row execute function public.reject_vnext_immutable_mutation();

alter table public.content_item_revisions enable row level security;
alter table public.content_manifests enable row level security;
alter table public.content_manifest_items enable row level security;
alter table public.feed_batches enable row level security;
alter table public.feed_assignments enable row level security;
alter table public.challenge_attempts enable row level security;
alter table public.user_events enable row level security;
alter table public.user_progress enable row level security;
alter table public.user_difficulty_profiles enable row level security;
alter table public.user_momentum enable row level security;
alter table public.seasons enable row level security;
alter table public.season_participation enable row level security;
alter table public.season_day_completions enable row level security;
alter table public.boss_events enable row level security;
alter table public.boss_participation enable row level security;
alter table public.user_artifacts enable row level security;
alter table public.social_proof_aggregates enable row level security;
alter table public.feature_flags enable row level security;
alter table public.data_deletion_receipts enable row level security;

create policy active_content_authenticated_read
on public.content_item_revisions for select to authenticated
using (
  published_at <= now() and
  (starts_at is null or starts_at <= now()) and
  (ends_at is null or ends_at > now()) and
  exists (
    select 1
    from public.content_manifest_items item
    join public.content_manifests manifest
      on manifest.manifest_id = item.manifest_id
     and manifest.locale = item.locale
    where item.content_id = content_item_revisions.content_id
      and item.content_revision = content_item_revisions.revision
      and item.locale = content_item_revisions.locale
      and manifest.active
      and manifest.generated_at <= now()
  )
);
create policy active_content_manifests_read
on public.content_manifests for select to authenticated
using (active and generated_at <= now());
create policy active_content_manifest_items_read
on public.content_manifest_items for select to authenticated
using (
  exists (
    select 1 from public.content_manifests manifest
    where manifest.manifest_id = content_manifest_items.manifest_id
      and manifest.locale = content_manifest_items.locale
      and manifest.active
      and manifest.generated_at <= now()
  )
);
create policy own_feed_batches_read on public.feed_batches for select to authenticated
using (user_id = auth.uid());
create policy own_feed_assignments_read on public.feed_assignments for select to authenticated
using (user_id = auth.uid());
create policy own_challenge_attempts_read on public.challenge_attempts for select to authenticated
using (user_id = auth.uid());
create policy own_vnext_events_read on public.user_events for select to authenticated
using (user_id = auth.uid());
create policy own_progress_read on public.user_progress for select to authenticated
using (user_id = auth.uid());
create policy own_difficulty_read on public.user_difficulty_profiles for select to authenticated
using (user_id = auth.uid());
create policy own_momentum_read on public.user_momentum for select to authenticated
using (user_id = auth.uid());
create policy active_seasons_read on public.seasons for select to authenticated
using (active and starts_at <= now() and ends_at > now());
create policy own_season_participation_read on public.season_participation for select to authenticated
using (user_id = auth.uid());
create policy own_season_day_completions_read on public.season_day_completions for select to authenticated
using (user_id = auth.uid());
create policy active_boss_events_read on public.boss_events for select to authenticated
using (starts_at <= now() and ends_at > now());
create policy own_boss_participation_read_vnext on public.boss_participation for select to authenticated
using (user_id = auth.uid());
create policy own_user_artifacts_read on public.user_artifacts for select to authenticated
using (user_id = auth.uid());
create policy thresholded_social_proof_read on public.social_proof_aggregates for select to authenticated
using (value >= threshold and window_starts_at <= now() and window_ends_at > now());

revoke all on public.content_item_revisions from anon, authenticated;
revoke all on public.content_manifests from anon, authenticated;
revoke all on public.content_manifest_items from anon, authenticated;
revoke all on public.feed_batches from anon, authenticated;
revoke all on public.feed_assignments from anon, authenticated;
revoke all on public.challenge_attempts from anon, authenticated;
revoke all on public.user_events from anon, authenticated;
revoke all on public.user_progress from anon, authenticated;
revoke all on public.user_difficulty_profiles from anon, authenticated;
revoke all on public.user_momentum from anon, authenticated;
revoke all on public.season_participation from anon, authenticated;
revoke all on public.season_day_completions from anon, authenticated;
revoke all on public.boss_participation from anon, authenticated;
revoke all on public.user_artifacts from anon, authenticated;
revoke all on public.seasons from anon, authenticated;
revoke all on public.boss_events from anon, authenticated;
revoke all on public.social_proof_aggregates from anon, authenticated;
revoke all on public.feature_flags from anon, authenticated;
revoke all on public.data_deletion_receipts from anon, authenticated;

grant select on public.content_item_revisions to authenticated;
grant select on public.content_manifests to authenticated;
grant select on public.content_manifest_items to authenticated;
grant select on public.feed_batches to authenticated;
grant select on public.feed_assignments to authenticated;
grant select on public.challenge_attempts to authenticated;
grant select on public.user_events to authenticated;
grant select on public.user_progress to authenticated;
grant select on public.user_difficulty_profiles to authenticated;
grant select on public.user_momentum to authenticated;
grant select on public.season_participation to authenticated;
grant select on public.season_day_completions to authenticated;
grant select on public.boss_participation to authenticated;
grant select on public.user_artifacts to authenticated;
