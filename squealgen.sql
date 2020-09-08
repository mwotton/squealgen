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

create or replace function pg_temp.type_decl_from(data_type text, udt_name text, nullable bool, fieldlen cardinal_number) RETURNS text as $$
  select
  (case
	-- this is pretty bad - we source the datatypes from the information_schema and also the basic tables (pg_type).
	-- probably better to move it to just the basic tables.
    when (data_type = 'ARRAY' or data_type = 'A') then
      format('(PGvararray (%s %s))'
	    , case when nullable then 'Null' else 'NotNull' end
	    , case when udt_name = '_varchar' and fieldlen is null then 'PGtext'
		   when udt_name = '_varchar' then format('(PGvarchar %s)', fieldlen)
		   else 'PG' || (trim(leading '_' from udt_name::text))
	      end)
    else
      (case
	 -- this won't work for everything - should check if it's got a max length.
	 --                    when udt_name = 'varchar' then 'PGtext'
	 when udt_name = 'varchar' and fieldlen is null then 'PGtext'
	 when udt_name = 'varchar' then format('(PGvarchar %s)', fieldlen)
	 else ('PG' || (udt_name :: text))
	 end)
    end);
$$
LANGUAGE sql;


CREATE or replace FUNCTION pg_temp.stripDoublequotes(arr text[]) RETURNS text[] AS $$
begin
   return array_agg(regexp_replace(component.f, '"+', '', 'g')) from unnest(arr) as component(f);
end;
$$
LANGUAGE plpgsql;


-- Create a function that always returns the first non-NULL item
CREATE OR REPLACE FUNCTION pg_temp.first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
	SELECT $1;
$$;

-- And then wrap an aggregate around it
CREATE AGGREGATE pg_temp.FIRST (
	sfunc    = pg_temp.first_agg,
	basetype = anyelement,
	stype    = anyelement
);

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
-- specified imports
select coalesce(string_agg(format('import %s', s.i)  , E'\n'), '') as imports
from unnest(string_to_array(:'extra_imports', ',')) as s(i) \gset
\echo :imports


-- should really move these out somehow
\echo type PGltree = UnsafePGType "ltree"
\echo type PGcidr = UnsafePGType "cidr"
\echo type PGltxtquery = UnsafePGType "ltxtquery"
\echo type PGlquery = UnsafePGType "lquery"

\echo

select format('type DB = ''["%s" ::: Schema]', :'chosen_schema') as db \gset
\echo
\echo :db
\echo
--\echo type Schema = Join (Join Tables Enums) Views
\echo type Schema = Join Tables (Join Views (Join Enums (Join Functions (Join Composites Domains))))


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
   order by (t.typname :: text COLLATE "C"))
 select coalesce(string_agg(enumerations.line, E'\n'),'') as enums,
       format(E'type Enums =\n  (''[%s] :: [(Symbol,SchemumType)])',
	      coalesce(string_agg(enumerations.decl, E',\n  '), '')) as decl
from enumerations \gset
\echo -- enums
\echo :enums
\echo -- decls
\echo :decl

with composites as (select
  format(E'type PG%s = ''PGcomposite ''[%s]', t.typname,
    string_agg(format(E'"%s" ::: ''NotNull PG%s', a.attname, t2.typname),', ' order by a.attnum ASC)) as types,
  format(E'"%1$s" ::: ''Typedef PG%1$s', t.typname) as decl
from pg_attribute a
join pg_type t on a.attrelid=t.typrelid
join pg_type t2 on a.atttypid=t2.oid
join pg_catalog.pg_namespace n ON n.oid = t.typnamespace
join pg_class c on t.typrelid=c.oid
where n.nspname=:'chosen_schema'
and t.typtype='c'
and c.relkind='c'
-- this is a bit of a guess, to be honest.
-- and t.typarray != 0
group by t.typname)
select coalesce(string_agg(composites.types, E'\n'), '') as comps,
       format(E'type Composites =\n  (''[%s] :: [(Symbol,SchemumType)])',
	      coalesce(string_agg(composites.decl, E',\n  '), '')) as decl
from composites \gset

\echo :comps
\echo :decl

\echo



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
		 -- nb: we are assuming the inner array may be nullable. this may not be true, TODO
		 pg_temp.type_decl_from(data_type, udt_name, false, character_maximum_length)
		 ) as colDef
  from columns
  where columns.table_schema = :'chosen_schema'
  ) mycolumns on mycolumns.table_name = tables.table_name

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
order by tables.table_name COLLATE "C"
	 );


