{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies     #-}

module Diagrams.Test.Trail where

import           Diagrams.Prelude
import           Instances
import           Test.Tasty
import           Test.Tasty.QuickCheck

import           Data.Fixed
import           Data.List

tests :: TestTree
tests = testGroup "Trail"
  [ let wrap :: Trail' Line V2 Double -> Located (Trail V2 Double)
        wrap = (`at` origin) . wrapLine
    in
    testProperty "unfixTrail . fixTrail == id for lines" $
    \l -> (unfixTrail . fixTrail $ wrap l) =~ (wrap l)

  , testProperty "glueLine . cutLoop == id" $
    \loop -> (glueLine . cutLoop $ loop) =~ (loop :: Trail' Loop V2 Double)

  , testProperty "trailOffset == sumV . trailOffsets" $
    \t -> trailOffset t =~ (sumV . trailOffsets $ (t :: Trail V2 Double))

  , testProperty "reverseTrail . reverseTrail == id" $
    \t -> (reverseTrail . reverseTrail $ t) =~ (t :: Trail V2 Double)

  , testProperty "reverseLocTrail . reverseLocTrail == id" $
    \t -> (reverseLocTrail . reverseLocTrail $ t) =~
          (t :: Located (Trail V2 Double))

  , testProperty "reverseLine . reverseLine == id" $
    \t -> (reverseLine . reverseLine $ t) =~
          (t :: Trail' Line V2 Double)

  , testProperty "reverseLocLine . reverseLocLine == id" $
    \t -> (reverseLocLine . reverseLocLine $ t) =~
          (t :: Located (Trail' Line V2 Double))

  , testProperty "reverseLoop . reverseLoop == id" $
    \t -> (reverseLoop . reverseLoop $ t) =~
          (t :: Trail' Loop V2 Double)

  , testProperty "reverseLocLoop . reverseLocLoop == id" $
    \t -> (reverseLocLoop . reverseLocLoop $ t) =~
          (t :: Located (Trail' Loop V2 Double))

  , testProperty "section on Trail' Line endpoints match paramaters" $
    \t (Param a) (Param b) ->
      let s = section (t :: Located (Trail' Line V2 Double)) a b
      in  t `atParam` a =~ s `atParam` 0 &&
          t `atParam` b =~ s `atParam` 1

  , testProperty "section on Trail' Line where a paramater is 0 or 1" $
    \t (Param a) ->
      let l = section (t :: Located (Trail' Line V2 Double)) 0 a
          r = section (t :: Located (Trail' Line V2 Double)) a 1
      in  t `atParam` 0 =~ l `atParam` 0 &&
          t `atParam` a =~ l `atParam` 1 &&
          t `atParam` a =~ r `atParam` 0 &&
          t `atParam` 1 =~ r `atParam` 1

  , testProperty "section on Trail' Line where a segment paramater is 0 or 1" $
    \t (Param a) i ->
      let st = unLoc t # \(Line st') -> st' :: SegTree V2 Double
          b | (numSegs st :: Word) > 0 = (fromIntegral (i `mod` (numSegs st + 1) :: Word)) / numSegs st
            | otherwise                = 0
          s = section (t :: Located (Trail' Line V2 Double)) a b
      in  t `atParam` a =~ s `atParam` 0 &&
          t `atParam` b =~ s `atParam` 1

  , testProperty "section on Trail' Line matches section on FixedSegment" $
    \t (Param a) (Param b) -> sectionTrailSectionFixedSegment t a b

  ]

data Param = Param Double deriving Show

instance Arbitrary Param where
  arbitrary = Param <$> choose (-0.5, 1.5)

sectionTrailSectionFixedSegment :: Located (Trail' Line V2 Double) -> Double -> Double -> Bool
sectionTrailSectionFixedSegment t k1 k2
  | null segs = t == t'
  | otherwise = aSecT =~ aSecFS && bSecT =~ bSecFS
  where
    a = min k1 k2
    b = max k1 k2
    t' = section t a b

    segs  = fixTrail $ mapLoc wrapLine t
    segs' = fixTrail $ mapLoc wrapLine t'

    aSecT = head segs'
    bSecT = last segs'

    (aSegIx, a') = splitParam a
    (bSegIx, b') = splitParam b

    aSecFS = section (segs !! floor aSegIx) a' x
      where x = if aSegIx == bSegIx then b' else 1
    bSecFS = section (segs !! floor bSegIx) x  b'
      where x = if aSegIx == bSegIx then a' else 0

    splitParam p | p <  0    = (0    , p           * n)
                 | p >= 1    = (n - 1, 1 + (p - 1) * n)
                 | otherwise = propFrac $  p       * n
      where
        propFrac x = let m = x `mod'` 1 in (x - m, m)
        n = genericLength segs
