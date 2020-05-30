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

module Basic.Schema where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)

-- squeal doesn't yet support cidr or ltree, so for the moment we emit them explicitly
type PGcidr = UnsafePGType "cidr"
type PGltree = UnsafePGType "ltree"
type PGltxtquery = UnsafePGType "ltxtquery"
type PGlquery = UnsafePGType "lquery"

type DB = '["public" ::: Schema]

type Schema = Join Tables (Join Views (Join Enums (Join Functions Domains)))
-- enums

-- decls
type Enums =
  ('[] :: [(Symbol,SchemumType)])
-- schema
type Tables = ('[
   "foo" ::: 'Table FooTable
  ,"foo2" ::: 'Table Foo2Table]  :: [(Symbol,SchemumType)])

-- defs
type FooColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"name" ::: 'NoDef :=> 'Null PGtext]
type FooConstraints = '[]
type FooTable = FooConstraints :=> FooColumns

type Foo2Columns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"limited" ::: 'NoDef :=> 'NotNull (PGvarchar 12)]
type Foo2Constraints = '[]
type Foo2Table = Foo2Constraints :=> Foo2Columns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[  ]
type Domains = '[]