create temporary view constraintDefs as (
SELECT
  con.conname AS conname,
  con.contype AS contype,
  nsp.nspname AS nsp,
  tab.relname AS table_name,
  col.cols,
  fnsp.nspname AS fnsp,
  ftab.relname AS ftab,
  fcol.fcols
FROM pg_catalog.pg_constraint AS con
join pg_catalog.pg_namespace n on n.oid = con.connamespace
INNER JOIN pg_catalog.pg_class AS tab
ON con.conrelid = tab.oid
INNER JOIN pg_catalog.pg_namespace AS nsp
ON con.connamespace = nsp.oid
LEFT JOIN LATERAL (select array_agg (all col.attname ORDER BY array_position(con.conkey, col.attnum) ASC) cols
		   from pg_catalog.pg_attribute col
     	  	   where con.conkey @> ARRAY[col.attnum]
		   and con.conrelid = col.attrelid
		   ) col on true
LEFT OUTER JOIN pg_catalog.pg_class AS ftab
ON con.confrelid = ftab.oid
LEFT OUTER JOIN pg_catalog.pg_namespace AS fnsp
ON ftab.relnamespace = fnsp.oid
--LEFT OUTER JOIN pg_catalog.pg_attribute AS fcol
--ON con.confkey @> ARRAY[fcol.attnum] AND con.confrelid = fcol.attrelid
LEFT JOIN LATERAL (select array_agg (all fcol.attname ORDER BY array_position(con.conkey, fcol.attnum) ASC) fcols
		   from pg_catalog.pg_attribute fcol
     	  	   where con.confkey @> ARRAY[fcol.attnum]
		   and con.conrelid = fcol.attrelid
		   ) fcol on true
WHERE con.contype IN ('f', 'c', 'p', 'u')
AND  n.nspname=:'chosen_schema'
GROUP BY
  con.conname,
  con.contype,
  nsp.nspname,
  tab.relname,
  fnsp.nspname,
  ftab.relname,
  col.cols,
  fcol.fcols
);

select coalesce(string_agg(allDefs.tabData, E'\n'),'') as defs,
       format(E'type Tables = (''[\n   %s]  :: [(Symbol,SchemumType)])',
	 coalesce(string_agg(format('"%s" ::: ''Table %sTable', allDefs.table_name, allDefs.cappedName), E'\n  ,' order by allDefs.table_name COLLATE "C" ),'')) as schem

