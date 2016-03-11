module GulpPurescript.Options
  ( Psci(..)
  , pscOptions
  , pscBundleOptions
  , pscDocsOptions
  ) where

import Prelude

import Control.Alt ((<|>))

import Data.Array (concat, singleton)
import Data.Either (Either(..), either)
import Data.Foreign (Foreign(), ForeignError(TypeMismatch), F())
import Data.Foreign.Class (IsForeign, read, readProp)
import Data.Foreign.Keys (keys)
import Data.Foreign.NullOrUndefined (NullOrUndefined(..), runNullOrUndefined)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Traversable (for)
import Data.Tuple (Tuple())
import Data.Tuple.Nested (tuple2)

srcOpt = "src"

srcKey = "src"

noOptsOpt = "no-opts"

noOptsKey = camelcaseFn noOptsOpt

noMagicDoOpt = "no-magic-do"

noMagicDoKey = camelcaseFn noMagicDoOpt

noTcoOpt = "no-tco"

noTcoKey = camelcaseFn noTcoOpt

verboseErrorsOpt = "verbose-errors"

verboseErrorsKey = camelcaseFn verboseErrorsOpt

outputOpt = "output"

outputKey = outputOpt

namespaceOpt = "namespace"

namespaceKey = namespaceOpt

commentsOpt = "comments"

commentsKey = commentsOpt

noPrefixOpt = "no-prefix"

noPrefixKey = camelcaseFn noPrefixOpt

mainOpt = "main"

mainKey = mainOpt

moduleOpt = "module"

moduleKey = moduleOpt

formatOpt = "format"

formatKey = formatOpt

ffiOpt = "ffi"

ffiKey = ffiOpt

docgenOpt = "docgen"

docgenKey = docgenOpt

requirePathOpt = "require-path"

requirePathKey = camelcaseFn requirePathOpt

jsonErrorsOpt = "json-errors"

jsonErrorsKey = camelcaseFn jsonErrorsOpt

newtype Psc
  = Psc { src :: Either String (Array String)
        , ffi :: NullOrUndefined (Either String (Array String))
        , output :: NullOrUndefined String
        , noTco :: NullOrUndefined Boolean
        , noMagicDo :: NullOrUndefined Boolean
        , noOpts :: NullOrUndefined Boolean
        , verboseErrors :: NullOrUndefined Boolean
        , comments :: NullOrUndefined Boolean
        , noPrefix :: NullOrUndefined Boolean
        , requirePath :: NullOrUndefined String
        , jsonErrors :: NullOrUndefined Boolean
        }

newtype PscBundle
  = PscBundle { src :: Either String (Array String)
              , output :: NullOrUndefined String
              , "module" :: NullOrUndefined (Either String (Array String))
              , main :: NullOrUndefined (Either Boolean String)
              , namespace :: NullOrUndefined String
              , requirePath :: NullOrUndefined String
              }

newtype PscDocs
  = PscDocs { src :: Either String (Array String)
            , format :: NullOrUndefined Format
            , docgen :: NullOrUndefined Docgen
            }

newtype Psci
  = Psci { src :: Either String (Array String)
         , ffi :: NullOrUndefined (Either String (Array String))
         }

newtype Docgen = Docgen Foreign

newtype PathArray = PathArray (Array String)

data Format = Markdown | ETags | CTags

instance isForeignPsc :: IsForeign Psc where
  read obj =
    Psc <$> ({ src: _
             , ffi: _
             , output: _
             , noTco: _
             , noMagicDo: _
             , noOpts: _
             , verboseErrors: _
             , comments: _
             , noPrefix: _
             , requirePath: _
             , jsonErrors: _
             } <$> (readProp srcKey obj >>= readEither)
               <*> (readProp ffiKey obj >>= readEitherNU)
               <*> readProp outputKey obj
               <*> readProp noTcoKey obj
               <*> readProp noMagicDoKey obj
               <*> readProp noOptsKey obj
               <*> readProp verboseErrorsKey obj
               <*> readProp commentsKey obj
               <*> readProp noPrefixKey obj
               <*> readProp requirePathKey obj
               <*> readProp jsonErrorsKey obj)

instance isForeignPscBundle :: IsForeign PscBundle where
  read obj =
    PscBundle <$> ({ src: _
                   , output: _
                   , "module": _
                   , main: _
                   , namespace: _
                   , requirePath: _
                   } <$> (readProp srcKey obj >>= readEither)
                     <*> readProp outputKey obj
                     <*> (readProp moduleKey obj >>= readEitherNU)
                     <*> (readProp mainKey obj >>= readEitherNU)
                     <*> readProp namespaceKey obj
                     <*> readProp requirePathKey obj)

instance isForeignPscDocs :: IsForeign PscDocs where
  read obj =
    PscDocs <$> ({ src: _
                 , format: _
                 , docgen: _
                 } <$> (readProp srcKey obj >>= readEither)
                   <*> readProp formatKey obj
                   <*> readProp docgenOpt obj)

