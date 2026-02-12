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
      driftExit `shouldSatisfy` (/= ExitSuccess)
      driftErr `shouldSatisfy` ("squealgen drift detected" `isInfixOf`)
      driftErr `shouldSatisfy` ("./mksquealgen.sh" `isInfixOf`)

  it "make ci executes drift check, tests, and coverage in order" $ do
    repoRoot <- getCurrentDirectory
    withSystemTempDirectory "make-ci-contract" $ \tmpDir -> do
      let makefile = tmpDir </> "Makefile"
          mkScript = tmpDir </> "mksquealgen.sh"
          driftScript = tmpDir </> "check_squealgen_drift.sh"
          coverageScript = tmpDir </> "check_coverage.sh"
          sqlFile = tmpDir </> "squealgen.sql"
          logFile = tmpDir </> "invocations.log"
          fakeBin = tmpDir </> "bin"
          fakeCabal = fakeBin </> "cabal"
      copyFile (repoRoot </> "Makefile") makefile
      writeFile sqlFile "select 1;\n"
      writeFile mkScript $ unlines
        [ "#!/usr/bin/env bash"
        , "set -euo pipefail"
        , "printf 'mksquealgen\\n' >> \"$SQG_TEST_LOG\""
        , "printf '#!/usr/bin/env bash\\nexit 0\\n' > squealgen"
        , "chmod +x squealgen"
        ]
      writeFile driftScript $ unlines
        [ "#!/usr/bin/env bash"
        , "set -euo pipefail"
        , "printf 'drift\\n' >> \"$SQG_TEST_LOG\""
        ]
      writeFile coverageScript $ unlines
        [ "#!/usr/bin/env bash"
        , "set -euo pipefail"
        , "printf 'coverage\\n' >> \"$SQG_TEST_LOG\""
        ]
      makeExecutable mkScript
      makeExecutable driftScript
      makeExecutable coverageScript
      createDirectoryIfMissing True fakeBin
      writeFile fakeCabal $ unlines
        [ "#!/usr/bin/env bash"
        , "set -euo pipefail"
        , "if [[ \"$1\" == \"test\" ]]; then"
        , "  printf 'tests\\n' >> \"$SQG_TEST_LOG\""
        , "  exit 0"
        , "fi"
        , "echo \"unexpected cabal args: $*\" >&2"
        , "exit 1"
        ]
      makeExecutable fakeCabal

      env <- (("SQG_TEST_LOG", logFile) :) . overridePath fakeBin <$> getEnvironment
      let cmd = (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && make ci"]) { env = Just env }
      (exitCode, _, err) <- readCreateProcessWithExitCode cmd ""
      exitCode `shouldBe` ExitSuccess
      err `shouldSatisfy` (not . isInfixOf "Validation contract failure")
      invocationLog <- readFile logFile
      invocationLog `shouldBe` "drift\nmksquealgen\ntests\ncoverage\n"

  it "coverage gate fails on zero-denominator expression coverage by default" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, _, err, _) <- runCoverageScriptWithFakeReport repoRoot "100% expressions used (0/0)" "100"
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("denominator is zero" `isInfixOf`)
    err `shouldSatisfy` ("COVERAGE_ZERO_DENOMINATOR_POLICY=allow" `isInfixOf`)

  it "coverage gate reports fail policy metadata for zero-denominator default path" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, _, _, summary) <- runCoverageScriptWithFakeReport repoRoot "100% expressions used (0/0)" "100"
    exitCode `shouldBe` ExitFailure 1
    summary `shouldSatisfy` ("zero_denominator_policy=fail" `isInfixOf`)
    summary `shouldSatisfy` ("zero_denominator_outcome=fail" `isInfixOf`)
    summary `shouldSatisfy` ("zero_denominator_triggered=true" `isInfixOf`)
    summary `shouldSatisfy` ("coverage_gate_result=fail" `isInfixOf`)

  it "coverage gate allows explicit local override for zero-denominator expression coverage" $ do
    repoRoot <- getCurrentDirectory
    let extraEnv = [("COVERAGE_ZERO_DENOMINATOR_POLICY", "allow")]
    (exitCode, out, err, summary) <- runCoverageScriptWithFakeReportEnv repoRoot "100% expressions used (0/0)" "100" extraEnv
    exitCode `shouldBe` ExitSuccess
    err `shouldBe` ""
    out `shouldSatisfy` ("Coverage gate not-applicable: expression denominator is zero (0/0)" `isInfixOf`)
    summary `shouldSatisfy` ("zero_denominator_policy=allow" `isInfixOf`)
    summary `shouldSatisfy` ("zero_denominator_outcome=not-applicable" `isInfixOf`)
    summary `shouldSatisfy` ("zero_denominator_triggered=true" `isInfixOf`)
    summary `shouldSatisfy` ("coverage_gate_result=not-applicable" `isInfixOf`)

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
    err `shouldSatisfy` ("ERROR [coverage-policy]" `isInfixOf`)
    err `shouldSatisfy` ("below threshold 95%" `isInfixOf`)
    err `shouldSatisfy` ("(9/10)" `isInfixOf`)

  it "coverage gate labels coverage-enabled build failures as toolchain failures" $ do
    repoRoot <- getCurrentDirectory
    let extraEnv = [("FAKE_CABAL_BUILD_FAIL", "1")]
    (exitCode, _, err, _) <- runCoverageScriptWithFakeReportEnv repoRoot "90% expressions used (9/10)" "80" extraEnv
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("simulated coverage build failure" `isInfixOf`)
    err `shouldSatisfy` ("ERROR [coverage-toolchain]" `isInfixOf`)

  it "coverage gate accepts decimal numeric COVERAGE_THRESHOLD values" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, out, _, summary) <- runCoverageScriptWithFakeReport repoRoot "90% expressions used (9/10)" "89.5"
    exitCode `shouldBe` ExitSuccess
    out `shouldSatisfy` ("Coverage gate passed: 90% (9/10) >= 89.5%" `isInfixOf`)
    summary `shouldSatisfy` ("threshold_percent=89.5" `isInfixOf`)

  it "coverage gate rejects non-numeric COVERAGE_THRESHOLD values" $ do
    repoRoot <- getCurrentDirectory
    (exitCode, _, err, summary) <- runCoverageScriptWithFakeReport repoRoot "90% expressions used (9/10)" "not-a-number"
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("invalid COVERAGE_THRESHOLD" `isInfixOf`)
    summary `shouldBe` ""

  it "coverage gate removes stale tix before running tests" $ do
    repoRoot <- getCurrentDirectory
    (firstRun, secondRun) <- runCoverageScriptWithStaleTixGuard repoRoot
    let (firstExit, _, firstErr, _) = firstRun
        (secondExit, _, secondErr, _) = secondRun
    firstExit `shouldBe` ExitSuccess
    secondExit `shouldBe` ExitSuccess
    firstErr `shouldSatisfy` (not . isInfixOf "stale tix present")
    secondErr `shouldSatisfy` (not . isInfixOf "stale tix present")

  it "coverage gate applies line-level exclusions from allowlist selectors" $ do
    repoRoot <- getCurrentDirectory
    let allowlist = "Foo:2|exclude known unreachable guard\n"
        fakeShow = unlines
          [ "0 1 pkg:Foo 1:1-1:5 ExpBox False"
          , "1 0 pkg:Foo 2:1-2:5 ExpBox False"
          ]
    (exitCode, out, _, summary) <- runCoverageScriptWithAllowlist repoRoot "50% expressions used (1/2)" "60" allowlist fakeShow
    exitCode `shouldBe` ExitSuccess
    out `shouldSatisfy` ("Applied line-level exclusions: 1 expressions removed" `isInfixOf`)
    summary `shouldSatisfy` ("line_exclusions_applied=1" `isInfixOf`)
    summary `shouldSatisfy` ("expressions_total=1" `isInfixOf`)

  it "coverage gate rejects malformed line-level allowlist selectors" $ do
    repoRoot <- getCurrentDirectory
    let allowlist = "Foo:abc|bad selector\n"
    (exitCode, _, err, _) <- runCoverageScriptWithAllowlist repoRoot "90% expressions used (9/10)" "80" allowlist ""
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("invalid allowlist selector" `isInfixOf`)

  it "coverage gate requires rationale for each allowlist selector" $ do
    repoRoot <- getCurrentDirectory
    let allowlist = "Foo:2|\n"
    (exitCode, _, err, _) <- runCoverageScriptWithAllowlist repoRoot "90% expressions used (9/10)" "80" allowlist ""
    exitCode `shouldBe` ExitFailure 1
    err `shouldSatisfy` ("missing rationale" `isInfixOf`)

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

  it "drift checker supports deterministic fallback outside git worktrees" $ do
    repoRoot <- getCurrentDirectory
    withSystemTempDirectory "squealgen-drift-check-nongit" $ \tmpDir -> do
      let driftScript = tmpDir </> "check_squealgen_drift.sh"
          mkScript = tmpDir </> "mksquealgen.sh"
          sqlFile = tmpDir </> "squealgen.sql"
      copyFile (repoRoot </> "check_squealgen_drift.sh") driftScript
      copyFile (repoRoot </> "mksquealgen.sh") mkScript
      makeExecutable driftScript
      makeExecutable mkScript
      writeFile sqlFile "select 1;\n"

      runInRepo tmpDir "bash ./mksquealgen.sh"

      writeFile sqlFile "select 2;\n"
      (driftExit, _, driftErr) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_squealgen_drift.sh"]) ""
      driftExit `shouldBe` ExitFailure 1
      driftErr `shouldSatisfy` ("squealgen drift detected" `isInfixOf`)
      driftErr `shouldSatisfy` ("non-git fallback mode" `isInfixOf`)

      runInRepo tmpDir "bash ./mksquealgen.sh"
      (cleanExit, _, cleanErr) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_squealgen_drift.sh"]) ""
      cleanExit `shouldBe` ExitSuccess
      cleanErr `shouldSatisfy` (not . isInfixOf "squealgen drift detected")

  it "drift checker bootstraps non-git runs when squealgen is absent" $ do
    repoRoot <- getCurrentDirectory
    withSystemTempDirectory "squealgen-drift-check-bootstrap-nongit" $ \tmpDir -> do
      let driftScript = tmpDir </> "check_squealgen_drift.sh"
          mkScript = tmpDir </> "mksquealgen.sh"
          sqlFile = tmpDir </> "squealgen.sql"
          generated = tmpDir </> "squealgen"
      copyFile (repoRoot </> "check_squealgen_drift.sh") driftScript
      copyFile (repoRoot </> "mksquealgen.sh") mkScript
      makeExecutable driftScript
      makeExecutable mkScript
      writeFile sqlFile "select 1;\n"

      existsBefore <- doesFileExist generated
      existsBefore `shouldBe` False
      (bootstrapExit, _, bootstrapErr) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_squealgen_drift.sh"]) ""
      bootstrapExit `shouldBe` ExitSuccess
      bootstrapErr `shouldSatisfy` (not . isInfixOf "requires an existing ./squealgen")
      doesFileExist generated `shouldReturn` True

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
  runCoverageScriptWithFakeReportEnv repoRoot fakeReportLine thresholdValue []

