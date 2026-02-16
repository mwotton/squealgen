{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE TypeApplications #-}

-- |
-- Module      : Property.DDLSpec
-- Description : Property-based tests for DDL schema generation
--
-- == unsafePerformIO Usage
--
-- This module uses 'unsafePerformIO' in two places, which requires justification:
--
-- 1. @traceEnabled@: Reads the @SQUEALGEN_TEST_TRACE@ environment variable at module
--    load time to enable optional debug tracing. This is safe because:
--    * It is run once at module load (due to NOINLINE pragma)
--    * The result is a pure 'Bool' after initial evaluation
--    * Environment variable lookup is idempotent with no side effects
--
-- 2. @checkSchema@ and @compileModule@: Called via 'unsafePerformIO' in property
--    test bodies. This is safe because:
--    * The property test framework ('Test.Tasty.Falsify') expects pure test bodies
--    * Each invocation creates isolated temporary resources (databases, files)
--    * The IO is fully contained within each test case
--    * Failures are captured as 'Either' results, not thrown as exceptions
--    * Tests are run sequentially (NumThreads 1) to avoid resource contention
module Property.DDLSpec
  ( testTree
  , SchemaDDL (..)
  , checkSchema
  , compileModule
  ) where

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
import           Debug.Trace              (traceM)
import           System.Environment       (lookupEnv)
import           Data.Char                (toLower)
import           Test.Falsify.Generator   (Gen)
import qualified Test.Falsify.Generator   as Gen
import qualified Test.Falsify.Range       as Range
import           Test.Tasty               (TestTree, localOption, testGroup)
import           Test.Tasty.Runners       (NumThreads (NumThreads))
import           Control.Monad            (when)
import           Test.Tasty.Falsify

compileTimeoutMicros :: Int
compileTimeoutMicros = 60 * 1000 * 1000

testTree :: TestTree
testTree = localOption (NumThreads 1) $ testGroup "Property.DDL"
  [ testProperty "DDL generator produces squeal schemas that compile" ddlProperty
  , testProperty "Generated module fails when invalid code is appended" ddlInvalidAppendProperty
  , testProperty "Large schema (500 tables) compiles within 30s" ddlLargeSchemaCompilesQuickly
  , testProperty "Long function names near identifier limit compile" ddlLongFunctionNamesProperty
  ]

ddlProperty :: Property ()
ddlProperty = do
  schema@(SchemaDDL sql) <- gen ddlSchema
  traceIf "--- Generated DDL ---"
  traceIf sql
  case unsafePerformIO (checkSchema schema) of
    Left err -> do
      traceIf "--- DDL Check Failed ---"
      traceIf err
      testFailed err
    Right moduleSource -> do
      traceIf "--- Generated Module Source ---"
      traceIf moduleSource
      pure ()

-- Append invalid Haskell to a generated module and ensure compilation fails
ddlInvalidAppendProperty :: Property ()
ddlInvalidAppendProperty = do
  let schema = SchemaDDL "CREATE TABLE gen_table_1 (id SERIAL PRIMARY KEY)\n"
  traceIf "--- Creating simple schema for invalid append test ---"
  case unsafePerformIO (checkSchema schema) of
    Left err -> do
      traceIf ("Setup schema failed: " <> err)
      testFailed ("setup schema failed: " <> err)
    Right moduleSource -> do
      let broken = moduleSource <> "\n\nfoo::Bool\nfoo=\"banana\"\n"
      traceIf "--- Compiling intentionally broken module ---"
      case unsafePerformIO (compileModule broken moduleName) of
        Left _ -> pure ()
        Right () -> testFailed "expected compilation to fail for invalid appended code"

-- Using Debug.Trace.traceM to emit immediate stderr output during property runs

newtype SchemaDDL = SchemaDDL { ddlText :: String }
  deriving stock (Show)

ddlSchema :: Gen SchemaDDL
ddlSchema = do
  tableCount <- Gen.int (Range.between (1, 100))
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

-- Controlled tracing: set SQUEALGEN_TEST_TRACE={1,true,yes,on} to enable
{-# NOINLINE traceEnabled #-}
traceEnabled :: Bool
traceEnabled = unsafePerformIO $ do
  m <- lookupEnv "SQUEALGEN_TEST_TRACE"
  let norm = fmap (map toLower) m
  pure $ case norm of
    Just "1"    -> True
    Just "true" -> True
    Just "yes"  -> True
    Just "on"   -> True
    Just "y"    -> True
    Just "t"    -> True
    _           -> False

traceIf :: String -> Property ()
traceIf msg = if traceEnabled then traceM msg else pure ()

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

-- Construct a very large schema with N simple tables (no FKs)
largeSchema :: Int -> SchemaDDL
largeSchema n =
  let mk i =
        let base = ["id SERIAL PRIMARY KEY"]
            refs = map (\j -> "gen_table_" <> show j <> "_id INT REFERENCES gen_table_" <> show j <> "(id)") (refTargets i)
            cols = List.intercalate "," (map ("\n    " <>) (base <> refs))
        in "CREATE TABLE gen_table_" <> show i <> " (" <> cols <> "\n);"
      ddl = List.intercalate "\n" (map mk [1..n]) <> "\n"
  in SchemaDDL ddl
  where
    -- Deterministic references to earlier tables to create a realistic graph
    refTargets :: Int -> [Int]
    refTargets i
      | i <= 1    = []
      | otherwise = uniq $ filter (> 0)
          ([i-1]
           <> [i-10 | i > 10 && i `mod` 10 == 0]
           <> [1     | i `mod` 100 == 0])
    uniq :: [Int] -> [Int]
    uniq = List.map head . List.group . List.sort

-- Property: a 500-table schema should compile within 30 seconds
ddlLargeSchemaCompilesQuickly :: Property ()
ddlLargeSchemaCompilesQuickly = do
  let tables = 500
      timeoutSeconds = 30
      schema = largeSchema tables
  traceIf ("--- Creating large schema with " <> show tables <> " tables ---")
  case unsafePerformIO (compileLargeSchemaWithin schema timeoutSeconds) of
    Left err -> testFailed ("large schema compile failed or timed out: " <> err)
    Right () -> pure ()

-- Property: long function names near PostgreSQL identifier limit (63 bytes) compile correctly
-- PostgreSQL NAMEDATALEN is 64, so max identifier length is 63 bytes.
-- This tests that disambiguated labels (funcname__argtype) work near this limit.
--
-- Note: This test documents current behavior. PostgreSQL will truncate identifiers
-- longer than 63 bytes during CREATE FUNCTION, and squealgen will emit what it finds
-- in pg_catalog. The test verifies compilation succeeds for names in the 55-63 char range.
ddlLongFunctionNamesProperty :: Property ()
ddlLongFunctionNamesProperty = do
  -- Generate a base name length between 55-63 chars (near the 63-byte limit)
  baseLen <- gen $ Gen.int (Range.between (55, 63))
  -- Use a single deterministic schema to keep test runtime reasonable
  let schema = longFunctionNameSchema baseLen
  traceIf ("--- Testing long function names with base length " <> show baseLen <> " ---")
  case unsafePerformIO (checkSchema schema) of
    Left err -> do
      traceIf "--- Long function name schema failed ---"
      traceIf err
      testFailed ("long function name schema failed to compile: " <> err)
    Right moduleSource -> do
      traceIf "--- Long function name schema compiled successfully ---"
      traceIf moduleSource
      pure ()

-- | Create a schema with long function names that trigger disambiguation.
-- Creates overloaded functions with different argument types to force
-- squealgen to emit disambiguated labels (name__argtype).
longFunctionNameSchema :: Int -> SchemaDDL
longFunctionNameSchema baseLen =
  let -- Generate a base name of exactly baseLen characters using alphabetic chars
      -- Using 'a' repeated ensures we get a valid SQL identifier
      baseName = replicate baseLen 'a'
      -- Create overloaded functions with int4 and int8 arguments
      -- These will get disambiguated labels like: aaa...__int4, aaa...__int8
      func1 = "CREATE FUNCTION " <> baseName <> "(x int4) RETURNS int4 AS 'SELECT x' LANGUAGE sql;"
      func2 = "CREATE FUNCTION " <> baseName <> "(x int8) RETURNS int8 AS 'SELECT x' LANGUAGE sql;"
      -- Also add a table to make the schema non-empty
      table = "CREATE TABLE test_table (id SERIAL PRIMARY KEY);"
      ddl = table <> "\n" <> func1 <> "\n" <> func2 <> "\n"
  in SchemaDDL ddl

compileLargeSchemaWithin :: SchemaDDL -> Int -> IO (Either String ())
compileLargeSchemaWithin schema timeoutSeconds = fmap (either (Left . displayException) id) . try @SomeException $ do
  withDbCache $ \cache -> do
    res <- withConfig (cacheConfig cache) $ \db -> do
      let connBS = toConnectionString db
      withConnection connBS $ do
        when traceEnabled $ traceM "--- Large schema: Generated DDL ---"
        when traceEnabled $ traceM (ddlText schema)
        define (UnsafeDefinition (BS8.pack (ddlText schema)))
      moduleSourceResult <- runSquealgen (BS8.unpack connBS) moduleName
      case moduleSourceResult of
        Left err -> pure (Left err)
        Right moduleSource -> do
          let micros = timeoutSeconds * 1000 * 1000
          when traceEnabled $ traceM "--- Large schema: Generated Module Source ---"
          when traceEnabled $ traceM moduleSource
          compileResult <- compileModuleWithTimeout micros moduleSource moduleName
          pure compileResult
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
compileModule source modName = compileModuleWithTimeout compileTimeoutMicros source modName

compileModuleWithTimeout :: Int -> String -> String -> IO (Either String ())
compileModuleWithTimeout micros source modName = withSystemTempDirectory "squealgen-ddl" $ \dir -> do
  let hsFile = dir </> modName <> ".hs"
  IO.withFile hsFile IO.WriteMode $ \h -> IO.hPutStr h source
  let cmd = proc "cabal" ["exec", "--", "ghc", "-fno-code", "-fforce-recomp", "-O0", hsFile]
  mRes <- timeout micros $ readCreateProcessWithExitCode cmd ""
  pure $ case mRes of
    Nothing -> Left "cabal exec ghc timed out"
    Just (ExitSuccess, _, _) -> Right ()
    Just (ExitFailure code, out, err) -> Left $ unlines
      [ "cabal exec ghc failed with exit code " <> show code
      , out
      , err
      ]
