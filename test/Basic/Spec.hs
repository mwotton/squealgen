module Basic.Spec where

import Test.Hspec
import Schema

spec = describe "Basic" $ do
  it "compiles" $ do
    -- nothing to do on an empty database
    pure ()