instance isForeignPsci :: IsForeign Psci where
  read obj =
    Psci <$> ({ src: _
              , ffi: _
              } <$> (readProp srcKey obj >>= readEither)
                <*> (readProp ffiKey obj >>= readEitherNU))

instance isForeignPathArray :: IsForeign PathArray where
  read val = PathArray <$> read val

instance isForeignDocgen :: IsForeign Docgen where
  read val = Docgen <$> read val

instance isForeignFormat :: IsForeign Format where
  read val = read val >>= (\a -> case a of
                                      "markdown" -> Right Markdown
                                      "etags" -> Right ETags
                                      "ctags" -> Right CTags
                                      b -> Left $ TypeMismatch "Format" b)

class CommandLineOption a where
  opt :: String -> NullOrUndefined a -> Array String

instance commandLineOptionBoolean :: CommandLineOption Boolean where
  opt key val = maybe [] (\a -> if a then ["--" ++ key] else []) (runNullOrUndefined val)

instance commandLineOptionString :: CommandLineOption String where
  opt key val = maybe [] (\a -> ["--" ++ key ++ "=" ++ a]) (runNullOrUndefined val)

instance commandLineOptionEither :: (CommandLineOption a, CommandLineOption b) => CommandLineOption (Either a b) where
  opt key val = maybe [] (either (\a -> opt key (NullOrUndefined $ Just a))
                                 (\a -> opt key (NullOrUndefined $ Just a)))
                      (runNullOrUndefined val)

instance commandLineOptionArray :: (CommandLineOption a) => CommandLineOption (Array a) where
  opt key val = concat $ opt key <$> (NullOrUndefined <<< Just)
                                 <$> (fromMaybe [] $ runNullOrUndefined val)

instance commandLineOptionPathArray :: CommandLineOption PathArray where
  opt key val = opt key (NullOrUndefined ((\(PathArray a) -> a >>= expandGlob) <$> (runNullOrUndefined val)))

instance commandLineOptionDocgen :: CommandLineOption Docgen where
  opt key val = opt key (NullOrUndefined (parseDocgen <$> (runNullOrUndefined val)))

parseDocgen :: Docgen -> Array String
parseDocgen (Docgen obj) = either (const []) id $ parseName obj
                                              <|> parseList obj
                                              <|> parseObj obj
                                              <|> pure []
  where
    parseName :: Foreign -> F (Array String)
    parseName obj = singleton <$> read obj

    parseList :: Foreign -> F (Array String)
    parseList obj = read obj

    parseObj :: Foreign -> F (Array String)
    parseObj obj = do
      modules <- keys obj
      for modules \m -> (\f -> m ++ ":" ++ f) <$> readProp m obj

instance commandLineOptionFormat :: CommandLineOption Format where
  opt key val = opt key (maybe (NullOrUndefined Nothing)
                               (\a -> case a of
                                           Markdown -> NullOrUndefined (Just "markdown")
                                           ETags -> NullOrUndefined (Just "etags")
                                           CTags -> NullOrUndefined (Just "ctags"))
                               (runNullOrUndefined val))

pscOptions :: Foreign -> Either ForeignError (Array String)
pscOptions opts = fold <$> parsed
  where parsed = read opts :: F Psc
        fold (Psc a) = either pure id a.src <>
                       opt ffiOpt a.ffi <>
                       opt outputOpt a.output <>
                       opt noTcoOpt a.noTco <>
                       opt noMagicDoOpt a.noMagicDo <>
                       opt noOptsOpt a.noOpts <>
                       opt verboseErrorsOpt a.verboseErrors <>
                       opt commentsOpt a.comments <>
                       opt noPrefixOpt a.noPrefix <>
                       opt requirePathOpt a.requirePath <>
                       opt jsonErrorsOpt a.jsonErrors

pscBundleOptions :: Foreign -> Either ForeignError (Array String)
pscBundleOptions opts = fold <$> parsed
  where parsed = read opts :: F PscBundle
        fold (PscBundle a) = either pure id a.src <>
                             opt outputOpt a.output <>
                             opt moduleOpt a."module" <>
                             opt mainOpt a.main <>
                             opt namespaceOpt a.namespace <>
                             opt requirePathOpt a.requirePath

pscDocsOptions :: Foreign -> Either ForeignError (Array String)
pscDocsOptions opts = fold <$> parsed
  where parsed = read opts :: F PscDocs
        fold (PscDocs a) = either pure id a.src <>
                           opt formatOpt a.format <>
                           opt docgenOpt a.docgen

readEither :: forall left right. (IsForeign left, IsForeign right) => Foreign -> F (Either left right)
readEither a = (Left <$> read a) <|> (Right <$> read a)

readEitherNU :: forall left right. (IsForeign left, IsForeign right) => NullOrUndefined Foreign -> F (NullOrUndefined (Either left right))
readEitherNU a @ (NullOrUndefined Nothing) = pure (NullOrUndefined Nothing)
readEitherNU (NullOrUndefined (Just a)) = (NullOrUndefined <<< Just) <$> readEither a

foreign import expandGlob :: String -> (Array String)

foreign import camelcaseFn :: String -> String
