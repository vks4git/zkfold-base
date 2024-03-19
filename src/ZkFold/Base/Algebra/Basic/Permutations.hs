{-# LANGUAGE TypeApplications #-}

module ZkFold.Base.Algebra.Basic.Permutations (
    IndexSet,
    IndexPartition,
    Permutation,
    fromPermutation,
    applyPermutation,
    mkIndexPartition,
    fromCycles
) where

import           Data.Map                        (Map, elems, empty, singleton, union)
import           Data.Maybe                      (fromJust)
import           Numeric.Natural                 (Natural)
import           Prelude                         hiding (Num (..), drop, length, (!!))
import           Test.QuickCheck                 (Arbitrary (..))

import           ZkFold.Base.Algebra.Basic.Class
import           ZkFold.Base.Data.Vector         (Vector (..), fromVector, toVector)
import           ZkFold.Prelude                  (chooseNatural, drop, elemIndex, length, (!!))

-- TODO (Issue #18): make the code safer

------------------------------ Index sets and partitions -------------------------------------

type IndexSet = [Natural]
type IndexPartition a = Map a IndexSet

mkIndexPartition :: Ord a => [a] -> IndexPartition a
mkIndexPartition vs =
    let f i = singleton i $ map snd $ filter (\(v, _) -> v == i) $ zip vs [1 .. length vs]
    in foldl union empty $ map f vs

------------------------------------- Permutations -------------------------------------------

newtype Permutation n = Permutation (Vector n Natural)
    deriving (Show, Eq)

instance Finite n => Arbitrary (Permutation n) where
    arbitrary =
        let f as [] = return as
            f as bs = do
                i <- chooseNatural (0, length bs - 1)
                let as' = (bs !! i) : as
                    bs' = drop i bs
                f as' bs'
        in Permutation . Vector <$> f [] [1..order @n]

fromPermutation :: Permutation n -> [Natural]
fromPermutation (Permutation perm) = fromVector perm

applyPermutation :: Permutation n -> Vector n a -> Vector n a
applyPermutation (Permutation (Vector ps)) (Vector as) = Vector $ map (as !!) ps

applyCycle :: IndexSet -> Permutation n -> Permutation n
applyCycle c (Permutation perm) = Permutation $ fmap f perm
    where
        f :: Natural -> Natural
        f i = case i `elemIndex` c of
            Just j  -> c !! ((j + 1) `mod` length c)
            Nothing -> i

fromCycles :: Finite n => IndexPartition a -> Permutation n
fromCycles p =
    let n = length $ concat $ elems p
    in foldr applyCycle (Permutation $ fromJust $ toVector [1 .. n]) $ elems p

