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


newtype PositiveInt = PositiveInt { unPositive :: Int64 }
  deriving stock (Eq,Show,GHC.Generic)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)


validInsert :: Statement DB PositiveInt ()
validInsert = manipulation $
  insertInto_ #pluslove
    (Values_ (Set (param @1) `as` #num))

-- FIXME this should return (Only (Maybe PositiveInt)), waiting for help from eitan
increment :: Statement DB PositiveInt (Only (Maybe Int64))
increment = query $ values ((function #increment_positive) (param @1) `as` #fromOnly) []

spec = describe "Domains" $ do
  it "accepts a good value" $ do
    runSession "./test/Domains/Schema.dump.sql"
      (getRows =<< executeParams validInsert (PositiveInt 1))
      `shouldReturn` []
  it "rejects a bad one" $ do
    runSession "./test/Domains/Schema.dump.sql"
      (getRows =<< executeParams validInsert (PositiveInt (-1)))
      `shouldThrow` (\(_::SquealException) -> True)
  it "can run a function that takes and returns a domain" $ do
    runSession "./test/Domains/Schema.dump.sql"
      (getRows =<< executeParams increment (PositiveInt 1))
      `shouldReturn` [Only (Just 2)]
