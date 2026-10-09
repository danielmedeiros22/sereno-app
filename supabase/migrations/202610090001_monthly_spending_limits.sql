-- Applied to rdlofauxvsbdytvvmlzd on 2026-10-09 with user authorization.
-- Does not change existing tables. Run once; check schema before replaying.
begin;

create table public.monthly_spending_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  amount numeric(12, 2) not null check (amount between 100 and 50000),
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.monthly_spending_limits enable row level security;
revoke all on public.monthly_spending_limits from public, anon, authenticated;
grant select, insert, update on public.monthly_spending_limits to authenticated;

create policy monthly_limit_read_own on public.monthly_spending_limits
  for select to authenticated using ((select auth.uid()) = user_id);
create policy monthly_limit_insert_own on public.monthly_spending_limits
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy monthly_limit_update_own on public.monthly_spending_limits
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create function public.stamp_monthly_spending_limit()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

create trigger stamp_monthly_spending_limit
  before insert or update on public.monthly_spending_limits
  for each row execute function public.stamp_monthly_spending_limit();

commit;
