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

module Domains.Public where
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
   "pluslove" ::: 'Table PlusloveTable]  :: [(Symbol,SchemumType)])

-- defs
type PlusloveColumns = '["num" ::: 'NoDef :=> 'NotNull PGpositive]
type PlusloveConstraints = '[]
type PlusloveTable = PlusloveConstraints :=> PlusloveColumns

-- VIEWS
type Views = 
  '[]

-- functions
type Functions = 
  '[ "increment_positive" ::: Function ('[ NotNull PGpositive ] :=> 'Returns ( 'Null PGpositive) ) ]
-- Omitted function signatures: none
-- Omitted SRF signatures: none
type Domains = '["positive" ::: 'Typedef PGint8]
type PGpositive = PGint8
-- Check-constraint fallback notes:
--   domain public.positive positive_check: not representable in Domains typedef output (CHECK (VALUE > 0 AND VALUE IS NOT NULL))

-- triggers
type Triggers = 
  '[]

-- Trigger fallback notes: none
