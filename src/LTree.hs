{-# LANGUAGE DataKinds #-}
module LTree where

import           Squeal.PostgreSQL

type PGltree = UnsafePGType "ltree"
type PGltxtquery = UnsafePGType "ltxtquery"
type PGlquery = UnsafePGType "lquery"
