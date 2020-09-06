
CREATE DOMAIN "positive" AS int8 CHECK ((("value" > 0) AND "value" IS NOT NULL));

create table pluslove ( num positive not null );
create function increment_positive (positive) returns positive as $$
  select ($1 + 1)::positive;
$$ language sql strict;
