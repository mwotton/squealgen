module CheckSchemaScript.DBSpec (spec) where

import           Data.List          (isInfixOf)
import           System.Directory   (Permissions (..), copyFile, createDirectoryIfMissing, getCurrentDirectory, getPermissions, setPermissions)
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

      (exitCode, _, _) <- readCreateProcessWithExitCode cmd ""
      exitCode `shouldBe` ExitFailure 1
      readFile existing `shouldReturn` "old generated module\n"

  it "make test invokes squealgen drift check" $ do
    makefile <- readFile "Makefile"
    makefile `shouldSatisfy` ("check-squealgen-drift" `isInfixOf`)

  it "CI invokes squealgen drift check" $ do
    workflow <- readFile ".github/workflows/ci.yml"
    workflow `shouldSatisfy` ("check_squealgen_drift.sh" `isInfixOf`)

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

makeExecutable :: FilePath -> IO ()
makeExecutable path = do
  perms <- getPermissions path
  setPermissions path (perms { executable = True })

overridePath :: FilePath -> [(String, String)] -> [(String, String)]
overridePath fakeBin env = ("PATH", fakeBin <> ":" <> currentPath) : filter ((/= "PATH") . fst) env
  where
    currentPath = maybe "" id (lookup "PATH" env)

runInRepo :: FilePath -> String -> IO ()
runInRepo dir command = do
  (exitCode, _, err) <- readCreateProcessWithExitCode (proc "bash" ["-lc", "cd \"" <> dir <> "\" && " <> command]) ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code -> expectationFailure $
      "command failed (" <> show code <> "): " <> command <> "\n" <> err
