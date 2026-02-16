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
