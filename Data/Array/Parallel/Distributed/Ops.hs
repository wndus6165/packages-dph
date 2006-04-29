-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Array.Parallel.Distributed.Ops
-- Copyright   :  (c) 2006 Roman Leshchinskiy
-- License     :  see libraries/base/LICENSE
-- 
-- Maintainer  :  Roman Leshchinskiy <rl@cse.unsw.edu.au>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- Parallel operations on distributed types.
--


module Data.Array.Parallel.Distributed.Ops (
  mapDT, mapM_DT, mapM_DT_, zipWithDT, zipWithM_DT, zipWithM_DT_,
  replicateDT, foldDT, scanDT,

  splitDT, joinDT
) where

import Data.Array.Parallel.Distributed.Types
import Data.Array.Parallel.Distributed.Gang
import Data.Array.Parallel.Monadic.UArr
import Data.Array.Parallel.Base.Hyperstrict

import Control.Monad.ST                     ( ST, runST )
import Monad                                ( liftM, zipWithM )

here s = "Distributed.Ops." ++ s

-- | Yields a 'Dist' with the same value in every position.
replicateDT :: MDT a => Gang -> a -> ST s (Dist a)
replicateDT g x = x `seq` runDST (seqGang g) (return x)

-- | Map a distributed value on the given 'Gang'.
mapDT :: (DT a, MDT b) => Gang -> (a -> b) -> Dist a -> ST s (Dist b)
mapDT g f d = checkGangDT (here "mapDT") g d $
              runDST g (myDT d >>= return . f)

-- | Map an 'ST' computation over a distributed value.
mapM_DT :: (DT a, MDT b) => Gang -> (a -> ST s b) -> Dist a -> ST s (Dist b)
mapM_DT g f d = checkGangDT (here "mapST_DT") g d $
                 runDST g (myDT d >>= liftST . f)

-- | Man an 'ST' computation which does not produce a result over a
-- distributed value.
mapM_DT_ :: DT a => Gang -> (a -> ST s ()) -> Dist a -> ST s ()
mapM_DT_ g f d = checkGangDT (here "mapST_DT_") g d $
                  runDST_ g (myDT d >>= liftST . f)

-- | Zip the distributed values with the given function.
zipWithDT :: (DT a, DT b, MDT c)
          => Gang -> (a -> b -> c) -> Dist a -> Dist b -> ST s (Dist c)
zipWithDT g f dx dy = mapDT g (uncurryS f) (zipDT dx dy)

-- | Zip two distributed values with an 'ST' computation.
zipWithM_DT :: (DT a, DT b, MDT c)
            => Gang -> (a -> b -> ST s c) -> Dist a -> Dist b -> ST s (Dist c)
zipWithM_DT g f dx dy = mapM_DT g (uncurryS f) (zipDT dx dy)

-- | Zip two distributed values with an 'ST' computation which does not
-- produce a result.
zipWithM_DT_ :: (DT a, DT b)
            => Gang -> (a -> b -> ST s ()) -> Dist a -> Dist b -> ST s ()
zipWithM_DT_ g f dx dy = mapM_DT_ g (uncurryS f) (zipDT dx dy)

-- | Folds a distributed value.
--
-- /TODO:/ The current implementation is sequential.
foldDT :: MDT a => Gang -> (a -> a -> a) -> Dist a -> ST s a
foldDT g f d = checkGangDT (here "foldDT") g d .
               return . foldl1 f $ fromDT g d

-- | Scans a distributed value, yielding the result of the scan and the sum of
-- all elements.
--
-- /TODO:/ The current implementation is sequential.
scanDT :: MDT a => Gang -> (a -> a -> a) -> a -> Dist a -> ST s (Dist a :*: a)
scanDT g f z d = checkGangDT (here "scanDT") g d $
  let xs = scanl f z (fromDT g d)
  in
  liftM (:*: last xs) (toDT g xs)

-- | Split the length of an array over the given number of threads.
splitLen :: Int   -- | Number of threads
         -> Int   -- | Array length
         -> [Int]
splitLen p n =
  let l = n `div` p
      m = n `mod` p
  in
  replicate m (l+1) ++ replicate (p-m) l

-- | Distribute the length of an array over a 'Gang'.
splitLenDT :: Gang -> Int -> ST s (Dist Int)
splitLenDT g = toDT g . splitLen (gangSize g)

-- | Distribute an array over a 'Gang'.
splitDT :: UA a => Gang -> UArr a -> ST s (Dist (UArr a))
splitDT g arr =
  do
    dlen       <- splitLenDT g (lengthU arr)
    (is :*: _) <- scanDT g (+) 0 dlen
    zipWithDT (seqGang g) (sliceU arr) is dlen

-- | Join a distributed array.
joinDT :: UA a => Gang -> Dist (UArr a) -> ST s (UArr a)
joinDT g darr = checkGangDT (here "joinDT") g darr $
  do
    (is :*: n) <- scanDT g (+) 0 $ lengthsDT darr
    marr <- newMU n
    zipWithM_DT_ g (copyMU marr) is darr
    unsafeFreezeMU marr n

-- | Generate a distributed value from the first @p@ elements of a list.
-- 
-- /NOTE:/ Temporary, will be removed.
toDT :: MDT a => Gang -> [a] -> ST s (Dist a)
toDT g xs = do
              mdt <- newMDT g
              zipWithM (writeMDT mdt) [0 .. gangSize g - 1] xs
              freezeMDT mdt

-- | Yield all elements of a distributed value.
--
-- /NOTE:/ Temporary, will be removed.
fromDT :: DT a => Gang -> Dist a -> [a]
fromDT g dt = checkGangDT (here "fromDT") g dt $
              map (indexDT dt) [0 .. gangSize g - 1]

