
\set QUIET
\set ON_ERROR_STOP true

set search_path to information_schema;
\echo -- | This code was originally created by squealgen. Edit if you know how it got made and are willing to own it now.

create or replace function croak(message text) returns text as $$
begin
  raise 'Croaked: %', message;
end;
$$
LANGUAGE plpgsql;

-- PRAGMAS of DOOM
\echo {-# LANGUAGE DataKinds #-}
\echo {-# LANGUAGE DeriveGeneric #-}
\echo {-# LANGUAGE OverloadedLabels #-} 
\echo {-# LANGUAGE FlexibleContexts #-}
\echo {-# LANGUAGE OverloadedStrings  #-}
\echo {-# LANGUAGE TypeApplications #-}
\echo {-# LANGUAGE TypeOperators #-}
\echo {-# LANGUAGE GADTs #-}

\echo module :modulename where
\echo import Squeal.PostgreSQL

-- squeal doesn't yet support cidr or ltree, so let's emit them explicitly
\echo type PGcidr = UnsafePGType "cidr"
\echo type PGltree = UnsafePGType "ltree"

-- now we emit all the enumerations

with enumerations as (select distinct on (udt_name,enum_values)
  format(E'type PG%s = ''PGenum\n  ''[%s]', udt_name, enum_values) as line
from (select col.udt_name,
       string_agg(format('"%s"', enu.enumLabel), ', ' 
                  order by enu.enumsortorder) as enum_values
from information_schema.columns col
join information_schema.tables tab on tab.table_schema = col.table_schema
                                   and tab.table_name = col.table_name
                                   and tab.table_type = 'BASE TABLE'
join pg_type typ on col.udt_name = typ.typname
join pg_enum enu on typ.oid = enu.enumtypid
where col.table_schema not in ('information_schema', 'pg_catalog')
      and typ.typtype = 'e'
group by col.table_schema,
         col.table_name,
         col.ordinal_position,
         col.column_name,
         col.udt_name
order by col.table_schema,
         col.table_name,
         col.ordinal_position) sub)
select string_agg(enumerations.line, E'\n') as enums	from enumerations \gset

\echo :enums

with   mytables as (SELECT tables.*,
                         initcap(tables.table_name) as cappedName,
			 
			 format(E'\n  ''[%s]',string_agg(mycolumns.colDef, E'\n  ,')) as haskCols,
			 format(E'\n  ''[%s]',string_agg(mycolumns.constraintDefs, E'\n  ,')) as constraintCols
FROM (select columns.*,
            format('"%s" ::: %s :=> %s %s',
	      column_name, 
	      case when column_default is null then '''Def'    else '''NoDef' end,
	      (case is_nullable
	         when 'YES' then '''Null'
	         when  'NO' then '''NotNull'
	         else croak ('is_nullable broken somehow: ' || is_nullable)
		 end ),
		 
                 -- mildly tricky: standard postgresql datatypes need a tick, usergen types don't. HOWEVER! if we leave them off, we just
		 -- get warnings, so this might be something to fix later.
		 (case 
		 	      -- this won't work for everything - should check if it's got a max length.
                    when udt_name = 'varchar' then 'PGtext'
                    else ('PG' || (udt_name :: text))
	  	    end)) as colDef,
	   ('[]'::text) as constraintDefs
  from columns) mycolumns
join tables on mycolumns.table_name = tables.table_name
WHERE table_type = 'BASE TABLE'
  AND tables.table_schema NOT IN ('pg_catalog', 'information_schema')
group by tables.table_catalog,
         tables.table_schema,
         tables.table_name,
         tables.table_type,
	 tables.self_referencing_column_name,
	 tables.reference_generation,
         tables.user_defined_type_catalog,
	 tables.user_defined_type_schema,
	 tables.user_defined_type_name,
	 tables.is_insertable_into,
	 tables.is_typed,
	 tables.commit_action)
select string_agg(format('type %sColumns = %s', mytables.cappedName, mytables.haskCols), E'\n') as cols,
       string_agg(format('type %sConstraints = %s', mytables.cappedName, mytables.constraintCols), E'\n') as straints,
       string_agg(format('type %sTable = %sConstraints :=> %sColumns', mytables.cappedName, mytables.cappedName, mytables.cappedName), E'\n') as tabs
from mytables \gset

\echo :cols
\echo :straints
\echo :tabs

