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

module InetArrays.Schema where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)

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
   "address_sets" ::: 'Table AddressSetsTable]  :: [(Symbol,SchemumType)])

-- defs
type AddressSetsColumns = '["addresses" ::: 'NoDef :=> 'NotNull (PGvararray (NotNull PGinet))]
type AddressSetsConstraints = '[]
type AddressSetsTable = AddressSetsConstraints :=> AddressSetsColumns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[  ]
type Domains = '[]

