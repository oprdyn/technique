{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Technique.Parser where

import Control.Monad
import Control.Monad.Combinators
import Core.Text.Rope
import Data.Void (Void)
import Data.Text (Text)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

import Technique.Language

type Parser = Parsec Void Text

__VERSION__ :: Int
__VERSION__ = 0

consumer :: (MonadParsec e s m, Token s ~ Char) => m ()
consumer = L.space space1 empty empty

lexeme :: (MonadParsec e s m, Token s ~ Char) => m a -> m a
lexeme = L.lexeme consumer

pMagicLine :: Parser Int
pMagicLine = do
    void (char '%') <?> "first line to begin with % character"
    void spaceChar <?> "a space character"
    void (string "technique")
    void spaceChar <?> "a space character"
    void (char 'v') <?> "the character v and then a number"
    v <- L.decimal <?> "the language version"
    void newline
    return v

pSpdxLine :: Parser (Text,Maybe Text)
pSpdxLine = do
    void (char '!') <?> "second line to begin with ! character"
    void spaceChar <?> "a space character"

    license <- takeWhile1P (Just "software license description (ie an SPDX-Licence-Header value)") (\c -> not (c == ',' || c == '\n'))

    copyright <- optional $ do
        void (char ',') <?> "a comma"
        hidden $ skipMany (spaceChar <?> "a space character")
        void (char '©') <|> void (string "(c)")
        void (spaceChar <?> "a space character")
        takeWhile1P (Just "a copyright declaration") (/= '\n')

    void newline
    return (license,copyright)

pProcfileHeader :: Parser Technique
pProcfileHeader = do
    version <- pMagicLine
    unless (version == __VERSION__) (fail ("currently the only recognized language version is v" ++ show __VERSION__))
    (license,copyright) <- pSpdxLine

    return $ Technique
        { techniqueVersion = version
        , techniqueLicense = intoRope license
        , techniqueCopyright = fmap intoRope copyright
        , techniqueBody = []
        }

-- FIXME consider making this top down, not LR
-- FIXME need to do lexeme to gobble optional whitespace instead of space1

pProcedureDeclaration :: Parser (Identifier,[Identifier],[Type],Type)
pProcedureDeclaration = do
    name <- pIdentifier
    void (many space1)
    -- zero or more separated by comma
    params <- sepBy pIdentifier (char ',')

    void (many space1)
    void (char ':')
    void (many space1)

    ins <- sepBy pType (char ',')

    void (many space1)
    void (string "->")
    void (many space1)

    out <- pType
    return (name,params,ins,out)

identifierChar :: Parser Char
identifierChar = lowerChar <|> digitChar <|> char '_'

pIdentifier :: Parser Identifier
pIdentifier = do
    first <- lowerChar
    remainder <- many identifierChar
    return (Identifier (singletonRope first <> intoRope remainder))

typeChar :: Parser Char
typeChar = upperChar <|> lowerChar <|> digitChar

pType :: Parser Type
pType = do
    first <- upperChar
    remainder <- many typeChar
    return (Type (singletonRope first <> intoRope remainder))

pProcedureFunction :: Parser Procedure
pProcedureFunction = do
    (name,params,ins,out) <- pProcedureDeclaration

    fail "unimplemented"
