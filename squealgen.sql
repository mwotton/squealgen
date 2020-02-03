
\set QUIET   
set search_path to information_schema;
-- imports of DOOM
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
with   mytables as (SELECT tables.*,
                         initcap(tables.table_name) as cappedName,
			 '[]'::text as haskCols,
			 '[]'::text as constraintCols,			 
                         json_object_agg (columns.column_name, columns.*) as columns
FROM columns
join tables on columns.table_name = tables.table_name
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
select string_agg('type ' || mytables.cappedName || 'Columns = ''' || mytables.haskCols, E'\n') as cols,
       string_agg('type ' || mytables.cappedName || 'Constraints = ''' || mytables.constraintCols, E'\n') as straints,
       string_agg('type ' || mytables.cappedName || 'Table = ' || mytables.cappedName || 'Constraints :=> ' || mytables.cappedName || 'Columns', E'\n') as tabs
from mytables \gset

\echo :cols
\echo :straints
\echo :tabs

