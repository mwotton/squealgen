{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Extensions.DBSpec where

import           Data.Int         (Int32)
import           Data.List        (sort)
import           DBHelpers        (runSession)
import           Extensions.Public
import           Squeal.PostgreSQL
import           Test.Hspec

pathDepths :: Statement DB () (Only (Maybe Int32))
pathDepths = query $
  select_ ((function #path_depth) (#paths ! #path) `as` #fromOnly)
    (from (table #paths))

spec :: Spec
spec = describe "Extensions" $ do
  it "supports ltree extension types in table columns and function signatures" $ do
    runSession "Extensions" "Public"
      (sort <$> (getRows =<< execute pathDepths))
      `shouldReturn` [Only (Just 2), Only (Just 3)]
