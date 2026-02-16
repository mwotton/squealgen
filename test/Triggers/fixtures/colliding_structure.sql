-- Manually maintained fixture for trigger name collision edge case.
--
-- This fixture lives outside schemas/Public/ because it's a specialized
-- regression test that doesn't need regeneration via `make test`.
-- It tests that triggers with identical names on different tables are
-- ordered deterministically (by relation_name, then trigger_name, then oid).
--
-- If squealgen.sql changes trigger output format, manually verify this
-- fixture still produces deterministic ordering across runs.

create table z_accounts (
  id serial primary key,
  balance int8 not null default 0
);

create table a_accounts (
  id serial primary key,
  balance int8 not null default 0
);

create function shared_trigger_z() returns trigger as $$
begin
  return new;
end;
$$ language plpgsql;

create function shared_trigger_a() returns trigger as $$
begin
  return new;
end;
$$ language plpgsql;

create trigger shared_trigger
before insert on z_accounts
for each row execute function shared_trigger_z();

create trigger shared_trigger
before insert on a_accounts
for each row execute function shared_trigger_a();
