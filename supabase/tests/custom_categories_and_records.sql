-- Uses an existing identity only for RLS claims. No users are created/changed.
begin;
do $$ declare owner uuid; begin
  select id into owner from auth.users order by id limit 1;
  if owner is null then raise exception 'Requires an existing account'; end if;
  perform set_config('sereno.test_owner', owner::text, true);
  perform set_config('request.jwt.claim.sub', owner::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', owner, 'role', 'authenticated')::text, true);
end $$;
set local role authenticated;
do $$ declare owner uuid := current_setting('sereno.test_owner')::uuid; n integer; begin
  insert into public.account_categories(user_id,type,name_key,name,icon)
    values(owner,'expense','codex rollback category','Codex rollback category','👨‍👩‍👧‍👦');
  select count(*) into n from public.account_categories where user_id=owner and name_key='codex rollback category' and icon='👨‍👩‍👧‍👦';
  if n <> 1 then raise exception 'Own category/Unicode read failed'; end if;
  update public.account_categories set icon='🇧🇷', updated_at='2000-01-01' where user_id=owner and name_key='codex rollback category';
  if exists(select 1 from public.account_categories where user_id=owner and name_key='codex rollback category' and updated_at<'2020-01-01') then raise exception 'Server timestamp failed'; end if;
  insert into public.account_financial_records(user_id,kind,id,payload) values
    (owner,'budget','codex-rollback-budget','{"id":"codex-rollback-budget","category":"Codex rollback category","categoryIcon":"🇧🇷","limit":50,"createdAt":"2026-10-10T00:00:00"}'),
    (owner,'recurring','codex-rollback-rule','{"id":"codex-rollback-rule","name":"Teste","category":"Codex rollback category","amount":1,"frequency":"monthly","dueDay":10,"active":true,"createdAt":"2026-10-10T00:00:00"}'),
    (owner,'paid','codex-rollback-paid','{"id":"codex-rollback-paid","rule_id":"codex-rollback-rule","month":"2026-10","paid":true}');
  select count(*) into n from public.account_financial_records where user_id=owner and id like 'codex-rollback-%';
  if n <> 3 then raise exception 'Own records read failed'; end if;
  update public.account_financial_records set is_deleted=true,payload=null where user_id=owner and id='codex-rollback-budget';
  if not exists(select 1 from public.account_financial_records where user_id=owner and id='codex-rollback-budget' and is_deleted and payload is null) then raise exception 'Tombstone failed'; end if;
  begin
    update public.account_categories set user_id='00000000-0000-4000-8000-000000000001' where user_id=owner and name_key='codex rollback category';
    raise exception 'Ownership transfer allowed';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.account_financial_records where user_id=owner and id='codex-rollback-paid';
    raise exception 'Physical DELETE allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.account_financial_records(user_id,kind,id,payload) values(owner,'budget','invalid','{"id":"invalid","category":"Teste","limit":-1,"createdAt":"2026-10-10"}');
    raise exception 'Invalid budget accepted';
  exception when check_violation then null; end;
  begin
    delete from public.account_categories where user_id=owner;
    raise exception 'Category DELETE allowed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
end $$;
set local role authenticated;
do $$ declare n integer; begin
  if exists(select 1 from public.account_categories where name_key='codex rollback category') then raise exception 'Other account can read category'; end if;
  if exists(select 1 from public.account_financial_records where id like 'codex-rollback-%') then raise exception 'Other account can read records'; end if;
  update public.account_financial_records set is_deleted=true,payload=null where id='codex-rollback-rule';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Other account can update records'; end if;
  begin
    insert into public.account_categories(user_id,type,name_key,name,icon) values(current_setting('sereno.test_owner')::uuid,'income','forbidden','forbidden','💰');
    raise exception 'Other account can insert category';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.account_financial_records(user_id,kind,id,payload,is_deleted) values(current_setting('sereno.test_owner')::uuid,'budget','forbidden',null,true);
    raise exception 'Other account can insert record';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
  begin perform 1 from public.account_categories; raise exception 'Anon SELECT category allowed'; exception when insufficient_privilege then null; end;
  begin perform 1 from public.account_financial_records; raise exception 'Anon SELECT records allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
select 'category and financial record security checks passed; rollback complete' as result;
