{-# LANGUAGE DataKinds #-}
module LTree where

import           Data.Char        (isAsciiLower, isDigit)
import           Squeal.PostgreSQL

type PGltree = UnsafePGType "ltree"
type PGltxtquery = UnsafePGType "ltxtquery"
type PGlquery = UnsafePGType "lquery"

ltreePathSegments :: String -> Maybe [String]
ltreePathSegments path
  | null path = Nothing
  | otherwise = traverse validateLabel (splitOnDot path)
  where
    validateLabel segment
      | null segment = Nothing
      | all isLtreeLabelChar segment = Just segment
      | otherwise = Nothing

isLtreeLabelChar :: Char -> Bool
isLtreeLabelChar char = isAsciiLower char || isDigit char || char == '_'

splitOnDot :: String -> [String]
splitOnDot input =
  case break (== '.') input of
    (segment, []) -> [segment]
    (segment, _ : rest) -> segment : splitOnDot rest
