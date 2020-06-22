-- | This is derived from the demo in the Squeal readme.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module Members.DBSpec where

import Members.Schema

import Squeal.PostgreSQL
import UnliftIO
import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Data.Text(Text)

import Test.Hspec.Expectations.Lifted
import Test.Hspec (it,describe)

import DBHelpers

data User = User { userName :: Text, userEmail :: Maybe Text , userKey :: Text}
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

users :: [User]
users =
  [ User "Alice" (Just "alice@gmail.com") "aaa"
  , User "Bob" Nothing "bbb"
  , User "Carole" (Just "carole@hotmail.com") "ccc"
  ]

insertUser :: Statement DB User ()
insertUser = manipulation $ with (u `as` #u) e
  where
    u = insertInto #users
      (Values_ (Default `as` #id
                :* Set (param @1) `as` #name
                :* Set (param @3) `as` #key))

      OnConflictDoRaise (Returning_ (#id :* param @2 `as` #email))
    e = insertInto_ #emails $ Select
      (Default `as` #id :* Set (#u ! #id) `as` #user_id :* Set (#u ! #email) `as` #email)
      (from (common #u))


getUsers :: Statement DB () User
getUsers = query $ select_
  (#u ! #name `as` #userName
   :* #e ! #email `as` #userEmail
   :* #u ! #key `as` #userKey )
  ( from (table (#users `as` #u)
    & innerJoin (table (#emails `as` #e))
      (#u ! #id .== #e ! #user_id)) )


spec = describe "Members" $ do
  it "can run a simple query" $ runSession "./test/Members/schemas" $ do
    executePrepared_ insertUser users
    fetchedUsers <- getRows =<< execute getUsers
    fetchedUsers `shouldBe` users
