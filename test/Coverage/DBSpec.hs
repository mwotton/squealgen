module Coverage.DBSpec where

import LTree (ltreePathSegments)
import Test.Hspec

spec :: Spec
spec = describe "Coverage scope" $ do
  it "accepts a valid path with lowercase, digits, and underscores" $
    ltreePathSegments "root.branch_2.leaf" `shouldBe` Just ["root", "branch_2", "leaf"]

  it "rejects uppercase labels that are not valid ltree segments" $
    ltreePathSegments "root.Branch" `shouldBe` Nothing

  it "rejects empty segments" $
    ltreePathSegments "root..leaf" `shouldBe` Nothing

  it "rejects an empty path" $
    ltreePathSegments "" `shouldBe` Nothing
