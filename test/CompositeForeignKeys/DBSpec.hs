-- | This is derived from the demo in the Squeal readme.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module CompositeForeignKeys.DBSpec where

import CompositeForeignKeys.Public

import Squeal.PostgreSQL
import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec (it,describe,shouldReturn)
import Data.Int (Int32)

import DBHelpers

data CompositeRow = CompositeRow { col_one :: Maybe Int32 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

selectCompositeRows :: Statement DB () CompositeRow
selectCompositeRows =
  query $ select_ #col_one (from $ table #table_two)

spec = describe "CompositeForeignKeys" $ do
  it "enforces and reads composite-foreign-key rows at runtime" $
    runSession "CompositeForeignKeys" "Public" (do
      getRows =<< execute selectCompositeRows)
      `shouldReturn` [CompositeRow (Just 11)]
