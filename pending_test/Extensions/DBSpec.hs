{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Extensions.DBSpec where

import           Data.Int
import           DBHelpers         (runSession)
import           Extensions.Schema
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           Test.Hspec

-- interesting to note that we are collecting the raw int names, like int4 and int8.
--
-- not currently generating set-returning functions, fixme.
--
-- nb: multi-argument functions need to be called with functionN


spec = describe "Extensions" $ do
  it "compiles ltree" $ do
    () `shouldBe` ()
    -- runSession "./test/Functions/Schema.dump.sql"
    --   ((,) <$> (getRows =<< execute multiArgQuery)
    --        <*> (getRows =<< execute doublerQuery))
    --   `shouldReturn` ([Only (Just 25)]
    --                  ,[Only (Just 2)])
