{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Functions.DBSpec where

import           Data.Int
import           DBHelpers         (runSession)
import           Functions.Schema
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           Test.Hspec

-- interesting to note that we are collecting the raw int names, like int4 and int8.
--
-- not currently generating set-returning functions, fixme.
--
-- nb: multi-argument functions need to be called with functionN

multiArgQuery :: Statement DB () (Only (Maybe Int64))
multiArgQuery = query $
  select_ ((functionN #somefunc) ((12 & notNull)
                                 *: notNull (#integers ! #num)) `as` #fromOnly)
  (from (table #integers))

doublerQuery :: Statement DB () (Only (Maybe Int64))
doublerQuery = query $
  select_ ((function #doubler) (notNull $ #integers ! #num) `as` #fromOnly)
  (from (table #integers))

-- | in this test, the inputs are defined to be not-null, because strict_doubler is annotated as strict.
strictDoublerQuery :: Statement DB () (Only (Maybe Int64))
strictDoublerQuery = query $
  select_ ((function #strict_doubler) (#integers ! #num) `as` #fromOnly)
  (from (table #integers))

manyParamsQuery :: Statement DB (Int64, Float, String) (Only (Maybe String))
manyParamsQuery = query $
  values_ ((functionN #many_params) (param @1 :* param @2 *: param @3) `as` #fromOnly)

spec = describe "Functions" $ do
  it "doubles things" $ do
    runSession "./test/Functions/Schema.dump.sql"
      ((,,)
        <$> (getRows =<< execute multiArgQuery)
        <*> (getRows =<< execute doublerQuery)
        <*> (getRows =<< executeParams manyParamsQuery (12, 7.3, "foo"))
      )
      `shouldReturn` ([Only (Just 25)]
                     ,[Only (Just 2)]
                     ,[Only (Just "foo")])
