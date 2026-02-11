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
-- Omitted function signatures:
--   account_view_iou(noargs): pseudotype return is not representable
--   check_balance_not_negative(noargs): pseudotype return is not representable
--   log_account_row(noargs): pseudotype return is not representable
--   log_account_stmt(noargs): pseudotype return is not representable
-- Omitted SRF signatures: none
type Domains = '[]

-- Omitted/fallback check constraints: none

-- triggers
type Triggers = 
  '[ '("account_view_instead_row", "CREATE TRIGGER account_view_instead_row INSTEAD OF INSERT OR DELETE OR UPDATE ON account_view FOR EACH ROW EXECUTE FUNCTION account_view_iou()")
   , '("accounts_after_stmt", "CREATE TRIGGER accounts_after_stmt AFTER DELETE ON accounts FOR EACH STATEMENT EXECUTE FUNCTION log_account_stmt()")
   , '("accounts_balance_guard", "CREATE CONSTRAINT TRIGGER accounts_balance_guard AFTER INSERT OR UPDATE ON accounts DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_balance_not_negative()")
   , '("accounts_before_row", "CREATE TRIGGER accounts_before_row BEFORE INSERT OR UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION log_account_row()") ]

-- Omitted/fallback triggers: none
