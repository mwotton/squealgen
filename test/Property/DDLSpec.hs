{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE TypeApplications #-}

module Property.DDLSpec (testTree) where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import qualified Data.List                as List
import qualified Data.List.NonEmpty       as NE
import           Database.Postgres.Temp
import           Squeal.PostgreSQL        (Definition (UnsafeDefinition), define, withConnection)
import           System.Exit              (ExitCode (..))
import           System.FilePath          ((</>))
import qualified System.IO                as IO
import           System.IO.Temp           (withSystemTempDirectory, withSystemTempFile)
import           System.IO.Unsafe         (unsafePerformIO)
import           System.Process           (proc, readCreateProcessWithExitCode)
import           System.Timeout           (timeout)
import           Test.Falsify.Generator   (Gen)
import qualified Test.Falsify.Generator   as Gen
import qualified Test.Falsify.Range       as Range
import           Test.Tasty               (TestTree, testGroup)
import           Test.Tasty.Falsify

compileTimeoutMicros :: Int
compileTimeoutMicros = 60 * 1000 * 1000

testTree :: TestTree
testTree = testGroup "Property.DDL"
  [ testProperty "DDL generator produces squeal schemas that compile" ddlProperty
  ]

ddlProperty :: Property ()
ddlProperty = do
  schema@(SchemaDDL sql) <- gen ddlSchema
  info sql
  case unsafePerformIO (checkSchema schema) of
    Left err -> testFailed err
    Right moduleSource -> do
      info moduleSource
      pure ()

newtype SchemaDDL = SchemaDDL { ddlText :: String }
  deriving stock (Show)

ddlSchema :: Gen SchemaDDL
ddlSchema = do
  tableCount <- Gen.int (Range.between (1, 4))
  tables <- buildTables [] 0 tableCount
  pure $ SchemaDDL { ddlText = renderSchema (reverse tables) }
  where
    buildTables :: [TableDef] -> Int -> Int -> Gen [TableDef]
    buildTables acc idx total
      | idx == total = pure acc
      | otherwise = do
          let name = tableNameFromIndex (idx + 1)
              prior = map tableName acc
          refs <- if null prior
                    then pure []
                    else do
                      maxRefs <- Gen.int (Range.between (0, min 3 (length prior)))
                      if maxRefs == 0
                        then pure []
                        else do
                          chosen <- Gen.list (Range.constant (fromIntegral maxRefs))
                                      (Gen.elem (NE.fromList prior))
                          pure (List.nub chosen)
          buildTables (TableDef name refs : acc) (idx + 1) total

data TableDef = TableDef
  { tableName :: String
  , tableRefs :: [String]
  }

tableNameFromIndex :: Int -> String
tableNameFromIndex idx = "gen_table_" <> show idx

renderSchema :: [TableDef] -> String
renderSchema tables =
  List.intercalate "\n\n" (map renderTable tables) <> "\n"

renderTable :: TableDef -> String
renderTable TableDef{ tableName = name, tableRefs = refs } =
  "CREATE TABLE " <> name <> " (\n"
    <> List.intercalate ",\n" columnDefs
    <> "\n);"
  where
    columnDefs = ["    id SERIAL PRIMARY KEY"] <> map renderRef refs
    renderRef target =
      "    " <> target <> "_id INT REFERENCES " <> target <> "(id)"

moduleName :: String
moduleName = "GeneratedSchema"

checkSchema :: SchemaDDL -> IO (Either String String)
checkSchema schema = fmap (either (Left . displayException) id) . try @SomeException $ do
  withDbCache $ \cache -> do
    res <- withConfig (cacheConfig cache) $ \db -> do
      let connBS = toConnectionString db
      withConnection connBS $ do
        define (UnsafeDefinition (BS8.pack (ddlText schema)))
      moduleSourceResult <- runSquealgen (BS8.unpack connBS) moduleName
      case moduleSourceResult of
        Left err -> pure (Left err)
        Right moduleSource -> do
          compileResult <- compileModule moduleSource moduleName
          pure $ case compileResult of
            Left compileErr -> Left compileErr
            Right ()        -> Right moduleSource
    pure $ either (Left . show) id res

runSquealgen :: String -> String -> IO (Either String String)
runSquealgen conn moduleName' = withSystemTempFile "squealgen.sql" $ \path h -> do
  script <- IO.readFile "squealgen.sql"
  IO.hPutStr h script
  IO.hClose h
  let cmd = proc "psql"
        [ "-X"
        , "-q"
        , "-v", "chosen_schema=public"
        , "-v", "modulename=" <> moduleName'
        , "-v", "extra_imports="
        , "-d", conn
        , "-f", path
        ]
  (exitCode, out, err) <- readCreateProcessWithExitCode cmd ""
  pure $ case exitCode of
    ExitSuccess   -> Right out
    ExitFailure c -> Left $ unlines
      [ "psql exited with code " <> show c
      , err
      ]

compileModule :: String -> String -> IO (Either String ())
compileModule source modName = withSystemTempDirectory "squealgen-ddl" $ \dir -> do
  let hsFile = dir </> modName <> ".hs"
  IO.withFile hsFile IO.WriteMode $ \h -> IO.hPutStr h source
  let cmd = proc "cabal" ["exec", "--", "ghc", "-fno-code", "-fforce-recomp", "-O0", hsFile]
  mRes <- timeout compileTimeoutMicros $ readCreateProcessWithExitCode cmd ""
  pure $ case mRes of
    Nothing -> Left "cabal exec ghc timed out"
    Just (ExitSuccess, _, _) -> Right ()
    Just (ExitFailure code, out, err) -> Left $ unlines
      [ "cabal exec ghc failed with exit code " <> show code
      , out
      , err
      ]
