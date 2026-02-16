module Main (main) where

import           Test.Tasty
import           Test.Tasty.Hspec

import qualified Arrays.DBSpec
import qualified Basic.DBSpec
import qualified CheckSchemaScript.DBSpec
import qualified Checks.DBSpec
import qualified ComplexPrimary.DBSpec
import qualified CompositeForeignKeys.DBSpec
import qualified Composites.DBSpec
import qualified Domains.DBSpec
import qualified EmptySchema.DBSpec
import qualified Enums.DBSpec
import qualified CrossSchemaEnums.DBSpec
import qualified CrossSchemaEnumComposites.DBSpec
import qualified Extensions.DBSpec
import qualified Functions.DBSpec
import qualified InetArrays.DBSpec
import qualified Members.DBSpec
import qualified NoConstraints.DBSpec
import qualified ForeignKeyReferencedColumns.DBSpec
import qualified Property.DDLSpec
import qualified Property.DDLHarnessSpec
import qualified Views.DBSpec
import qualified PgCatalog.DBSpec
import qualified SearchPathFragments.DBSpec
import qualified Triggers.DBSpec

main :: IO ()
main = do
  hspecTrees <- sequence
    [ testSpec "Arrays.DB" Arrays.DBSpec.spec
    , testSpec "Basic.DB" Basic.DBSpec.spec
    , testSpec "Checks.DB" Checks.DBSpec.spec
    , testSpec "CheckSchemaScript.DB" CheckSchemaScript.DBSpec.spec
    , testSpec "SearchPathFragments.DB" SearchPathFragments.DBSpec.spec
    , testSpec "ComplexPrimary.DB" ComplexPrimary.DBSpec.spec
    , testSpec "CompositeForeignKeys.DB" CompositeForeignKeys.DBSpec.spec
    , testSpec "Composites.DB" Composites.DBSpec.spec
    , testSpec "Domains.DB" Domains.DBSpec.spec
    , testSpec "EmptySchema.DB" EmptySchema.DBSpec.spec
    , testSpec "Enums.DB" Enums.DBSpec.spec
    , testSpec "CrossSchemaEnums.DB" CrossSchemaEnums.DBSpec.spec
    , testSpec "CrossSchemaEnumComposites.DB" CrossSchemaEnumComposites.DBSpec.spec
    , testSpec "Extensions.DB" Extensions.DBSpec.spec
    , testSpec "Functions.DB" Functions.DBSpec.spec
    , testSpec "InetArrays.DB" InetArrays.DBSpec.spec
    , testSpec "Members.DB" Members.DBSpec.spec
    , testSpec "NoConstraints.DB" NoConstraints.DBSpec.spec
    , testSpec "ForeignKeyReferencedColumns.DB" ForeignKeyReferencedColumns.DBSpec.spec
    , testSpec "Property.DDLHarness" Property.DDLHarnessSpec.spec
    , testSpec "Views.DB" Views.DBSpec.spec
    , testSpec "PgCatalog.DB" PgCatalog.DBSpec.spec
    , testSpec "Triggers.DB" Triggers.DBSpec.spec
    ]
  defaultMain $ testGroup "tests" (hspecTrees ++ [Property.DDLSpec.testTree])
