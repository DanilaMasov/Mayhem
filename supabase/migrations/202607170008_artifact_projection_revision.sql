-- Artifact ownership is part of the reconciled server projection. Advance the
-- projection revision only when a genuinely new artifact row is issued.

create or replace function public.advance_artifact_projection_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.user_progress (user_id, projection_revision, updated_at)
  values (new.user_id, 1, now())
  on conflict (user_id) do update set
    projection_revision = public.user_progress.projection_revision + 1,
    updated_at = excluded.updated_at;
  return new;
end;
$$;

revoke all on function public.advance_artifact_projection_revision()
  from public, anon, authenticated;

create trigger user_artifacts_advance_projection_revision
after insert on public.user_artifacts
for each row execute function public.advance_artifact_projection_revision();
