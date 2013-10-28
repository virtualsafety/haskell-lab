module Anagram where

import Data.List
import Data.Char (toLower)
import qualified Data.Map as Map
import Test.HUnit

-- ######### Definition type

type Word = String

type Sentence = [Word]

type Occurrences = [(Char, Int)]

-- ######### Production code

wordOccurrences :: Word -> Occurrences
wordOccurrences = map (\x -> ((head x), length x)) . group . sort . (map toLower)

sentenceOccurrences :: Sentence -> Occurrences
sentenceOccurrences = wordOccurrences . (intercalate "")

combinations :: Occurrences -> [Occurrences]
combinations =
  foldl' comb [[]]
  where comb :: [Occurrences] -> (Char, Int) -> [Occurrences]
        comb ss ci = ss ++ [sub ++ [c] | sub <- ss, c <- subOccurrences ci]
        subOccurrences :: (Char, Int) -> Occurrences
        subOccurrences (c, n) = [(c, i) | i <- [1..n]]

substract :: Occurrences -> Occurrences -> Occurrences
substract occ = foldl' update occ
                where update :: Occurrences -> (Char, Int) -> Occurrences
                      update [] _                       = []
                      update (x@(cc, nn) : xs) e@(c, n) = case cc == c of
                        True -> let ni = nn - n in if ni <= 0 then xs else (c, ni):xs
                        _    -> x : update xs e

type DicoOcc = [(Occurrences, [Word])]

