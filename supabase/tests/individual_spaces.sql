-- Production-safe validation: all records roll back; no accounts are created.
begin;
do $$
declare owner_id text;
begin
  select id::text into owner_id from auth.users limit 1;
  if owner_id is null then raise exception 'Requires an existing account'; end if;
  perform set_config('request.jwt.claim.sub', owner_id, true);
  perform set_config('sereno.test_owner', owner_id, true);
  perform set_config('sereno.test_space', 'validation-space-' || gen_random_uuid()::text, true);
  if has_table_privilege('anon', 'public.account_financial_records', 'select')
     or has_table_privilege('authenticated', 'public.account_financial_records', 'delete') then
    raise exception 'Unexpected grants';
  end if;
end $$;
set local role authenticated;
do $$
declare test_id text := current_setting('sereno.test_space');
        owner_id uuid := current_setting('sereno.test_owner')::uuid;
        affected integer;
        transaction_id uuid := gen_random_uuid();
begin
  insert into public.account_transactions(user_id,id,payload) values (owner_id,transaction_id,
    jsonb_build_object('id',transaction_id::text,'type','expense','amount',0.01,
      'category','Validação','date',now()::text,'createdAt',now()::text,
      'spaceId','home','spaceName','Casa'));
  if not exists(select 1 from public.account_transactions where id=transaction_id and payload->>'spaceId'='home') then
    raise exception 'Transaction space did not round trip';
  end if;
  insert into public.account_financial_records(user_id,kind,id,payload)
    values (owner_id,'space',test_id,jsonb_build_object('id',test_id,'name','Teste','icon','🏠'));
  if not exists(select 1 from public.account_financial_records where id=test_id and kind='space' and updated_at is not null) then
    raise exception 'Owner cannot read saved space';
  end if;
  update public.account_financial_records set payload=jsonb_build_object('id',test_id,'name','Teste atualizado','icon','✈️')
    where id=test_id and kind='space';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Owner cannot update'; end if;
  begin
    update public.account_financial_records set payload=jsonb_build_object('id',test_id,'name','','icon','🏠') where id=test_id and kind='space';
    raise exception 'Empty name accepted';
  exception when check_violation then null; end;
  begin
    update public.account_financial_records set payload=jsonb_build_object('id',test_id,'name','Teste') where id=test_id and kind='space';
    raise exception 'Missing emoji accepted';
  exception when check_violation then null; end;
  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  if exists(select 1 from public.account_financial_records where id=test_id) then
    raise exception 'Another identity can read space';
  end if;
  update public.account_financial_records set is_deleted=true,payload=null where id=test_id;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Another identity can update space'; end if;
  begin
    insert into public.account_financial_records(user_id,kind,id,payload)
      values (owner_id,'space',test_id || '-foreign',jsonb_build_object('id',test_id || '-foreign','name','Teste','icon','🏠'));
    raise exception 'Foreign insert accepted';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  update public.account_financial_records set is_deleted=true,payload=null where id=test_id and kind='space';
  if not exists(select 1 from public.account_financial_records where id=test_id and is_deleted and payload is null) then
    raise exception 'Space tombstone invalid';
  end if;
end $$;
reset role;
rollback;
