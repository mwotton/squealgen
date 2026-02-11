{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module Arrays.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import Arrays.Public
import DBHelpers (runSession)
import Squeal.PostgreSQL
import qualified Data.ByteString.Char8 as BS8
import Data.Text

data TextArrays = TextArrays { name :: [Text] }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getFoos :: Statement DB () TextArrays
getFoos = Query nilParams (TextArrays . getVarArray <$> #name)
          $ select_ #name (from $ table #text_arrays)

spec = describe "Arrays" $ do
  it "round-trips text arrays via runtime query" $
    runSession "Arrays" "Public" (do
      define $ UnsafeDefinition (BS8.pack "INSERT INTO text_arrays(name) VALUES (ARRAY['alpha','beta']::varchar[]);")
      getRows =<< execute getFoos)
      `shouldReturn` [TextArrays ["alpha", "beta"]]
