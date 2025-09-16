module Property.DDLSpec (spec) where

import           Control.Exception        (evaluate)
import           Control.Monad            (replicateM_)
import qualified Data.ByteString          as BS
import qualified Data.ByteString.Char8    as BS8
import qualified Data.List                as List
import qualified Data.List.NonEmpty       as NE
import           Database.Postgres.Temp
import           Squeal.PostgreSQL        (Definition (UnsafeDefinition), define, withConnection)
import           System.Exit              (ExitCode (..))
import           System.FilePath          ((</>))
import           System.IO                (Handle, hClose)
import qualified System.IO                as IO
import           System.IO.Temp           (withSystemTempDirectory)
import           System.Process           (CreateProcess (..), StdStream (CreatePipe), proc, terminateProcess,
                                           waitForProcess, withCreateProcess)
import           System.Timeout           (timeout)
import           Test.Falsify.Generator   (Gen)
import qualified Test.Falsify.Generator   as Gen
import qualified Test.Falsify.Interactive as Falsify
import qualified Test.Falsify.Range       as Range
import           Test.Hspec

compileTimeoutMicros :: Int
compileTimeoutMicros = 60 * 1000 * 1000

iterations :: Int
iterations = 5

spec :: Spec
spec = describe "DDL generator" $ do
  it "produces squeal schemas that compile" $ do
    withDbCache $ \cache -> replicateM_ iterations (propertyCase cache)

propertyCase :: Cache -> IO ()
propertyCase cache = do
  schema <- Falsify.sample ddlSchema
  result <- withConfig (cacheConfig cache) $ \db -> do
    let conn = BS8.unpack (toConnectionString db)
    withConnection (toConnectionString db) $ do
      define (UnsafeDefinition (BS8.pack (ddlText schema)))
    moduleSource <- runSquealgen conn moduleName
    compileModule moduleSource moduleName
  either (fail . show) pure result

moduleName :: String
moduleName = "GeneratedSchema"

newtype SchemaDDL = SchemaDDL { ddlText :: String }

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

runSquealgen :: String -> String -> IO String
runSquealgen conn moduleName' = do
  script <- IO.readFile "squealgen.sql"
  withCreateProcess processSpec $ \mIn mOut mErr ph -> do
    maybe (pure ()) (\h -> IO.hPutStr h script >> hClose h) mIn
    out <- maybe (pure mempty) hGetStrict mOut
    err <- maybe (pure mempty) hGetStrict mErr
    exit <- waitForProcess ph
    case exit of
      ExitSuccess   -> pure (BS8.unpack out)
      ExitFailure c -> fail $ unlines
        [ "psql exited with code " <> show c
        , BS8.unpack err
        ]
  where
    processSpec = (proc "psql"
      [ "-X"
      , "-q"
      , "-v", "chosen_schema=public"
      , "-v", "modulename=" <> moduleName'
      , "-v", "extra_imports="
      , "-d", conn
      ])
      { std_in  = CreatePipe
      , std_out = CreatePipe
      , std_err = CreatePipe
      }

compileModule :: String -> String -> IO ()
compileModule source modName =
  withSystemTempDirectory "squealgen-ddl" $ \dir -> do
    let hsFile = dir </> modName <> ".hs"
    IO.writeFile hsFile source
    let args = ["-fno-code", "-fforce-recomp", "-O0", hsFile]
    withCreateProcess (proc "ghc" args)
      { std_in  = CreatePipe
      , std_out = CreatePipe
      , std_err = CreatePipe
      } $ \mIn mOut mErr ph -> do
        maybe (pure ()) hClose mIn
        out <- maybe (pure mempty) hGetStrict mOut
        err <- maybe (pure mempty) hGetStrict mErr
        mExit <- timeout compileTimeoutMicros (waitForProcess ph)
        case mExit of
          Nothing -> do
            terminateProcess ph
            _ <- waitForProcess ph
            fail "ghc -fno-code timed out"
          Just ExitSuccess -> pure ()
          Just (ExitFailure code) ->
            fail $ unlines
              [ "ghc -fno-code failed with exit code " <> show code
              , BS8.unpack out
              , BS8.unpack err
              ]

hGetStrict :: Handle -> IO BS.ByteString
hGetStrict h = do
  bs <- BS.hGetContents h
  _ <- evaluate (BS.length bs)
  pure bs
