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

module Composites.Public where
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
type PGclump = 'PGcomposite '["foo" ::: 'NotNull PGtext, "bar" ::: 'NotNull PGint4]
type PGvarclump = 'PGcomposite '["vfoo" ::: 'NotNull PGtext, "vbar" ::: 'NotNull PGint4, "vbaz" ::: 'NotNull PGtext]
type Composites =
  ('["clump" ::: 'Typedef PGclump,
  "varclump" ::: 'Typedef PGvarclump] :: [(Symbol,SchemumType)])

-- schema
type Tables = ('[
   "dummy" ::: 'Table DummyTable]  :: [(Symbol,SchemumType)])

-- defs
type DummyColumns = '["i" ::: 'NoDef :=> 'Null PGint4]
type DummyConstraints = '[]
type DummyTable = DummyConstraints :=> DummyColumns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[  ]
type Domains = '[]

