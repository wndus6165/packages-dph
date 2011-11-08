{-# LANGUAGE UndecidableInstances, ParallelListComp #-}
-- Undeciable instances only need for derived Show instance

#include "fusion-phases.h"

module Data.Array.Parallel.PArray.PData.Base 
        ( -- * Parallel Array types.
          PArray(..)
        , length, takeData
        , PprPhysical (..), PprVirtual (..)

        , PR (..)
        , PData(..), PDatas(..)
        , uextracts)
where
import Data.Array.Parallel.Pretty
import GHC.Exts
import SpecConstr
import Data.Vector                              (Vector)
import Data.Array.Parallel.Base                 (Tag)
import qualified Data.Array.Parallel.Unlifted   as U
import qualified Data.Vector                    as V
import qualified Data.Vector.Unboxed            as VU
import Prelude hiding (length)

-- PArray ---------------------------------------------------------------------
-- | A parallel array. 
--   PArrays always contain a finite (sized) number of elements, which means
--   they have a length.
--
--   IMPORTANT: 
--    The vectoriser requires the data constructor to have this specific form,
--    because it builds them explicitly.
--    In particular, the array length must be unboxed.
--
--   TODO: Why do we need the NoSpecConstr annotation?
-- 
{-# ANN type PArray NoSpecConstr #-}
data PArray a
        = PArray Int# (PData  a)

-- | Take the length of an array
{-# INLINE_PA length #-}
length :: PArray a -> Int
length (PArray n# _)   = (I# n#)


-- | Take the data from an array.
{-# INLINE_PA takeData #-}
takeData :: PArray a -> PData a
takeData (PArray _ d)   = d


-- Parallel array data --------------------------------------------------------
{-# ANN type PData NoSpecConstr #-}
data family PData a

{-# ANN type PDatas NoSpecConstr #-}
data family PDatas a


-- Put these here to break an import loop.
data instance PData Int
        = PInt  (U.Array Int)

data instance PDatas Int
        = PInts (V.Vector (U.Array Int))


-- PR -------------------------------------------------------------------------
class PR a where

  -- House Keeping ------------------------------
  --  These methods are helpful for debugging, but we don't want their
  --  associated type classes as superclasses of PR.

  -- | Check that an array has a well formed representation.
  --   This should only return False where there is a bug in the library.
  validPR       :: PData a -> Bool

  -- | Ensure there are no thunks in the representation of a manifest array.
  nfPR          :: PData a -> ()

  -- | Weak equality of contained elements.
  --   Returns True for functions of the same type.  
  --   In the case of nested arrays, this ignores the physical representation,
  --   that is, it doesn't care about the exact form of segment descriptors.
  similarPR     :: a -> a -> Bool

  -- | Check that an index is within this array.
  --   The (PData Void) arrays don't have a real length, but we still want to
  --   to check that indices are in-range during testing.
  --   If the array has a hard length, and the flag is True, then we allow
  --   the index to be equal to this length.
  coversPR      :: Bool -> PData a -> Int   -> Bool

  -- | Pretty print the physical representation of an element.
  pprpPR        :: a       -> Doc

  -- | Pretty print the physical representation of this array.
  pprpDataPR    :: PData a -> Doc


  -- Constructors -------------------------------
  -- | Produce an empty array with size zero.
  emptyPR       :: PData a

  -- | Define an array of the given size, that maps all elements to the same value.
  --   We require the replication count to be > 0 so that it's easier to maintain
  --   the validPR invariants for nested arrays.
  --   O(n). 
  replicatePR   :: Int          -- ^ length of result array. Must be > 0.
                -> a            -- ^ element to replicate.
                -> PData a

  -- | O(sum lengths). Segmented replicate.
  --   TODO: This takes a whole Segd instead of just the lengths, because we could
  --         do it more efficiently if we knew there were no zero lengths.
  replicatesPR  :: U.Segd               -- ^ segment descriptor defining the lengths of the segments.
                -> PData a              -- ^ data elements to replicate
                -> PData a

  -- | Append two sized arrays.
  appendPR      :: PData a -> PData a -> PData a

  -- | Segmented append
  appendsPR     :: U.Segd               -- ^ segd of result
                -> U.Segd -> PData a    -- ^ segd/data of first  arrays
                -> U.Segd -> PData a    -- ^ segd/data of second arrays
                -> PData a


  -- Projections --------------------------------
  -- | O(1). Get the length of an array, if it has one.
  --   A (PData Void) array has no length, so this returns `error` in that case.
  --   To check array bounds, use coversPR instead, as that's a total function.
  lengthPR      :: PData a -> Int
  
  -- | O(1). Lookup a single element from the source array.
  indexPR       :: PData a -> Int -> a

  -- | Lookup several elements from several source arrays
  indexlPR      :: PData (PArray a)
                -> PData Int
                -> PData a

  -- | O(n). Extract a range of elements from an array.
  extractPR     :: PData a 
                -> Int                  -- ^ starting index
                -> Int                  -- ^ length of slice
                -> PData a

  -- | O(sum seglens). Segmented extract.
  extractsPR    :: PDatas a
                -> U.SSegd              -- ^ segment descriptor describing scattering of data.
                -> PData a

  -- | Backwards permutation
  bpermutePR    :: PData a              -- ^ source array
                -> U.Array Int          -- ^ source indices
                -> PData a


  -- Pack and Combine ---------------------------
  -- | Filter an array based on some tags.
  packByTagPR   :: PData a              -- ^ source array
                -> U.Array Tag          -- ^ array of tags
                -> Tag                  -- ^ tag of elements to select
                -> PData a

  -- | Combine two arrays based on a selector.
  combine2PR    :: U.Sel2               -- ^ selector
                -> PData a              -- ^ first source array
                -> PData a              -- ^ second source array
                -> PData a


  -- Conversions --------------------------------
  -- | Convert a boxed vector to an array.
  fromVectorPR  :: Vector a -> PData a

  -- | Convert an array to a boxed vector.
  toVectorPR    :: PData a -> Vector a


  -- PDatas -------------------------------------
  -- | O(1). Yield an empty collection of PData.
  emptydPR      :: PDatas a

  -- | O(1). Yield a singleton collection of PData.
  singletondPR  :: PData a  -> PDatas a

  -- | O(1). Yield how many PData are in the collection.
  lengthdPR     :: PDatas a -> Int

  -- | O(1). Lookup a PData from a collection.
  indexdPR      :: PDatas a -> Int -> PData a

  -- | O(n). Append two collections of PData.
  appenddPR     :: PDatas a -> PDatas a -> PDatas a

  -- | O(n). Combine several collections of PData into a single one.
  concatdPR     :: V.Vector (PDatas a) -> PDatas a

  -- | O(n). Convert a vector of PData to a PDatas collection.
  fromVectordPR :: V.Vector (PData a) -> PDatas a

  -- | O(n). Convert a PDatas collection to a vector of PData.
  toVectordPR   :: PDatas a           -> V.Vector (PData a)


instance PR a  => PprPhysical (PData a) where
 pprp = pprpDataPR

instance PR a  => PprPhysical (PDatas a) where
 pprp pdatas
  = vcat
  $ [ int n <> colon <> text " " <> pprpDataPR pd
        | n  <- [0..]
        | pd <- V.toList $ toVectordPR pdatas]


-------------------------------------------------------------------------------
-- extra unlifted primitives should be moved into unlifted library ------------
-------------------------------------------------------------------------------

-- TODO: zip srcids ixBase and startsix before calling replicate_s
--       don't want to replicate_s multiple times on same segd.
--
-- TODO: pass in a projection function to get the correct array from the vector, 
--       to avoid unpackig all the arrays from PDatas with a big map traversal.

{-# NOINLINE uextracts #-}
uextracts 
        :: U.Elt a 
        => V.Vector (U.Array a) 
        -> U.Array Int  -- source ids
        -> U.Array Int  -- base indices
        -> U.Array Int  -- segment lengths
        -> U.Array a

uextracts arrs srcids ixBase lens 
 = let -- total length of the result
        dstLen    = U.sum lens
        segd      = U.lengthsToSegd lens
    
        -- source array ids to load from
        srcids'   = U.replicate_s segd srcids

        -- base indices in the source array to load from
        baseixs   = U.replicate_s segd ixBase
        
        -- starting indices for each of the segments
        startixs  = U.scan (+) 0 lens
          
        -- starting indices for each of the segments in the result
        startixs' = U.replicate_s segd startixs

        {-# INLINE get #-}
        get ixDst ixSegDst (ixSegSrcBase, srcid)
         = let  !arr    = arrs V.! srcid                         -- TODO: use unsafeIndex
                !ix     = ixDst - ixSegDst + ixSegSrcBase
           in   arr U.!: ix                         -- TODO unsafe unsafeIndex
         
        result    = U.zipWith3 get
                        (U.enumFromTo 0 (dstLen - 1))
                        startixs'
                        (U.zip baseixs srcids')

   in result

