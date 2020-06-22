{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
module Views.DBSpec where

import qualified Generics.SOP as SOP
import qualified GHC.Generics as GHC
import Test.Hspec
import Views.Schema
import Squeal.PostgreSQL
import Data.Int
import DBHelpers(runSession)

data NotEvil = NotEvil { num :: Maybe Int64 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getView :: Statement DB () NotEvil
getView = query $ select_ #num (from $ view #nullable_constant)

data Evil = Evil { evilnum :: Int64 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

getEvilView :: Statement DB () Evil
getEvilView = query $ select_ #evilnum (from $ view #evil_constant)



spec = describe "Arrays" $ do
  it "compiles" $ do
    'a' `shouldBe` 'a'

  it "works" $ do
    runSession "./test/Views/schemas"
      ((,) <$> (getRows =<< execute getEvilView)
           <*> (getRows =<< execute getView))
      `shouldReturn` ([Evil 1337],
                       [NotEvil (Just 12)])
