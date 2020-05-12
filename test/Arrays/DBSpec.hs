{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module Arrays.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import Arrays.Schema
import Squeal.PostgreSQL
import Data.Text
import Data.Set

data TextArrays = TextArrays { name :: [Text] }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getFoos :: Statement DB () TextArrays
getFoos = Query nilParams (TextArrays . getVarArray <$> #name)
          $ select_ #name (from $ table #text_arrays)

spec = describe "Arrays" $ do
  it "compiles" $ do
    -- nothing to do on an empty database
    'a' `shouldBe` 'a'
