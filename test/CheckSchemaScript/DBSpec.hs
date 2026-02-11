module CheckSchemaScript.DBSpec (spec) where

import           Data.List          (isInfixOf)
import           System.Directory   (Permissions (..), copyFile, createDirectoryIfMissing, doesFileExist, getCurrentDirectory, getPermissions, setPermissions)
import           System.Environment (getEnvironment)
import           System.Exit        (ExitCode (..))
import           System.FilePath    ((</>))
import           System.IO.Temp     (withSystemTempDirectory)
import           System.Process     (CreateProcess (..), proc, readCreateProcessWithExitCode)
import           Test.Hspec

spec :: Spec
spec = describe "check_schema/buildTestSchema scripts" $ do
  it "fails and does not overwrite on mismatch" $ do
    withSystemTempDirectory "check-schema-mismatch" $ \tmpDir -> do
      let generated = tmpDir </> "generated.hs"
          existing = tmpDir </> "Existing.hs"
      writeFile generated "new content\n"
      writeFile existing "old content\n"

      (exitCode, _, _) <- readCreateProcessWithExitCode (proc "bash" ["check_schema", generated, existing]) ""
      exitCode `shouldBe` ExitFailure 1
      readFile existing `shouldReturn` "old content\n"

  it "succeeds when files match" $ do
    withSystemTempDirectory "check-schema-match" $ \tmpDir -> do
      let generated = tmpDir </> "generated.hs"
          existing = tmpDir </> "Existing.hs"
          content = "same content\n"
      writeFile generated content
      writeFile existing content

      (exitCode, _, _) <- readCreateProcessWithExitCode (proc "bash" ["check_schema", generated, existing]) ""
      exitCode `shouldBe` ExitSuccess

  it "propagates check_schema failure through buildTestSchema.sh" $ do
    repoRoot <- getCurrentDirectory
    withSystemTempDirectory "build-test-schema" $ \tmpDir -> do
      let scriptCopy = tmpDir </> "buildTestSchema.sh"
          checkSchemaCopy = tmpDir </> "check_schema"
          fakeSquealgen = tmpDir </> "squealgen"
          fakePgTmp = tmpDir </> "vendor" </> "pg_tmp"
          fakeBin = tmpDir </> "bin"
          fakePsql = fakeBin </> "psql"
          basedir = tmpDir </> "testfixture"
          schemaDir = basedir </> "schemas" </> "Public"
          existing = basedir </> "Public.hs"

      createDirectoryIfMissing True (tmpDir </> "vendor")
      createDirectoryIfMissing True fakeBin
      createDirectoryIfMissing True schemaDir

      copyFile (repoRoot </> "buildTestSchema.sh") scriptCopy
      copyFile (repoRoot </> "check_schema") checkSchemaCopy
      makeExecutable scriptCopy
      makeExecutable checkSchemaCopy

      writeFile fakePgTmp "#!/usr/bin/env bash\necho fake_db\n"
      makeExecutable fakePgTmp

      writeFile fakePsql "#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n"
      makeExecutable fakePsql

      writeFile fakeSquealgen "#!/usr/bin/env bash\necho \"new generated module\"\n"
      makeExecutable fakeSquealgen

      writeFile (schemaDir </> "structure.sql") "create table t (id int primary key);\n"
      writeFile (schemaDir </> "extra_imports") ""
      writeFile existing "old generated module\n"

      env <- overridePath fakeBin <$> getEnvironment
      let cmd = (proc "bash" ["buildTestSchema.sh", basedir, "Public"]) { cwd = Just tmpDir, env = Just env }

      (exitCode, out, err) <- readCreateProcessWithExitCode cmd ""
      exitCode `shouldBe` ExitFailure 1
      (out <> err) `shouldSatisfy` ("refusing to overwrite mismatched file" `isInfixOf`)
      readFile existing `shouldReturn` "old generated module\n"

  it "make test fails on drift and passes in clean state" $ do
    repoRoot <- getCurrentDirectory
    withSystemTempDirectory "make-test-drift-check" $ \tmpDir -> do
      let driftScript = tmpDir </> "check_squealgen_drift.sh"
          mkScript = tmpDir </> "mksquealgen.sh"
          makefile = tmpDir </> "Makefile"
          sqlFile = tmpDir </> "squealgen.sql"
          fakeBin = tmpDir </> "bin"
          fakeCabal = fakeBin </> "cabal"
      copyFile (repoRoot </> "check_squealgen_drift.sh") driftScript
      copyFile (repoRoot </> "mksquealgen.sh") mkScript
      copyFile (repoRoot </> "Makefile") makefile
      makeExecutable driftScript
      makeExecutable mkScript
      createDirectoryIfMissing True fakeBin
      writeFile fakeCabal "#!/usr/bin/env bash\nexit 0\n"
      makeExecutable fakeCabal
      writeFile sqlFile "select 1;\n"

      runInRepo tmpDir "bash ./mksquealgen.sh"
      runInRepo tmpDir "git init -q"
      runInRepo tmpDir "git config user.email test@example.com"
      runInRepo tmpDir "git config user.name test"
      runInRepo tmpDir "git add squealgen.sql squealgen mksquealgen.sh check_squealgen_drift.sh Makefile"
      runInRepo tmpDir "git commit -q -m init"

      env <- overridePath fakeBin <$> getEnvironment
      let makeTestCmd = (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && make test"]) { env = Just env }

      (cleanExit, _, cleanErr) <- readCreateProcessWithExitCode makeTestCmd ""
      cleanExit `shouldBe` ExitSuccess
      cleanErr `shouldSatisfy` (not . isInfixOf "ERROR: your generated squealgen")

      writeFile sqlFile "select 2;\n"
      (driftExit, _, driftErr) <- readCreateProcessWithExitCode makeTestCmd ""
      driftExit `shouldBe` ExitFailure 2
      driftErr `shouldSatisfy` ("squealgen drift detected" `isInfixOf`)
      driftErr `shouldSatisfy` ("./mksquealgen.sh" `isInfixOf`)

  it "make test invokes squealgen drift check" $ do
    makefile <- readFile "Makefile"
    makefile `shouldSatisfy` ("check-squealgen-drift" `isInfixOf`)

  it "CI invokes canonical make test gate" $ do
    workflow <- readFile ".github/workflows/ci.yml"
    workflow `shouldSatisfy` ("run: make test" `isInfixOf`)

  it "CI includes the coverage gate command" $ do
    workflow <- readFile ".github/workflows/ci.yml"
    workflow `shouldSatisfy` ("run: ./check_coverage.sh" `isInfixOf`)

  it "coverage gate fails when expression denominator is zero" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, _, err, _) <- runCoverageScriptWithFakeReport repoRoot "100% expressions used (0/0)" "100"
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("denominator is zero" `isInfixOf`)
    err `shouldSatisfy` ("(0/0)" `isInfixOf`)

  it "coverage gate passes when denominator is non-zero and threshold is met" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, out, _, summary) <- runCoverageScriptWithFakeReport repoRoot "90% expressions used (9/10)" "80"
    exitCode `shouldBe` ExitSuccess
    out `shouldSatisfy` ("Parsed expression coverage: 90% (9/10)" `isInfixOf`)
    out `shouldSatisfy` ("Coverage gate passed: 90% (9/10) >= 80%" `isInfixOf`)
    summary `shouldSatisfy` ("expressions_used=9" `isInfixOf`)
    summary `shouldSatisfy` ("expressions_total=10" `isInfixOf`)

  it "coverage gate fails when denominator is non-zero but threshold is not met" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, _, err, _) <- runCoverageScriptWithFakeReport repoRoot "90% expressions used (9/10)" "95"
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("below threshold 95%" `isInfixOf`)
    err `shouldSatisfy` ("(9/10)" `isInfixOf`)

  it "coverage gate removes stale tix before running tests" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, _, err, _) <- runCoverageScriptWithStaleTixGuard repoRoot
    exitCode `shouldBe` ExitSuccess
    err `shouldSatisfy` (not . isInfixOf "stale tix present")

  it "drift checker fails on SQL and mode drift, then passes after regeneration" $ do
    repoRoot <- getCurrentDirectory
    withSystemTempDirectory "squealgen-drift-check" $ \tmpDir -> do
      let driftScript = tmpDir </> "check_squealgen_drift.sh"
          mkScript = tmpDir </> "mksquealgen.sh"
          sqlFile = tmpDir </> "squealgen.sql"
      copyFile (repoRoot </> "check_squealgen_drift.sh") driftScript
      copyFile (repoRoot </> "mksquealgen.sh") mkScript
      makeExecutable driftScript
      makeExecutable mkScript
      writeFile sqlFile "select 1;\n"

      runInRepo tmpDir "bash ./mksquealgen.sh"
      runInRepo tmpDir "git init -q"
      runInRepo tmpDir "git config user.email test@example.com"
      runInRepo tmpDir "git config user.name test"
      runInRepo tmpDir "git add squealgen.sql squealgen mksquealgen.sh check_squealgen_drift.sh"
      runInRepo tmpDir "git commit -q -m init"

      writeFile sqlFile "select 2;\n"
      (sqlDriftExit, _, sqlDriftErr) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_squealgen_drift.sh"]) ""
      sqlDriftExit `shouldBe` ExitFailure 1
      sqlDriftErr `shouldSatisfy` ("./mksquealgen.sh" `isInfixOf`)

      runInRepo tmpDir "chmod -x squealgen"
      (modeDriftExit, _, modeDriftErr) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_squealgen_drift.sh"]) ""
      modeDriftExit `shouldBe` ExitFailure 1
      modeDriftErr `shouldSatisfy` ("./mksquealgen.sh" `isInfixOf`)

      runInRepo tmpDir "bash ./mksquealgen.sh"
      runInRepo tmpDir "git add squealgen"
      runInRepo tmpDir "git commit -q -m regen"
      (cleanExit, _, _) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_squealgen_drift.sh"]) ""
      cleanExit `shouldBe` ExitSuccess

  it "squealgen.sql contains a single stripDoublequotes definition" $ do
    sql <- readFile "squealgen.sql"
    countOccurrences "CREATE or replace FUNCTION pg_temp.stripDoublequotes" sql `shouldBe` 1

  it "cross-schema and pg_catalog specs use shared runSquealgen helper" $ do
    crossSchema <- readFile "test/CrossSchemaEnums/DBSpec.hs"
    pgCatalog <- readFile "test/PgCatalog/DBSpec.hs"
    crossSchema `shouldSatisfy` ("runSquealgenScript" `isInfixOf`)
    pgCatalog `shouldSatisfy` ("runSquealgenScript" `isInfixOf`)
    crossSchema `shouldSatisfy` (not . isInfixOf "runSquealgen ::")
    pgCatalog `shouldSatisfy` (not . isInfixOf "runSquealgen ::")

