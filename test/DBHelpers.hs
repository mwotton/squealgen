{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
module DBHelpers where

import qualified Data.ByteString.Char8  as BS8
import           Database.Postgres.Temp (toConnectionString, with)
import           Squeal.PostgreSQL      hiding (with)
import           System.IO
import           UnliftIO

runSession :: FilePath
           -> PQ schema schema IO a
           -> IO a
runSession sqlfile f = either (error . show)  pure =<< do

  sql <- BS8.readFile sqlfile
  with $ \db -> do
    withConnection (toConnectionString db) $ do
      define (UnsafeDefinition sql)
      f
