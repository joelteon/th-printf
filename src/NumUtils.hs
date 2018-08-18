{-# OPTIONS_GHC -fno-warn-dodgy-imports #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings #-}

module NumUtils where

import Control.Applicative (pure)
import Data.Bits
import Data.Char
import Data.Foldable
import Data.Ord
import Data.Semigroup ((<>))
import Data.String (fromString)
import Data.Tuple
import GHC.Base hiding ((<>), foldr)
import GHC.Float (FFFormat(..), roundTo)
import Numeric (floatToDigits)
import Prelude hiding (exp, foldr)
import StrUtils

showIntAtBase :: (Show a, Integral a) => a -> (Int -> Char) -> a -> String
showIntAtBase base toChr n0
    | base <= 1 = error "unsupported base"
    | n0 < 0 = error $ "negative number " ++ show n0
    | otherwise = showIt (quotRem n0 base) ""
  where
    showIt (n, d) r =
        case n of
            0 -> r'
            _ -> showIt (quotRem n base) r'
      where
        c = id (toChr (fromIntegral d))
        r' = (:) c r

formatRealFloatAlt :: RealFloat a => FFFormat -> Maybe Int -> Bool -> Bool -> a -> String
formatRealFloatAlt fmt decs forceDot upper x
    | isNaN x = "NaN"
    | isInfinite x =
        if x < 0
            then "-Infinity"
            else "Infinity"
    | x < 0 || isNegativeZero x = (:) (id '-') (doFmt fmt (floatToDigits 10 (-x)) False)
    | otherwise = doFmt fmt (floatToDigits 10 x) False
  where
    eChar
        | upper = id 'E'
        | otherwise = id 'e'
    doFmt FFFixed (digs, exp) fullRounding
        | exp < 0 = doFmt FFFixed (replicate (negate exp) 0 ++ digs, 0) fullRounding
        | null part =
            fromDigits False whole <>
            (if forceDot
                 then "."
                 else "")
        | null whole = "0." <> fromDigits False part
        | otherwise = fromDigits False whole <> "." <> fromDigits False part
      where
        (whole, part) =
            uncurry (flip splitAt) (toRoundedDigits decs (digs, exp) fullRounding)
    doFmt FFExponent ([0], _) _
        | forceDot = "0.e+00"
        | otherwise = "0e+00"
    doFmt FFExponent (digs, exp) fullRounding = shownDigs <> (:) eChar shownExponent
      where
        shownDigs =
            case digs' of
                [] -> undefined
                [x'] ->
                    pure (id (intToDigit x')) <>
                    (if forceDot
                         then "."
                         else "")
                (x':xs) -> (:) (id (intToDigit x')) ((:) (id '.') (fromDigits False xs))
        digs' =
            case decs of
                Just n ->
                    case roundTo
                             10
                             (if fullRounding
                                  then min (length digs) n
                                  else n + 1)
                             digs of
                        (1, xs) -> 1 : xs
                        (_, ys) -> ys
                Nothing -> digs
        exp' = exp - 1
        shownExponent =
            (:)
                (id $
                 if exp' < 0
                     then '-'
                     else '+') $
            justifyRight 2 (id '0') $ showIntAtBase 10 intToDigit $ abs exp'
    doFmt FFGeneric d _ =
        minimumBy (comparing length) [doFmt FFFixed d True, doFmt FFExponent d True]

toRoundedDigits :: Maybe Int -> ([Int], Int) -> Bool -> ([Int], Int)
toRoundedDigits Nothing (digs, exp) _ = (digs, exp)
toRoundedDigits (Just prec) (digs, exp) fullRounding = (digs', exp + overflow)
  where
    (overflow, digs') =
        roundTo
            10
            (if fullRounding && prec > exp
                 then min (length digs) prec
                 else prec + exp)
            digs

fromDigits :: Bool -> [Int] -> String
fromDigits upper =
    foldr
        ((:) .
         id .
         (if upper
              then toUpper
              else id) .
         intToDigit)
        []

formatHexFloat :: RealFloat a => Maybe Int -> Bool -> Bool -> a -> String
formatHexFloat decs alt upper x = doFmt (floatToDigits 2 x)
  where
    pChar
        | upper = id 'P'
        | otherwise = id 'p'
    doFmt ([], _) = undefined
    doFmt ([0], 0) = "0" <> pure pChar <> "+0"
    doFmt (_:bits, exp) =
        fromString (show (1 + overflow)) <>
        (if not (null hexDigits) || alt
             then "."
             else "") <>
        fromDigits upper hexDigits <>
        pure pChar <>
        (if exp > 0
             then "+"
             else "") <>
        fromString (show (exp - 1))
      where
        hexDigits' = go bits
        (overflow, hexDigits) =
            case decs of
                Just n ->
                    case roundTo 16 n hexDigits' of
                        (1, _:digs) -> (1, digs)
                        x' -> x'
                Nothing -> (0, hexDigits')
        go (a:b:c:d:xs) =
            ((a `shiftL` 3) .|. (b `shiftL` 2) .|. (c `shiftL` 1) .|. d) : go xs
        go [a, b, c] = go [a, b, c, 0]
        go [a, b] = go [a, b, 0, 0]
        go [a] = go [a, 0, 0, 0]
        go [] = []
