{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

{-|
Given an instantiated Technique Procedure, evalutate it at runtime.
-}
-- At present this is a proof of concept. It might benefit from being
-- converted to a typeclass in the tagless final style.
module Technique.Evaluator where

import Control.Monad (foldM, liftM)
import Control.Monad.Except (MonadError(..))
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Reader.Class (MonadReader(..))
import Control.Monad.Trans.Class (MonadTrans, lift)
import Control.Monad.Trans.Except (Except(), runExceptT)
import Control.Monad.Trans.Reader (ReaderT(..))
import Core.Data
import Core.Text
import Core.Program
import Core.System (liftIO)
import Data.UUID.Types (UUID, nil)

import Technique.Failure
import Technique.Internal
import Technique.Language

{-|
In order to execute a Procedure we need to supply a context: an identifier
for the event (collection of procedure calls) it is a part of, and the path
history we took to get here.
-}
-- TODO values needs to be somewhere, but here?
data Unique = Unique
    { uniqueEvent :: UUID
    , uniquePath :: Rope -- or a  list or a fingertree or...
    , uniqueValues :: Map Name Promise -- TODO this needs to evolve to IVars or equivalent
    }

emptyUnique :: Unique
emptyUnique = Unique
    { uniqueEvent = nil
    , uniquePath = "/"
    , uniqueValues = emptyMap
    }

{-
data Expression b where
    Binding :: Variable b -> Expression a -> Expression b
    Comment :: Rope -> Expression ()
    Declaration :: (a -> b) -> Expression (a -> b)
    Application :: Expression (a -> b) -> Expression a -> Expression b 
    Attribute :: Role -> Expression a -> Expression a
-}

-- Does this need to upgrade to a MonadEvaluate mtl style class in order to
-- support different interpeters / backends? This seems so cumbersome
-- compared to the elegent tagless final method.

{-|
A monad in which to run an abstract Procedure.
-}
-- Ideally accessing the internals of the Program monad (the Context type)
-- would not be necessary - or at least confined to the core-program
-- library. It is exposed, sure, but having to explicitly weave it into the
-- type of Evaluate in order to have it available to use in liftProgram' is
-- a bit messy.
newtype Evaluate a = Evaluate (ReaderT (Unique,Context None) (Program None) a)
    deriving (Functor, Applicative, Monad, MonadIO, MonadReader (Unique,Context None))

{-|
Given an initial context and a fully-translated ready-to-evaluate
'Evaluate' action, execute it in the 'Program' monad.
-}
runEvaluate :: Unique -> Evaluate a -> Program None a
runEvaluate unique (Evaluate action) = do
    context <- getContext
    runReaderT action (unique,context)
{-# INLINE runEvaluate #-}

liftProgram' :: Program None a -> Evaluate a
liftProgram' program = do
    (_,context) <- ask
    liftIO $ subProgram context program

{-|
Take a fully resolved abstract syntax tree representation and lift it into
the Evaluate monad ready for binding with a context so it is able to be
evaluated.

The type of a technique is the type of the first top-level procedure
defined in the file.
-}
evaluateExecutable :: Executable -> Value -> Evaluate Value
evaluateExecutable abstract  value = do
    let initial = entryPoint abstract
    case initial of
        Nothing -> error "No function?!?"
        Just func -> functionApplication func value

{-|
The heart of the evaluation loop. Translate from the abstract syntax tree 
into a monadic sequence which results in a Value.
-}
evaluateStep :: Step -> Evaluate Value
evaluateStep step = case step of
    Known _ value -> do
        return value

    Depends _ name -> do
        blockUntilValue name

    Tuple _ steps -> do
        values <- traverse evaluateStep steps
        return (Parametriq values)

    Asynchronous _ names substep -> do
        promise <- assignNames names substep
        undefined -- TODO put promise into environment

-- TODO do something with role!

    Invocation _ attr func substep -> do
        value <- evaluateStep substep
        functionApplication func value

-- FIXME this doesn't make sense. Unitus is neither null nor Nothing. The
-- semantics of NoOp need tidying up.

    NoOp -> return Unitus

    Bench _ pairs -> do
        values <- mapM f pairs
        return (Tabularum values)
      where
         f :: (Label,Step) -> Evaluate (Label,Value)
         f (label,substep) = do
            value <- evaluateStep substep
            assignLabel label value

-- Again we're using Unitus as the empty value. This is probably wrong.

    Nested _ substeps -> do
        final <- foldM g Unitus substeps
        return final
      where
        g :: Value -> Step -> Evaluate Value
        g _ substep = do
            value <- evaluateStep substep
            return value


functionApplication :: Function -> Value -> Evaluate Value --  IO Promise ?
functionApplication func value = case func of
    -- TODO no this isn't right. runEvaluate to create a sub scope?

    -- HERE the value is the input parameter; it had a name, but does it now? Does it need one?

    Subroutine _ step -> do
        -- TODO HERE put value into Context?!?
        evaluateStep step

    Primitive _ action -> liftProgram' (action value)

    -- TODO This should be unreachable if we indeed completed the
    -- translation phase. But nothing guarantees that yet.
    Unresolved _ -> error (show func)


blockUntilValue :: Name -> Evaluate Value
blockUntilValue = undefined

{-|
Take a step and lauch it asynchronously, binding its result to a name.
Returns a promise of a value that can be in evaluated (block on) when
needed.
-}
assignNames :: [Name] -> Step -> Evaluate Promise
assignNames = do
    -- dunno
    return (undefined) -- fixme not empty list

assignLabel :: Label -> Value -> Evaluate (Label,Value)
assignLabel label value = do
    -- TODO log event
    return (label,value)
