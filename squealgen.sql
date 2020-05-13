\set QUIET
\set ON_ERROR_STOP true

set search_path to information_schema,:chosen_schema;
\echo -- | This code was originally created by squealgen. Edit if you know how it got made and are willing to own it now.

create or replace function pg_temp.croak(message text) returns text as $$
begin
  raise 'Croaked: %', message;
end;
$$
LANGUAGE plpgsql;

create or replace function pg_temp.initCaps(message text) returns text as $$
begin
 return replace(initcap(replace(message, '_', ' ')), ' ', '');
end;
$$
LANGUAGE plpgsql;

CREATE or replace FUNCTION pg_temp.stripDoublequotes(arr text[]) RETURNS text[] AS $$
begin
   return array_agg(regexp_replace(component.f, '"+', '', 'g')) from unnest(arr) as component(f);
end;
$$
LANGUAGE plpgsql;


CREATE or replace FUNCTION pg_temp.stripDoublequotes(arr text[]) RETURNS text[] AS $$
begin
   return array_agg(regexp_replace(component.f, '"+', '', 'g')) from unnest(arr) as component(f);
end;
$$
LANGUAGE plpgsql;

-- PRAGMAS of DOOM
\echo {-# LANGUAGE DataKinds #-}
\echo {-# LANGUAGE DeriveGeneric #-}
\echo {-# LANGUAGE OverloadedLabels #-}
\echo {-# LANGUAGE FlexibleContexts #-}
\echo {-# LANGUAGE OverloadedStrings  #-}
\echo {-# LANGUAGE PolyKinds  #-}
\echo {-# LANGUAGE TypeApplications #-}
\echo {-# LANGUAGE TypeOperators #-}
\echo {-# LANGUAGE GADTs #-}
\echo {-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}
\echo
\echo module :modulename where
\echo import Squeal.PostgreSQL
\echo import GHC.TypeLits(Symbol)
\echo
\echo '-- squeal doesn''t yet support cidr or ltree, so for the moment we emit them explicitly'
\echo type PGcidr = UnsafePGType "cidr"
\echo type PGltree = UnsafePGType "ltree"

select format('type DB = ''["%s" ::: Schema]', :'chosen_schema') as db \gset
\echo
\echo :db
\echo
--\echo type Schema = Join (Join Tables Enums) Views
\echo type Schema = Join Tables (Join Views (Join Enums Functions))

-- now we emit all the enumerations
with enumerations as  (select
       format(E'type PG%s = ''PGenum\n  ''[%s]',
       		            t.typname,
			    string_agg(format('"%s"', e.enumlabel), ', ' order by e.enumsortorder)) as line,
       format(E'"%1$s" ::: ''Typedef PG%1$s', t.typname) as decl
from pg_type t
   join pg_enum e on t.oid = e.enumtypid
   join pg_catalog.pg_namespace n ON n.oid = t.typnamespace
   where n.nspname=:'chosen_schema'
   group by t.typname
   order by t.typname)
 select coalesce(string_agg(enumerations.line, E'\n'),'') as enums,
       format(E'type Enums =\n  (''[%s] :: [(Symbol,SchemumType)])',
              coalesce(string_agg(enumerations.decl, E',\n  '), '')) as decl
from enumerations \gset
\echo -- enums
\echo :enums
\echo -- decls
\echo :decl




create temporary view columnDefs as (SELECT tables.table_name,
			 format(E'''[%s]',string_agg(mycolumns.colDef, E'\n  ,' order by mycolumns.ordinal_position)
			 ) as haskCols
FROM tables
join (select columns.*,
            format('"%s" ::: %s :=> %s %s',
	      column_name,
	      case when column_default is null then '''NoDef'    else '''Def' end,
	      (case is_nullable
	         when 'YES' then '''Null'
	         when  'NO' then '''NotNull'
	         else pg_temp.croak ('is_nullable broken somehow: ' || is_nullable)
		 end ),

                 -- mildly tricky: standard postgresql datatypes need a tick, usergen types don't. HOWEVER! if we leave them off, we just
		 -- get warnings, so this might be something to fix later.
		 (case
		   when data_type = 'ARRAY' then
   		   -- possibly we shouldn't be assuming the elements of the array are non-null?
		     (case when udt_name = '_varchar' then '(PGvararray (NotNull PGtext))'
                           else ('(PGvararray (NotNull PG' || (trim(leading '_' from udt_name::text)) || '))')
                           end)
                   else
		     (case
			-- this won't work for everything - should check if it's got a max length.
			--                    when udt_name = 'varchar' then 'PGtext'
			when udt_name = 'varchar' then 'PGtext'
			else ('PG' || (udt_name :: text))
			end)
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
order by tables.table_name
	 );

create temporary view constraintDefs as (

  select regexp_split_to_array(trim(both '()'
                                    from replace(fk, ' ','')),',') as fk,
         split_part(target, '(', 1) as tab,
	 (select pg_temp.stripDoublequotes(regexp_split_to_array(split_part(target, '(', 2)::text, E', '::text))) as reffields,
	 conname,
	 table_name,
	 contype,
	 (select pg_temp.stripDoublequotes(regexp_split_to_array(pkeytable, ' *, *'))) as pkeys
  from
    (select regexp_replace(split_part(split_part(condef, 'FOREIGN KEY ', 2), 'REFERENCES', 1), '"', '', 'g') as fk,
            regexp_replace(split_part(split_part(condef, 'REFERENCES ', 2), ')', 1), '"', '', 'g') as target,
	    split_part(split_part(condef, 'PRIMARY KEY (',2), ')', 1) as pkeytable,
	    *
     from
  (SELECT conname,contype,
             pg_catalog.pg_get_constraintdef(r.oid, false) as condef,
	     c.relname as table_name
      FROM pg_catalog.pg_constraint r
      join pg_catalog.pg_class c
        on r.conrelid=c.oid
	-- we don't look up checks, because we'd then have to be able to translate arbitrary
	-- expressions in sql and translate them to squeal's type structure. ain't nobody
	-- got time for that.
      WHERE r.contype = 'f' or r.contype = 'p'
      ORDER BY 1) rawCons) blah);

select coalesce(string_agg(allDefs.tabData, E'\n'),'') as defs,
       format(E'type Tables = (''[\n   %s]  :: [(Symbol,SchemumType)])',
         coalesce(string_agg(format('"%s" ::: ''Table %sTable', allDefs.table_name, allDefs.cappedName), E'\n  ,'),'')) as schem

from (
  select format(E'type %1$sColumns = %2$s\ntype %1$sConstraints = ''[%3$s]\ntype %1$sTable = %1$sConstraints :=> %1$sColumns\n',
               replace(initcap(replace(defs.table_name, '_', ' ')), ' ', ''),
    	       string_agg(defs.cols, 'XXXXX'), -- this shouldn't be necessary
	       string_agg(cd.str, 'YYYYY')) as tabData,
	 replace(initcap(replace(defs.table_name, '_', ' ')), ' ', '') as cappedName,
	 defs.table_name
from (select table_name, string_agg(columnDefs.haskCols, E'\n  ,') as cols
      from columnDefs
      group by table_name) defs
left join (select table_name,
             string_agg(format('"%s" ::: %s',constraintDefs.conname,
	       case contype
	       when 'p' then format('''PrimaryKey ''["%s"]', array_to_string(pkeys, '","'))
	       when 'f' then format('''ForeignKey ''["%s"] "%s" ''["%s"]', array_to_string(fk,'","'), tab, array_to_string(reffields, '","'))
	       else pg_temp.croak (format('bad type %s',contype))
	       end)
			, E'\n  ,') as str
from constraintDefs  group by table_name) cd on cd.table_name = defs.table_name
group by defs.table_name) allDefs \gset

\echo -- schema
\echo :schem
\echo
\echo -- defs
\echo :defs

\echo -- VIEWS


create temporary view my_views as (
SELECT
  string_agg(format(E'"%s" ::: ''%s ''PG%s',
    a.attname,
    case when a.attnotnull
      then 'NotNull'
      else 'Null'
    end,
    t.typname
    ),E'\n   ,') as views,
  c.relname as viewname
FROM pg_catalog.pg_attribute a join pg_catalog.pg_class c on a.attrelid = c.oid
 join pg_catalog.pg_namespace n on n.oid = c.relnamespace
 join pg_catalog.pg_type t on a.atttypid=t.oid
 where c.relkind='v' and n.nspname=:'chosen_schema'
 AND a.attnum > 0 AND NOT a.attisdropped group by c.relname);

-- select coalesce(string_agg(allDefs.tabData, E'\n'),'') as defs,
select format( E'type Views = \n  ''[%s]\n', coalesce(string_agg(format('"%s" ::: ''View %sView', viewname, pg_temp.initCaps(viewname)), ',')), '') as viewtype,
       coalesce (string_agg( format( E'type %sView = \n  ''[%s]\n', pg_temp.initCaps(viewname),views), E'\n'), '') as views
       from my_views \gset
\echo :viewtype
\echo :views

\echo -- functions

select format(E'type Functions = \n  ''[ %s ]',
	       coalesce(string_agg(funcdefs.stringform, E'\n   , '), '')) as functions
from
  (select format(E'"%s" ::: Function (''[ %s ] :=> ''Returns ( ''Null ''PG%s) )',
    funcs.proname,
    string_agg(format(E'''Null PG%s', pg_type.typname), ', '),
    ret_type) as stringform
   from
     (SELECT p.proname,
	     unnest(p.proargtypes) as arg,
	     pg_type.typname as ret_type
      FROM pg_proc p
      INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
      inner join pg_type on p.prorettype=pg_type.oid
      WHERE ns.nspname = :'chosen_schema') as funcs
   join pg_type on funcs.arg=pg_type.oid
   group by proname,
	    ret_type) funcdefs \gset

\echo :functions
