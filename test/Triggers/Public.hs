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

module Triggers.Public where
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
   "accounts" ::: 'Table AccountsTable
  ,"audit_log" ::: 'Table AuditLogTable]  :: [(Symbol,SchemumType)])

-- defs
type AccountsColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"balance" ::: 'Def :=> 'NotNull PGint8
  ,"status" ::: 'NoDef :=> 'Null PGtext]
type AccountsConstraints = '["accounts_pkey" ::: 'PrimaryKey '["id"]]
type AccountsTable = AccountsConstraints :=> AccountsColumns

type AuditLogColumns = '["event" ::: 'NoDef :=> 'NotNull PGtext]
type AuditLogConstraints = '[]
type AuditLogTable = AuditLogConstraints :=> AuditLogColumns

-- VIEWS
type Views =
  '["account_view" ::: 'View AccountViewView]

type AccountViewView =
  '["id" ::: 'Null PGint4
   ,"balance" ::: 'Null PGint8
   ,"status" ::: 'Null PGtext]

-- functions
type Functions =
  '[  ]
type Domains = '[]

-- triggers
type Triggers =
  '[ '("accounts_after_stmt", "AFTER:STATEMENT:DELETE")
   , '("accounts_balance_guard", "AFTER:ROW:INSERT OR UPDATE:CONSTRAINT")
   , '("accounts_before_row", "BEFORE:ROW:INSERT OR UPDATE")
   , '("account_view_instead_row", "INSTEAD OF:ROW:INSERT OR UPDATE OR DELETE")
   ]
-- Omitted/fallback triggers: none
