create table foo (id serial, name text);
create table foo2 (id serial, limited varchar(12) not null);

comment on table foo is 'Primary foo table.';
comment on column foo.name is 'Optional display name.';

insert into foo2 (limited) values ('hi');
