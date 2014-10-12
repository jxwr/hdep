module Main where

import Parser
import Core
import Typecheck

main = do 
  f <- readFile "test.hdep"
  let Right defs = parseFile f
  print defs
  let ctxt = checkProgram [] defs
  print ctxt
