{-# LANGUAGE FlexibleInstances #-}
module Test where

import Control.Monad (forM_)
import Layout2
import Lexer2
import Parser2
import Core
import TransformationMonad
import Types
import Aux

a :: IO ()
a = do
  tx <- readFile "test/test"
  let tks = tokenize tx
      tks' = layout tks
      Right expr = parse' tks'
      transformation = do
        storeDataInState expr
        storeCoreInState expr
        putDataDefsInState
        putFunctionTypesInState
        c <- getCore
        debug "!!!!!!!!!"
        debugs c
        x <- getCFuncTypes
        debug "AAAAAAAAA"
        debugs x
        a <- typeCheck
        debugs "TYPECHECK"
        debugs a
      st = runTM transformation
  putStrLn "TOKENS"
  print tks
  putStrLn "LAYOUT TOKENS"
  print tks'
  putStrLn "EXPR"
  print expr
  putStrLn "CORE"
  showE st

showE :: TState -> IO ()
showE state = do
  forM_ (reverse (tLogs state)) $ \log -> case log of
    TLogErr terr _ -> putStrLn $ show terr
    --TLogDebug msg _ -> putStrLn msg
    _ -> return ()

