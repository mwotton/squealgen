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

module Extensions.Public where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)

-- Required extensions:
--   ltree

type PGltree = UnsafePGType "ltree"


type DB = '["public" ::: Schema]

type Schema = Join Tables (Join Views (Join Enums (Join Functions (Join Composites Domains))))
-- Trigger contract: Triggers is generated metadata and is not composed into Schema.
-- enums

-- decls
type Enums =
  ('[] :: [(Symbol,SchemumType)])

type Composites =
  ('[] :: [(Symbol,SchemumType)])

-- schema
type Tables = ('[
   "paths" ::: 'Table PathsTable]  :: [(Symbol,SchemumType)])

-- defs
type PathsColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"path" ::: 'NoDef :=> 'NotNull PGltree]
type PathsConstraints = '["paths_pkey" ::: 'PrimaryKey '["id"]]
type PathsTable = PathsConstraints :=> PathsColumns

-- VIEWS
type Views = 
  '[]

-- functions
type Functions = 
  '[ "path_depth" ::: Function ('[ NotNull PGltree ] :=> 'Returns ( 'Null PGint4) ) ]
-- Omitted function signatures: none
-- Omitted SRF signatures: none
type Domains = '[]

-- Check-constraint fallback notes: none

-- triggers
-- Trigger contract: Triggers is generated metadata and is not composed into Schema.
type Triggers = 
  '[]

-- Trigger fallback notes: none
