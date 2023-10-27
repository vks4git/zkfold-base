{-# LANGUAGE TypeApplications    #-}

module Examples.MiMCHash (exampleMiMC) where

import           Prelude                                       hiding ((||), not, Num(..), Eq(..), (^), (/), (!!), any)

import           ZkFold.Base.Algebra.Basic.Class
import           ZkFold.Base.Algebra.Basic.Field               (Zp)
import           ZkFold.Base.Algebra.Polynomials.GroebnerBasis (fromR1CS)
import           ZkFold.Base.Protocol.Arithmetization.R1CS
import           ZkFold.Base.Data.Conditional                  (bool)
import           ZkFold.Prelude                                ((!!))

import           Examples.MiMC.Constants                       (mimcConstants)
import           Tests.Utility.Types                           (R, SmallField, Symbolic)

mimcHash :: forall a . Symbolic a => Integer -> a -> a -> a -> a
mimcHash nRounds k xL xR = 
    let c  = mimcConstants !! (nRounds-1)
        t5 = (xL + k + c) ^ (5 :: Integer)
    in bool (xR + t5) (mimcHash (nRounds-1) k (xR + t5) xL) (nRounds > 1)
          
exampleMiMC :: IO ()
exampleMiMC = do
    let nRounds = 220

    -- TODO: change the type application to build an arithmetization for the correct field
    let r = compile @(Zp SmallField) (mimcHash @R nRounds zero) :: R

    putStrLn "\nStarting MiMC test...\n"

    putStrLn "MiMC hash function"
    putStrLn "R1CS size:"
    putStrLn $ "Number of constraints: " ++ show (acSizeN r)
    putStrLn $ "Number of variables: " ++ show (acSizeM r)

    putStrLn "\nR1CS polynomials:\n"
    print $ fromR1CS r