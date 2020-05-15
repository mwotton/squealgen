create table foo (id serial, name text);
create table foo2 (id serial, limited varchar(12) not null);

insert into foo2 (limited) values ('hi');
