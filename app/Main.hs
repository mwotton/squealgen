{-# LANGUAGE TemplateHaskell #-}
module Main where

import System.Process
import System.Environment
import Language.Haskell.TH.Syntax

$(addDependentFile "/home/mark/projects/squealgen/squealgen.sql" >> pure [])

-- | generate haskell from the sql to the given path
main :: IO ()
main = do
  [database, sqlFile, targetFile] <- getArgs
  -- insanely unsafe
  print (database, sqlFile, targetFile)
  callCommand $ "psql " <> database <> " < " <> sqlFile <> " > " <> targetFile
  
