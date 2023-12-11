{-# LANGUAGE TypeApplications #-}

module Main where

import           Prelude                                      hiding (Num(..), Fractional(..), length)

import           Tests.Arithmetization                       (specArithmetization)
import           Tests.Field                                 (specField)
import           Tests.GroebnerBasis                         (specGroebner)
import           Tests.Group                                 (specAdditiveGroup)

import           ZkFold.Base.Algebra.EllipticCurve.BLS12_381 (Fr, Fq, Fq2, Fq6, Fq12)
import           ZkFold.Base.Protocol.Commitment.KZG         (G1, G2)

main :: IO ()
main = do
    specField @Fr
    specField @Fq
    specField @Fq2
    specField @Fq6
    specField @Fq12
    specAdditiveGroup @G1
    specAdditiveGroup @G2
    specArithmetization
    specGroebner

    putStrLn "\nAll tests passed!"