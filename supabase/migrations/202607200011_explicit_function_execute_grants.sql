-- Supabase projects may grant newly created functions directly to Data API
-- roles. Revoke every SECURITY DEFINER entry point, then restore only the
-- authenticated RPC allowlist used by Mayhem clients.

do $$
declare
  target record;
begin
  for target in
    select
      namespace.nspname as schema_name,
      proc.proname as function_name,
      pg_get_function_identity_arguments(proc.oid) as identity_arguments
    from pg_proc proc
    join pg_namespace namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'public' and proc.prosecdef
  loop
    execute format(
      'revoke all privileges on function %I.%I(%s) from public, anon, authenticated',
      target.schema_name,
      target.function_name,
      target.identity_arguments
    );
  end loop;
end;
$$;

grant execute on function public.ingest_quest_events(uuid, jsonb)
  to authenticated;
grant execute on function public.delete_my_cloud_data()
  to authenticated;
grant execute on function public.register_installation(uuid, text, text, text, jsonb)
  to authenticated;
grant execute on function public.get_content_manifest(text)
  to authenticated;
grant execute on function public.get_content_revisions(jsonb)
  to authenticated;
grant execute on function public.get_progress_projection()
  to authenticated;
grant execute on function public.get_active_season()
  to authenticated;
grant execute on function public.get_bootstrap_payload(uuid, text, text)
  to authenticated;
grant execute on function public.get_feed_batch(text, integer)
  to authenticated;
grant execute on function public.ingest_events_v2(uuid, jsonb)
  to authenticated;
grant execute on function public.delete_my_data()
  to authenticated;
