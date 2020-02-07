
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
  format(E'type PG%s = ''PGenum\n  ''[%s]', udt_name, enum_values) as line,
  format(E'"%s" ::: ''Typedef PG%s', udt_name, udt_name) as decl
  
from (select col.udt_name,
       string_agg(format('"%s"', enu.enumLabel), ', ' 
                  order by enu.enumsortorder) as enum_values
from information_schema.columns col
join information_schema.tables tab on tab.table_schema = col.table_schema
                                   and tab.table_name = col.table_name
                                   and tab.table_type = 'BASE TABLE'
join pg_type typ on col.udt_name = typ.typname
join pg_enum enu on typ.oid = enu.enumtypid
where col.table_schema = :'chosen_schema'
      and typ.typtype = 'e'
group by col.table_schema,
         col.table_name,
         col.ordinal_position,
         col.column_name,
         col.udt_name
order by col.table_schema,
         col.table_name,
         col.ordinal_position) sub)
select string_agg(enumerations.line, E'\n') as enums,
       format(E'type Enums =\n  ''[%s]', string_agg(enumerations.decl, E',\n  ')) as decl
from enumerations \gset

\echo :enums
\echo :decl

with   mytables as (SELECT tables.*,
			 replace(initcap(replace(tables.table_name, '_', ' ')), ' ', '') as cappedName,
			 format(E'\n  ''[%s]',string_agg(mycolumns.colDef, E'\n  ,')) as haskCols
FROM tables
join (select columns.*,
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
	  	    end)) as colDef
  from columns) mycolumns on mycolumns.table_name = tables.table_name

WHERE table_type = 'BASE TABLE'
  AND tables.table_schema = :'chosen_schema' --  NOT IN ('pg_catalog', 'information_schema')
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
	 tables.commit_action
	 )
select string_agg(format('type %sColumns = %s', mytables.cappedName, mytables.haskCols), E'\n') as cols,
--       string_agg(format('type %sConstraints = %s', mytables.cappedName, mytables.constraintCols), E'\n') as straints,
       string_agg(format('type %sTable = %sConstraints :=> %sColumns', mytables.cappedName, mytables.cappedName, mytables.cappedName), E'\n') as tabs
from mytables \gset

\echo :cols
-- \echo :straints
\echo :tabs


-- here's where it gets weird.
--
-- ```
-- select kcu.column_name as kcu_column_name,kcu.ordinal_position,kcu.position_in_unique_constraint,ccu.* from (select distinct * from referential_constraints) rc join table_constraints tc on tc.constraint_name=rc.constraint_name join constraint_column_usage ccu on ccu.constraint_name = rc.unique_constraint_name join key_column_usage kcu on kcu.constraint_name=tc.constraint_name and kcu.table_name=tc.table_name
-- ```
-- apply a suitable where clause to this on your db, and you'll see that if you have multi-column keys, there's no apparent way to work out what points to what.
--
-- however, we _can_ run shell scripts inside psql, and we can pipe postgres commands to them. therefore, with appropriate begging of preemptive forgiveness:
--
-- 
--

