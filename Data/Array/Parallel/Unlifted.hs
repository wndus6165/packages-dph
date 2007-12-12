-----------------------------------------------------------------------------
-- |
-- Module      : Data.Array.Parallel.Unlifted
-- Copyright   : (c) [2001..2002] Manuel M T Chakravarty & Gabriele Keller
--		 (c) [2006..2007] Manuel M T Chakravarty & Roman Leshchinskiy
-- License     : see libraries/ndp/LICENSE
-- 
-- Maintainer  : Roman Leshchinskiy <rl@cse.unsw.edu.au>
-- Stability   : experimental
-- Portability : portable
--
-- Description ---------------------------------------------------------------
--
-- External interface to unlifted arrays.
--
-- Todo ----------------------------------------------------------------------
-- 

module Data.Array.Parallel.Unlifted (

  -- * Array classes
  UA,

  -- * Array types
  UArr, USegd, SUArr,

  -- * Strict pairs and sums (reexported)
  (:*:)(..), fstS, sndS, uncurryS, curryS,

  -- * Basic operations
  lengthU, nullU, emptyU, singletonU, consU, unitsU, replicateU, (!:), (+:+),
  indexedU, repeatU,

  -- * Subarrays
  sliceU, extractU,
  tailU,
  takeU, dropU, splitAtU,
  {-takeWhileU, dropWhileU, spanU, breakU,-}

  -- * Permutations
  permuteU, bpermuteU, bpermuteDftU, reverseU, updateU,


  -- * Higher-order operations
  mapU, zipWithU, zipWith3U,
  filterU, filterFlagsU, 
  foldlU, foldl1U,
  {-foldrU, foldr1U,-}
  foldU, fold1U,
  scanlU, scanl1U,
  {-scanrU, scanr1U,-}
  scanU, scan1U,
  mapAccumLU,

  -- Segmented filter and combines
  filterSU,
  combineU, combineSU,

  -- * Searching
  elemU, notElemU,
  {-lookupU, indexOfU,-}

  -- * Logical operations
  andU, orU, anyU, allU,

  -- * Arithmetic operations
  sumU, productU,
  maximumU, minimumU,
  maximumByU, minimumByU,
  maximumIndexU, minimumIndexU,
  maximumIndexByU, minimumIndexByU,

  -- * Arrays of pairs
  zipU, zip3U, unzipU, unzip3U, fstU, sndU,
  {-crossU,-}

  -- * Enumerations
  enumFromToU, enumFromThenToU, enumFromStepLenU, enumFromToEachU,

  -- * Searching
  findU, findIndexU,

  -- * Conversions to\/from lists
  toU, fromU,

  -- * Unlifted arrays
  randomU, randomRU,

  -- * I\/O
  UIO(..),

  -- * Segmentation
  concatSU, flattenSU, (>:), segmentU, segmentArrU,

  -- * Basic operations (segmented)
  lengthSU, singletonSU, replicateSU, (+:+^),

  -- * Basic operations lifted
  lengthsSU, indicesSU,

  -- * Zipping (segmented)
  fstSU, sndSU, zipSU,

  -- * Permutations (segmented)
  bpermuteSU, bpermuteSU',

  -- * Higher-order operations (segmented)
  mapSU, zipWithSU,
  {-concatMapU,-}
  foldlSU, foldSU,
  fold1SU,
  {-scanSU, scan1SU,-}

  -- * Logical operations (segmented)
  andSU, orSU,

  -- * Arithmetic operations (segmented)
  sumSU, productSU, maximumSU, minimumSU,

  -- * Enumerations (segmented)
  enumFromToSU, enumFromThenToSU,

--  lines, words, unlines, unwords,  -- is string processing really needed

  -- * Conversions to\/from lists (segmented)
  toSU, fromSU,

  -- * Segment descriptors
  lengthsToUSegd, toUSegd,

  -- * Library id
  idstr, name, versnum, date, version, copyright, disclaimer,

  -- FIXME
  lengthU'

) where

import Data.Array.Parallel.Base.Hyperstrict
import Data.Array.Parallel.Unlifted.Flat
import Data.Array.Parallel.Unlifted.Segmented

-- version number is major.minor.patchlvl; don't change the format of the
-- `versnum' line as it is `grep'ed for by a Makefile
--
idstr      = "$Id: FIXME: Have the build-system produce an id$"
name       = "Unlifted Array Library"
versnum    = "0.6.0"
date	   = "28 Apr 2006"
version    = name ++ ", version " ++ versnum ++ ", " ++ date
copyright  = "Copyright (c) [2001..2006] \
	     \M M T Chakravarty, G Keller & R Leshchinskiy"
disclaimer = "This software is distributed under the terms \
	     \of the BSD3 license.  NO WARRANTY WHATSOEVER IS PROVIDED. \
	     \See the details in the documentation."


-- |Parallel array instances of standard classes
-- ---------------------------------------------

-- |
instance (Eq e, UA e) => Eq (UArr e) where
  a1 == a2 = lengthU a1 == lengthU a2 && foldlU cmp True (zipU a1 a2)
	     where
	       cmp r (e1 :*: e2) = e1 == e2 && r

-- |
instance (Eq e, UA e) => Eq (SUArr e) where
  a1 == a2 = flattenSU a1 == flattenSU a2

