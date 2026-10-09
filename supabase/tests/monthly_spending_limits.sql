-- DEVELOPMENT ONLY. Apply the migration first. All test data is rolled back.
begin;
insert into auth.users (id, email) values
  ('11111111-1111-4111-8111-111111111111', 'monthly-limit-a@example.invalid'),
  ('22222222-2222-4222-8222-222222222222', 'monthly-limit-b@example.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
insert into public.monthly_spending_limits (user_id, amount, updated_at)
values ('11111111-1111-4111-8111-111111111111', 6200, '2099-01-01');

do $$
begin
  if not exists (select 1 from public.monthly_spending_limits
      where amount = 6200 and updated_at < '2099-01-01') then
    raise exception 'FAIL: own row or server timestamp';
  end if;
  begin
    update public.monthly_spending_limits set amount = 0.99;
    raise exception 'FAIL: invalid amount accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.monthly_spending_limits (user_id, amount)
      values ('22222222-2222-4222-8222-222222222222', 5000);
    raise exception 'FAIL: inserted row for another user';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
do $$
declare affected integer;
begin
  if exists (select 1 from public.monthly_spending_limits) then
    raise exception 'FAIL: another user can read the row';
  end if;
  update public.monthly_spending_limits set amount = 9000;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'FAIL: cross-user update'; end if;
end;
$$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform 1 from public.monthly_spending_limits;
    raise exception 'FAIL: anonymous read allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
rollback;
