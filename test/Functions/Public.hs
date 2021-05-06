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

module Functions.Public where
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
   "integers" ::: 'Table IntegersTable]  :: [(Symbol,SchemumType)])

-- defs
type IntegersColumns = '["num" ::: 'NoDef :=> 'NotNull PGint8]
type IntegersConstraints = '[]
type IntegersTable = IntegersConstraints :=> IntegersColumns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[ "doubler" ::: Function ('[ Null PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "many_params" ::: Function ('[ NotNull PGint8,  NotNull PGfloat4,  NotNull PGtext ] :=> 'Returns ( 'Null PGtext) )
   , "somefunc" ::: Function ('[ Null PGint4,  Null PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "strict_doubler" ::: Function ('[ NotNull PGint8 ] :=> 'Returns ( 'Null PGint8) ) ]
type Domains = '[]

