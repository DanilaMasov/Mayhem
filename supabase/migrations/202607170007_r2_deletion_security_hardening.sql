-- R2 hardening discovered by the live-acceptance delta audit.
-- Keep legacy RPCs callable while removing public-schema name resolution.

alter function public.ingest_quest_events(uuid, jsonb)
  set search_path to '';

alter function public.delete_my_cloud_data()
  set search_path to '';

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
  v_social record;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  select receipt into v_receipt from public.data_deletion_receipts
    where user_id = v_user_id;
  if found then return v_receipt; end if;

  for v_social in
    select aggregate.aggregate_key, count(*)::bigint as decrement_by
    from public.boss_participation participation
    join public.social_proof_aggregates aggregate
      on aggregate.boss_event_id = participation.boss_event_id
    where participation.user_id = v_user_id
    group by aggregate.aggregate_key
  loop
    perform pg_advisory_xact_lock(
      hashtextextended('social:' || v_social.aggregate_key, 0)
    );
    update public.social_proof_aggregates
    set value = greatest(0, value - v_social.decrement_by),
        updated_at = now()
    where aggregate_key = v_social.aggregate_key;
  end loop;

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

revoke all on function public.delete_my_data() from public, anon;
grant execute on function public.delete_my_data() to authenticated;
