-- | This is derived from the demo in the Squeal readme.
--   we use the column "user" because it tickles a corner case - postgresql double-quotes
--   it because it's a reserved word postgresql side.
--
--   this also tests complex primary keys
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module ComplexPrimary.DBSpec where

import ComplexPrimary.Schema

import Squeal.PostgreSQL
import UnliftIO
import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Data.Text(Text)

import Test.Hspec.Expectations.Lifted
import Test.Hspec (it,describe)

import DBHelpers

data User = User { userUser :: Text }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

users :: [User]
users =
  [ User "Alice"
  , User "Bob"
  , User "Carole"
  ]

insertUser :: Statement DB User ()
insertUser = manipulation $ insertInto_ #users (Values_ (Default `as` #id :* Set (param @1) `as` #user))

getUsers :: Statement DB () User
getUsers = query $ select_
  (#u ! #user `as` #userUser )
  ( from (table (#users `as` #u)) )


spec = describe "Members" $ do
  it "can run a simple query" $ runSession "./test/ComplexPrimary/Schema.dump.sql" $ do
    executePrepared_ insertUser users
    fetchedUsers <- getRows =<< execute getUsers
    fetchedUsers `shouldBe` users
