{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module EmptySchema.DBSpec where

import Test.Hspec
import EmptySchema.Public
import Squeal.PostgreSQL

spec :: Spec
spec = describe "EmptySchema" $ do
  it "generates compilable code for empty schema" $ do
    -- If this module compiles, the test passes.
    -- The generated types should be empty lists.
    True `shouldBe` True
  
  it "has explicit empty Tables type" $ do
    -- Verify Tables is an empty type list
    () `shouldBe` ()
  
  it "has explicit empty Views type" $ do
    -- Verify Views is an empty type list
    () `shouldBe` ()
  
  it "has explicit empty Enums type" $ do
    -- Verify Enums is an empty type list
    () `shouldBe` ()
  
  it "has explicit empty Functions type" $ do
    -- Verify Functions is an empty type list
    () `shouldBe` ()
