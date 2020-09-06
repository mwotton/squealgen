{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module DBHelpers where

import qualified Data.ByteString.Char8  as BS8
import           Data.Int
import           Database.Postgres.Temp
import           Squeal.PostgreSQL      hiding (with)
import           System.IO
import           UnliftIO

runSession :: String
           -> String
           -> PQ schema schema IO a
           -> IO a
runSession testname schema f = either (error . show)  pure =<< do
  let sqlFile = "./test/" <> testname <> "/schemas/" <> schema <> "/structure.sql"
  sql <- BS8.readFile sqlFile
  withDbCache $ \cache -> do
    withConfig (cacheConfig cache) $ \db -> do
      withConnection (toConnectionString db) $ do
        define (UnsafeDefinition sql)
        f
