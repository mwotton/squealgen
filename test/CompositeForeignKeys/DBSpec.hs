-- | This is derived from the demo in the Squeal readme.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module CompositeForeignKeys.DBSpec where

import CompositeForeignKeys.Public

import Squeal.PostgreSQL
import UnliftIO
import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Data.Text(Text)

import Test.Hspec.Expectations.Lifted
import Test.Hspec (it,describe)
import Data.Int

import DBHelpers

-- probably should have something better to actually look at the foreign keys, but it appears to be working at least.
spec = describe "CompositeForeignKeys" $ do
  it "can run a simple query" $ runSession "CompositeForeignKeys" "Public" [] $ do
    pure ()
