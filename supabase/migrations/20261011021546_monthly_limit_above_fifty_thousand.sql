-- User requested limits above R$ 50,000. Preserve rows, type, RLS and grants.
begin;
set local lock_timeout = '5s';
alter table public.monthly_spending_limits
  drop constraint monthly_spending_limits_amount_check;
alter table public.monthly_spending_limits
  add constraint monthly_spending_limits_amount_check
  check (amount >= 1 and amount <= 9999999999.99);
commit;
