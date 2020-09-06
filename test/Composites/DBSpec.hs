{-# LANGUAGE DeriveAnyClass       #-}
{-# LANGUAGE DerivingStrategies   #-}
{-# LANGUAGE DerivingVia          #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeOperators #-}
module Composites.DBSpec where

import           Data.Int
import           DBHelpers         (runSession)
import           Composites.Public
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           Test.Hspec
import Data.Text

data Clump = Clump
  { foo :: Text
  , bar :: Int32
  }  deriving stock (Show, GHC.Generic, Eq)
     deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)
     deriving (IsPG,ToPG db, FromPG) via (Composite Clump)


data VarClump = VarClump
  { vfoo :: Text
  , vbar :: Int32
  , vbaz :: Text
  }  deriving stock (Show, GHC.Generic, Eq)
     deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)
     deriving (IsPG,ToPG db, FromPG) via (Composite VarClump)

getClump :: Statement DB (Text,Int32) (Only Clump)
getClump = query q
  where q :: Query '[] '[] DB '[NotNull PGtext,NotNull PGint4] '["fromOnly" ::: 'NotNull PGclump]
        q = values_ ((astype (typedef #clump) (row (param @1 `as` #foo :* param @2 `as` #bar)))
                     `as` #fromOnly)

-- we have a second one to make sure we emit all of the composites.
getVarClump :: Statement DB (Text,Int32,Text) (Only VarClump)
getVarClump = query q
  where q :: Query '[] '[] DB '[NotNull PGtext,NotNull PGint4,NotNull PGtext]
                   '["fromOnly" ::: 'NotNull PGvarclump]
        q = values_ ((astype (typedef #varclump) (row (param @1 `as` #vfoo
                                                    :* param @2 `as` #vbar
                                                    :* param @3 `as` #vbaz
                                                      )))
                     `as` #fromOnly)


spec = describe "Domains" $ do
  it "parses a value" $ do
    runSession "Composites" "Public"
      (getRows =<< executeParams getClump ("hi", 12))
      `shouldReturn` [Only (Clump "hi" 12)]

    runSession "Composites" "Public"
      (getRows =<< executeParams getVarClump ("hi", 12, "bye"))
      `shouldReturn` [Only (VarClump "hi" 12 "bye")]
