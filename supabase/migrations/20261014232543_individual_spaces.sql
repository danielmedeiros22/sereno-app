-- Add individual spaces to the existing owner-scoped record sync.
-- Existing record validation, grants, RLS policies and triggers remain intact.
begin;
alter table public.account_financial_records
  drop constraint account_financial_records_kind_check;
alter table public.account_financial_records
  add constraint account_financial_records_kind_check
  check (kind in ('budget', 'recurring', 'paid', 'space'));
alter table public.account_financial_records
  drop constraint account_financial_records_payload;
alter table public.account_financial_records
  add constraint account_financial_records_payload check (
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
        when 'space' then payload ?& array['name','icon']
          and jsonb_typeof(payload->'name') = 'string'
          and char_length(payload->>'name') between 1 and 160
          and payload->>'name' = btrim(payload->>'name')
          and jsonb_typeof(payload->'icon') = 'string'
          and char_length(payload->>'icon') between 1 and 64
        when 'paid' then payload ?& array['rule_id','month','paid']
          and jsonb_typeof(payload->'rule_id') = 'string'
          and payload->>'month' ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
          and jsonb_typeof(payload->'paid') = 'boolean'
        else false end)
  );
commit;
