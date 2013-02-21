{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}

module Hajure.Data
  ( Element(..)
  , SExpr
  , mkSexpr
  , sexprView
  , Identifier
  , PrettyShow
  , pshow
  ) where

import Prelude hiding (showList)

import Control.Monad (join)
import Data.List (intercalate)
import Data.Text (Text, unpack)

import ParsecImports

{--
newtype IdentState = IdentState { fromState :: Integer }
  deriving Show

emptyIdentState :: IdentState
emptyIdentState = IdentState (-1)

nextIdent :: HParser Text
nextIdent = asText <$> (modifyState succIdent *> getState)
  where succIdent = IdentState . (+1) . fromState
        asText    = pack . ("$x" ++) . show . fromState

type Source  = Text

type HParser = Parsec Source IdentState

runHParser :: HParser a -> SourceName -> Source -> Either ParseError a
runHParser = flip runParser emptyIdentState
--}

type Identifier = Text

data Element = Nested SExpr
             | Ident  Identifier
             | Num    Double
             | Op     Text
             | List   [Element]
             | Fun    Identifier [Identifier] SExpr
  deriving (Eq, Show)

newtype Wrapped a = Wrapped { unwrap :: [a] }
  deriving (Show, Eq, Functor)

type SExpr = Wrapped Element

mkSexpr :: [Element] -> SExpr
mkSexpr = Wrapped

sexprView :: SExpr -> [Element]
sexprView = unwrap

class PrettyShow a where
  pshow :: a -> String

instance PrettyShow Element where
  pshow (Nested   s) = pshow s
  pshow (List     l) = emptyAcc showListElems l
  pshow (Ident    i) = "Ident " ++ unpack i
  pshow (Num      n) = "Num "   ++ show   n
  pshow (Op       o) = "Op "    ++ unpack o
  pshow (Fun i is s) = unlines' $ showFun "" "" i is s

instance PrettyShow SExpr where
  pshow = emptyAcc showExpr

emptyAcc :: (String -> String -> a -> [String]) -> a -> String
emptyAcc f = unlines' . join f ""


chld, nxt :: String
chld = "|-- "
nxt  = "|   "

unlines' :: [String] -> String
unlines' = intercalate "\n"


withChld :: String -> String
withChld = (++ chld)

withNxt :: String -> String
withNxt  = (++ nxt)

showExpr :: String -> String -> SExpr -> [String]
showExpr acc1 acc2 e = start : body e ++ end
  where start = acc1 ++ "S("
        body  = map (showElem acc2) . unwrap
        end   = [acc2 ++ ")"]

showElem :: String -> Element -> String
showElem acc (List   es) = showList    acc es
showElem acc (Nested e ) = showExpr'   acc e
showElem acc e           = showAsChild acc e

showAsChild :: PrettyShow a => String -> a -> String
showAsChild acc a = withChld acc ++ pshow a

showWith :: (String -> String -> a -> [String]) -> String -> a -> String
showWith f acc    = unlines' . lifted f acc
  where lifted f' = liftA2 f' withChld withNxt

showExpr' :: String -> SExpr -> String
showExpr' = showWith showExpr

showList :: String -> [Element] -> String
showList = showWith showListElems

showListElems :: String -> String -> [Element] -> [String]
showListElems acc1 acc2 es = start : showElems es ++ end
  where showElems = map (showElem acc2)
        start     =  acc1 ++ "["
        end       = [acc2 ++ "]"]

showFun :: String -> String -> Identifier -> [Identifier] -> SExpr -> [String]
showFun acc1 acc2 i is s = [start, body, end]
  where start = acc1 ++ "Fun( " ++ unpack i ++ " " ++ args ++ " ->"
        args  = "[ " ++ (unwords . map unpack $ is) ++ " ]"
        body  = showExpr' (withNxt acc2) s
        end   = nxt ++ ")"

