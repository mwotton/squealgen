{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module DBHelpers where

import           Control.Monad          (forM_, when)
import qualified Data.ByteString.Char8  as BS8
import           Data.Int
import           Database.Postgres.Temp
import           Squeal.PostgreSQL      hiding (with)
import           System.Directory       (listDirectory)
import           System.IO
import           UnliftIO

-- | runSses
runSession :: FilePath
           -> PQ schema schema IO a
           -> IO a
runSession schemaDir f = either (error . show)  pure =<< do
  files <- listDirectory schemaDir
  -- sql <- BS8.readFile sqlfile
  withDbCache $ \cache -> do
    withConfig (cacheConfig cache) $ \db -> do
      withConnection (toConnectionString db) $ do
        forM_ files $ \(filename :: FilePath) -> do
          when (filename /= "public") $ do
            define (UnsafeDefinition $ BS8.pack $ "create schema " <> filename <> ";")
          define (UnsafeDefinition $ BS8.pack $ "set search_path to " <> filename <> ";")
          sql <- liftIO $ BS8.readFile (schemaDir <> "/" <> filename)
          define (UnsafeDefinition sql)
        f
