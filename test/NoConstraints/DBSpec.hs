{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module NoConstraints.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import NoConstraints.Public
import Squeal.PostgreSQL

data Foo = Foo { name :: String }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getFoos :: Statement DB () Foo
getFoos = query $ select_ #name (from $ table #foos)

spec = describe "NoConstraints" $ do
  it "compiles" $ do
    -- nothing to do on an empty database
    'a' `shouldBe` 'a'
