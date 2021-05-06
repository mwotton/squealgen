-- | This code was originally created by squealgen. Edit if you know how it got made and are willing to own it now.
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE GADTs #-}
{-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}

module CompositeForeignKeys.Public where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)

type PGname = UnsafePGType "name"
type PGregclass = UnsafePGType "regclass"
type PGltree = UnsafePGType "ltree"
type PGcidr = UnsafePGType "cidr"
type PGltxtquery = UnsafePGType "ltxtquery"
type PGlquery = UnsafePGType "lquery"


type DB = '["public" ::: Schema]

type Schema = Join Tables (Join Views (Join Enums (Join Functions (Join Composites Domains))))
-- enums

-- decls
type Enums =
  ('[] :: [(Symbol,SchemumType)])

type Composites =
  ('[] :: [(Symbol,SchemumType)])

-- schema
type Tables = ('[
   "table_one" ::: 'Table TableOneTable
  ,"table_two" ::: 'Table TableTwoTable]  :: [(Symbol,SchemumType)])

-- defs
type TableOneColumns = '["table_two_id" ::: 'NoDef :=> 'Null PGint4
  ,"col_one" ::: 'NoDef :=> 'NotNull PGint4
  ,"col_two" ::: 'NoDef :=> 'NotNull PGint4]
type TableOneConstraints = '["table_one_pkey" ::: 'PrimaryKey '["col_one","col_two"]]
type TableOneTable = TableOneConstraints :=> TableOneColumns

type TableTwoColumns = '["table_two_id" ::: 'NoDef :=> 'Null PGint4
  ,"col_one" ::: 'NoDef :=> 'Null PGint4
  ,"col_two" ::: 'NoDef :=> 'Null PGint4]
type TableTwoConstraints = '["table_two_fkey" ::: 'ForeignKey '["col_one","col_two"] "public" "table_one" '["col_one","col_two"]]
type TableTwoTable = TableTwoConstraints :=> TableTwoColumns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[  ]
type Domains = '[]

