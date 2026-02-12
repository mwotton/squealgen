create schema ext;
create extension ltree schema ext;

create table paths (
  id serial primary key,
  path ext.ltree not null
);

insert into paths (path)
values ('root.branch'::ext.ltree)
     , ('root.branch.leaf'::ext.ltree);

create function path_depth(p ext.ltree) returns int4
language sql
immutable
strict
as $$
  select ext.nlevel($1);
$$;
