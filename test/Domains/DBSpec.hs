{-# LANGUAGE DeriveAnyClass       #-}
{-# LANGUAGE DerivingStrategies   #-}
{-# LANGUAGE DerivingVia          #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Domains.DBSpec where

import           Data.Int
import           DBHelpers         (runSession)
import           Domains.Public
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           Test.Hspec


newtype PositiveInt = PositiveInt { unPositive :: Int64 }
  deriving stock (Eq,Show,GHC.Generic)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)
  deriving newtype (IsPG,FromPG)

validInsert :: Statement DB PositiveInt ()
validInsert = manipulation $
  insertInto_ #pluslove
    (Values_ (Set (param @1) `as` #num))

increment :: Statement DB PositiveInt (Only (Maybe PositiveInt))
increment = query $ values ((function #increment_positive) (param @1) `as` #fromOnly) []

spec = describe "Domains" $ do
  it "accepts a good value" $ do
    runSession "Domains" "Public" []
      (getRows =<< executeParams validInsert (PositiveInt 1))
      `shouldReturn` []
  it "rejects a bad one" $ do
    runSession "Domains" "Public" []
      (getRows =<< executeParams validInsert (PositiveInt (-1)))
      `shouldThrow` (\(_::SquealException) -> True)
  it "can run a function that takes and returns a domain" $ do
    runSession "Domains" "Public" []
      (getRows =<< executeParams increment (PositiveInt 1))
      `shouldReturn` [Only (Just $ PositiveInt 2)]
