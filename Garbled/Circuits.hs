{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Garbled.Circuits where

import Garbled.Circuits.Garbler
import Garbled.Circuits.Types
import Garbled.Circuits.Util (violentLookup, bindM2, err, bits2Word, word2Bits)
import Garbled.Circuits.Plaintext.Language
import Garbled.Circuits.Plaintext.TruthTable

import Control.Applicative
import Control.Monad
import Data.Word

-- circuit language - done
-- intermediate TruthTable representation - done
-- garbled circuit representation - done
-- garbling - in progress - add testing
-- ot
-- evaluation

--------------------------------------------------------------------------------
-- garble

garble :: Program Circ -> IO (Program GarbledGate, AllTheThings)
garble = tt2gg . circ2tt

--------------------------------------------------------------------------------
-- id example

-- implement circ_add2 directly
circ_why :: CircBuilder [Ref Circ]
circ_why = do
  [in0,in1,in2,in3] <- replicateM 4 c_input
  false <- c_const False

  {-(out0, c0) <- add1Bit in0 in1 false-}
  tmp0 <- c_xor in0 in2
  out0 <- c_xor false tmp0
  c0   <- bindM2 c_or (c_and in0 in2) (c_and false out0)

  {-(out1, c1) <- add1Bit out0 in2 c0-}
  tmp1 <- c_xor in1 in3
  out1 <- c_xor c0 tmp1
  {-c1   <- bindM2 c_or (c_and in1 in3) (c_and false out1)-}

  return [out1, out0]


circ_add1 :: CircBuilder [Ref Circ]
circ_add1 = do
  in0 <- c_input
  in1 <- c_input
  in2 <- c_input
  in3 <- c_input
  false <- c_const False
  (out0, c0) <- add1Bit in0 in1 false
  (out1, c1) <- add1Bit out0 in2 c0
  out2 <- c_and in3 out1
  out3 <- c_not out2
  out4 <- c_or out1 out3
  return [out0, out1, c1, out2, out4]

circ_add2 :: CircBuilder [Ref Circ]
circ_add2 = do
  in0 <- c_input
  in1 <- c_input
  in2 <- c_input
  in3 <- c_input
  false <- c_const False
  (out0, c0) <- add1Bit in0 in2 false
  (out1, c1) <- add1Bit in1 in3 c0
  return [out1, out0]

evalCircGG :: CircBuilder [Ref Circ] -> [Bool] -> IO [Bool]
evalCircGG c xs = evalGG xs =<< garble (buildCirc c)

--------------------------------------------------------------------------------
-- 8 bit adder example

add1Bit :: Ref Circ -> Ref Circ -> Ref Circ -> CircBuilder (Ref Circ, Ref Circ)
add1Bit x y c = do
    s    <- c_xor x y
    out  <- c_xor c s
    cout <- bindM2 c_or (c_and x y) (c_and c s)
    return (out, cout)

addBits :: [Ref Circ] -> [Ref Circ] -> CircBuilder ([Ref Circ], Ref Circ)
addBits xs ys = do
    f <- c_const False
    builder xs ys f []
  where
    builder [] []         c outs = return (outs, c)
    builder (x:xs) (y:ys) c outs = do
      (out,c') <- add1Bit x y c
      builder xs ys c' (out:outs)
    builder xs ys _ _ = err "builder" ("lists of unequal length: " ++ show [xs,ys])

circ_NBitAdder :: Int -> Program Circ
circ_NBitAdder n = buildCirc $ do
    inp1      <- replicateM n c_input
    inp2      <- replicateM n c_input
    (outs, _) <- addBits inp1 inp2
    return outs

circ_8BitAdder :: Program Circ
circ_8BitAdder = circ_NBitAdder 8

eval_2BitAdder :: (Bool, Bool) -> (Bool, Bool) -> IO [Bool]
eval_2BitAdder (x0,x1) (y0,y1) = evalCirc (circ_NBitAdder 2) [x0,x1,y0,y1]

eval_2BitAdderGG :: (Bool, Bool) -> (Bool, Bool) -> IO [Bool]
eval_2BitAdderGG (x0,x1) (y0,y1) = do
  gg <- garble (circ_NBitAdder 2)
  evalGG [x0,x1,y0,y1] gg

eval_8BitAdder :: Word8 -> Word8 -> IO Word8
eval_8BitAdder x y = bits2Word <$> result
  where
    result = evalCirc circ_8BitAdder (word2Bits x ++ word2Bits y)

-- convert to TruthTable and use TruthTable evaluator
eval_8BitAdderTT :: Word8 -> Word8 -> IO Word8
eval_8BitAdderTT x y = bits2Word <$> result
  where
    result = evalTT (circ2tt circ_8BitAdder) (word2Bits x ++ word2Bits y)

-- convert to GarbledGate and use GG evaluator
eval_8BitAdderGG :: Word8 -> Word8 -> IO Word8
eval_8BitAdderGG x y = do
    gg <- garble circ_8BitAdder
    result <- evalGG (word2Bits x ++ word2Bits y) gg
    return (bits2Word result)
