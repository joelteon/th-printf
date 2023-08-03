{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module Buf (Buf (..), SizedStr, SizedBuilder, SizedStrictBuilder) where

import Data.Char (intToDigit)
import Data.Coerce
import qualified Data.DList as D
import Data.Kind (Type)
import Data.String
import qualified Data.Text as S
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as L
import qualified Data.Text.Lazy.Builder as T
import qualified Data.Text.Lazy.Builder.Int as T

newtype Sized a = Sized {unSized :: (a, Int)} deriving (Show, Ord, Eq)

newtype StrictBuilder = StrictBuilder {unStrictBuilder :: T.Builder}
  deriving (Eq, Ord, Show, IsString, Semigroup, Monoid)

type SizedStr = Sized (D.DList Char)
type SizedBuilder = Sized T.Builder
type SizedStrictBuilder = Sized StrictBuilder

instance (IsString a) => IsString (Sized a) where
  fromString s = Sized (fromString s, length s)

instance (Semigroup a) => Semigroup (Sized a) where
  Sized (a, b) <> Sized (c, d) = Sized (a <> c, b + d)
  {-# INLINE (<>) #-}

instance (Monoid a) => Monoid (Sized a) where
  mempty = Sized (mempty, 0)
  mappend = (<>)
  {-# INLINE mappend #-}

class (Monoid a) => Buf a where
  type Output a :: Type

  str :: String -> a

  sText :: S.Text -> a
  sText = str . S.unpack
  lText :: L.Text -> a
  lText = str . L.unpack

  singleton :: Char -> a
  digit :: Int -> a
  digit = singleton . intToDigit
  {-# INLINE digit #-}

  cons :: Char -> a -> a
  cons c s = singleton c <> s
  {-# INLINE cons #-}

  repeatN :: Int -> Char -> a
  repeatN n = str . replicate n

  size :: a -> Int

  finalize :: a -> Output a

instance Buf SizedStr where
  type Output SizedStr = String
  str a = Sized (D.fromList a, length a)
  singleton c = Sized (D.singleton c, 1)
  finalize = D.toList . fst . unSized
  cons c (Sized (r, m)) = Sized (D.cons c r, m + 1)
  repeatN n c = Sized (D.replicate n c, n)
  size = snd . unSized

instance Buf SizedBuilder where
  type Output SizedBuilder = Text
  str a = Sized (fromString a, length a)
  sText a = Sized (T.fromText a, S.length a)
  lText a = Sized (T.fromLazyText a, fromIntegral (L.length a))
  singleton c = Sized (T.singleton c, 1)
  digit c = Sized (T.hexadecimal c, 1)
  finalize = T.toLazyText . fst . unSized
  size = snd . unSized

instance Buf SizedStrictBuilder where
  type Output SizedStrictBuilder = S.Text
  str = coerce $ str @SizedBuilder
  sText = coerce $ sText @SizedBuilder
  lText = coerce $ lText @SizedBuilder
  singleton = coerce $ singleton @SizedBuilder
  digit = coerce $ digit @SizedBuilder
  finalize = L.toStrict . coerce (finalize @SizedBuilder)
  size = coerce $ size @SizedBuilder
