{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

{-|
This is the beginnings of the standard library.
-}
-- Do these need descriptions? Not really, unless this becomes a form of
-- online help. Such text would not be used in overviews, so we'll see if
-- we ever need them.
module Technique.Builtins where

import Core.Data.Structures
import Core.Program.Execute (Program, None)
import Core.Program.Logging (writeR)
import Core.Text.Rope ()

import Technique.Diagnostics ()
import Technique.Internal
import Technique.Language

builtinProcedures :: Map Identifier Function
builtinProcedures = intoMap (fmap (\p -> (functionName p, p))
    [ builtinProcedureWaitEither
    , builtinProcedureWaitBoth
    , builtinProcedureCombineValues
    , builtinProcedureTask
    , builtinProcedureRecord
    ])

placeholder :: Value -> Program None Value
placeholder value = do
    writeR value
    return value

builtinProcedureTask :: Function
builtinProcedureTask = Primitive
    emptyProcedure
        { procedureName = Identifier "task"
        , procedureInput = [Type "Text"]
        , procedureOutput = [Type "()"] -- ?
        , procedureTitle = Just (Markdown "Task")
        , procedureDescription = Just (Markdown "A task to be executed by the person carrying out this role.")
        }
    placeholder

builtinProcedureRecord :: Function
builtinProcedureRecord = Primitive
    emptyProcedure
        { procedureName = Identifier "record"
        , procedureInput = [Type "Text"]
        , procedureOutput = [Type "Text"] -- ?
        , procedureTitle = Just (Markdown "Record")
        , procedureDescription = Just (Markdown "Input from the user to be parsed as a quantity.")
        }
    placeholder

-- the '|' operation
builtinProcedureWaitEither :: Function
builtinProcedureWaitEither = Primitive
    emptyProcedure
        { procedureName = Identifier "wait_either"
        , procedureInput = [Type "*", Type "*"]
        , procedureOutput = [Type "()"]
        , procedureTitle = Just (Markdown "Wait Either")
        , procedureDescription = Just (Markdown "Wait for either of two values to be ready.")
        }
    placeholder

-- the '&' operation
builtinProcedureWaitBoth :: Function
builtinProcedureWaitBoth = Primitive
    emptyProcedure
        { procedureName = Identifier "wait_both"
        , procedureInput = [Type "*", Type "*"]
        , procedureOutput = [Type "()"]
        , procedureTitle = Just (Markdown "Wait Both")
        , procedureDescription = Just (Markdown "Wait for two values to both be ready.")
        }
    placeholder

-- the '+' operation
builtinProcedureCombineValues :: Function
builtinProcedureCombineValues = Primitive
    emptyProcedure
        { procedureName = Identifier "combine_values"
        , procedureInput = [Type "*", Type "*"]
        , procedureOutput = [Type "*"]
        , procedureTitle = Just (Markdown "Combine Two Values")
        , procedureDescription = Just (Markdown "Combine two values. This will involve coersion if the concrete types differ.")
        }
    placeholder
