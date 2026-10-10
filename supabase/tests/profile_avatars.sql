-- Metadata-only RLS test. No file upload, no account changes, always rolled back.
begin;
do $$
declare
  owner_uuid uuid := gen_random_uuid();
  other_uuid uuid := gen_random_uuid();
  row_uuid uuid;
  matches integer;
begin
  perform set_config('request.jwt.claim.sub', owner_uuid::text, true);
  perform set_config('role', 'authenticated', true);
  insert into storage.objects(bucket_id, name, metadata)
  values ('profile-avatars', owner_uuid::text || '/avatar.png', '{"test":true}')
  returning id into row_uuid;
  select count(*) into matches from storage.objects where id = row_uuid;
  if matches <> 1 then raise exception 'owner read failed'; end if;
  update storage.objects set metadata = '{"test":"updated"}' where id = row_uuid;
  get diagnostics matches = row_count;
  if matches <> 1 then raise exception 'owner update failed'; end if;

  perform set_config('request.jwt.claim.sub', other_uuid::text, true);
  select count(*) into matches from storage.objects where id = row_uuid;
  if matches <> 0 then raise exception 'other identity can read'; end if;
  update storage.objects set metadata = '{}' where id = row_uuid;
  get diagnostics matches = row_count;
  if matches <> 0 then raise exception 'other identity can update'; end if;
  begin
    insert into storage.objects(bucket_id, name)
    values ('profile-avatars', owner_uuid::text || '/forbidden.png');
    raise exception 'unexpected insert allowed';
  exception when insufficient_privilege then null;
  end;

  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claim.sub', '', true);
  select count(*) into matches from storage.objects where id = row_uuid;
  if matches <> 0 then raise exception 'anonymous can read'; end if;

  -- DELETE is protected by Storage's server trigger and must use its HTTP API.
  -- Its owner-only policy is inspected separately, not bypassed here.
  perform set_config('role', 'postgres', true);
end;
$$;
rollback;
