-- Run only AFTER the migration. Uses one existing user without modifying it.
-- All writes to the transaction table are rolled back; no accounts are created.
begin;
do $$
declare owner_id uuid;
begin
  select id into owner_id from auth.users order by created_at limit 1;
  if owner_id is null then raise exception 'An existing test account is required'; end if;
  perform set_config('test.transactions_owner', owner_id::text, true);
  perform set_config('test.transactions_id', gen_random_uuid()::text, true);
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
end;
$$;
set local role authenticated;
insert into public.account_transactions(user_id, id, payload, updated_at)
select current_setting('test.transactions_owner')::uuid,
  current_setting('test.transactions_id')::uuid,
  jsonb_build_object('id', current_setting('test.transactions_id'), 'type', 'expense',
    'amount', 50, 'category', 'Teste', 'date', '2026-10-09T12:00:00',
    'createdAt', '2026-10-09T12:00:00'), '2099-01-01';
do $$
begin
  if not exists(select 1 from public.account_transactions
      where id = current_setting('test.transactions_id')::uuid
      and updated_at < '2099-01-01') then
    raise exception 'FAIL: owner read or server timestamp';
  end if;
  begin
    update public.account_transactions set payload = jsonb_set(payload, '{amount}', '-1')
      where id = current_setting('test.transactions_id')::uuid;
    raise exception 'FAIL: negative amount accepted';
  exception when check_violation then null;
  end;
  begin
    delete from public.account_transactions where id = current_setting('test.transactions_id')::uuid;
    raise exception 'FAIL: physical delete allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
do $$
declare affected integer;
begin
  if exists(select 1 from public.account_transactions
      where id = current_setting('test.transactions_id')::uuid) then
    raise exception 'FAIL: another identity can read owner data';
  end if;
  update public.account_transactions set is_deleted = true, payload = null
    where id = current_setting('test.transactions_id')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'FAIL: another identity can update owner data'; end if;
  begin
    insert into public.account_transactions(user_id, id, payload, is_deleted)
      values(current_setting('test.transactions_owner')::uuid, gen_random_uuid(), null, true);
    raise exception 'FAIL: another identity can insert owner data';
  exception when insufficient_privilege then null;
  end;
end;
$$;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform 1 from public.account_transactions;
    raise exception 'FAIL: anonymous read allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
rollback;
