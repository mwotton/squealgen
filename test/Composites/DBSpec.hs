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
import           Composites.Schema
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

-- to be generated
type PGclump = 'PGcomposite '["foo" ::: 'NotNull 'PGtext, "bar" ::: 'NotNull 'PGint4]
-- finish generation

getClump :: Statement DB (Text,Int32) (Only Clump)
getClump = query q
  where q :: Query '[] '[] DB '[NotNull PGtext,NotNull PGint4] '["fromOnly" ::: 'NotNull PGclump]
        q = values_ ((astype (typedef #clump) (row (param @1 `as` #foo :* param @2 `as` #bar)))
                     `as` #fromOnly)
spec = describe "Domains" $ do
  it "parses a value" $ do
    runSession "./test/Composites/Schema.dump.sql"
      (getRows =<< executeParams getClump ("hi", 12))
      `shouldReturn` [Only (Clump "hi" 12)]
