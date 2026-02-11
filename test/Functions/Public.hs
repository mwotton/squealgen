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
type PGscore_row = 'PGcomposite '["num" ::: 'NotNull PGint8, "label" ::: 'NotNull PGtext]
type Composites =
  ('["score_row" ::: 'Typedef PGscore_row] :: [(Symbol,SchemumType)])

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
   , "inout_only" ::: Function ('[ Null PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "many_params" ::: Function ('[ NotNull PGint8,  NotNull PGfloat4,  NotNull PGtext ] :=> 'Returns ( 'Null PGtext) )
   , "mixed_in_inout" ::: Function ('[ Null PGint8,  Null PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "out_only" ::: Function ('[  ] :=> 'Returns ( 'Null PGint8) )
   , "overloaded__int4" ::: Function ('[ Null PGint4 ] :=> 'Returns ( 'Null PGint4) )
   , "overloaded__int8" ::: Function ('[ Null PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "proc_increment" ::: 'Procedure '[ Null PGint8 ]
   , "somefunc" ::: Function ('[ Null PGint4,  Null PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "srf_composite" ::: Function ('[  ] :=> 'ReturnsTable '["num" ::: 'Null PGint8,"label" ::: 'Null PGtext])
   , "srf_scalar" ::: Function ('[ Null PGint8 ] :=> 'ReturnsTable '["result" ::: 'Null PGint8])
   , "srf_table" ::: Function ('[ Null PGint8 ] :=> 'ReturnsTable '["out_num" ::: 'Null PGint8,"out_text" ::: 'Null PGtext])
   , "strict_doubler" ::: Function ('[ NotNull PGint8 ] :=> 'Returns ( 'Null PGint8) )
   , "zero_arg" ::: Function ('[  ] :=> 'Returns ( 'Null PGint8) ) ]
-- Omitted function signatures:
--   inout_params(int8): pseudotype return is not representable
-- Omitted SRF signatures:
--   srf_any(anyelement): set-returning pseudotype return is not representable
type Domains = '[]

-- Omitted/fallback check constraints: none

-- triggers
type Triggers = 
  '[]

-- Omitted/fallback triggers: none
