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
import Data.Char(toLower)

runSession :: String
           -> String
           -> [String]
           -> PQ schema schema IO a
           -> IO a
runSession testname schema extraSchemas f = either (error . show)  pure =<< do
  withDbCache $ \cache -> do
    withConfig (cacheConfig cache) $ \db -> do
      withConnection (toConnectionString db) $ do
        mapM (loader testname) extraSchemas
        loader testname schema
        f
  where
    loader testname sch = do
      let sqlFile = "./test/" <> testname <> "/schemas/" <> sch <> "/structure.sql"
      sql <- liftIO $ BS8.readFile sqlFile
      define (UnsafeDefinition sql)
