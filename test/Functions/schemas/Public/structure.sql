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

create function legacy_alias(int8) returns int8 as $$
  select $1 + 3;
$$ language sql;

create function legacy_alias(anyelement) returns anyelement as $$
  select $1;
$$ language sql;

create function zero_arg() returns int8 as $$
  select 42;
$$ language sql;

create function out_only(OUT result int8) as $$
  select 99;
$$ language sql;

create function inout_only(INOUT var int8) as $$
  select var + 10;
$$ language sql;

create function mixed_in_inout(IN one int8, INOUT two int8) as $$
  select one + two;
$$ language sql;

create function inout_params(IN var int8, OUT plus1 int8, OUT plus2 int8) as $$
  select var+1 as plus1, var+2 as plus2;
$$ language sql strict;

create procedure proc_increment(IN amount int8) as $$
begin
  insert into integers values(amount);
end;
$$ language plpgsql;

create type score_row as (num int8, label text);

create function srf_scalar(limit_n int8) returns setof int8 as $$
  select generate_series(1, limit_n);
$$ language sql;

create function srf_composite() returns setof score_row as $$
  select (g, 'label-' || g::text)::score_row
  from generate_series(1, 2) as g;
$$ language sql;

create function srf_table(seed int8)
returns table (out_num int8, out_text text) as $$
  select seed, 'seed-' || seed::text
  union all
  select seed + 1, 'seed-' || (seed + 1)::text;
$$ language sql;

create function srf_any(anyelement) returns setof anyelement as $$
  select $1;
$$ language sql;

create function many_params(one int8,two real,three text) returns text as $$
  select three;
$$ language sql strict;
