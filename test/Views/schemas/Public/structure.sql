
create view evil_constant as select (1337::bigint) as evilnum;
create view nullable_constant as select (12::bigint) as num;

comment on view evil_constant is 'An evil constant view.';
comment on view nullable_constant is 'A nullable constant view.';

-- this is pretty evil, and it should be clear that squealgen's author accepts no liability
-- for actually using it like this. still, this is how to make it non-nullable if you really
-- want it.
update pg_attribute
set attnotnull=true
from pg_class
where pg_attribute.attname='evilnum'
and pg_class.relname='evil_constant'
and pg_class.oid = pg_attribute.attrelid;
