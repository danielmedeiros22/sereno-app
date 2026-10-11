begin;
create table public.account_categories (
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  name_key text not null check (char_length(name_key) between 1 and 160),
  name text not null check (char_length(name) between 1 and 160 and name = btrim(name)),
  icon text not null check (char_length(icon) between 1 and 64),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, type, name_key),
  check (name_key = lower(name))
);
alter table public.account_categories enable row level security;
revoke all on public.account_categories from public, anon, authenticated;
grant select, insert, update on public.account_categories to authenticated;
create policy account_categories_select on public.account_categories for select to authenticated
  using ((select auth.uid()) = user_id);
create policy account_categories_insert on public.account_categories for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy account_categories_update on public.account_categories for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create table public.account_financial_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('budget', 'recurring', 'paid')),
  id text not null check (char_length(id) between 1 and 200),
  payload jsonb,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, kind, id),
  constraint account_financial_records_payload check (
    (is_deleted and payload is null) or
    (not is_deleted and payload is not null and jsonb_typeof(payload) = 'object'
      and payload ? 'id' and payload->>'id' = id
      and case kind
        when 'budget' then payload ?& array['category','limit','createdAt']
          and jsonb_typeof(payload->'category') = 'string'
          and jsonb_typeof(payload->'limit') = 'number' and (payload->>'limit')::numeric > 0
        when 'recurring' then payload ?& array['name','category','amount','frequency','dueDay','active','createdAt']
          and jsonb_typeof(payload->'category') = 'string'
          and jsonb_typeof(payload->'amount') = 'number' and (payload->>'amount')::numeric > 0
          and payload->>'frequency' in ('weekly','biweekly','monthly','yearly')
          and jsonb_typeof(payload->'dueDay') = 'number' and (payload->>'dueDay')::numeric between 1 and 31
          and jsonb_typeof(payload->'active') = 'boolean'
        when 'paid' then payload ?& array['rule_id','month','paid']
          and jsonb_typeof(payload->'rule_id') = 'string'
          and payload->>'month' ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
          and jsonb_typeof(payload->'paid') = 'boolean'
        else false end)
  )
);
alter table public.account_financial_records enable row level security;
revoke all on public.account_financial_records from public, anon, authenticated;
grant select, insert, update on public.account_financial_records to authenticated;
create policy account_financial_records_select on public.account_financial_records for select to authenticated
  using ((select auth.uid()) = user_id);
create policy account_financial_records_insert on public.account_financial_records for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy account_financial_records_update on public.account_financial_records for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create function public.account_category_records_server_time() returns trigger
  language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.account_category_records_server_time() from public, anon, authenticated;
create trigger account_categories_server_time before insert or update on public.account_categories
  for each row execute function public.account_category_records_server_time();
create trigger account_financial_records_server_time before insert or update on public.account_financial_records
  for each row execute function public.account_category_records_server_time();
commit;
