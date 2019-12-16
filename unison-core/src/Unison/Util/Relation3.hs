{-# LANGUAGE RecordWildCards #-}

module Unison.Util.Relation3 where

import Unison.Prelude

import Unison.Util.Relation (Relation)
import qualified Data.Map as Map
import qualified Unison.Hashable as H
import qualified Unison.Util.Relation as R
import Data.Semigroup (Sum(Sum, getSum))

-- Represents a set of (fact, d1, d2, d3), but indexed using a star schema so
-- it can be efficiently quried from any of the dimensions.
data Relation3 a b c
  = Relation3
  { d1 :: Map a (Relation b c)
  , d2 :: Map b (Relation a c)
  , d3 :: Map c (Relation a b)
  } deriving (Eq,Ord,Show)

-- Cross4 ref name type value

size :: (Ord a, Ord b, Ord c) => Relation3 a b c -> Int
size = getSum . foldMap (Sum . R.size) . d1

toList :: Relation3 a b c -> [(a,b,c)]
toList = fmap (\(a,(b,c)) -> (a,b,c)) . toNestedList

toNestedList :: Relation3 a b c -> [(a,(b,c))]
toNestedList r3 =
  [ (a,bc) | (a,r2) <- Map.toList $ d1 r3
           , bc <- R.toList r2 ]

insert, delete
  :: (Ord a, Ord b, Ord c)
  => a -> b -> c -> Relation3 a b c -> Relation3 a b c
insert a b c Relation3{..} =
  Relation3
    (Map.alter (ins b c) a d1)
    (Map.alter (ins a c) b d2)
    (Map.alter (ins a b) c d3)
  where
    ins x y = Just . R.insert x y . fromMaybe mempty

delete a b c Relation3{..} =
  Relation3
    (Map.alter (del b c) a d1)
    (Map.alter (del a c) b d2)
    (Map.alter (del a b) c d3)
  where
    del _ _ Nothing = Nothing
    del x y (Just r) =
      let r' = R.delete x y r
      in if r' == mempty then Nothing else Just r'

instance (Ord a, Ord b, Ord c) => Semigroup (Relation3 a b c) where
  (<>) = mappend

instance (Ord a, Ord b, Ord c) => Monoid (Relation3 a b c) where
  mempty = Relation3 mempty mempty mempty
  s1 `mappend` s2 = Relation3 d1' d2' d3' where
    d1' = Map.unionWith (<>) (d1 s1) (d1 s2)
    d2' = Map.unionWith (<>) (d2 s1) (d2 s2)
    d3' = Map.unionWith (<>) (d3 s1) (d3 s2)

instance (H.Hashable d1, H.Hashable d2, H.Hashable d3)
       => H.Hashable (Relation3 d1 d2 d3) where
  tokens s = [ H.accumulateToken $ toNestedList s ]