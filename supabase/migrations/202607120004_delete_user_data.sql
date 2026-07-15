create or replace function public.delete_my_cloud_data()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_boss record;
  v_events_deleted integer := 0;
  v_installations_deleted integer := 0;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  for v_boss in
    select boss_date, count(*)::integer as participant_count
    from public.boss_quest_participants
    where user_id = v_user_id
    group by boss_date
  loop
    update public.daily_boss_quests
    set participants_count = greatest(
      0,
      participants_count - v_boss.participant_count
    )
    where date = v_boss.boss_date;
  end loop;

  delete from public.boss_quest_participants where user_id = v_user_id;
  perform set_config('mayhem.allow_event_delete', 'on', true);
  delete from public.quest_events_cloud where user_id = v_user_id;
  get diagnostics v_events_deleted = row_count;
  delete from public.user_stats_cloud where user_id = v_user_id;
  delete from public.user_installations where user_id = v_user_id;
  get diagnostics v_installations_deleted = row_count;

  return jsonb_build_object(
    'deleted', true,
    'eventsDeleted', v_events_deleted,
    'installationsDeleted', v_installations_deleted
  );
end;
$$;

revoke all on function public.delete_my_cloud_data() from public, anon;
grant execute on function public.delete_my_cloud_data() to authenticated;
