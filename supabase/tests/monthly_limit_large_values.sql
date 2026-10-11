-- Verify against existing identities only; all row changes are rolled back.
begin;
do $$
declare owner_id uuid;
begin
  select id into owner_id from auth.users order by created_at limit 1;
  if owner_id is null then raise exception 'An existing account is required'; end if;
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
end;
$$;
set local role authenticated;
do $$
declare affected integer;
begin
  insert into public.monthly_spending_limits(user_id, amount, updated_at)
  values(auth.uid(), 75000.25, '2099-01-01')
  on conflict(user_id) do update set amount=excluded.amount, updated_at=excluded.updated_at;
  if not exists(select 1 from public.monthly_spending_limits
      where user_id=auth.uid() and amount=75000.25 and updated_at < '2099-01-01') then
    raise exception 'Large value or timestamp failed';
  end if;
  update public.monthly_spending_limits set amount=1000000.50 where user_id=auth.uid();
  if not exists(select 1 from public.monthly_spending_limits where amount=1000000.50) then
    raise exception 'Million value failed';
  end if;
  begin
    update public.monthly_spending_limits set amount=0.99 where user_id=auth.uid();
    raise exception 'Invalid minimum accepted';
  exception when check_violation then null;
  end;
  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  if exists(select 1 from public.monthly_spending_limits) then
    raise exception 'Another identity can read private data';
  end if;
  update public.monthly_spending_limits set amount=1;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Another identity can update private data'; end if;
end;
$$;
rollback;
select 'large values, minimum, timestamp and isolation passed; rolled back' as result;
