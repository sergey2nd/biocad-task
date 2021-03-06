module SampleData
  ( randomReaction
  , randomMolecule
  , randomCatalyst
  , randomProductFrom
  , randomAccelerate
  , randomReactionData
  , putSampleData
  ) where

import Types
import Functions.TextRequest          (putReaction)

import Control.Applicative            (liftA2)
import Control.Monad                  (replicateM, forM_)
import Control.Monad.IO.Class         (liftIO)
import Data.Maybe                     (catMaybes)
import Database.Bolt                  
import System.Random                  (randomRIO)
import           Data.Text            (Text)
import qualified Data.Text    as T    (splitOn, lines)
import qualified Data.Text.IO as TIO  (readFile)
   


parseReaction :: Text -> Reaction
parseReaction = Reaction . Name

parseMolecule :: Text -> Maybe Molecule
parseMolecule txt = case T.splitOn "; " txt of
                      (smiles:iupacName:_) -> Just $ Molecule (Smiles smiles) (Name iupacName)
                      _                    -> Nothing

parseCatalyst :: Text -> Maybe Catalyst
parseCatalyst txt = case T.splitOn "; " txt of
                      []              -> Nothing
                      [smiles]        -> Just $ Catalyst (Smiles smiles) Nothing
                      (smiles:name:_) -> Just $ Catalyst (Smiles smiles) (Just $ Name name)

randomReaction :: IO Reaction
randomReaction = do
  input <- TIO.readFile "./SampleData/Reactions.csv"
  let lst = fmap parseReaction . tail . T.lines $ input
  randomListElement lst

randomMolecule :: IO Molecule
randomMolecule = do 
  input <- TIO.readFile "./SampleData/Molecules.csv"
  let lst = catMaybes . fmap parseMolecule . tail . T.lines $ input
  randomListElement lst

randomCatalyst :: IO Catalyst
randomCatalyst = do 
  input <- TIO.readFile "./SampleData/Catalysts.csv"
  let lst = catMaybes . fmap parseCatalyst . tail . T.lines $ input
  randomListElement lst

randomListElement :: [a] -> IO a
randomListElement lst = randomRIO (0,n) >>= pure . (lst !!)
  where n = length lst - 1

randomAccelerate :: IO ACCELERATE
randomAccelerate = do
  a'temperature <- (Temp . (/10). fromIntegral) <$> randomRIO (1,10000 :: Integer)
  a'pressure    <- (Pressure . (/10). fromIntegral) <$> randomRIO (1,100 :: Integer)
  pure ACCELERATE{..}

randomProductFrom :: IO PRODUCT_FROM
randomProductFrom = (PRODUCT_FROM . Amount . (/100) . fromIntegral) <$> randomRIO (1,10000 :: Integer)

randomReactionData :: IO ReactionData
randomReactionData = do
  reagentN  <- (ceiling . (*3)) <$> randomRIO (0.2, 0.8 :: Float)
  productN  <- (ceiling . (*3)) <$> randomRIO (0.2, 0.8 :: Float)
  catalystN <- (floor . (*3)) <$> randomRIO (0.3, 0.8 :: Float)
  rdReaction <- randomReaction
  rdReagents <- replicateM reagentN randomMolecule
  rdProducts <- replicateM productN $ liftA2 (,) randomMolecule randomProductFrom
  rdCatalyst <- replicateM catalystN $ liftA2 (,) randomCatalyst randomAccelerate
  pure ReactionData{..}

putSampleData :: Int -> BoltActionT IO ()
putSampleData n = do
  reacts <- liftIO $ replicateM n randomReactionData
  forM_ reacts $ \r -> do i <- putReaction r
                          liftIO $ print $ "Created reaction: Id " ++ show i
