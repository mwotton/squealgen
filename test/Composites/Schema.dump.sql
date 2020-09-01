
-- we want an extra table, because every table creates a shadow composite,
-- and we need to make sure we don't list these.
create table dummy (i int );

create type clump as
  ( foo text
  , bar int4
  );


create type varclump as
  ( vfoo text
  , vbar int4
  , vbaz text
  );