--- where rc.constraint_name='fk_scope' and tc.table_name='stock'; --
--  kcu_column_name | ordinal_position | position_in_unique_constraint |   table_catalog   | table_schema | table_name | column_name | constraint_catalog | constraint_schema | constraint_name 
-- -----------------+------------------+-------------------------------+-------------------+--------------+------------+-------------+--------------------+-------------------+-----------------
--  scope_id        |                1 |                             1 | range-data-server | public       | scope      | id          | range-data-server  | public            | pk_scope
--  scope_tag       |                2 |                             2 | range-data-server | public       | scope      | id          | range-data-server  | public            | pk_scope
--  scope_id        |                1 |                             1 | range-data-server | public       | scope      | tag         | range-data-server  | public            | pk_scope
--  scope_tag       |                2 |                             2 | range-data-server | public       | scope      | tag         | range-data-server  | public            | pk_scope
-- (4 rows)
-- (4 rows)
-- ```
-- doesn't seem a way to disentangle the fact that scope_id should point to id only, and scope_tag only to tag - the position isn't mentioned elsewhere.
-- So! another filthy hack, that only does the constraints, via evil shell shit
-- this looks weird but bear with me.

-- set it up to run a stream editor on what follows
-- should convert this to `stack run` eventually but annoyingly, it wants to build the library, which is
-- usually broken because it's what we're generating!
-- TODO how to pass the schema here?
\o |stack runhaskell ./app/genConstraints.hs
--\o foobar
\pset format unaligned
-- this is a bit hacky. maybe nulls? anyway.
\pset recordsep '||||'
-- display all the data from all the tables
\d :chosen_schema.*
-- couldn't make this work - accessing the individual components of a foreign key seems very hard.

-- left join (
--  select -- distinct on (orig_table_name) -- distinct on    (flat_constraints.constraint_def)
-- 	-- this is the table that has the constraints, not the one being pointed to.
--        orig_table_name,
 	
--        string_agg(flat_constraints.constraint_def, E'\n  ,') as constraint_defs
--  from 
--   (SELECT -- distinct on (cc.orig_table_name)
-- --          'foo'::text as constraint_def,
-- --          tc.table_name,
--           cc.orig_table_name,
-- 	  format('"%s" ::: %s',
-- 	  --	  tc.constraint_name,
-- 	  	  cc.constraint_name,
-- --		  case tc.constraint_type
-- 		  case cc.constraint_type
-- 		    when 'FOREIGN KEY' then format('ForeignKey ''[%s] "%s" ''[%s]',
-- --		      string_agg(format('"%s"', kcu.column_name), ',' order by kcu.position_in_unique_constraint),
-- 		      string_agg(format('"%s"', cc.kcolumn_name), ',' order by cc.kposition_in_unique_constraint),
-- --		      ccu.table_name,
--                       cc.ccu_table_name,
-- --     		      string_agg(format('"%s"', ccu.column_name),
-- 		      string_agg(format('"%s"', cc.ccu_column_name),
-- 		      ','))
-- 		    when 'PRIMARY KEY' then 'unknownprimarykey'
-- 		    when 'UNIQUE' then
-- 		      format('Unique ''[%s]', 'unknownunique')
-- 		    when 'CHECK' then
-- 		      format('Check ''[%s]', -- string_agg(format('"%s"', cu.column_name), ','))
-- 		      'unknowncheck'
-- 		      --json_agg(rc.*)
-- 		      )
--                     else croak('unknown type ' || cc.constraint_type)
-- 		  end) as constraint_def
-- --		  json_agg(row_to_json(tc.*))::text as constraint_def_dummy,
		    
--           -- end as constraint_def
-- --          tc.constraint_name,
-- --          tc.constraint_type,
-- --          tc.table_name
--           -- kcu.column_name,
--           -- tc.is_deferrable,
--           -- tc.initially_deferred,
--           -- rc.match_option AS match_type,
--           -- rc.update_rule AS on_update,
--           -- rc.delete_rule AS on_delete,
--           -- ccu.table_name AS references_table,
--           -- ccu.column_name AS references_field
--    FROM (select distinct on (tc.constraint_type, tc.table_name,kcu.column_name)
--    tc.table_name as orig_table_name,
--    tc.constraint_name,
--    tc.constraint_type,
--    kcu.column_name as kcolumn_name,
--    kcu.position_in_unique_constraint as kposition_in_unique_constraint,
--    ccu.table_name as ccu_table_name,
--    ccu.column_name as ccu_column_name
   
   
--    from
--    information_schema.table_constraints tc
--    LEFT JOIN information_schema.key_column_usage kcu ON tc.constraint_catalog = kcu.constraint_catalog
--    AND tc.constraint_schema = kcu.constraint_schema
--    AND tc.constraint_name = kcu.constraint_name
--    LEFT JOIN information_schema.referential_constraints rc ON tc.constraint_catalog = rc.constraint_catalog
--    AND tc.constraint_schema = rc.constraint_schema
--    AND tc.constraint_name = rc.constraint_name
--    LEFT JOIN information_schema.constraint_column_usage ccu ON rc.unique_constraint_catalog = ccu.constraint_catalog
--    AND rc.unique_constraint_schema = ccu.constraint_schema
--    AND rc.unique_constraint_name = ccu.constraint_name) cc

--    group by cc.orig_table_name,
--    	    cc.constraint_name,
-- 	    cc.constraint_type,
-- 	    cc.ccu_table_name
-- --           ,tc.constraint_name
-- --           ,tc.constraint_type
-- --	   ,tc.is_deferrable
-- --	   ,ccu.table_name
-- --	   ,ccu.constraint_name
-- --	   ,kcu.table_name

-- --   group by tc.table_name
-- --            ,tc.constraint_name
-- --            ,tc.constraint_type
-- -- --	   ,tc.is_deferrable
-- -- 	   ,ccu.table_name
-- -- 	   ,ccu.constraint_name
-- -- 	   ,kcu.table_name
-- ) flat_constraints
-- group by flat_constraints.orig_table_name

-- ) table_constraints on table_constraints.orig_table_name=tables.table_name


-- some interim evil hacking
-- select regexp_split_to_array(trim(both '()'
--                                   from replace(fk, ' ','')),',') as fk,
--        split_part(target, '(', 1) as tab,
--        regexp_split_to_array(split_part(target, '(', 2)::text, E', '::text) as reffields
-- from
--   (select split_part(split_part(condef, 'FOREIGN KEY ', 2), 'REFERENCES', 1) as fk,
--           split_part(split_part(condef, 'REFERENCES ', 2), ')', 1) as target
--    from
--      (SELECT conname,
--              pg_catalog.pg_get_constraintdef(r.oid, true) as condef
--       FROM pg_catalog.pg_constraint r
--       WHERE r.contype = 'f'
--       ORDER BY 1) def) def2;
