create table table_one (
   table_two_id INT,
   col_one INT,
   col_two INT);

create table table_two (
   table_two_id INT,
   col_one INT,
   col_two INT);

alter table table_one
  add constraint "table_one_pkey"
  primary key (col_one, col_two);

alter table table_two
  ADD CONSTRAINT "table_two_fkey"
  foreign key (col_one, col_two) references table_one (col_one, col_two);
