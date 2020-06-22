{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE UndecidableInstances #-}
module Enums.DBSpec where

import           Data.Int
import           DBHelpers         (runSession)
import           Enums.Schema
import qualified Generics.SOP      as SOP
import qualified GHC.Generics      as GHC
import           Squeal.PostgreSQL
import           Test.Hspec

-- nb: this setup does require that the enums be valid haskell data-constructors,
-- ie uppercase-first-letter.
data TrafficLight = Red | Yellow | Green
  deriving stock (Eq,Show,GHC.Generic)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)
  deriving (IsPG, ToPG db, FromPG, Inline) via (Enumerated TrafficLight)

getLightsFromView :: Statement DB () (Only (Maybe TrafficLight))
getLightsFromView = query $ select_ (#lights_v ! #light `as` #fromOnly) (from (view #lights_v))

getLights :: Statement DB () (Only TrafficLight)
getLights = query $ select_ (#lights ! #light `as` #fromOnly) (from (table #lights))

spec = describe "Enums" $ do
  it "can fetch enums, and enums from a view" $ do
    runSession "./test/Enums/schemas"
      ((,) <$> (getRows =<< execute getLights)
           <*> (getRows =<< execute getLightsFromView))
      `shouldReturn` ([Only Red,Only Yellow]
                     ,[Only (Just Yellow),Only (Just Green)])