dicoByOccurrences :: [String] -> DicoOcc
dicoByOccurrences = nub . (foldl' add []) -- Fixme - using nub to destroy duplicated entries at the end
  where add acc word = let occ = wordOccurrences word in
          case lookup occ acc of
            Nothing -> (occ, [word]) : acc
            Just ws -> (occ, nws) : acc -- Fixme - how to update the associative array
                       where nws = if elem word ws then ws else word : ws -- no duplicated entries

findAnagram :: Word -> [(Occurrences, a)] -> Maybe a
findAnagram w d = (flip lookup d . wordOccurrences) w

-- Returns all the anagrams of a given word.
wordAnagrams :: Word -> DicoOcc -> [Word]
wordAnagrams w d = case findAnagram w d of
  Nothing -> []
  Just x  -> x

-- ######### I/O

extractLines :: FilePath -> IO [String]
extractLines filePath =
  do contents <- readFile filePath
     return $ lines contents

disp :: Int -> IO [String] -> IO ()
disp n allLines =
  do ll <- allLines
     let f = take n ll in
       mapM_ putStrLn f

--  An anagram of a sentence is formed by taking the occurrences of all the characters of
--  all the words in the sentence, and producing all possible combinations of words with those characters,
--  such that the words have to be from the dictionary.

-- Returns a list of all anagram sentences of the given sentence.
sentenceAnagrams :: Sentence -> DicoOcc -> [Sentence]
sentenceAnagrams s d =
  (filter (\x -> sum (map length x) == sum (map length s)) . nub . sentenceCompute . combinations . sentenceOccurrences) s
  where sentenceCompute :: [Occurrences] -> [Sentence]
        sentenceCompute []     = [[]]
        sentenceCompute (o:os) = case lookup o d of
          Nothing        -> sentenceCompute os
          Just anagrams  -> [y:ys | y <- anagrams, ys <- sentenceCompute oss] ++ sentenceCompute os
            where oss = map (flip substract o) os

dictionaryFromFile :: FilePath -> IO DicoOcc
dictionaryFromFile filepath =
  do dicoLines <- extractLines filepath
     return $ dicoByOccurrences dicoLines

mainWordAnagrams :: String -> FilePath -> IO ()
mainWordAnagrams word filePath =
  do dicoLines <- extractLines filePath
     mapM_ putStrLn $ wordAnagrams word (dicoByOccurrences dicoLines)

printSentence :: Sentence -> IO ()
printSentence sentence = putStr "[" >> mapM_ (putStr . (++) " ") sentence >> putStrLn "]"

mainSentenceAnagrams :: [String] -> FilePath -> IO ()
mainSentenceAnagrams sentence filePath =
  do dico <- dictionaryFromFile filePath
     mapM_ printSentence $ sentenceAnagrams sentence dico

-- ######### Tests

testWordOccurrences1 :: Test.HUnit.Test
testWordOccurrences1 = [(' ',6),('a',3),('d',1),('e',2),('h',3),('i',2),('l',1),('n',1),('o',1),('r',1),('s',3),('t',4),('y',1)]
                       ~=?
                       wordOccurrences "This is the last day on earth"

testWordOccurrences2 :: Test.HUnit.Test
testWordOccurrences2 = [(' ',2),('i',1),('m',1),('p',3),('t',1),('u',2)] ~=? wordOccurrences "pump it up"

testWordOccurrencess :: Test.HUnit.Test
testWordOccurrencess = TestList ["testWordOccurrences1" ~: testWordOccurrences1,
                                 "testWordOccurrences2" ~: testWordOccurrences2]

testSentenceOccurrences1 :: Test.HUnit.Test
testSentenceOccurrences1 = [(' ',8),('a',3),('d',1),('e',2),('h',3),('i',3),('l',1),('m',1),('n',1),('o',1),('p',3),('r',1),('s',3),('t',5),('u',2),('y',1)]
                           ~=?
                           sentenceOccurrences ["this is the last day on earth", "pump it up"]

testSentenceOccurrencess :: Test.HUnit.Test
testSentenceOccurrencess = TestList [ "testSentenceOccurrences1" ~: testSentenceOccurrences1]

testCombinations1 :: Test.HUnit.Test
testCombinations1 = [[],[('a',1)],[('a',2)],[('b',1)],[('a',1),('b',1)],[('a',2),('b',1)]]
                    ~=?
                    combinations [('a', 2), ('b', 1)]

testCombinations2 :: Test.HUnit.Test
testCombinations2 = [[],[('a',1)],[('a',2)],[('b',1)],[('b',2)],[('a',1),('b',1)],[('a',1),('b',2)],[('a',2),('b',1)],[('a',2),('b',2)]]
                    ~=?
                    combinations [('a', 2), ('b', 2)]

testCombinationss :: Test.HUnit.Test
testCombinationss = TestList ["testCombinations1" ~: testCombinations1,
                              "testCombinations2" ~: testCombinations2]

testSubstract1 :: Test.HUnit.Test
testSubstract1 = [('x',2),('b',1)]
                 ~=?
                 substract [('x', 3), ('a', 2), ('b', 1)] [('x', 1), ('a', 2)]

testSubstract2 :: Test.HUnit.Test
testSubstract2 = []
                 ~=?
                 substract [] [('x', 1), ('a', 2)]

testSubstract3 :: Test.HUnit.Test
testSubstract3 = [('b',1)]
                 ~=?
                 substract [('x', 3), ('a', 2), ('b', 1)] [('x', 3), ('a', 2)]

testSubstracts :: Test.HUnit.Test
testSubstracts = TestList [ "testSubstract1" ~: testSubstract1,
                            "testSubstract2" ~: testSubstract2,
                            "testSubstract3" ~: testSubstract3]

testDicoByOccurrences1 :: Test.HUnit.Test
testDicoByOccurrences1 = [([('c',1)],["c"]),([('a',2),('b',1)],["baa"]),([('a',1),('b',2)],["abb"]),([('a',1)],["a"])]
                         ~=?
                         dicoByOccurrences ["a", "abb", "baa", "c"]

testDicoByOccurrencess :: Test.HUnit.Test
testDicoByOccurrencess = TestList ["testDicoByOccurrences1" ~: testDicoByOccurrences1]

testFindAnagram1 :: Test.HUnit.Test
testFindAnagram1 = Nothing
                   ~=?
                   findAnagram "a" [([('a', 1), ('b', 2)], ["abb", "bab", "bba"])]

testFindAnagram2 :: Test.HUnit.Test
testFindAnagram2 = Just ["abb","bab","bba"]
                   ~=?
                   findAnagram "abb" [([('a', 1), ('b', 2)], ["abb", "bab", "bba"])]

testFindAnagram3 :: Test.HUnit.Test
testFindAnagram3 = Just ["abb","bab","bba"]
                   ~=?
                   findAnagram "bab" [([('a', 1), ('b', 2)], ["abb", "bab", "bba"])]

testFindAnagrams :: Test.HUnit.Test
testFindAnagrams = TestList ["testFindAnagram1" ~: testFindAnagram1,
                             "testFindAnagram2" ~: testFindAnagram2,
                             "testFindAnagram3" ~: testFindAnagram3]

testWordAnagrams1 :: Test.HUnit.Test
testWordAnagrams1 = ["abb"] ~=? wordAnagrams "abb" [([('a', 1), ('b', 2)], ["abb"])]

testWordAnagrams2 :: Test.HUnit.Test
testWordAnagrams2 = ["abb","bab","bba"] ~=? wordAnagrams "abb" [([('a', 1), ('b', 2)], ["abb", "bab", "bba"])]

testWordAnagrams3 :: Test.HUnit.Test
testWordAnagrams3 = ["abb","bab","bba"] ~=? wordAnagrams "bba" [([('a', 1), ('b', 2)], ["abb", "bab", "bba"])]

testWordAnagrams4 :: Test.HUnit.Test
testWordAnagrams4 = [] ~=? wordAnagrams "a" [([('a', 1), ('b', 2)], ["abb", "bab", "bba"])]

testWordAnagrams :: Test.HUnit.Test
testWordAnagrams = TestList ["testWordAnagrams1" ~: testWordAnagrams1,
                             "testWordAnagrams2" ~: testWordAnagrams2,
                             "testWordAnagrams3" ~: testWordAnagrams3,
                             "testWordAnagrams4" ~: testWordAnagrams4]

testSentenceAnagrams1 :: Test.HUnit.Test
testSentenceAnagrams1 =  [["en","as","my"],
                          ["en","my","as"],
                          ["man","yes"],
                          ["men","say"],
                          ["as","en","my"],
                          ["as","my","en"],
                          ["Sean","my"],
                          ["sane","my"],
                          ["my","en","as"],
                          ["my","as","en"],
                          ["my","Sean"],
                          ["my","sane"],
                          ["say","men"],
                          ["yes","man"]]
                        ~=?
                        sentenceAnagrams ["yes", "man"] dicoYesMan
  where dicoYesMan = dicoByOccurrences ["en", "as", "my",
                                        "en", "my", "as",
                                        "man", "yes", "men",
                                        "say", "as", "en",
                                        "my", "as", "my",
                                        "en", "sane", "my",
                                        "Sean", "my", "my",
                                        "en", "as", "my",
                                        "as", "en", "my",
                                        "sane", "my", "Sean",
                                        "say", "men", "yes",
                                        "man"]

testSentenceAnagrams2 :: Test.HUnit.Test
testSentenceAnagrams2 = [["nil","Rex","Zulu"],
                         ["nil","Zulu","Rex"],
                         ["Lin","Rex","Zulu"],
                         ["Lin","Zulu","Rex"],
                         ["null","Rex","Uzi"],
                         ["null","Uzi","Rex"],
                         ["Rex","nil","Zulu"],
                         ["Rex","Lin","Zulu"],
                         ["Rex","null","Uzi"],
                         ["Rex","Uzi","null"],
                         ["Rex","Zulu","nil"],
                         ["Rex","Zulu","Lin"],
                         ["Linux","rulez"],
                         ["Uzi","null","Rex"],
                         ["Uzi","Rex","null"],
                         ["Zulu","nil","Rex"],
                         ["Zulu","Lin","Rex"],
                         ["Zulu","Rex","nil"],
                         ["Zulu","Rex","Lin"],
                         ["rulez","Linux"]]
                        ~=?
                        sentenceAnagrams ["Linux", "rulez"] dicoLinuxRulez
  where dicoLinuxRulez = dicoByOccurrences ["Rex", "Lin", "Zulu",
                                            "nil", "Zulu", "Rex",
                                            "Rex", "nil", "Zulu",
                                            "Zulu", "Rex", "Lin",
                                            "null", "Uzi", "Rex",
                                            "Rex", "Zulu", "Lin",
                                            "Uzi", "null", "Rex",
                                            "Rex", "null", "Uzi",
                                            "null", "Rex", "Uzi",
                                            "Lin", "Rex", "Zulu",
                                            "nil", "Rex", "Zulu",
                                            "Rex", "Uzi", "null",
                                            "Rex", "Zulu", "nil",
                                            "Zulu", "Rex", "nil",
                                            "Zulu", "Lin", "Rex",
                                            "Lin", "Zulu", "Rex",
                                            "Uzi", "Rex", "null",
                                            "Zulu", "nil", "Rex",
                                            "rulez", "Linux",
                                            "Linux", "rulez"]

testSentenceAnagrams :: Test.HUnit.Test
testSentenceAnagrams = TestList ["testSentenceAnagrams1" ~: testSentenceAnagrams1,
                                 "testSentenceAnagrams2" ~: testSentenceAnagrams2]

-- Full tests
tests :: Test.HUnit.Test
tests = TestList [testWordOccurrencess,
                  testSentenceOccurrencess,
                  testCombinationss,
                  testSubstracts,
                  testDicoByOccurrencess,
                  testFindAnagrams,
                  testWordAnagrams,
                  testSentenceAnagrams]

main :: IO ()
main = runTestTT tests >>= print

-- *Anagram> runTestTT tests
-- Cases: 18  Tried: 18  Errors: 0  Failures: 0
-- Counts {cases = 18, tried = 18, errors = 0, failures = 0}
