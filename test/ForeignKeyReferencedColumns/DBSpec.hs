{-# LANGUAGE OverloadedStrings #-}
module ForeignKeyReferencedColumns.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           Database.Postgres.Temp
import           System.Exit              (ExitCode (..))
import           System.IO                as IO
import           System.Process           (proc, readCreateProcessWithExitCode)
import           Test.Hspec
import           Squeal.PostgreSQL        (define, withConnection, Definition (UnsafeDefinition))

spec :: Spec
spec = describe "ForeignKeyReferencedColumns" $ do
  it "emits referenced FK columns from the referenced relation in the declared order" $ do
    res <- try @SomeException run :: IO (Either SomeException String)
    case res of
      Left e   -> expectationFailure ("setup failed: " <> displayException e)
      Right hs -> do
        hs `shouldContain` "\"child_single_parent_fk\" ::: 'ForeignKey '[\"local_parent_id\"] \"public\" \"parent_single\" '[\"id\"]"
        hs `shouldContain` "\"child_composite_parent_fk\" ::: 'ForeignKey '[\"local_b\",\"local_a\"] \"public\" \"parent_composite\" '[\"ref_b\",\"ref_a\"]"
        hs `shouldContain` "\"child_cross_parent_fk\" ::: 'ForeignKey '[\"left_local\",\"right_local\"] \"ref\" \"parent_cross\" '[\"target_left\",\"target_right\"]"
        hs `shouldContain` "\"self_ref_parent_fk\" ::: 'ForeignKey '[\"parent_local\"] \"public\" \"self_ref\" '[\"id\"]"

run :: IO String
run = withDbCache $ \cache -> do
  e <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    setup <- BS8.readFile "test/ForeignKeyReferencedColumns/schemas/Public/structure.sql"
    withConnection connBS $ define (UnsafeDefinition setup)
    runSquealgen (BS8.unpack connBS) "ForeignKeyReferencedColumns.Generated" "public"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x

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