from (
  select format(E'type %1$sColumns = %2$s\ntype %1$sConstraints = ''[%3$s]\ntype %1$sTable = %1$sConstraints :=> %1$sColumns\n',
	       replace(initcap(replace(defs.table_name, '_', ' ')), ' ', ''),
	       string_agg(defs.cols, 'XXXXX'), -- this shouldn't be necessary
	       string_agg(cd.str, 'YYYYY')) as tabData,
	 replace(initcap(replace(defs.table_name, '_', ' ')), ' ', '') as cappedName,
	 defs.table_name
from (select table_name, string_agg(columnDefs.haskCols, E'\n  ,') as cols
      from columnDefs
      group by table_name
      order by table_name COLLATE "C") defs
left join (select table_name,
	     string_agg(format('"%s" ::: %s',constraintDefs.conname,
	       case contype
	       when 'p' then format('''PrimaryKey ''["%s"]', array_to_string(cols, '","'))
	       when 'f' then format('''ForeignKey ''["%s"] "%s" "%s" ''["%s"]', array_to_string(cols,'","'), fnsp, ftab, array_to_string(fcols, '","'))
	       when 'u' then format('''Unique ''["%s"]', array_to_string(cols,'","'))
	       else pg_temp.croak (format('bad type %s',contype))
	       end)
			, E'\n  ,' order by (constraintDefs.conname ::text) COLLATE "C") as str
from constraintDefs
where contype in ('p', 'f', 'u') -- should also handle 'c' for check, but not now.
group by table_name
order by (table_name :: text) COLLATE "C" ) cd on cd.table_name = defs.table_name
group by defs.table_name
order by defs.table_name COLLATE "C") allDefs \gset

\echo -- schema
\echo :schem
\echo
\echo -- defs
\echo :defs

\echo -- VIEWS


create temporary view my_views as (
SELECT
  string_agg(format(E'"%s" ::: ''%s %s',
    a.attname,
    case when a.attnotnull
      then 'NotNull'
      else 'Null'
    end,
    pg_temp.type_decl_from(t.typcategory,t.typname,false,null) -- this may be dodgy? need a view that has a varchar(n)
    ),E'\n   ,') as views,
  c.relname as viewname
FROM pg_catalog.pg_attribute a join pg_catalog.pg_class c on a.attrelid = c.oid
 join pg_catalog.pg_namespace n on n.oid = c.relnamespace
 join pg_catalog.pg_type t on a.atttypid=t.oid
 where c.relkind='v' and n.nspname=:'chosen_schema'
 AND a.attnum > 0 AND NOT a.attisdropped
 group by c.relname
 order by (c.relname :: text) COLLATE "C");

-- select coalesce(string_agg(allDefs.tabData, E'\n'),'') as defs,
select format( E'type Views = \n  ''[%s]\n', coalesce(string_agg(format('"%s" ::: ''View %sView', viewname, pg_temp.initCaps(viewname)), ',')), '') as viewtype,
       coalesce (string_agg( format( E'type %sView = \n  ''[%s]\n', pg_temp.initCaps(viewname),views), E'\n'), '') as views
       from my_views \gset
\echo :viewtype
\echo :views

\echo -- functions

select format(E'type Functions = \n  ''[ %s ]'
     , coalesce(string_agg(funcdefs.stringform, E'\n   , ' order by (funcdefs.proname :: text) COLLATE "C"), '')) as functions
from
  (select format(E'"%s" ::: Function (''[ %s ] :=> ''Returns ( ''Null PG%s) )'
	  , funcs.proname
	  , string_agg(format('%s %s', (case
				 when proisstrict then 'NotNull'
				 else 'Null'
			     end), pg_temp.type_decl_from(type_arg.typcategory,type_arg.typname,false,null)) -- fixme
			     , ',  ' order by arg_index)
	  , ret_type) as stringform
	  , funcs.proname
   from
     (select proname,
	     pronamespace,
	     proisstrict,
	     typname,
	     args.arg,
	     args.arg_index,
	     type_ret.typname as ret_type
      from (select proname,
		   pg_temp.FIRST(pronamespace) as pronamespace,
		   pg_temp.FIRST(proargtypes) as proargtypes,
		   pg_temp.FIRST(proisstrict) as proisstrict,
		   pg_temp.FIRST(prorettype) as prorettype
	    from pg_proc
	    group by proname
	    having count(proname)=1 ) p
	   -- need ordinality to keep function argument ordering correct
	  ,unnest(p.proargtypes) with  ordinality as args(arg,arg_index)
	  ,pg_namespace ns
	  ,pg_type type_ret
	  WHERE p.pronamespace = ns.oid
	  AND p.prorettype=type_ret.oid
	  AND ns.nspname = :'chosen_schema'
	  -- TODO we can't currently model functions with in and out parameters,
	  -- so we'll just avoid generating anything for them.
	  -- we will still want to ignore all other pseudotypes
	  -- but records will be ok eventually.
	  AND type_ret.typtype <> 'p'

	  ) as funcs
join pg_type type_arg on funcs.arg=type_arg.oid -- internal args are never usable from sql.
group by proname,
	 ret_type
having (bool_and(type_arg.typtype <> 'p'))
order by (proname :: text) COLLATE "C"

	 ) funcdefs \gset


\echo :functions

SELECT format('type Domains = ''[%s]',
	 coalesce(string_agg(format(E'"%s" ::: ''Typedef PG%s',
					   pg_type.typname, p2.typname  ),
			E'\n   ,' ), '')) as domains,
       coalesce(string_agg(format ('type PG%s = PG%s', pg_type.typname, p2.typname ) , E'\n' order by (pg_type.typname :: text) COLLATE "C" asc, (p2.typname :: text) COLLATE "C" asc), '') as decls
FROM pg_catalog.pg_type
JOIN pg_catalog.pg_namespace ON pg_namespace.oid = pg_type.typnamespace
join pg_catalog.pg_type p2 on pg_type.typbasetype = p2.oid
WHERE pg_type.typtype = 'd' AND nspname = :'chosen_schema' \gset

\echo :domains
\echo :decls
