{-# LANGUAGE OverloadedStrings #-}
import           Data.Maybe
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Text.Casing        (pascal)

import           Data.Map           (Map)
import qualified Data.Map           as Map
import           System.Environment

passthrough = putStr =<< getContents


main = do
  putStrLn "-- i got called!"
  xs <- getArgs
  let schema = case xs of
                 [s] -> s
                 []  -> "public" -- default it for now
                 xs  -> error (show xs)
  real (T.pack schema)
--  passthrough

real schema = do
  alldata <- T.lines . T.pack <$> getContents
  let tables = filter (T.isPrefixOf "Table") alldata
      indices :: Map Text Text
      indices = Map.fromList . mapMaybe findPrimaryIndex $ filter (T.isPrefixOf "Index") alldata

      findPrimaryIndex :: Text -> Maybe (Text,Text)
      findPrimaryIndex t = do
        let fields = T.splitOn "||||" t
        table <- T.stripSuffix "\"" =<< (T.stripPrefix "\"" . last . T.splitOn " " $ last fields)
        tablename <- T.stripPrefix (schema <> ".") table
        keyname <- T.stripSuffix "\"" =<< T.stripPrefix ("Index \"" <> schema <> ".") (head fields)
        let dataFields = map (head . T.splitOn "|") $ init (drop 2 fields)
        pure (tablename, tshow keyname <> " ::: 'PrimaryKey '"  <>  tshow dataFields)
  -- putStrLn "-- parsed indices"
  -- (`mapM` (Map.toList indices)) $ \x ->
  --   putStrLn ("-- " <> show x)


  let (tableNames, definedTables) = unzip $ map (processTableChunk schema (`Map.lookup` indices)) tables
  putStrLn . T.unpack $ "type Schema = '[" <> T.intercalate "\n  ," (map (\t -> tshow t <> "::: 'Table " <> textPascal t <> "Table" )  tableNames) <> "]"
  mapM (putStrLn . T.unpack) definedTables

processTableChunk schema indices s = --
  let (tablenameComp:tablecomponents) = T.splitOn "||||" s
      tablename = fromJust $ T.stripPrefix (schema <> ".") $ fromJust $ T.stripSuffix "\"" $ fromJust $ T.stripPrefix "Table \"" tablenameComp
      meat = dropWhile (not . T.isSuffixOf ":") tablecomponents

      getChunks :: [Text] -> [Maybe Text] -- (Text,[Text])]
      getChunks [] = []
      getChunks (t:ts) = case T.stripSuffix ":" t of
        Just section -> let
          (ls, rest) = span (not . T.isSuffixOf ":") ts
          in (processConstraint section ls):getChunks rest
        Nothing -> getChunks ts -- shouldn't happen?

      processConstraint :: Text -> [Text] -> Maybe Text
      processConstraint section rules = case T.dropWhile (=='|') section of
        "Indexes"                 -> Nothing -- Just (section,rules)
        "Check constraints"       -> Nothing -- Just (T.intercalate "," $ map genCheck rules)
        "Foreign-key constraints" -> Just (T.intercalate "," $ map genForeignKey rules)
        "Referenced by"           -> Nothing
        "Triggers"                -> Nothing
        x                         -> Just ("othererror:" <> tshow x)

      -- genCheck :: Text -> Text
      -- genCheck t = case T.splitOn " \"CHECK\" " t of
      --   [name,s

      --   tshow . T.strip


      genForeignKey :: Text -> Text
      genForeignKey s = case T.splitOn " "
        -- this is pretty horrible but i don't want to write a real parser
        $ T.replace ", " ","
        $ T.strip s of
        (key:"FOREIGN":"KEY":keys:"REFERENCES":targets:_) ->
          let hkeys = stripList keys

              (targetTable, targetFields) = T.span (/='(') . fromJust . T.stripPrefix (schema <> ".") $ targets
          in
          key <> " ::: 'ForeignKey '" <>  tshow hkeys <> " " <> tshow targetTable <> " '" <> tshow (stripList targetFields)
        x -> T.unlines ["error!!!:",tablename,tshow x,s]

  in (tablename,  "type " <> textPascal tablename <> "Constraints = '[\n  "
     <> T.intercalate "\n  ," (catMaybes $ (indices tablename:getChunks meat)) <> "]")


--  in T.unlines $ ["begin"] <> (tablename:meat) <> ["end"]
--      splitOn "\nTable \"" . snd .
  --     (boringColumns, rest1) = break (T.isInfixOf ":") $ T.lines rest
  -- in
  -- T.unlines ["Table",tablename,(T.pack $ show rest1),"End"]

textPascal :: Text -> Text
textPascal = T.pack . pascal . T.unpack

tshow :: Show a => a -> Text
tshow = T.pack.show

stripList = T.splitOn "," . fromJust . T.stripPrefix "(" . fromJust . T.stripSuffix ")"
