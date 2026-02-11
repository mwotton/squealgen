create table integers (num int8 not null);
insert into integers values(1);

create function doubler(int8) returns int8 as $$
  select (2*$1);
$$ language sql;

create function somefunc(int4,int8) returns int8 as $$
  select(2 * $1 + $2) ;
$$ language sql;

create function strict_doubler(int8) returns int8 as $$
  select (2*$1);
$$ language sql strict;

create function overloaded(int4) returns int4 as $$
  select $1 + 1;
$$ language sql;

create function overloaded(int8) returns int8 as $$
  select $1 + 2;
$$ language sql;

create function zero_arg() returns int8 as $$
  select 42;
$$ language sql;

create function inout_params(IN var int8, OUT plus1 int8, OUT plus2 int8) as $$
  select var+1 as plus1, var+2 as plus2;
$$ language sql strict;


create function many_params(one int8,two real,three text) returns text as $$
  select three;
$$ language sql strict;
