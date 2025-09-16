{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module InetArrays.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import InetArrays.Public
import Squeal.PostgreSQL
import Data.Text
import Data.Set
import Data.IP (IPRange)

data AddressSets = AddressSets { addresses :: [IPRange] }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getFoos :: Statement DB () AddressSets
getFoos = Query nilParams (AddressSets . getVarArray <$> #addresses)
          $ select_ #addresses (from $ table #address_sets)

spec = describe "Arrays" $ do
  it "compiles" $ do
    -- nothing to do on an empty database
    'a' `shouldBe` 'a'
