
create type traffic_light as ENUM('Red', 'Yellow', 'Green');
create table lights(light traffic_light not null);

create view lights_v as (
       select * from (values ('Yellow'::traffic_light), ('Green')) as t(light));

insert into lights values ('Red');
insert into lights values ('Yellow');
