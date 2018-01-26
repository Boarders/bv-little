module Main (main) where

import Control.DeepSeq
import Criterion.Main
import Data.Bits
import Data.BitVector.LittleEndian
import Data.Semigroup


main :: IO ()
main = defaultMain [ benchmarks ]

benchmarks :: Benchmark
benchmarks = bgroup "BitVector"
    [ fromNumberBench
    , isZeroVectorBench
    , zeroPopCountBench
    ]


-- |
-- This number is the first 10-digit prime in e. It is used as a "no trick up my sleeve" arbitrary large number.
--
-- ceiling ( log_2 (prime) ) === 33
tinyNumber :: Integer
tinyNumber = 7427466391


-- |
-- This number is phi * 10^20. It is used as a "no trick up my sleeve" arbitrary large number.
--
-- ceiling ( log_2 (phi * 10^20) ) === 68
smallNumber :: Integer
smallNumber = 161803398874989484820


-- |
-- This number is e * 10^50. It is used as a "no trick up my sleeve" arbitrary large number.
--
-- ceiling ( log_2 (e * 10^50) ) === 168
mediumNumber :: Integer
mediumNumber = 271828182845904523536028747135266249775724709369995


-- |
-- This number is pi * 10^100. It is used as a "no trick up my sleeve" arbitrary large number.
--
-- ceiling ( log_2 (pi * 10^100) ) === 334
largeNumber :: Integer
largeNumber = 31415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679


-- |
-- This number is -1 * √2 * 10^200. It is used as a "no trick up my sleeve" arbitrary large negative number.
--
-- ceiling ( log_2 (√2 * 10^200) ) === 665
hugeNumber :: Integer
hugeNumber  = 14142135623730950488016887242096980785696718753769480731766797379907324784621070388503875343276415727350138462309122970249248360558507372126441214970999358314132226659275055927557999505011527820605715


fromNumberBench :: Benchmark
fromNumberBench = constantTimeBenchmark "fromNumber" id g
  where
    g int = let !bitCount = logBase2Word int
            in  fromNumber bitCount
    logBase2Word = succ . succ . ceiling . logBase (2.0 :: Double) . fromIntegral . abs
  

isZeroVectorBench :: Benchmark
isZeroVectorBench = constantTimeBenchmark "isZeroVector" id g
  where
    g int val = let !bitCount  = logBase2Word int
                    !bitVector = fromNumber bitCount int
                in  val `seq` isZeroVector bitVector
    logBase2Word = succ . succ . ceiling . logBase (2.0 :: Double) . fromIntegral . abs
  

zeroPopCountBench :: Benchmark
zeroPopCountBench = constantTimeBenchmark "popCount is zero" id g
  where
    g int val = let !bitCount  = logBase2Word int
                    !bitVector = fromNumber bitCount int
                in  val `seq` ((0==) . popCount) bitVector
    logBase2Word = succ . succ . ceiling . logBase (2.0 :: Double) . fromIntegral . abs
  

constantTimeBenchmark :: (NFData a, NFData b) => String -> (Integer -> a) -> (Integer -> a -> b) -> Benchmark
constantTimeBenchmark  label f g = bgroup label $ generateBenchmark <$>
    [ ("zero"  ,            0)
    , ("tiny"  ,   tinyNumber)
    , ("small" ,  smallNumber)
    , ("medium", mediumNumber)
    , ("large" ,  largeNumber)
    , ("huge"  ,   hugeNumber)
    ]
  where
    generateBenchmark (intLabel, intValue) = bench intLabel $ nf app target
      where
        !target    = force $ f intValue
        !app       = g intValue
    

{-
invertBench :: Benchmark
invertBench = bench "MutualExclusionSet invert is constant-time" $ whnf invert $ force (ofSize 50)


isCoherentBench :: Benchmark
isCoherentBench = bench "MutualExclusionSet isCoherent is constant-time" $ whnf isCoherent $ force (ofSize 50)


isPermissibleBench :: Benchmark
isPermissibleBench = linearBenchmark "MutualExclusionSet isPermissible log-access" (force . ofSize) (const isPermissible)


isExcludedBench :: Benchmark
isExcludedBench = logBenchmark "MutualExclusionSet isExcluded log-access" ofSize f
  where
    -- We negate i to consider both the included and excluded cases
    f i xs = (i `isExcluded` xs) `seq` negate i `isExcluded` xs


isIncludedBench :: Benchmark
isIncludedBench = logBenchmark "MutualExclusionSet isIncluded log-access" ofSize f
  where
    -- We negate i to consider both the included and excluded cases
    f i xs = (i `isIncluded` xs) `seq` negate i `isIncluded` xs


excludedLookupBench :: Benchmark
excludedLookupBench = logBenchmark "MutualExclusionSet excludedLookup log-access" ofSize f
  where
    -- We negate i to consider both the included and excluded cases
    f i xs = (i `excludedLookup` xs) `seq` negate i `excludedLookup` xs


includedLookupBench :: Benchmark
includedLookupBench = logBenchmark "MutualExclusionSet includedLookup log-access" ofSize f
  where
    -- We negate i to consider both the included and excluded cases
    f i xs = (i `includedLookup` xs) `seq` negate i `includedLookup` xs


excludedSetBench :: Benchmark
excludedSetBench = linearBenchmark "MutualExclusionSet excludedSet linear access" (force . ofSize) (const excludedSet)


includedSetBench :: Benchmark
includedSetBench = linearBenchmark "MutualExclusionSet includedSet linear access" (force . ofSize) (const includedSet)


mutualExclusivePairsBench :: Benchmark
mutualExclusivePairsBench = linearBenchmark "MutualExclusionSet mutuallyExclusivePairs linear access" (force . ofSize) (const mutuallyExclusivePairs)


mergeBench :: Benchmark
mergeBench = linearBenchmark2 "merge (<>) is linear" (force . ofSize) (force . ofSizeEven) (const (<>))


linearBenchmark :: (NFData a, NFData b) => String -> (Int -> a) -> (Int -> a -> b) -> Benchmark
linearBenchmark  label f g = bgroup label $ generateBenchmark <$> [0 .. 9]
  where
    generateBenchmark expVal = bench (show domainSize) $ nf app target
      where
        !target    = force $ f domainSize
        !app       = g expVal
        domainSize = 10 * (expVal + 1)
    

linearBenchmark2 :: (NFData a, NFData b, NFData c) => String -> (Int -> a) -> (Int -> b) -> (Int -> a -> b -> c) -> Benchmark
linearBenchmark2  label f g h = bgroup label $ generateBenchmark <$> [0 .. 9]
  where
    generateBenchmark expVal = bench (show domainSize) $ nf app rhs
      where
        !lhs       = force $ f domainSize
        !rhs       = force $ g domainSize
        !app       = h expVal lhs
        domainSize = 10 * (expVal + 1)
    

logBenchmark :: String -> (Int -> a) -> (Int -> a -> b) -> Benchmark
logBenchmark label f g = bgroup label $ generateBenchmark <$> [0 .. 9]
  where
    generateBenchmark expVal = bench (show domainSize) $ whnf app target
      where
        !app       = g indexpValrod
        !target    = f domainSize
        indexpValrod  = product [1..expVal] `mod` domainSize
        domainSize = 2 `shiftL` expVal


ofSize :: Int -> MutualExclusionSet Int
ofSize n = unsafeFromList $ (\x -> (x, negate x)) <$> [1..n]


ofSizeEven :: Int -> MutualExclusionSet Int
ofSizeEven n = unsafeFromList $ (\x -> (x, negate x)) <$> [2,4..2*n]

-}
