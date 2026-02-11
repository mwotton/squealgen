{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module NoConstraints.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import NoConstraints.Public
import DBHelpers (runSession)
import Squeal.PostgreSQL
import qualified Data.ByteString.Char8 as BS8

data Foo = Foo { name :: String }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getFoos :: Statement DB () Foo
getFoos = query $ select_ #name (from $ table #foos)

spec = describe "NoConstraints" $ do
  it "reads inserted rows with runtime query assertions" $
    runSession "NoConstraints" "Public" (do
      define $ UnsafeDefinition (BS8.pack "INSERT INTO foos(name) VALUES ('squealgen');")
      getRows =<< execute getFoos)
      `shouldReturn` [Foo "squealgen"]
