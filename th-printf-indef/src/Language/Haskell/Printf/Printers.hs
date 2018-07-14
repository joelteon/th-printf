{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}

module Language.Haskell.Printf.Printers where

import Control.Monad
import Data.Bool
import Data.Char
import Data.String (fromString)
import GHC.Float (FFFormat(..))
import Language.Haskell.Printf.Geometry
import Language.Haskell.PrintfArg
import NumUtils
import Numeric.Natural
import Parser.Types (Adjustment(..))
import qualified Str as S

type Printer n = PrintfArg n -> Value

printfString :: Printer S.Str
printfString spec =
    Value
        { valArg =
              case prec spec of
                  Nothing -> spec
                  Just c -> S.take c <$> spec
        , valPrefix = Nothing
        , valSign = Nothing
        }

printfChar spec =
    Value {valArg = S.singleton <$> spec, valPrefix = Nothing, valSign = Nothing}

printfDecimal :: (Integral a, Show a) => Printer a
printfDecimal spec =
    Value
        { valArg = padDecimal spec . showIntAtBase 10 intToDigit . abs <$> spec
        , valPrefix = Nothing
        , valSign = sign' spec
        }

fmtUnsigned ::
       forall a. (Bounded a, Integral a, Show a)
    => (Integer -> S.Str)
    -> (PrintfArg a -> Maybe S.Str)
    -> Printer a
fmtUnsigned shower p spec =
    Value
        { valArg = padDecimal spec . shower . clamp <$> spec
        , valPrefix = p spec
        , valSign = Nothing
        }
  where
    lb = minBound :: a
    clamp :: a -> Integer
    clamp x
        | x < 0 = toInteger x + (-2 * toInteger lb)
        | otherwise = toInteger x

printfUnsigned = fmtUnsigned (showIntAtBase 10 intToDigit) (const Nothing)

printfHex b = fmtUnsigned showHex (prefix (bool "0x" "0X" b))
  where
    showHex =
        showIntAtBase
            16
            ((if b
                  then toUpper
                  else id) .
             intToDigit)

printfOctal spec
    | "0" `S.isPrefixOf` value valArg = v
    | otherwise = v {valPrefix = prefix "0" spec}
  where
    showOctal = showIntAtBase 8 intToDigit
    v@Value {..} = fmtUnsigned showOctal (const Nothing) spec

printfFloating upperFlag spec =
    Value {valArg = showFloat . abs <$> spec, valPrefix = Nothing, valSign = sign' spec}
  where
    precision =
        case prec spec of
            Just n -> Just (fromIntegral n)
            Nothing
                | Just ZeroPadded <- adjustment spec -> Just 6
            _ -> Nothing
    showFloat = formatRealFloatAlt FFFixed precision (prefixed spec) upperFlag

printfScientific upperFlag spec =
    Value {valArg = showSci . abs <$> spec, valPrefix = Nothing, valSign = sign' spec}
  where
    showSci =
        formatRealFloatAlt
            FFExponent
            (fromIntegral <$> prec spec)
            (prefixed spec)
            upperFlag

printfGeneric upperFlag spec =
    Value {valArg = showSci . abs <$> spec, valPrefix = Nothing, valSign = sign' spec}
  where
    showSci =
        formatRealFloatAlt
            FFGeneric
            (fromIntegral <$> prec spec)
            (prefixed spec)
            upperFlag

printfFloatHex upperFlag spec =
    Value
        { valArg = showHexFloat . abs <$> spec
        , valPrefix = Just (bool "0x" "0X" upperFlag)
        , valSign = sign' spec
        }
  where
    showHexFloat = formatHexFloat (fromIntegral <$> prec spec) (prefixed spec) upperFlag
