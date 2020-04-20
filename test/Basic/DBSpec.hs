module Basic.DBSpec where

import Test.Hspec
import Basic.Schema

spec = describe "Basic" $ do
  it "compiles" $ do
    -- nothing to do on an empty database
    'a' `shouldBe` 'a'
