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

module Checks.Public where
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
   "checked_accounts" ::: 'Table CheckedAccountsTable]  :: [(Symbol,SchemumType)])

-- defs
type CheckedAccountsColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"amount" ::: 'NoDef :=> 'Null PGint8
  ,"balance" ::: 'NoDef :=> 'NotNull PGint8
  ,"status" ::: 'NoDef :=> 'Null PGtext
  ,"quantity" ::: 'NoDef :=> 'Null PGpositive_amount]
type CheckedAccountsConstraints = '[-- | CHECK (amount > 0)
  "amount_positive" ::: 'Check '["amount"]
  ,-- | CHECK (balance >= 0)
  "balance_nonnegative" ::: 'Check '["balance"]
  ,"checked_accounts_pkey" ::: 'PrimaryKey '["id"]
  ,-- | CHECK (1 = 1)
  "literal_true" ::: 'Check '[]
  ,-- | CHECK (status IS NULL OR char_length(status) > 0)
  "status_guard" ::: 'Check '["status"]]
type CheckedAccountsTable = CheckedAccountsConstraints :=> CheckedAccountsColumns

-- VIEWS
type Views = 
  '[]

-- functions
type Functions = 
  '[  ]
-- Omitted function signatures: none
-- Omitted SRF signatures: none
type Domains = '["positive_amount" ::: 'Typedef PGint8]
type PGpositive_amount = PGint8
-- Check-constraint fallback notes:
--   domain public.positive_amount positive_amount_check: not representable in Domains typedef output (CHECK (VALUE > 0))
--   public.checked_accounts amount_positive: expression emitted as Haddock note only (CHECK (amount > 0))
--   public.checked_accounts balance_nonnegative: expression emitted as Haddock note only (CHECK (balance >= 0))
--   public.checked_accounts literal_true: expression emitted as Haddock note only (CHECK (1 = 1))
--   public.checked_accounts status_guard: expression emitted as Haddock note only (CHECK (status IS NULL OR char_length(status) > 0))

-- triggers
-- Trigger contract: Triggers is generated metadata and is not composed into Schema.
type Triggers = 
  '[]

-- Trigger fallback notes: none
