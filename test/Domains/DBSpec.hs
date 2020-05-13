{-# LANGUAGE DeriveAnyClass       #-}
{-# LANGUAGE DerivingStrategies   #-}
{-# LANGUAGE DerivingVia          #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE UndecidableInstances #-}
module Domains.DBSpec where

import           Data.Int
import           DBHelpers         (runSession)
import           Domains.Schema
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           Test.Hspec

validInsert :: Statement DB (Only Int64) ()
validInsert = manipulation $
  insertInto_ #pluslove
    (Values_ (Set (param @1) `as` #num))

spec = describe "Domains" $ do
  it "accepts a good value" $ do
    runSession "./test/Domains/Schema.dump.sql"
      (getRows =<< executeParams validInsert (Only ((1)::Int64)))
      `shouldReturn` []
  it "rejects a bad one" $ do
    runSession "./test/Domains/Schema.dump.sql"
      (getRows =<< executeParams validInsert (Only ((-1)::Int64)))
      `shouldThrow` (\(_::SquealException) -> True)
