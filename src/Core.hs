{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies #-}

module Core where

import Control.Monad.State

data Option = SetInSet
            | CheckConv
  deriving Eq

data Name = UN [String]
          | MN Int String
  deriving (Show, Eq)

data Raw = Var Name
         | RBind Name (Binder Raw) Raw
         | RApp Raw Raw
         | RSet Int
  deriving Show

data Binder b = Lam   { binderTy  :: b }
              | Pi    { binderTy  :: b }
              | Let   { binderTy  :: b,
                        binderVal :: b }
              | Hole  { binderTy  :: b}
              | Guess { binderTy  :: b,
                        binderVal :: b }
              | PVar  { binderTy  :: b }
  deriving (Show, Eq)

data RawFun = RawFun { rtype :: Raw,
                       rval  :: Raw
                     }
  deriving Show

data RDef = RFunction RawFun
          | RConst Raw
  deriving Show

type RProgram = [(Name, RDef)]

data NameType = Ref | DCon Int Int | TCon Int
  deriving (Show, Eq)

data TT n = P NameType n (TT n) -- embed type
          | V Int 
          | Bind n (Binder (TT n)) (TT n)
          | App (TT n) (TT n) (TT n) -- function, function type, arg
          | Set Int
  deriving (Show, Eq)

type EnvTT n = [(n, Binder (TT n))]

bindEnv :: EnvTT n -> TT n -> TT n
bindEnv [] tm = tm
bindEnv ((n, b):bs) tm = Bind n b (bindEnv bs tm)

type Term = TT Name
type Type = Term

type Env  = EnvTT Name

data HTT = HP NameType Name HTT
         | HV Int
         | HBind Name (Binder HTT) (HTT -> HTT)
         | HApp HTT HTT HTT
         | HSet Int
         | HTmp Int

instance Show HTT where
    show h = "<<HOAS>>"

hoas :: [HTT] -> TT Name -> HTT
hoas env (P nt n ty) = HP nt n (hoas env ty)
hoas env (V i) | i < length env = env!!i
               | otherwise = HV i
hoas env (Bind n b sc) = HBind n (hbind b) (\x -> hoas (x:env) sc)
  where hbind (Lam t)  = Lam (hoas env t)
        hbind (Pi t)   = Pi (hoas env t)
        hbind (Hole t) = Hole (hoas env t)
        hbind (PVar t) = PVar (hoas env t)
        hbind (Let v t)   = Let (hoas env v) (hoas env t)
        hbind (Guess v t) = Guess (hoas env v) (hoas env t)
hoas env (App f t a) = HApp (hoas env f) (hoas env t) (hoas env a)
hoas env (Set i) = HSet i

-- contexts --

data Fun = Fun Type HTT Term HTT
  deriving Show

data Def = Function Fun
         | Constant NameType Type HTT
  deriving Show

type Context = [(Name, Def)]

lookupTy :: Name -> Context -> Maybe Type
lookupTy n ctxt = do def <-  lookup n ctxt
                     case def of
                       (Function (Fun ty _ _ _)) -> return ty
                       (Constant _ ty _) -> return ty

lookupP :: Name -> Context -> Maybe Term
lookupP n ctxt 
   = do def <-  lookup n ctxt
        case def of
          (Function (Fun ty _ tm _)) -> return (P Ref n ty)
          (Constant nt ty hty) -> return (P nt n ty)

lookupVal :: Name -> Context -> Maybe HTT
lookupVal n ctxt 
   = do def <- lookup n ctxt
        case def of
          (Function (Fun _ _ _ htm)) -> return htm
          (Constant nt ty hty) -> return (HP nt n hty)

lookupTyEnv :: Name -> Env -> Maybe (Int, Type)
lookupTyEnv n env = li n 0 env where
  li n i []           = Nothing
  li n i ((x, b): xs) 
             | n == x = Just (i, binderTy b)
             | otherwise = li n (i+1) xs


x = UN ["x"]
xt = UN ["X"]
testtm = RBind xt (Lam (RSet 0)) (RBind x (Lam (Var xt)) (Var x))
