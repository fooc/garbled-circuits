module Main where

import System.Environment
import Data.Word

import Crypto.GarbledCircuits
import Crypto.GarbledCircuits.Util (word2Bits, bits2Word)

import Example.Adder

main :: IO ()
main = do
    args <- getArgs
    let port  = read (args !! 1)
        input = word2Bits (read (args !! 2) :: Word8)
    result <- garblerProto port circ_8BitAdder input
    print (bits2Word result :: Word8)