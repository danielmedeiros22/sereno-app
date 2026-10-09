-- Allows unit and tens amounts without changing rows or access policies.
begin;
alter table public.monthly_spending_limits
  drop constraint monthly_spending_limits_amount_check;
alter table public.monthly_spending_limits
  add constraint monthly_spending_limits_amount_check
  check (amount between 1 and 50000);
commit;
