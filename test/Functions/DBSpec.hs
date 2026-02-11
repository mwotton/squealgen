{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Functions.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           Data.Int
import           Data.List               (sort)
import           Database.Postgres.Temp   (cacheConfig, withConfig, withDbCache, toConnectionString)
import           DBHelpers         (runSession)
import           Functions.Public
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           System.Exit              (ExitCode (..))
import qualified System.IO                as IO
import           System.Process           (proc, readCreateProcessWithExitCode)
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

outOnlyQuery :: Statement DB () (Only (Maybe Int64))
outOnlyQuery = query $
  values_ ((functionN #out_only) Nil `as` #fromOnly)

inoutOnlyQuery :: Statement DB () (Only (Maybe Int64))
inoutOnlyQuery = query $
  values_ ((function #inout_only) (3 & notNull) `as` #fromOnly)

mixedInInoutQuery :: Statement DB () (Only (Maybe Int64))
mixedInInoutQuery = query $
  values_ ((functionN #mixed_in_inout) ((4 & notNull) *: (6 & notNull)) `as` #fromOnly)

procIncrement :: Statement DB () ()
procIncrement = manipulation $ call #proc_increment (5 & notNull)

integersQuery :: Statement DB () (Only Int64)
integersQuery = query $
  select_ (#integers ! #num `as` #fromOnly) (from (table #integers))

spec = describe "Functions" $ do
  it "doubles things" $ do
    runSession "Functions" "Public"
      ((,,)
        <$> (getRows =<< execute multiArgQuery)
        <*> (getRows =<< execute doublerQuery)
        <*> (getRows =<< executeParams manyParamsQuery (12, 7.3, "foo"))
      )
      `shouldReturn` ([Only (Just 25)]
                     ,[Only (Just 2)]
                     ,[Only (Just "foo")])
  it "supports representable IN/OUT/INOUT signatures and procedures" $ do
    runSession "Functions" "Public"
      (do
        _ <- execute procIncrement
        (,,,)
          <$> (getRows =<< execute outOnlyQuery)
          <*> (getRows =<< execute inoutOnlyQuery)
          <*> (getRows =<< execute mixedInInoutQuery)
          <*> (sort <$> (getRows =<< execute integersQuery)))
      `shouldReturn` ([Only (Just 99)]
                     ,[Only (Just 13)]
                     ,[Only (Just 10)]
                     ,[Only 1, Only 5])
  it "generates overloaded and zero-arg functions" $ do
    e <- try @SomeException runGenerator :: IO (Either SomeException String)
    case e of
      Left err -> expectationFailure ("setup failed: " <> displayException err)
      Right hs -> do
        hs `shouldContain` "\"overloaded__int4\" ::: Function ('[ Null PGint4 ] :=> 'Returns ( 'Null PGint4) )"
        hs `shouldContain` "\"overloaded__int8\" ::: Function ('[ Null PGint8 ] :=> 'Returns ( 'Null PGint8) )"
        hs `shouldContain` "\"zero_arg\" ::: Function ('[  ] :=> 'Returns ( 'Null PGint8) )"
        hs `shouldContain` "\"out_only\" ::: Function ('[  ] :=> 'Returns ( 'Null PGint8) )"
        hs `shouldContain` "\"inout_only\" ::: Function ('[ Null PGint8 ] :=> 'Returns ( 'Null PGint8) )"
        hs `shouldContain` "\"mixed_in_inout\" ::: Function ('[ Null PGint8,  Null PGint8 ] :=> 'Returns ( 'Null PGint8) )"
        hs `shouldContain` "\"proc_increment\" ::: 'Procedure '[ Null PGint8 ]"
        hs `shouldContain` "-- Omitted function signatures:"
        hs `shouldContain` "--   inout_params(int8): pseudotype return is not representable"

runGenerator :: IO String
runGenerator = withDbCache $ \cache -> do
  result <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    sql <- BS8.readFile "./test/Functions/schemas/Public/structure.sql"
    withConnection connBS $ define (UnsafeDefinition sql)
    runSquealgen (BS8.unpack connBS) "FunctionsGenerated" "public"
  case result of
    Left err -> ioError (userError (displayException err))
    Right out -> pure out

runSquealgen :: String -> String -> String -> IO String
runSquealgen conn moduleName' chosen = do
  script <- IO.readFile "squealgen.sql"
  let cmd = proc "psql"
        [ "-X"
        , "-q"
        , "-v", "chosen_schema=" <> chosen
        , "-v", "modulename=" <> moduleName'
        , "-v", "extra_imports="
        , "-d", conn
        ]
  (exitCode, out, err) <- readCreateProcessWithExitCode cmd script
  case exitCode of
    ExitSuccess   -> pure out
    ExitFailure c -> ioError (userError (unlines ["psql exited with code " <> show c, err]))
