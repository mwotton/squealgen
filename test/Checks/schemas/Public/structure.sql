create domain positive_amount as int8
  constraint positive_amount_check check (value > 0);

create table checked_accounts (
  id serial primary key,
  amount int8 constraint amount_positive check (amount > 0),
  balance int8 not null,
  status text,
  quantity positive_amount,
  constraint balance_nonnegative check (balance >= 0),
  constraint status_guard check ((status is null) or (char_length(status) > 0)),
  constraint literal_true check ((1 = 1))
);
