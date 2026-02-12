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

module ForeignKeyReferencedColumns.Public where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)





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
   "child_composite" ::: 'Table ChildCompositeTable
  ,"child_cross" ::: 'Table ChildCrossTable
  ,"child_single" ::: 'Table ChildSingleTable
  ,"parent_composite" ::: 'Table ParentCompositeTable
  ,"parent_single" ::: 'Table ParentSingleTable
  ,"self_ref" ::: 'Table SelfRefTable]  :: [(Symbol,SchemumType)])

-- defs
type ChildCompositeColumns = '["local_b" ::: 'NoDef :=> 'NotNull PGint4
  ,"local_a" ::: 'NoDef :=> 'NotNull PGint4]
type ChildCompositeConstraints = '["child_composite_parent_fk" ::: 'ForeignKey '["local_b","local_a"] "public" "parent_composite" '["ref_b","ref_a"]]
type ChildCompositeTable = ChildCompositeConstraints :=> ChildCompositeColumns

type ChildCrossColumns = '["left_local" ::: 'NoDef :=> 'NotNull PGint4
  ,"right_local" ::: 'NoDef :=> 'NotNull PGint4]
type ChildCrossConstraints = '["child_cross_parent_fk" ::: 'ForeignKey '["left_local","right_local"] "ref" "parent_cross" '["target_left","target_right"]]
type ChildCrossTable = ChildCrossConstraints :=> ChildCrossColumns

type ChildSingleColumns = '["local_parent_id" ::: 'NoDef :=> 'NotNull PGint4]
type ChildSingleConstraints = '["child_single_parent_fk" ::: 'ForeignKey '["local_parent_id"] "public" "parent_single" '["id"]]
type ChildSingleTable = ChildSingleConstraints :=> ChildSingleColumns

type ParentCompositeColumns = '["ref_a" ::: 'NoDef :=> 'NotNull PGint4
  ,"ref_b" ::: 'NoDef :=> 'NotNull PGint4]
type ParentCompositeConstraints = '["parent_composite_pkey" ::: 'PrimaryKey '["ref_a","ref_b"]]
type ParentCompositeTable = ParentCompositeConstraints :=> ParentCompositeColumns

type ParentSingleColumns = '["id" ::: 'NoDef :=> 'NotNull PGint4]
type ParentSingleConstraints = '["parent_single_pkey" ::: 'PrimaryKey '["id"]]
type ParentSingleTable = ParentSingleConstraints :=> ParentSingleColumns

type SelfRefColumns = '["id" ::: 'NoDef :=> 'NotNull PGint4
  ,"parent_local" ::: 'NoDef :=> 'Null PGint4]
type SelfRefConstraints = '["self_ref_parent_fk" ::: 'ForeignKey '["parent_local"] "public" "self_ref" '["id"]
  ,"self_ref_pkey" ::: 'PrimaryKey '["id"]]
type SelfRefTable = SelfRefConstraints :=> SelfRefColumns

-- VIEWS
type Views = 
  '[]

-- functions
type Functions = 
  '[  ]
-- Omitted function signatures: none
-- Omitted SRF signatures: none
type Domains = '[]

-- Check-constraint fallback notes: none

-- triggers
-- Trigger contract: Triggers is generated metadata and is not composed into Schema.
type Triggers = 
  '[]

-- Trigger fallback notes: none
