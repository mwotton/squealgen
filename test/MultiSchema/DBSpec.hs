{-# LANGUAGE OverloadedStrings #-}
module MultiSchema.DBSpec where

import Control.Monad
import           MultiSchema.Schema
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

instance KnownNat n => FromPG (VarChar n) where
  fromPG = devalue $ maybe (throwError "bad varchar encoding")  pure . varChar =<< text_strict
-- end temporary code

getFoo2 :: Statement DB () (Only (VarChar 12))
getFoo2 = query $ select_ (#foo2 ! #limited `as` #fromOnly) (from (table #foo2))

spec = describe "Basic" $ do
  it "can fetch varchar(12)" $
    runSession "./test/Basic/schemas"
      (getRows =<< execute getFoo2)
      `shouldReturn` [Only (fromJust $ varChar "hi")]
