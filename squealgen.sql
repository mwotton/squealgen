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

create or replace function pg_temp.type_decl_from(data_type text, udt_name text, domain_name text, nullable bool, fieldlen cardinal_number) RETURNS text as $$
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
	 else ('PG' || (coalesce(domain_name, udt_name) :: text))
	 end)
    end);
$$
LANGUAGE sql;


create or replace function pg_temp.haddock_comment(message text, indent text default '')
  returns text as $$
  select case
           when message is null or btrim(message) = '' then ''
           else indent || '-- | ' || regexp_replace(message, E'\n', E'\n' || indent || '--   ', 'g') || E'\n'
         end;
$$
language sql
immutable;


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
\echo type PGname = UnsafePGType "name"
\echo type PGregclass = UnsafePGType "regclass"
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
-- Determine only the enums actually used by the chosen schema (including arrays and function args/returns)
with used_enums as (
  -- From table/view columns in information_schema
  select distinct (case when t.typcategory = 'A' then elem.typname else t.typname end) as enumname
  from information_schema.columns c
  join pg_catalog.pg_type t on t.typname = c.udt_name
  left join pg_catalog.pg_type elem on t.typcategory = 'A' and elem.oid = t.typelem
  join pg_catalog.pg_type base on (case when t.typcategory = 'A' then base.oid = elem.oid else base.oid = t.oid end)
  where c.table_schema = :'chosen_schema'
    and base.typcategory = 'E'
  union
  -- From function arguments in the chosen schema
  select distinct (case when targ.typcategory = 'A' then elem2.typname else targ.typname end) as enumname
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace ns on ns.oid = p.pronamespace
  join unnest(p.proargtypes) as arg(oid) on true
  join pg_catalog.pg_type targ on targ.oid = arg.oid
  left join pg_catalog.pg_type elem2 on targ.typcategory = 'A' and elem2.oid = targ.typelem
  join pg_catalog.pg_type base2 on (case when targ.typcategory = 'A' then base2.oid = elem2.oid else base2.oid = targ.oid end)
  where ns.nspname = :'chosen_schema'
    and base2.typcategory = 'E'
  union
  -- From function return types in the chosen schema
  select distinct (case when tret.typcategory = 'A' then elem3.typname else tret.typname end) as enumname
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace ns on ns.oid = p.pronamespace
  join pg_catalog.pg_type tret on tret.oid = p.prorettype
  left join pg_catalog.pg_type elem3 on tret.typcategory = 'A' and elem3.oid = tret.typelem
  join pg_catalog.pg_type base3 on (case when tret.typcategory = 'A' then base3.oid = elem3.oid else base3.oid = tret.oid end)
  where ns.nspname = :'chosen_schema'
    and base3.typcategory = 'E'
  union
  -- From composite type attributes in the chosen schema
  select distinct (case when att_t.typcategory = 'A' then elem4.typname else att_t.typname end) as enumname
  from pg_catalog.pg_type comp
  join pg_catalog.pg_namespace comp_ns on comp_ns.oid = comp.typnamespace
  join pg_catalog.pg_class comp_cls on comp.typrelid = comp_cls.oid
  join pg_catalog.pg_attribute a on a.attrelid = comp.typrelid and a.attnum > 0 and not a.attisdropped
  join pg_catalog.pg_type att_t on att_t.oid = a.atttypid
  left join pg_catalog.pg_type elem4 on att_t.typcategory = 'A' and elem4.oid = att_t.typelem
  join pg_catalog.pg_type base4 on (case when att_t.typcategory = 'A' then base4.oid = elem4.oid else base4.oid = att_t.oid end)
  where comp_ns.nspname = :'chosen_schema'
    and comp.typtype = 'c'
    and comp_cls.relkind = 'c'
    and base4.typcategory = 'E'
),
enumerations as (
  select
       format(E'type PG%s = ''PGenum\n  ''[%s]',
                t.typname,
                string_agg(format('"%s"', e.enumlabel), ', ' order by e.enumsortorder)) as line,
       format(E'"%1$s" ::: ''Typedef PG%1$s', t.typname) as decl
  from pg_type t
     join pg_enum e on t.oid = e.enumtypid
     join pg_catalog.pg_namespace n ON n.oid = t.typnamespace
  where t.typname in (select enumname from used_enums)
  group by t.typname
  order by (t.typname :: text COLLATE "C")
)
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
    string_agg(
      format(
        E'"%s" ::: ''NotNull %s',
        a.attname,
        pg_temp.type_decl_from(
          case when t2.typcategory = 'A' then 'ARRAY' else 'USER-DEFINED' end,
          t2.typname,
          NULL,
          false,
          case when a.atttypmod > 4 then a.atttypmod - 4 else NULL end
        )
      )
      ,', ' order by a.attnum ASC)) as types,
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
join (
  -- Select normal columns from information_schema
  select columns.table_schema,
         columns.table_name,
         columns.ordinal_position,
         format('"%s" ::: %s :=> %s %s',
           column_name,
           case when column_default is null then '''NoDef' else '''Def' end,
           (case is_nullable
              when 'YES' then '''Null'
              when 'NO'  then '''NotNull'
              else pg_temp.croak ('is_nullable broken somehow: ' || is_nullable)
            end),
           -- nb: we are assuming the inner array may be nullable. this may not be true, TODO
           pg_temp.type_decl_from(data_type, udt_name, domain_name, false, character_maximum_length)
         ) as colDef
  from columns
  where columns.table_schema = :'chosen_schema'
  union all
  -- Include system OID column for catalogs that expose it (e.g. pg_catalog)
  select :'chosen_schema'::text as table_schema,
         c.relname          as table_name,
         0::information_schema.cardinal_number as ordinal_position,
         '"oid" ::: ''NoDef :=> ''NotNull PGoid' as colDef
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  join pg_catalog.pg_attribute a on a.attrelid = c.oid
  where n.nspname = :'chosen_schema'
    and c.relkind = 'r'
    and a.attname = 'oid'
    and a.attnum < 0
    and not a.attisdropped
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


create temporary view tableComments as (
  select c.relname as table_name,
         obj_description(c.oid, 'pg_class') as comment
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = :'chosen_schema'
    and c.relkind = 'r'
);


create temporary view constraintDefs as (
SELECT
  con.oid AS conoid,
  con.conname AS conname,
  con.contype AS contype,
  nsp.nspname AS nsp,
  tab.relname AS table_name,
  col.cols,
  fnsp.nspname AS fnsp,
  ftab.relname AS ftab,
  fcol.fcols,
  pg_catalog.pg_get_constraintdef(con.oid, true) AS condef
FROM pg_catalog.pg_constraint AS con
join pg_catalog.pg_namespace n on n.oid = con.connamespace
INNER JOIN pg_catalog.pg_class AS tab
ON con.conrelid = tab.oid
INNER JOIN pg_catalog.pg_namespace AS nsp
ON con.connamespace = nsp.oid
LEFT JOIN LATERAL (select array_agg (all col.attname ORDER BY array_position(con.conkey, col.attnum) ASC) cols
		   from pg_catalog.pg_attribute col
		   where col.attnum > 0
		   and not col.attisdropped
		   and con.conkey @> ARRAY[col.attnum]
		   and con.conrelid = col.attrelid
		   ) col on true
LEFT OUTER JOIN pg_catalog.pg_class AS ftab
ON con.confrelid = ftab.oid
LEFT OUTER JOIN pg_catalog.pg_namespace AS fnsp
ON ftab.relnamespace = fnsp.oid
--LEFT OUTER JOIN pg_catalog.pg_attribute AS fcol
--ON con.confkey @> ARRAY[fcol.attnum] AND con.confrelid = fcol.attrelid
LEFT JOIN LATERAL (select array_agg (all fcol.attname ORDER BY array_position(con.confkey, fcol.attnum) ASC) fcols
		   from pg_catalog.pg_attribute fcol
		   where fcol.attnum > 0
		   and not fcol.attisdropped
		   and con.confkey @> ARRAY[fcol.attnum]
		   and con.confrelid = fcol.attrelid
		   ) fcol on true
WHERE con.contype IN ('f', 'c', 'p', 'u')
AND  n.nspname=:'chosen_schema'
GROUP BY
  con.oid,
  con.conname,
  con.contype,
  nsp.nspname,
  tab.relname,
  fnsp.nspname,
  ftab.relname,
  col.cols,
  fcol.fcols,
  pg_catalog.pg_get_constraintdef(con.oid, true)
);

select coalesce(string_agg(allDefs.tabData, E'\n'),'') as defs,
       format(E'type Tables = (''[\n   %s]  :: [(Symbol,SchemumType)])',
	 coalesce(string_agg(format('"%s" ::: ''Table %sTable', allDefs.table_name, allDefs.cappedName), E'\n  ,' order by allDefs.table_name COLLATE "C" ),'')) as schem

from (
  select format(E'type %1$sColumns = %2$s\ntype %1$sConstraints = ''[%3$s]\n%4$stype %1$sTable = %1$sConstraints :=> %1$sColumns\n',
	       replace(initcap(replace(defs.table_name, '_', ' ')), ' ', ''),
	       string_agg(defs.cols, 'XXXXX'), -- this shouldn't be necessary
	       string_agg(cd.str, 'YYYYY'),
	       coalesce(pg_temp.haddock_comment((select comment from tableComments where table_name = defs.table_name limit 1)), '')) as tabData,
	 replace(initcap(replace(defs.table_name, '_', ' ')), ' ', '') as cappedName,
	 defs.table_name
from (select table_name, string_agg(columnDefs.haskCols, E'\n  ,') as cols
      from columnDefs
      group by table_name
      order by table_name COLLATE "C") defs
left join (select table_name,
	     string_agg(
               case
               when contype = 'c' then
                 format(E'-- | %s\n  "%s" ::: %s',
                   constraintDefs.condef,
                   constraintDefs.conname,
                   case
                     when constraintDefs.cols is null or cardinality(constraintDefs.cols) = 0
                       then '''Check ''[]'
                     else format('''Check ''["%s"]', array_to_string(constraintDefs.cols,'","'))
                   end)
               else
                 format('"%s" ::: %s',constraintDefs.conname,
	           case contype
	           when 'p' then format('''PrimaryKey ''["%s"]', array_to_string(cols, '","'))
	           when 'f' then format('''ForeignKey ''["%s"] "%s" "%s" ''["%s"]', array_to_string(cols,'","'), fnsp, ftab, array_to_string(fcols, '","'))
	           when 'u' then format('''Unique ''["%s"]', array_to_string(cols,'","'))
	           else pg_temp.croak (format('bad type %s',contype))
	           end)
               end
			, E'\n  ,' order by (constraintDefs.conname ::text) COLLATE "C") as str
from constraintDefs
where contype in ('p', 'f', 'u', 'c')
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
  string_agg(
    format(E'"%s" ::: ''%s %s',
      cols.column_name,
      case cols.is_nullable
        when 'YES' then 'Null'
        when 'NO'  then 'NotNull'
        else 'Null'
      end,
      pg_temp.type_decl_from(cols.data_type, cols.udt_name, cols.domain_name, false, cols.character_maximum_length)
    )
    ,E'\n   ,') as views,
  cols.table_name as viewname,
  obj_description(c.oid, 'pg_class') as comment
FROM information_schema.columns cols
JOIN pg_catalog.pg_class c ON c.relname = cols.table_name
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE cols.table_schema = :'chosen_schema'
  AND n.nspname = :'chosen_schema'
  AND c.relkind IN ('v','m')
GROUP BY cols.table_name, obj_description(c.oid, 'pg_class')
ORDER BY (cols.table_name :: text) COLLATE "C");

-- select coalesce(string_agg(allDefs.tabData, E'\n'),'') as defs,
-- Emit the Views type list via a variable (short string),
-- but print each View type definition row-by-row to avoid oversized variables.
select format( E'type Views = \n  ''[%s]\n', coalesce(string_agg(format('"%s" ::: ''View %sView', viewname, pg_temp.initCaps(viewname)), ','), '')) as viewtype
  from my_views \gset
\echo :viewtype
\pset tuples_only on
\pset format unaligned
select format( E'%3$stype %1$sView = \n  ''[%2$s]\n'
             , pg_temp.initCaps(viewname)
             , views
             , coalesce(pg_temp.haddock_comment(comment), '') )
  from my_views
 order by viewname COLLATE "C";
\pset tuples_only off

\echo -- functions

create temporary view my_functions as
with function_meta as (
  select p.oid,
         p.proname,
         p.proisstrict,
         p.prokind,
         p.proretset,
         p.proargtypes,
         p.proargmodes,
         p.proallargtypes,
         p.proargnames,
         ret.typname as ret_type,
         ret.typcategory as ret_category,
         ret.typtype as ret_typtype,
         ret.typrelid as ret_typrelid
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace ns
      on ns.oid = p.pronamespace
    join pg_catalog.pg_type ret
      on ret.oid = p.prorettype
   where ns.nspname = :'chosen_schema'
), function_args as (
  select fm.oid,
         string_agg(
           format('%s %s',
                  case when fm.proisstrict then 'NotNull' else 'Null' end,
                  pg_temp.type_decl_from(type_arg.typcategory, type_arg.typname, null, false, null)),
           ',  ' order by args.arg_index
         ) filter (where args.arg_oid is not null) as arg_decls,
         string_agg(
           regexp_replace(
             lower(
               case
                 when type_arg_ns.nspname = 'pg_catalog' then type_arg.typname
                 else type_arg_ns.nspname || '_' || type_arg.typname
               end
             ),
             '[^a-z0-9]+', '_', 'g'),
           '__' order by args.arg_index
         ) filter (where args.arg_oid is not null) as arg_tokens,
         bool_and(type_arg.typtype <> 'p') filter (where args.arg_oid is not null) as args_representable
    from function_meta fm
    left join lateral unnest(fm.proargtypes) with ordinality as args(arg_oid, arg_index)
      on true
    left join pg_catalog.pg_type type_arg
      on type_arg.oid = args.arg_oid
    left join pg_catalog.pg_namespace type_arg_ns
      on type_arg_ns.oid = type_arg.typnamespace
   group by fm.oid
), function_srf_outcols as (
  select fm.oid,
         string_agg(
           format('"%s" ::: ''Null %s',
             coalesce((fm.proargnames)[idx.pos], format('column_%s', idx.pos)),
             pg_temp.type_decl_from(arg_type.typcategory, arg_type.typname, null, false, null)),
           ',' order by idx.pos
         ) as row_decls,
         bool_and(arg_type.typtype <> 'p') as row_representable
    from function_meta fm
    join lateral generate_subscripts(coalesce(fm.proallargtypes, array[]::oid[]), 1) as idx(pos)
      on true
    join pg_catalog.pg_type arg_type
      on arg_type.oid = (fm.proallargtypes)[idx.pos]
   where coalesce((fm.proargmodes)[idx.pos]::text, 'i') in ('o', 't', 'b')
   group by fm.oid
), function_srf_composite_cols as (
  select fm.oid,
         string_agg(
           format('"%s" ::: ''Null %s',
             a.attname,
             pg_temp.type_decl_from(att_t.typcategory, att_t.typname, null, false, null)),
           ',' order by a.attnum
         ) as row_decls,
         bool_and(att_t.typtype <> 'p') as row_representable
    from function_meta fm
    join pg_catalog.pg_attribute a
      on a.attrelid = fm.ret_typrelid
     and a.attnum > 0
     and not a.attisdropped
    join pg_catalog.pg_type att_t
      on att_t.oid = a.atttypid
   where fm.proretset
     and fm.ret_typtype = 'c'
   group by fm.oid
), function_classified as (
  select fm.oid,
         fm.proname,
         fm.prokind,
         fm.proretset,
         fm.ret_type,
         fm.ret_category,
         count(*) over (partition by fm.proname) as overload_count,
         coalesce(fa.arg_decls, '') as arg_decls,
         coalesce(fa.arg_tokens, '') as arg_tokens,
         (fm.proretset and coalesce(fo.row_decls, fc.row_decls) is not null)
           or (fm.proretset and fm.ret_typtype <> 'p' and fm.ret_typtype <> 'c') as is_srf,
         case
           when fm.proretset and fo.row_decls is not null then fo.row_decls
           when fm.proretset and fm.ret_typtype = 'c' then fc.row_decls
           when fm.proretset then format('"result" ::: ''Null %s',
                               pg_temp.type_decl_from(fm.ret_category, fm.ret_type, null, false, null))
           else null
         end as srf_row_decls,
         case
           when fm.proretset and fo.row_decls is not null then coalesce(fo.row_representable, true)
           when fm.proretset and fm.ret_typtype = 'c' then coalesce(fc.row_representable, false)
           when fm.proretset then fm.ret_typtype <> 'p'
           else true
         end as srf_representable,
         case
           when fm.proretset and (
             case
               when fo.row_decls is not null then not coalesce(fo.row_representable, true)
               when fm.ret_typtype = 'c' then not coalesce(fc.row_representable, false)
               else fm.ret_typtype = 'p'
             end
           ) then 'set-returning pseudotype return is not representable'
           when not coalesce(fa.args_representable, true) then 'pseudotype argument is not representable'
           when not fm.proretset and fm.prokind <> 'p' and fm.ret_typtype = 'p' then 'pseudotype return is not representable'
           else null
         end as omission_reason
    from function_meta fm
    left join function_args fa
      on fa.oid = fm.oid
    left join function_srf_outcols fo
      on fo.oid = fm.oid
    left join function_srf_composite_cols fc
      on fc.oid = fm.oid
), function_labeled as (
  select funcs.*,
         count(*) filter (where funcs.omission_reason is null) over (partition by funcs.proname) as representable_overload_count,
         case
           when funcs.overload_count > 1
             then funcs.proname || '__' || coalesce(nullif(funcs.arg_tokens, ''), 'noargs')
           else funcs.proname
         end as disambiguated_label
    from function_classified funcs
)
select proname,
       prokind,
       proretset,
       arg_decls,
       arg_tokens,
       ret_type,
       ret_category,
       is_srf,
       srf_row_decls,
       omission_reason,
       disambiguated_label as label,
       case
         when overload_count > 1
              and omission_reason is null
              and representable_overload_count = 1
           then proname
         else null
       end as compatibility_alias
  from function_labeled;

select format(E'type Functions = \n  ''[ %s ]'
     , coalesce(string_agg(
         case
           when entries.prokind = 'p'
             then format(E'"%s" ::: ''Procedure ''[ %s ]',
                         entries.label,
                         entries.arg_decls)
           when entries.is_srf
             then format(E'"%s" ::: Function (''[ %s ] :=> ''ReturnsTable ''[%s])',
                         entries.label,
                         entries.arg_decls,
                         entries.srf_row_decls)
           else format(E'"%s" ::: Function (''[ %s ] :=> ''Returns ( ''Null %s) )',
                       entries.label,
                       entries.arg_decls,
                       pg_temp.type_decl_from(entries.ret_category, entries.ret_type, null, false, null))
         end,
         E'\n   , ' order by (entries.label :: text) COLLATE "C"), '')
       ) as functions
from (
  select funcs.label,
         funcs.prokind,
         funcs.is_srf,
         funcs.arg_decls,
         funcs.srf_row_decls,
         funcs.ret_category,
         funcs.ret_type
    from my_functions funcs
   where funcs.omission_reason is null
  union all
  select funcs.compatibility_alias as label,
         funcs.prokind,
         funcs.is_srf,
         funcs.arg_decls,
         funcs.srf_row_decls,
         funcs.ret_category,
         funcs.ret_type
    from my_functions funcs
   where funcs.omission_reason is null
     and funcs.compatibility_alias is not null
) entries \gset
\echo :functions

select case
         when count(*) = 0 then '-- Omitted function signatures: none'
         else E'-- Omitted function signatures:\n'
              || string_agg(
                   format(E'--   %s(%s): %s',
                     funcs.proname,
                     coalesce(nullif(replace(funcs.arg_tokens, '__', ', '), ''), 'noargs'),
                     funcs.omission_reason),
                   E'\n' order by (funcs.proname :: text) COLLATE "C",
                                 (funcs.arg_tokens :: text) COLLATE "C")
       end as omitted_function_signatures
  from my_functions funcs
 where funcs.omission_reason is not null
   and not funcs.proretset \gset
\echo :omitted_function_signatures

select case
         when count(*) = 0 then '-- Omitted SRF signatures: none'
         else E'-- Omitted SRF signatures:\n'
              || string_agg(
                   format(E'--   %s(%s): %s',
                     funcs.proname,
                     coalesce(nullif(replace(funcs.arg_tokens, '__', ', '), ''), 'noargs'),
                     funcs.omission_reason),
                   E'\n' order by (funcs.proname :: text) COLLATE "C",
                                 (funcs.arg_tokens :: text) COLLATE "C")
       end as omitted_srf_signatures
  from my_functions funcs
 where funcs.omission_reason is not null
   and funcs.proretset \gset
\echo :omitted_srf_signatures

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

select case
         when count(*) = 0 then '-- Omitted/fallback check constraints: none'
         else E'-- Omitted/fallback check constraints:\n'
              || string_agg(line, E'\n' order by (line :: text) COLLATE "C")
       end as omitted_fallback_check_constraints
from (
  select format(
           E'--   %s.%s %s: expression emitted as Haddock note only (%s)',
           c.nsp,
           c.table_name,
           c.conname,
           c.condef
         ) as line
  from constraintDefs c
  where c.contype = 'c'
  union all
  select format(
           E'--   domain %s.%s %s: not representable in Domains typedef output (%s)',
           dn.nspname,
           dt.typname,
           con.conname,
           pg_catalog.pg_get_constraintdef(con.oid, true)
         ) as line
  from pg_catalog.pg_constraint con
  join pg_catalog.pg_type dt
    on dt.oid = con.contypid
  join pg_catalog.pg_namespace dn
    on dn.oid = dt.typnamespace
  where con.contype = 'c'
    and dn.nspname = :'chosen_schema'
) fallback_checks \gset
\echo :omitted_fallback_check_constraints

create temporary view triggerDefs as (
  select t.oid as tgoid,
         t.tgname as trigger_name,
         rel.relname as relation_name,
         case
           when (t.tgtype & 2) <> 0 then 'BEFORE'
           when (t.tgtype & 64) <> 0 then 'INSTEAD OF'
           else 'AFTER'
         end as trigger_timing,
         case
           when (t.tgtype & 1) <> 0 then 'ROW'
           else 'STATEMENT'
         end as trigger_level,
         array_to_string(
           array_remove(
             array[
               case when (t.tgtype & 4) <> 0 then 'INSERT' end,
               case when (t.tgtype & 8) <> 0 then 'DELETE' end,
               case when (t.tgtype & 16) <> 0 then 'UPDATE' end,
               case when (t.tgtype & 32) <> 0 then 'TRUNCATE' end
             ],
             null
           ),
           ' OR '
         ) as trigger_events,
         (t.tgconstraint <> 0) as is_constraint_trigger,
         pg_catalog.pg_get_triggerdef(t.oid, true) as trigger_definition
  from pg_catalog.pg_trigger t
  join pg_catalog.pg_class rel
    on rel.oid = t.tgrelid
  join pg_catalog.pg_namespace n
    on n.oid = rel.relnamespace
  where n.nspname = :'chosen_schema'
    and not t.tgisinternal
);

\echo
\echo -- triggers
select case
         when count(*) = 0 then E'type Triggers = \n  ''[]'
         else format(
           E'type Triggers = \n  ''[ %s ]',
           string_agg(
             format(
               E'''("%s", "%s")',
               replace(td.trigger_name, '"', E'\\\"'),
               replace(
                 replace(
                   coalesce(
                     td.trigger_definition,
                     format(
                       '%s %s %s ON %s%s',
                       td.trigger_timing,
                       td.trigger_level,
                       td.trigger_events,
                       td.relation_name,
                       case when td.is_constraint_trigger then ' [constraint]' else '' end
                     )
                   ),
                   E'\\',
                   E'\\\\'
                 ),
                 '"',
                 E'\\\"'
               )
             ),
             E'\n   , ' order by (td.trigger_name :: text) COLLATE "C"
           )
         )
       end as triggers
  from triggerDefs td \gset
\echo :triggers

select coalesce(
         string_agg(
           format(
             E'-- | Trigger %s on %s: full definition unavailable, emitted metadata fallback.',
             td.trigger_name,
             td.relation_name
           ),
           E'\n' order by (td.trigger_name :: text) COLLATE "C"
         ),
         ''
       ) as fallback_trigger_haddocks
  from triggerDefs td
 where td.trigger_definition is null \gset
\echo :fallback_trigger_haddocks

select case
         when count(*) = 0 then '-- Omitted/fallback triggers: none'
         else E'-- Omitted/fallback triggers:\n'
              || string_agg(
                   format(
                     E'--   %s on %s: full definition unavailable; emitted metadata fallback (%s %s %s%s)',
                     td.trigger_name,
                     td.relation_name,
                     td.trigger_timing,
                     td.trigger_level,
                     td.trigger_events,
                     case when td.is_constraint_trigger then ', constraint trigger' else '' end
                   ),
                   E'\n' order by (td.trigger_name :: text) COLLATE "C"
                 )
       end as omitted_fallback_triggers
  from triggerDefs td
 where td.trigger_definition is null \gset
\echo :omitted_fallback_triggers
