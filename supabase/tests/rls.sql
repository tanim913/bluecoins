-- Row Level Security checks. Run the whole file in one execute_sql call (it rolls back).
-- Any failed expectation raises an exception; reaching the final select means all passed.
begin;

insert into auth.users (id, instance_id, aud, role, email)
values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'a@test.invalid'),
       ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'b@test.invalid');

-- user A writes
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
insert into public.checkins (user_id, id, balance, updated_at) values ('00000000-0000-0000-0000-00000000000a', '2026-04-24', 12500000, 1000);

do $$ begin
  if (select count(*) from public.checkins) <> 1 then raise exception 'A should see own row'; end if;
end $$;

-- A cannot write a row for B
do $$ begin
  begin
    insert into public.checkins (user_id, id, balance, updated_at) values ('00000000-0000-0000-0000-00000000000b', '2026-04-24', 1, 1);
    raise exception 'A wrote into B (should be blocked)';
  exception when insufficient_privilege or check_violation then null;
  end;
end $$;

-- an older update is ignored, a newer one wins
update public.checkins set balance = 1, updated_at = 500 where id = '2026-04-24';
do $$ begin
  if (select balance from public.checkins where id = '2026-04-24') <> 12500000 then raise exception 'older update must be ignored'; end if;
end $$;
update public.checkins set balance = 2, updated_at = 2000 where id = '2026-04-24';
do $$ begin
  if (select balance from public.checkins where id = '2026-04-24') <> 2 then raise exception 'newer update must apply'; end if;
end $$;

-- a clock far in the future is capped
update public.checkins set balance = 3, updated_at = 9999999999999999 where id = '2026-04-24';
do $$ begin
  if (select updated_at from public.checkins where id = '2026-04-24') > (extract(epoch from now()) * 1000)::bigint + 61000 then raise exception 'future updated_at must be capped'; end if;
end $$;

-- user B sees nothing of A
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.checkins) <> 0 then raise exception 'B must not see A rows'; end if;
end $$;
update public.checkins set balance = 99;  -- touches 0 rows
do $$ begin
  if (select count(*) from public.checkins) <> 0 then raise exception 'B update leaked'; end if;
end $$;

-- hard deletes are not allowed for users
do $$ begin
  begin
    delete from public.checkins;
    raise exception 'delete must be denied';
  exception when insufficient_privilege then null;
  end;
end $$;

-- anonymous users get nothing
reset role;
set local role anon;
do $$ begin
  begin
    perform count(*) from public.checkins;
    raise exception 'anon must be denied';
  exception when insufficient_privilege then null;
  end;
end $$;

-- delete_my_account: anon cannot call it; a user deletes only themselves and their data cascades
reset role;
do $$ begin
  if has_function_privilege('anon', 'public.delete_my_account()', 'execute') then raise exception 'anon can delete accounts'; end if;
  if not has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') then raise exception 'authenticated cannot delete account'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.delete_my_account();
reset role;
do $$ begin
  if exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000a') then raise exception 'A should be gone'; end if;
  if exists (select 1 from public.checkins where user_id = '00000000-0000-0000-0000-00000000000a') then raise exception 'A data should cascade'; end if;
  if not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-00000000000b') then raise exception 'B must survive'; end if;
end $$;

select 'all rls checks passed' as result;
rollback;
