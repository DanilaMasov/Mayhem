create extension if not exists pgcrypto;

create table public.quests_pool_cloud (
  id text primary key,
  level integer not null check (level between 1 and 3),
  stat_type text not null check (stat_type in ('charisma', 'boldness', 'networking')),
  energy_cost integer not null check (energy_cost between 0 and 50),
  reward_energy integer not null default 0 check (reward_energy between 0 and 100),
  is_shadow boolean not null default false,
  is_boss boolean not null default false,
  quest_text text not null,
  low_pressure_variant text not null,
  advanced_variant text not null,
  safety_reviewed boolean not null default true,
  content_version integer not null default 1,
  updated_at timestamptz not null default now(),
  check (not is_boss or (level = 3 and energy_cost = 50)),
  check (not is_shadow or (energy_cost = 0 and reward_energy > 0))
);

create table public.user_installations (
  installation_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, installation_id)
);

create table public.quest_events_cloud (
  id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  installation_id uuid not null references public.user_installations(installation_id) on delete cascade,
  event_type text not null check (event_type in (
    'quest_started',
    'quest_completed',
    'quest_deferred',
    'reflection_submitted',
    'guide_opened',
    'npc_training_completed',
    'dice_rolled',
    'onboarding_step_completed'
  )),
  quest_id text,
  modifier_id text,
  xp_delta integer not null default 0,
  energy_delta integer not null default 0,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null,
  received_at timestamptz not null default now(),
  primary key (user_id, id)
);

create index quest_events_cloud_user_time_idx
  on public.quest_events_cloud (user_id, created_at, id);
create index quest_events_cloud_quest_type_idx
  on public.quest_events_cloud (user_id, quest_id, event_type, created_at desc);

create table public.user_stats_cloud (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp_charisma integer not null default 0 check (xp_charisma >= 0),
  xp_boldness integer not null default 0 check (xp_boldness >= 0),
  xp_networking integer not null default 0 check (xp_networking >= 0),
  energy integer not null default 100 check (energy between 0 and 100),
  energy_updated_at timestamptz not null default now(),
  completed_offline_count integer not null default 0 check (completed_offline_count >= 0),
  last_event_id uuid,
  updated_at timestamptz not null default now()
);

create table public.daily_boss_quests (
  date date primary key,
  quest_id text not null references public.quests_pool_cloud(id),
  participants_count integer not null default 0 check (participants_count >= 0),
  created_at timestamptz not null default now()
);

create table public.boss_quest_participants (
  boss_date date not null references public.daily_boss_quests(date) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  quest_id text not null references public.quests_pool_cloud(id),
  variant text not null check (variant in ('normal', 'low_pressure')),
  participated_at timestamptz not null default now(),
  primary key (boss_date, user_id)
);

create or replace function public.reject_quest_event_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' and current_setting('mayhem.allow_event_delete', true) = 'on' then
    return old;
  end if;
  raise exception 'quest_events_cloud is append-only';
end;
$$;

create trigger quest_events_cloud_append_only
before update or delete on public.quest_events_cloud
for each row execute function public.reject_quest_event_mutation();

alter table public.quests_pool_cloud enable row level security;
alter table public.user_installations enable row level security;
alter table public.quest_events_cloud enable row level security;
alter table public.user_stats_cloud enable row level security;
alter table public.daily_boss_quests enable row level security;
alter table public.boss_quest_participants enable row level security;

create policy quests_pool_authenticated_read
on public.quests_pool_cloud for select
to authenticated
using (true);

create policy own_installations_read
on public.user_installations for select
to authenticated
using (user_id = auth.uid());

create policy own_events_read
on public.quest_events_cloud for select
to authenticated
using (user_id = auth.uid());

create policy own_stats_read
on public.user_stats_cloud for select
to authenticated
using (user_id = auth.uid());

create policy daily_boss_authenticated_read
on public.daily_boss_quests for select
to authenticated
using (true);

create policy own_boss_participation_read
on public.boss_quest_participants for select
to authenticated
using (user_id = auth.uid());

revoke insert, update, delete on public.quest_events_cloud from anon, authenticated;
revoke insert, update, delete on public.user_stats_cloud from anon, authenticated;
revoke insert, update, delete on public.user_installations from anon, authenticated;

grant select on public.quests_pool_cloud to authenticated;
grant select on public.user_installations to authenticated;
grant select on public.quest_events_cloud to authenticated;
grant select on public.user_stats_cloud to authenticated;
grant select on public.daily_boss_quests to authenticated;
grant select on public.boss_quest_participants to authenticated;
