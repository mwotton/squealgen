{-# LANGUAGE TypeApplications #-}
module Main (main) where

import qualified Control.Exception as E
import           Data.Maybe        (fromMaybe)
import           System.Environment (getArgs, lookupEnv)
import           System.Exit        (ExitCode (..), exitFailure, exitWith)
import           System.IO          (hPutStrLn, stderr)
import           System.Process     (CreateProcess (..), StdStream (..), createProcess,
                                    proc, waitForProcess)

import           Paths_squealgen    (getDataFileName)

usage :: IO a
usage = do
  hPutStrLn stderr "Usage: squealgen DBNAME MODULENAME SCHEMA [IMPORTS]"
  exitFailure

main :: IO ()
main = do
  args <- getArgs
  case args of
    [dbName, moduleName, schemaFragment] -> run dbName moduleName schemaFragment ""
    [dbName, moduleName, schemaFragment, imports] -> run dbName moduleName schemaFragment imports
    _ -> usage

run :: String -> String -> String -> String -> IO ()
run dbName moduleName schemaFragment imports = do
  e <- E.try @E.SomeException $ do
    sqlPath <- getDataFileName "squealgen.sql"
    psqlCmd <- fromMaybe "psql" <$> lookupEnv "PSQLCMD"

    -- Keep this in sync with the generated ./squealgen script.
    let psql = (proc psqlCmd
          [ "-X"
          , "-v", "ON_ERROR_STOP=1"
          , "-d", dbName
          , "-v", "chosen_schema=" <> schemaFragment
          , "-v", "modulename=" <> moduleName
          , "-v", "extra_imports=" <> imports
          , "-f", sqlPath
          ])
          { std_in = Inherit
          , std_out = Inherit
          , std_err = Inherit
          }

    (_, _, _, ph) <- createProcess psql
    waitForProcess ph

  case e of
    Left err -> do
      hPutStrLn stderr ("error: " <> show err)
      exitFailure
    Right code -> exitWith code
