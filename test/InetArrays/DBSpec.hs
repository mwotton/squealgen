{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module InetArrays.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import InetArrays.Public
import DBHelpers (runSession)
import Squeal.PostgreSQL
import qualified Data.ByteString.Char8 as BS8
import Data.IP (IPRange)
import Text.Read (readMaybe)

data AddressSets = AddressSets { addresses :: [IPRange] }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getFoos :: Statement DB () AddressSets
getFoos = Query nilParams (AddressSets . getVarArray <$> #addresses)
          $ select_ #addresses (from $ table #address_sets)

spec = describe "Arrays" $ do
  it "round-trips inet arrays via runtime query" $ do
    expected <- case readMaybe "192.168.0.0/24" of
      Just r -> pure [AddressSets [r]]
      Nothing -> expectationFailure "failed to parse expected IP range literal" >> pure []
    runSession "InetArrays" "Public" (do
      getRows =<< execute getFoos)
      `shouldReturn` expected
