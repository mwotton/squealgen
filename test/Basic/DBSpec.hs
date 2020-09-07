{-# LANGUAGE OverloadedStrings #-}
module Basic.DBSpec where

import Control.Monad
import           Basic.Public
import           DBHelpers
import           Squeal.PostgreSQL
import           Test.Hspec
import Data.Text
import Data.Maybe(fromJust)

-- temporary, needs to be in Squeal https://github.com/morphismtech/squeal/pull/231
import Squeal.PostgreSQL.Session.Decode(devalue)
import PostgreSQL.Binary.Decoding(text_strict)
import Control.Monad.Error.Class
import GHC.TypeNats

getFoo2 :: Statement DB () (Only (VarChar 12))
getFoo2 = query $ select_ (#foo2 ! #limited `as` #fromOnly) (from (table #foo2))

spec = describe "Basic" $ do
  it "can fetch varchar(12)" $
    runSession "Basic" "Public" []
      (getRows =<< execute getFoo2)
      `shouldReturn` [Only (fromJust $ varChar "hi")]
