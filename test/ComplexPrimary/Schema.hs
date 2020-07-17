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

module ComplexPrimary.Schema where
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
   "users" ::: 'Table UsersTable]  :: [(Symbol,SchemumType)])

-- defs
type UsersColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"user" ::: 'NoDef :=> 'NotNull PGtext]
type UsersConstraints = '["pk_users" ::: 'PrimaryKey '["id","user"]]
type UsersTable = UsersConstraints :=> UsersColumns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[  ]
type Domains = '[]

