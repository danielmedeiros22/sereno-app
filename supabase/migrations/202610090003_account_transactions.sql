-- Additive, isolated transaction store. Do not change existing feature tables.
begin;
create table public.account_transactions (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  payload jsonb,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, id),
  constraint account_transactions_payload check (
    (is_deleted and payload is null) or
    (not is_deleted and payload is not null
      and jsonb_typeof(payload) = 'object'
      and payload ?& array['id', 'type', 'amount', 'category', 'date', 'createdAt']
      and payload->>'id' = id::text
      and payload->>'type' in ('income', 'expense')
      and jsonb_typeof(payload->'amount') = 'number'
      and (payload->>'amount')::numeric > 0)
  )
);
alter table public.account_transactions enable row level security;
revoke all on public.account_transactions from anon, authenticated;
grant select, insert, update on public.account_transactions to authenticated;
create policy account_transactions_select on public.account_transactions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy account_transactions_insert on public.account_transactions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy account_transactions_update on public.account_transactions
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create function public.account_transactions_server_time() returns trigger
  language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
create trigger account_transactions_server_time
  before insert or update on public.account_transactions
  for each row execute function public.account_transactions_server_time();
commit;