makeExecutable :: FilePath -> IO ()
makeExecutable path = do
  perms <- getPermissions path
  setPermissions path (perms { executable = True })

overridePath :: FilePath -> [(String, String)] -> [(String, String)]
overridePath fakeBin env = ("PATH", fakeBin <> ":" <> currentPath) : filter ((/= "PATH") . fst) env
  where
    currentPath = maybe "" id (lookup "PATH" env)

runCoverageScriptWithFakeReport :: FilePath -> String -> String -> IO (ExitCode, String, String, String)
runCoverageScriptWithFakeReport repoRoot fakeReportLine thresholdValue =
  withSystemTempDirectory "coverage-gate" $ \tmpDir -> do
    let coverageScript = tmpDir </> "check_coverage.sh"
        fakeBin = tmpDir </> "bin"
        fakeCabal = fakeBin </> "cabal"
        fakeHpc = fakeBin </> "hpc"
        fakeTestBin = tmpDir </> "fake-tests-bin"
        srcDir = tmpDir </> "src"
        mixPkgDir = tmpDir </> "dist-newstyle" </> "build" </> "x" </> "hpc" </> "mix" </> "pkg"
        envVars =
          [ ("FAKE_TEST_BIN", fakeTestBin)
          , ("FAKE_HPC_REPORT_LINE", fakeReportLine)
          , ("COVERAGE_THRESHOLD", thresholdValue)
          ]
        summaryPath = tmpDir </> "coverage" </> "summary.txt"
    copyFile (repoRoot </> "check_coverage.sh") coverageScript
    makeExecutable coverageScript
    createDirectoryIfMissing True fakeBin
    createDirectoryIfMissing True srcDir
    createDirectoryIfMissing True mixPkgDir
    writeFile (srcDir </> "Foo.hs") "module Foo where\nfoo :: Int\nfoo = 1\n"
    writeFile fakeTestBin "#!/usr/bin/env bash\nset -euo pipefail\n: \"${HPCTIXFILE:?missing HPCTIXFILE}\"\ntouch \"$HPCTIXFILE\"\n"
    makeExecutable fakeTestBin
    writeFile fakeCabal $ unlines
      [ "#!/usr/bin/env bash"
      , "set -euo pipefail"
      , "if [[ \"$1\" == \"build\" ]]; then exit 0; fi"
      , "if [[ \"$1\" == \"list-bin\" ]]; then"
      , "  printf '%s\\n' \"$FAKE_TEST_BIN\""
      , "  exit 0"
      , "fi"
      , "echo \"unexpected cabal args: $*\" >&2"
      , "exit 1"
      ]
    makeExecutable fakeCabal
    writeFile fakeHpc $ unlines
      [ "#!/usr/bin/env bash"
      , "set -euo pipefail"
      , "if [[ \"$1\" != \"report\" ]]; then"
      , "  echo \"unexpected hpc args: $*\" >&2"
      , "  exit 1"
      , "fi"
      , "printf '%s\\n' \"$FAKE_HPC_REPORT_LINE\""
      ]
    makeExecutable fakeHpc

    env <- ((envVars ++) . overridePath fakeBin) <$> getEnvironment
    let cmd = (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_coverage.sh"]) { env = Just env }
    (exitCode, out, err) <- readCreateProcessWithExitCode cmd ""
    hasSummary <- doesFileExist summaryPath
    summary <- if hasSummary then readFile summaryPath else pure ""
    pure (exitCode, out, err, summary)

runCoverageScriptWithStaleTixGuard :: FilePath -> IO (ExitCode, String, String, String)
runCoverageScriptWithStaleTixGuard repoRoot =
  withSystemTempDirectory "coverage-stale-tix" $ \tmpDir -> do
    let coverageScript = tmpDir </> "check_coverage.sh"
        fakeBin = tmpDir </> "bin"
        fakeCabal = fakeBin </> "cabal"
        fakeHpc = fakeBin </> "hpc"
        fakeTestBin = tmpDir </> "fake-tests-bin"
        srcDir = tmpDir </> "src"
        reportDir = tmpDir </> "coverage"
        staleTix = reportDir </> "tests.tix"
        mixPkgDir = tmpDir </> "dist-newstyle" </> "build" </> "x" </> "hpc" </> "mix" </> "pkg"
        envVars =
          [ ("FAKE_TEST_BIN", fakeTestBin)
          , ("FAKE_HPC_REPORT_LINE", "100% expressions used (1/1)")
          ]
        summaryPath = reportDir </> "summary.txt"
    copyFile (repoRoot </> "check_coverage.sh") coverageScript
    makeExecutable coverageScript
    createDirectoryIfMissing True fakeBin
    createDirectoryIfMissing True srcDir
    createDirectoryIfMissing True mixPkgDir
    createDirectoryIfMissing True reportDir
    writeFile (srcDir </> "Foo.hs") "module Foo where\nfoo :: Int\nfoo = 1\n"
    writeFile staleTix "stale\n"
    writeFile fakeTestBin $ unlines
      [ "#!/usr/bin/env bash"
      , "set -euo pipefail"
      , ": \"${HPCTIXFILE:?missing HPCTIXFILE}\""
      , "if [[ -e \"$HPCTIXFILE\" ]]; then"
      , "  echo \"stale tix present before test execution\" >&2"
      , "  exit 1"
      , "fi"
      , "touch \"$HPCTIXFILE\""
      ]
    makeExecutable fakeTestBin
    writeFile fakeCabal $ unlines
      [ "#!/usr/bin/env bash"
      , "set -euo pipefail"
      , "if [[ \"$1\" == \"build\" ]]; then exit 0; fi"
      , "if [[ \"$1\" == \"list-bin\" ]]; then"
      , "  printf '%s\\n' \"$FAKE_TEST_BIN\""
      , "  exit 0"
      , "fi"
      , "echo \"unexpected cabal args: $*\" >&2"
      , "exit 1"
      ]
    makeExecutable fakeCabal
    writeFile fakeHpc $ unlines
      [ "#!/usr/bin/env bash"
      , "set -euo pipefail"
      , "if [[ \"$1\" != \"report\" ]]; then"
      , "  echo \"unexpected hpc args: $*\" >&2"
      , "  exit 1"
      , "fi"
      , "printf '%s\\n' \"$FAKE_HPC_REPORT_LINE\""
      ]
    makeExecutable fakeHpc

    env <- ((envVars ++) . overridePath fakeBin) <$> getEnvironment
    let cmd = (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_coverage.sh"]) { env = Just env }
    (exitCode, out, err) <- readCreateProcessWithExitCode cmd ""
    hasSummary <- doesFileExist summaryPath
    summary <- if hasSummary then readFile summaryPath else pure ""
    pure (exitCode, out, err, summary)

runInRepo :: FilePath -> String -> IO ()
runInRepo dir command = do
  (exitCode, _, err) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> dir <> "\" && " <> command]) ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code -> expectationFailure $
      "command failed (" <> show code <> "): " <> command <> "\n" <> err

countOccurrences :: Eq a => [a] -> [a] -> Int
countOccurrences needle haystack
  | null needle = 0
  | otherwise = go haystack 0
  where
    go [] n = n
    go s@(_:xs) n
      | needle `isPrefixOf` s = go xs (n + 1)
      | otherwise = go xs n

isPrefixOf :: Eq a => [a] -> [a] -> Bool
isPrefixOf [] _          = True
isPrefixOf _ []          = False
isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys
