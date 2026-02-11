create table accounts (
  id serial primary key,
  balance int8 not null default 0,
  status text
);

create table audit_log (
  event text not null
);

create view account_view as
  select id, balance, status from accounts;

create function log_account_row() returns trigger as $$
begin
  insert into audit_log(event) values (tg_name || ':' || tg_op || ':row');
  return new;
end;
$$ language plpgsql;

create function log_account_stmt() returns trigger as $$
begin
  insert into audit_log(event) values (tg_name || ':' || tg_op || ':statement');
  return null;
end;
$$ language plpgsql;

create function account_view_iou() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    insert into accounts(balance, status)
    values (new.balance, new.status)
    returning id, balance, status into new;
    return new;
  elsif tg_op = 'UPDATE' then
    update accounts
    set balance = new.balance,
        status = new.status
    where id = old.id
    returning id, balance, status into new;
    return new;
  elsif tg_op = 'DELETE' then
    delete from accounts where id = old.id;
    return old;
  end if;
  return null;
end;
$$ language plpgsql;

create function check_balance_not_negative() returns trigger as $$
begin
  if new.balance < 0 then
    raise exception 'balance must be nonnegative';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger accounts_before_row
before insert or update on accounts
for each row execute function log_account_row();

create trigger accounts_after_stmt
after delete on accounts
for each statement execute function log_account_stmt();

create trigger account_view_instead_row
instead of insert or update or delete on account_view
for each row execute function account_view_iou();

create constraint trigger accounts_balance_guard
after insert or update on accounts
deferrable initially deferred
for each row execute function check_balance_not_negative();

create schema private;
create table private.secret_log (
  id serial primary key,
  note text
);

create function private.secret_trigger_fn() returns trigger as $$
begin
  return new;
end;
$$ language plpgsql;

create trigger private_only_trigger
after insert on private.secret_log
for each row execute function private.secret_trigger_fn();
