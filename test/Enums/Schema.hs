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

module Enums.Schema where
import Squeal.PostgreSQL
import GHC.TypeLits(Symbol)



type DB = '["public" ::: Schema]

type Schema = Join Tables (Join Views (Join Enums (Join Functions Domains)))
-- enums
type PGtraffic_light = 'PGenum
  '["Red", "Yellow", "Green"]
-- decls
type Enums =
  ('["traffic_light" ::: 'Typedef PGtraffic_light] :: [(Symbol,SchemumType)])
-- schema
type Tables = ('[
   "lights" ::: 'Table LightsTable]  :: [(Symbol,SchemumType)])

-- defs
type LightsColumns = '["light" ::: 'NoDef :=> 'NotNull PGtraffic_light]
type LightsConstraints = '[]
type LightsTable = LightsConstraints :=> LightsColumns

-- VIEWS
type Views = 
  '["lights_v" ::: 'View LightsVView]

type LightsVView = 
  '["light" ::: 'Null PGtraffic_light]

-- functions
type Functions = 
  '[  ]
type Domains = '[]

