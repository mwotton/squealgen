{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module ForeignKeyReferencedColumns.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           Database.Postgres.Temp   (cacheConfig, toConnectionString, withConfig, withDbCache)
import           ForeignKeyReferencedColumns.Public
import           Data.Int                 (Int32)
import qualified Generics.SOP             as SOP
import qualified GHC.Generics             as GHC
import           Test.Hspec               (Spec, describe, it, shouldContain, expectationFailure)
import           Test.Hspec.Expectations.Lifted (shouldBe)
import           Squeal.PostgreSQL
import           DBHelpers                (runSession, runSquealgenScript)

data ChildSingleRow = ChildSingleRow { local_parent_id :: Int32 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

data ChildCompositeRow = ChildCompositeRow { local_b :: Int32 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

data ChildCrossRow = ChildCrossRow { left_local :: Int32 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

data SelfRefRow = SelfRefRow { self_id :: Int32 }
  deriving stock (Show, GHC.Generic, Eq)
  deriving anyclass (SOP.Generic, SOP.HasDatatypeInfo)

spec :: Spec
spec = describe "ForeignKeyReferencedColumns" $ do
  it "emits referenced FK columns from the referenced relation in the declared order" $ do
    res <- try @SomeException run :: IO (Either SomeException String)
    case res of
      Left e   -> expectationFailure ("setup failed: " <> displayException e)
      Right hs -> do
        hs `shouldContain` "\"child_single_parent_fk\" ::: 'ForeignKey '[\"local_parent_id\"] \"public\" \"parent_single\" '[\"id\"]"
        hs `shouldContain` "\"child_composite_parent_fk\" ::: 'ForeignKey '[\"local_b\",\"local_a\"] \"public\" \"parent_composite\" '[\"ref_b\",\"ref_a\"]"
        hs `shouldContain` "\"child_cross_parent_fk\" ::: 'ForeignKey '[\"left_local\",\"right_local\"] \"ref\" \"parent_cross\" '[\"target_left\",\"target_right\"]"
        hs `shouldContain` "\"self_ref_parent_fk\" ::: 'ForeignKey '[\"parent_local\"] \"public\" \"self_ref\" '[\"id\"]"
  it "runs typed runtime queries against all FK fixture tables" $
    runSession "ForeignKeyReferencedColumns" "Public" $ do
      define $ UnsafeDefinition $ BS8.pack $ unlines
        [ "INSERT INTO public.parent_single (id) VALUES (1);"
        , "INSERT INTO public.child_single (local_parent_id) VALUES (1);"
        , "INSERT INTO public.parent_composite (ref_a, ref_b) VALUES (1, 2);"
        , "INSERT INTO public.child_composite (local_b, local_a) VALUES (2, 1);"
        , "INSERT INTO ref.parent_cross (target_left, target_right) VALUES (10, 20);"
        , "INSERT INTO public.child_cross (left_local, right_local) VALUES (10, 20);"
        , "INSERT INTO public.self_ref (id, parent_local) VALUES (100, NULL);"
        , "INSERT INTO public.self_ref (id, parent_local) VALUES (101, 100);"
        ]
      childSingleRows <- getRows =<< execute selectChildSingle
      childCompositeRows <- getRows =<< execute selectChildComposite
      childCrossRows <- getRows =<< execute selectChildCross
      selfRefRows <- getRows =<< execute selectSelfRef
      childSingleRows `shouldBe` [ChildSingleRow 1]
      childCompositeRows `shouldBe` [ChildCompositeRow 2]
      childCrossRows `shouldBe` [ChildCrossRow 10]
      selfRefRows `shouldBe` [SelfRefRow 100, SelfRefRow 101]

selectChildSingle :: Statement DB () ChildSingleRow
selectChildSingle =
  query $ select_ #local_parent_id (from $ table #child_single)

selectChildComposite :: Statement DB () ChildCompositeRow
selectChildComposite =
  query $ select_ #local_b (from $ table #child_composite)

selectChildCross :: Statement DB () ChildCrossRow
selectChildCross =
  query $ select_ #left_local (from $ table #child_cross)

selectSelfRef :: Statement DB () SelfRefRow
selectSelfRef =
  query $ select (#s ! #id `as` #self_id) (from $ table (#self_ref `as` #s))

run :: IO String
run = withDbCache $ \cache -> do
  e <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    setup <- BS8.readFile "test/ForeignKeyReferencedColumns/schemas/Public/structure.sql"
    withConnection connBS $ define (UnsafeDefinition setup)
    runSquealgenScript (BS8.unpack connBS) "ForeignKeyReferencedColumns.Generated" "public"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x
