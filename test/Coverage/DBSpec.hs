module Coverage.DBSpec where

import LTree (ltreeCoverageProbe)
import Test.Hspec

spec :: Spec
spec = describe "Coverage scope" $ do
  it "exposes a measurable expression probe from src" $
    ltreeCoverageProbe `shouldBe` True