runCoverageScriptWithFakeReportEnv :: FilePath -> String -> String -> [(String, String)] -> IO (ExitCode, String, String, String)
runCoverageScriptWithFakeReportEnv repoRoot fakeReportLine thresholdValue extraEnv =
  runCoverageScriptWithAllowlistEnv repoRoot fakeReportLine thresholdValue "" "" extraEnv

runCoverageScriptWithAllowlist :: FilePath -> String -> String -> String -> String -> IO (ExitCode, String, String, String)
runCoverageScriptWithAllowlist repoRoot fakeReportLine thresholdValue allowlistContents fakeShowOutput =
  runCoverageScriptWithAllowlistEnv repoRoot fakeReportLine thresholdValue allowlistContents fakeShowOutput []

runCoverageScriptWithAllowlistEnv :: FilePath -> String -> String -> String -> String -> [(String, String)] -> IO (ExitCode, String, String, String)
runCoverageScriptWithAllowlistEnv repoRoot fakeReportLine thresholdValue allowlistContents fakeShowOutput extraEnv =
  withSystemTempDirectory "coverage-gate" $ \tmpDir -> do
    let coverageScript = tmpDir </> "check_coverage.sh"
        fakeBin = tmpDir </> "bin"
        fakeCabal = fakeBin </> "cabal"
        fakeHpc = fakeBin </> "hpc"
        fakeTestBin = tmpDir </> "fake-tests-bin"
        srcDir = tmpDir </> "src"
        mixPkgDir = tmpDir </> "dist-newstyle" </> "build" </> "x" </> "hpc" </> "mix" </> "pkg"
        allowlistPath = tmpDir </> "coverage-allowlist.txt"
        envVars =
          [ ("FAKE_TEST_BIN", fakeTestBin)
          , ("FAKE_HPC_REPORT_LINE", fakeReportLine)
          , ("FAKE_HPC_SHOW_OUTPUT", fakeShowOutput)
          , ("COVERAGE_THRESHOLD", thresholdValue)
          , ("COVERAGE_ALLOWLIST_FILE", allowlistPath)
          ] <> extraEnv
        summaryPath = tmpDir </> "coverage" </> "summary.txt"
    copyFile (repoRoot </> "check_coverage.sh") coverageScript
    makeExecutable coverageScript
    createDirectoryIfMissing True fakeBin
    createDirectoryIfMissing True srcDir
    createDirectoryIfMissing True mixPkgDir
    writeFile (srcDir </> "Foo.hs") "module Foo where\nfoo :: Int\nfoo = 1\n"
    writeFile allowlistPath allowlistContents
    writeFile fakeTestBin "#!/usr/bin/env bash\nset -euo pipefail\n: \"${HPCTIXFILE:?missing HPCTIXFILE}\"\ntouch \"$HPCTIXFILE\"\n"
    makeExecutable fakeTestBin
    writeFile fakeCabal $ unlines
      [ "#!/usr/bin/env bash"
      , "set -euo pipefail"
      , "if [[ \"$1\" == \"build\" ]]; then"
      , "  if [[ \"${FAKE_CABAL_BUILD_FAIL:-0}\" == \"1\" ]]; then"
      , "    echo \"simulated coverage build failure\" >&2"
      , "    exit 12"
      , "  fi"
      , "  exit 0"
      , "fi"
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
      , "case \"$1\" in"
      , "  report)"
      , "    printf '%s\\n' \"$FAKE_HPC_REPORT_LINE\""
      , "    ;;"
      , "  show)"
      , "    printf '%s\\n' \"$FAKE_HPC_SHOW_OUTPUT\""
      , "    ;;"
      , "  *)"
      , "    echo \"unexpected hpc args: $*\" >&2"
      , "    exit 1"
      , "    ;;"
      , "esac"
      ]
    makeExecutable fakeHpc

    env <- ((envVars ++) . overridePath fakeBin) <$> getEnvironment
    let cmd = (proc "bash" ["-lc", "cd \"" <> tmpDir <> "\" && ./check_coverage.sh"]) { env = Just env }
    (exitCode, out, err) <- readCreateProcessWithExitCode cmd ""
    hasSummary <- doesFileExist summaryPath
    summary <- if hasSummary then readFile summaryPath else pure ""
    pure (exitCode, out, err, summary)

runCoverageScriptWithStaleTixGuard :: FilePath -> IO ((ExitCode, String, String, String), (ExitCode, String, String, String))
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
    (firstExit, firstOut, firstErr) <- readCreateProcessWithExitCode cmd ""
    firstHasSummary <- doesFileExist summaryPath
    firstSummary <- if firstHasSummary then readFile summaryPath else pure ""

    (secondExit, secondOut, secondErr) <- readCreateProcessWithExitCode cmd ""
    secondHasSummary <- doesFileExist summaryPath
    secondSummary <- if secondHasSummary then readFile summaryPath else pure ""

    pure ((firstExit, firstOut, firstErr, firstSummary), (secondExit, secondOut, secondErr, secondSummary))

runInRepo :: FilePath -> String -> IO ()
runInRepo dir command = do
  (exitCode, _, err) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> dir <> "\" && " <> command]) ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code -> expectationFailure $
      "command failed (" <> show code <> "): " <> command <> "\n" <> err
