-- | This code was originally created by squealgen. Edit if you know how it got made and are willing to own it now.
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE GADTs #-}
{-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}

module Extensions.Schema where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)

-- squeal doesn't yet support cidr or ltree, so for the moment we emit them explicitly
type PGcidr = UnsafePGType "cidr"
type PGltree = UnsafePGType "ltree"
type PGltxtquery = UnsafePGType "ltxtquery"
type PGlquery = UnsafePGType "lquery"

type DB = '["public" ::: Schema]

type Schema = Join Tables (Join Views (Join Enums (Join Functions Domains)))
-- enums

-- decls
type Enums =
  ('[] :: [(Symbol,SchemumType)])
-- schema
type Tables = ('[
   ]  :: [(Symbol,SchemumType)])

-- defs

-- VIEWS
type Views = 
  '[]


-- functions
type Functions = 
  '[ "_lt_q_regex" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull (PGvararray (NotNull PGlquery)) ] :=> 'Returns ( 'Null PGbool) )
   , "_lt_q_rregex" ::: Function ('[ NotNull (PGvararray (NotNull PGlquery)),  NotNull (PGvararray (NotNull PGltree)) ] :=> 'Returns ( 'Null PGbool) )
   , "_ltq_extract_regex" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGlquery ] :=> 'Returns ( 'Null PGltree) )
   , "_ltq_regex" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGlquery ] :=> 'Returns ( 'Null PGbool) )
   , "_ltq_rregex" ::: Function ('[ NotNull PGlquery,  NotNull (PGvararray (NotNull PGltree)) ] :=> 'Returns ( 'Null PGbool) )
   , "_ltree_consistent" ::: Function ('[ NotNull PGint2,  NotNull PGoid ] :=> 'Returns ( 'Null PGbool) )
   , "_ltree_extract_isparent" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGltree ] :=> 'Returns ( 'Null PGltree) )
   , "_ltree_extract_risparent" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGltree ] :=> 'Returns ( 'Null PGltree) )
   , "_ltree_isparent" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "_ltree_r_isparent" ::: Function ('[ NotNull PGltree,  NotNull (PGvararray (NotNull PGltree)) ] :=> 'Returns ( 'Null PGbool) )
   , "_ltree_r_risparent" ::: Function ('[ NotNull PGltree,  NotNull (PGvararray (NotNull PGltree)) ] :=> 'Returns ( 'Null PGbool) )
   , "_ltree_risparent" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "_ltxtq_exec" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGltxtquery ] :=> 'Returns ( 'Null PGbool) )
   , "_ltxtq_extract_exec" ::: Function ('[ NotNull (PGvararray (NotNull PGltree)),  NotNull PGltxtquery ] :=> 'Returns ( 'Null PGltree) )
   , "_ltxtq_rexec" ::: Function ('[ NotNull PGltxtquery,  NotNull (PGvararray (NotNull PGltree)) ] :=> 'Returns ( 'Null PGbool) )
   , "index" ::: Function ('[ NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGint4 ] :=> 'Returns ( 'Null PGint4) )
   , "lca" ::: Function ('[ NotNull PGltree,  NotNull (PGvararray (NotNull PGltree)),  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGltree) )
   , "lt_q_regex" ::: Function ('[ NotNull PGltree,  NotNull (PGvararray (NotNull PGlquery)) ] :=> 'Returns ( 'Null PGbool) )
   , "lt_q_rregex" ::: Function ('[ NotNull (PGvararray (NotNull PGlquery)),  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltq_regex" ::: Function ('[ NotNull PGltree,  NotNull PGlquery ] :=> 'Returns ( 'Null PGbool) )
   , "ltq_rregex" ::: Function ('[ NotNull PGlquery,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree2text" ::: Function ('[ NotNull PGltree ] :=> 'Returns ( 'Null PGtext) )
   , "ltree_addltree" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGltree) )
   , "ltree_addtext" ::: Function ('[ NotNull PGltree,  NotNull PGtext ] :=> 'Returns ( 'Null PGltree) )
   , "ltree_cmp" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGint4) )
   , "ltree_consistent" ::: Function ('[ NotNull PGint2,  NotNull PGoid ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_eq" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_ge" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_gt" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_isparent" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_le" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_lt" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_ne" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_risparent" ::: Function ('[ NotNull PGltree,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "ltree_textadd" ::: Function ('[ NotNull PGtext,  NotNull PGltree ] :=> 'Returns ( 'Null PGltree) )
   , "ltreeparentsel" ::: Function ('[ NotNull PGoid,  NotNull PGint4 ] :=> 'Returns ( 'Null PGfloat8) )
   , "ltxtq_exec" ::: Function ('[ NotNull PGltree,  NotNull PGltxtquery ] :=> 'Returns ( 'Null PGbool) )
   , "ltxtq_rexec" ::: Function ('[ NotNull PGltxtquery,  NotNull PGltree ] :=> 'Returns ( 'Null PGbool) )
   , "nlevel" ::: Function ('[ NotNull PGltree ] :=> 'Returns ( 'Null PGint4) )
   , "subltree" ::: Function ('[ NotNull PGltree,  NotNull PGint4,  NotNull PGint4 ] :=> 'Returns ( 'Null PGltree) )
   , "subpath" ::: Function ('[ NotNull PGltree,  NotNull PGltree,  NotNull PGint4,  NotNull PGint4,  NotNull PGint4 ] :=> 'Returns ( 'Null PGltree) )
   , "text2ltree" ::: Function ('[ NotNull PGtext ] :=> 'Returns ( 'Null PGltree) ) ]
type Domains = '[]

