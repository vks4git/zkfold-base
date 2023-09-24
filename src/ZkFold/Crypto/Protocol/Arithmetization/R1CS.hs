{-# LANGUAGE TypeApplications    #-}

module ZkFold.Crypto.Protocol.Arithmetization.R1CS (
        BigField,
        R1CS,
        r1csSizeN,
        r1csSizeM,
        r1csOptimize,
        r1csValue,
        r1csPrint
    ) where

import           Data.List                            (nub)
import           Data.Map                             hiding (null, map, foldr)
import           Prelude                              hiding (Num(..), (+), (^), product, length)
import           Text.Pretty.Simple                   (pPrint)

import           ZkFold.Crypto.Algebra.Basic.Class
import           ZkFold.Crypto.Algebra.Basic.Field
import           ZkFold.Crypto.Data.Symbolic          (Symbolic (..))
import           ZkFold.Prelude                       (length)
import ZkFold.Crypto.Data.Conditional (bool)

-- | A finite field with a large order.
-- It is used in the R1CS compiler for generating new variable indices.
--
-- TODO: move this elsewhere
data BigField
instance Finite BigField where
    order = 52435875175126190479447740508185965837690552500527637822603658699938581184513
instance Prime BigField

-- | A rank-1 constraint system (R1CS).
-- This type represents the result of a compilation of a function into a R1CS.
--
-- To compile a function @/f :: C a => a -> a/@, we must define an instance @/C (R1CS a)/@.
-- Keep in mind that the more type constraints we impose on the polymorphic argument @/a/@,
-- the broader the class of functions that can be compiled.
data R1CS a = R1CS
    {
        r1csMatrices :: Map Integer (Map Integer a, Map Integer a, Map Integer a),
        -- ^ The R1CS matrices
        r1csInput    :: [Integer],
        -- ^ The input variables
        r1csWitness  :: Map Integer a -> Map Integer a,
        -- ^ The witness generation function
        r1csOutput   :: [Integer]
        -- ^ The output variables
    }

-- | Calculates the number of constraints in the system.
r1csSizeN :: R1CS a -> Integer
r1csSizeN = length . r1csMatrices

-- | Calculates the number of variables in the system.
r1csSizeM :: R1CS a -> Integer
r1csSizeM r = length $ nub $ concatMap (keys . f) (elems $ r1csMatrices r)
    where f (a, b, c) = a `union` b `union` c

-- | Optimizes the constraint system.
--
-- TODO: Implement this.
r1csOptimize :: R1CS a -> R1CS a
r1csOptimize = undefined

r1csValue :: R1CS a -> [a]
r1csValue r =
    let w = r1csWitness r empty
        o = r1csOutput r
    in map (w !) o

-- | Prints the constraint system, the witness, and the output on a given input.
--
-- TODO: Move this elsewhere.
r1csPrint :: (Show a) => R1CS a -> IO ()
r1csPrint r = do
    let m = elems (r1csMatrices r)
        i = r1csInput r
        w = r1csWitness r empty
        o = r1csOutput r
        v = r1csValue r
    putStr "System size: "
    pPrint $ r1csSizeN r
    putStr "Variable size: "
    pPrint $ r1csSizeM r
    putStr "Matrices: "
    pPrint m
    putStr "Input: "
    pPrint i
    putStr "Witness: "
    pPrint w
    putStr "Output: "
    pPrint o
    putStr"Value: "
    pPrint v

------------------------------------- Instances -------------------------------------

instance Eq a => Semigroup (R1CS a) where
    -- The concatenation is left-biased.
    r1 <> r2 = R1CS
        {
            r1csMatrices =
                let m1 = elems $ r1csMatrices r1
                    m2 = elems $ r1csMatrices r2
                in fromList $ zip [0..] $ nub (m1 ++ m2),
            -- NOTE: is it possible that we get a wrong argument order when doing `eval` because of this concatenation?
            -- We need a way to ensure the correct order no matter how `(<>)` is used.
            r1csInput    = nub $ r1csInput r1 ++ r1csInput r2,
            r1csWitness  = \w -> r1csWitness r1 w `union` r1csWitness r2 w,
            r1csOutput   = r1csOutput r1
        }

instance (FiniteField a, Eq a) => Monoid (R1CS a) where
    mempty = R1CS
        {
            r1csMatrices = empty,
            r1csInput    = [],
            r1csWitness  = insert 0 one,
            r1csOutput   = []
        }

instance (FiniteField a, Eq a, ToBits a) => Symbolic (R1CS a) (R1CS a) where
    type ValueOf (R1CS a) = a

    type WitnessMap (R1CS a) (R1CS a) = [a] -> [a]

    type Constraint (R1CS a) (R1CS a) = Integer -> (Map Integer a, Map Integer a, Map Integer a)

    merge = (<>)

    -- TODO: forbid reassignment of variables
    assignment zs xs f r = r
        {
            r1csWitness = \i -> 
                let w  = r1csWitness r i
                    ys = map (w !) xs
                in fromList (zip zs (f ys)) `union` w
        }

    constraint con r =
        let x = r1csNewVariable (con $ -1)
        in r
        {
            r1csMatrices = insert (r1csSizeN r) (con x) (r1csMatrices r),
            r1csOutput   = [x]
        }

    input r =
        let ins = r1csInput r
            s   = if null ins then 1 else maximum (r1csInput r) + 1
        in r
        {
            r1csInput  = ins ++ [s],
            r1csOutput = [s]
        }

    extract = id

    -- TODO: make this safe
    apply r x =
        let ins = r1csInput r
        in r
        {
            r1csInput = tail ins,
            r1csWitness = r1csWitness r . insert (head ins) x
        }

    eval ctx =
        let w = r1csWitness ctx empty
            o = r1csOutput ctx
        in w ! head o

instance (FiniteField a) => Finite (R1CS a) where
    order = order @a

instance (FiniteField a, Eq a, ToBits a) => AdditiveSemigroup (R1CS a) where
    r1 + r2 =
        -- TODO: this should be extended to lists
        let r   = r1 <> r2
            x1  = head $ r1csOutput r1
            x2  = head $ r1csOutput r2
            con = \z -> (empty, empty, fromListWith (+) [(x1, one), (x2, one), (z, negate one)]) 
            r'  = constraint @(R1CS a) @(R1CS a) con r
        in assignment @(R1CS a) @(R1CS a) [head $ r1csOutput r'] [x1, x2] (\xs -> [Prelude.foldl (+) zero xs]) r'

instance (FiniteField a, Eq a, ToBits a) => AdditiveMonoid (R1CS a) where
    zero =
        let con = \z -> (empty, empty, fromList [(z, one)])
            r' = constraint @(R1CS a) @(R1CS a) con mempty
        in assignment @(R1CS a) @(R1CS a) [head $ r1csOutput r'] [] (const [zero]) r'

instance (FiniteField a, Eq a, ToBits a) => AdditiveGroup (R1CS a) where
    negate r =
        -- TODO: this should be extended to lists
        let x1 = head $ r1csOutput r
            con = \z -> (empty, empty, fromList [(x1, one), (z, one)])
            r' = constraint @(R1CS a) @(R1CS a) con r
        in assignment @(R1CS a) @(R1CS a) [head $ r1csOutput r'] [x1] (\xs -> [negate $ head xs]) r'

instance (FiniteField a, Eq a, ToBits a) => MultiplicativeSemigroup (R1CS a) where
    r1 * r2 =
        -- TODO: this should be extended to lists
        let r  = r1 <> r2
            x1 = head $ r1csOutput r1
            x2 = head $ r1csOutput r2
            con = \z -> (singleton x1 one, singleton x2 one, singleton z one)
            r' = constraint @(R1CS a) @(R1CS a) con r
        in assignment @(R1CS a) @(R1CS a) [head $ r1csOutput r'] [x1, x2] (\xs -> [Prelude.foldl (*) one xs]) r'

instance (FiniteField a, Eq a, ToBits a) => MultiplicativeMonoid (R1CS a) where
    one = mempty { r1csOutput = [0] }

instance (FiniteField a, Eq a, ToBits a) => MultiplicativeGroup (R1CS a) where
    invert r =
        -- TODO: this should be extended to lists
        let x1   = head $ r1csOutput r
            con  = \z -> (singleton x1 one, singleton z one, empty)
            r'   = constraint @(R1CS a) @(R1CS a) con r
            err  = head $ r1csOutput r'
            con' = \z -> (singleton x1 one, singleton z one, fromList [(0, one), (err, negate one)])
            r''   = constraint @(R1CS a) @(R1CS a) con' r'
        in assignment @(R1CS a) @(R1CS a) [head $ r1csOutput r'', err] [x1] (\xs -> let y = head xs in [invert y, bool zero one (y == zero)]) r''

instance (FiniteField a, Eq a, ToBits a, FromConstant b a) => FromConstant b (R1CS a) where
    fromConstant c =
        let x = fromConstant c
            con = \z -> (empty, empty, fromList [(0, x), (z, negate one)])
            r' = constraint @(R1CS a) @(R1CS a) con mempty
        in assignment @(R1CS a) @(R1CS a) [head $ r1csOutput r'] [] (const [x]) r'

------------------------------------- Internal -------------------------------------

-- TODO: Remove the hardcoded constant.
r1csNewVariable :: (Eq a, ToBits a) => (Map Integer a, Map Integer a, Map Integer a) -> Integer
r1csNewVariable (a, b, c) = g a + g b + g c
    where
        z         = toZp 891752917250912079751095709127490 :: Zp BigField
        f (x, y)  = multiExp z (map (toZp :: Integer -> Zp BigField) x) + multiExp z y
        g m       = fromZp $ f $ unzip $ toList m