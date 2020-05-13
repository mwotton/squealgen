
create type traffic_light as ENUM('Red', 'Yellow', 'Green');
create table lights(light traffic_light not null);

insert into lights values ('Red');
insert into lights values ('Yellow');
