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

module Members.Public where
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
   "emails" ::: 'Table EmailsTable
  ,"users" ::: 'Table UsersTable]  :: [(Symbol,SchemumType)])

-- defs
type EmailsColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"user_id" ::: 'NoDef :=> 'NotNull PGint4
  ,"email" ::: 'NoDef :=> 'Null PGtext]
type EmailsConstraints = '["fk_user_id" ::: 'ForeignKey '["user_id"] "public" "users" '["id"]
  ,"pk_emails" ::: 'PrimaryKey '["id"]]
type EmailsTable = EmailsConstraints :=> EmailsColumns

type UsersColumns = '["id" ::: 'Def :=> 'NotNull PGint4
  ,"name" ::: 'NoDef :=> 'NotNull PGtext
  ,"key" ::: 'NoDef :=> 'NotNull PGtext]
type UsersConstraints = '["pk_users" ::: 'PrimaryKey '["id"]
  ,"uniqueness" ::: 'Unique '["name","key"]]
type UsersTable = UsersConstraints :=> UsersColumns

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[  ]
type Domains = '[]

