create table integers (num int8 not null);
insert into integers values(1);
create function doubler(int4,int8) returns int8 as $$
  select(2 * $1 + $2) ;
$$ language sql;
