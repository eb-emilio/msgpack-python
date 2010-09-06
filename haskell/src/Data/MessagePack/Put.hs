{-# Language FlexibleInstances #-}
{-# Language IncoherentInstances #-}
{-# Language OverlappingInstances #-}

--------------------------------------------------------------------
-- |
-- Module    : Data.MessagePack.Put
-- Copyright : (c) Hideyuki Tanaka, 2009-2010
-- License   : BSD3
--
-- Maintainer:  tanaka.hideyuki@gmail.com
-- Stability :  experimental
-- Portability: portable
--
-- MessagePack Serializer using @Data.Binary.Put@
--
--------------------------------------------------------------------

module Data.MessagePack.Put(
  -- * Serializable class
  ObjectPut(..),
  ) where

import Data.Binary.Put
import Data.Binary.IEEE754
import Data.Bits
import qualified Data.ByteString as B
import qualified Data.Vector as V

import Data.MessagePack.Object

-- | Serializable class
class ObjectPut a where
  -- | Serialize a value
  put :: a -> Put

instance ObjectPut Object where
  put = putObject

instance ObjectPut Int where
  put = putInteger

instance ObjectPut () where
  put _ = putNil

instance ObjectPut Bool where
  put = putBool

instance ObjectPut Double where
  put = putDouble

instance ObjectPut B.ByteString where
  put = putRAW

instance ObjectPut a => ObjectPut [a] where
  put = putArray

instance ObjectPut a => ObjectPut (V.Vector a) where
  put = putArrayVector

instance (ObjectPut k, ObjectPut v) => ObjectPut [(k, v)] where
  put = putMap

instance (ObjectPut k, ObjectPut v) => ObjectPut (V.Vector (k, v)) where
  put = putMapVector

putObject :: Object -> Put
putObject obj =
  case obj of
    ObjectInteger n ->
      putInteger n
    ObjectNil ->
      putNil
    ObjectBool b ->
      putBool b
    ObjectDouble d ->
      putDouble d
    ObjectRAW raw ->
      putRAW raw
    ObjectArray arr ->
      putArray arr
    ObjectMap m ->
      putMap m

putInteger :: Int -> Put      
putInteger n =
  case n of
    _ | n >= 0 && n <= 127 ->
      putWord8 $ fromIntegral n
    _ | n >= -32 && n <= -1 ->
      putWord8 $ fromIntegral n
    _ | n >= 0 && n < 0x100 -> do
      putWord8 0xCC
      putWord8 $ fromIntegral n
    _ | n >= 0 && n < 0x10000 -> do
      putWord8 0xCD
      putWord16be $ fromIntegral n
    _ | n >= 0 && n < 0x100000000 -> do
      putWord8 0xCE
      putWord32be $ fromIntegral n
    _ | n >= 0 -> do
      putWord8 0xCF
      putWord64be $ fromIntegral n
    _ | n >= -0x80 -> do
      putWord8 0xD0
      putWord8 $ fromIntegral n
    _ | n >= -0x8000 -> do
      putWord8 0xD1
      putWord16be $ fromIntegral n
    _ | n >= -0x80000000 -> do
      putWord8 0xD2
      putWord32be $ fromIntegral n
    _ -> do
      putWord8 0xD3
      putWord64be $ fromIntegral n

putNil :: Put
putNil = putWord8 0xC0

putBool :: Bool -> Put
putBool True = putWord8 0xC3
putBool False = putWord8 0xC2

putDouble :: Double -> Put
putDouble d = do
  putWord8 0xCB
  putFloat64be d

putRAW :: B.ByteString -> Put
putRAW bs = do
  case len of
    _ | len <= 31 -> do
      putWord8 $ 0xA0 .|. fromIntegral len
    _ | len < 0x10000 -> do
      putWord8 0xDA
      putWord16be $ fromIntegral len
    _ -> do
      putWord8 0xDB
      putWord32be $ fromIntegral len
  putByteString bs
  where
    len = B.length bs

putArray :: ObjectPut a => [a] -> Put
putArray arr = do
  case len of
    _ | len <= 15 ->
      putWord8 $ 0x90 .|. fromIntegral len
    _ | len < 0x10000 -> do
      putWord8 0xDC
      putWord16be $ fromIntegral len
    _ -> do
      putWord8 0xDD
      putWord32be $ fromIntegral len
  mapM_ put arr
  where
    len = length arr

putArrayVector :: ObjectPut a => V.Vector a -> Put
putArrayVector arr = do
  case len of
    _ | len <= 15 ->
      putWord8 $ 0x90 .|. fromIntegral len
    _ | len < 0x10000 -> do
      putWord8 0xDC
      putWord16be $ fromIntegral len
    _ -> do
      putWord8 0xDD
      putWord32be $ fromIntegral len
  V.mapM_ put arr
  where
    len = V.length arr

putMap :: (ObjectPut k, ObjectPut v) => [(k, v)] -> Put
putMap m = do
  case len of
    _ | len <= 15 ->
      putWord8 $ 0x80 .|. fromIntegral len
    _ | len < 0x10000 -> do
      putWord8 0xDE
      putWord16be $ fromIntegral len
    _ -> do
      putWord8 0xDF
      putWord32be $ fromIntegral len
  mapM_ (\(k, v) -> put k >> put v) m
  where
    len = length m

putMapVector :: (ObjectPut k, ObjectPut v) => V.Vector (k, v) -> Put
putMapVector m = do
  case len of
    _ | len <= 15 ->
      putWord8 $ 0x80 .|. fromIntegral len
    _ | len < 0x10000 -> do
      putWord8 0xDE
      putWord16be $ fromIntegral len
    _ -> do
      putWord8 0xDF
      putWord32be $ fromIntegral len
  V.mapM_ (\(k, v) -> put k >> put v) m
  where
    len = V.length m