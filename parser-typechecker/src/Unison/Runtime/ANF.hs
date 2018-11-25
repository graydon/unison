{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE ViewPatterns #-}
{-# Language OverloadedStrings #-}
{-# Language PatternSynonyms #-}
{-# Language ScopedTypeVariables #-}

module Unison.Runtime.ANF (optimize, fromTerm, fromTerm', term) where

import Data.Foldable hiding (and,or)
import Data.List hiding (and,or)
import Prelude hiding (abs,and,or)
import Unison.Term
import Unison.Var (Var)
import qualified Data.Map as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import qualified Unison.ABT as ABT
import qualified Unison.Term as Term
import qualified Unison.Var as Var

newtype ANF v a = ANF_ { term :: Term.AnnotatedTerm v a }
-- Replace all lambdas with free variables with closed lambdas.
-- Works by adding a parameter for each free variable. These
-- synthetic parameters are added before the existing lambda params.
-- For example, `(x -> x + y + z)` becomes `(y z x -> x + y + z) y z`.
-- As this replacement has the same type as the original lambda, it
-- can be done as a purely local transformation, without updating any
-- call sites of the lambda.
--
-- The transformation is shallow and doesn't look inside lambdas.
lambdaLift :: (Ord v, Semigroup a) => AnnotatedTerm v a -> AnnotatedTerm v a
lambdaLift t = ABT.visitPure go t where
  go t@(LamsNamed' vs body) = Just $ let
    fvs = ABT.freeVars t
    a = ABT.annotation t
    in if Set.null fvs then lam' a vs body -- `lambdaLift body` would make transform deep
       else apps' (lam' a (toList fvs ++ vs) body)
                  (var a <$> toList fvs)
  go _ = Nothing

optimize :: forall a v . (Semigroup a, Var v) => AnnotatedTerm v a -> AnnotatedTerm v a
optimize t = go t where
  ann = ABT.annotation
  go (Let1' b body) | canSubstLet b body = go (ABT.bind body b)
  go e@(App' f arg) = case go f of
    Lam' f -> go (ABT.bind f arg)
    f -> app (ann e) f (go arg)
  go (If' (Boolean' False) _ f) = go f
  go (If' (Boolean' True) t _) = go t
  -- todo: can simplify match expressions
  go e@(ABT.Var' _) = e
  go e@(ABT.Tm' f) = case e of
    Lam' _ -> e -- optimization is shallow - don't descend into lambdas
    _ -> ABT.tm' (ann e) (go <$> f)
  go e@(ABT.out -> ABT.Cycle body) = ABT.cycle' (ann e) (go body)
  go e@(ABT.out -> ABT.Abs v body) = ABT.abs' (ann e) v (go body)
  go e = e

  -- test for whether an expression `let x = y in body` can be
  -- reduced by substituting `y` into `body`. We only substitute
  -- when `y` is a variable or a primitive, otherwise this might
  -- end up duplicating evaluation or changing the order that
  -- effects are evaluated
  canSubstLet (Var' _) _body = True
  canSubstLet (Int' _) _body = True
  canSubstLet (Float' _) _body = True
  canSubstLet (Nat' _) _body = True
  canSubstLet (Boolean' _) _body = True
  -- todo: if number of occurrences of the binding is 1 and the
  -- binding is pure, okay to substitute
  canSubstLet _ _ = False

fromTerm' :: (Semigroup a, Var v) => AnnotatedTerm v a -> AnnotatedTerm v a
fromTerm' t = term (fromTerm t)

fromTerm :: forall a v . (Semigroup a, Var v) => AnnotatedTerm v a -> ANF v a
fromTerm t = ANF_ (go $ lambdaLift t) where
  ann = ABT.annotation
  isVar (Var' _) = True
  isVar _ = False
  isRef (Ref' _) = True
  isRef _ = False
  fixAp t f args = let
    args' = Map.fromList $ toVar =<< (args `zip` [0..])
    toVar (b, i) | isVar b   = []
                 | otherwise = [(i, ABT.fresh t (Var.named . Text.pack $ "arg" ++ show i))]
    argsANF = map toANF (args `zip` [0..])
    toANF (b,i) = maybe b (var (ann b)) $ Map.lookup i args'
    addLet (b,i) body = maybe body (\v -> let1' False [(v,go b)] body) (Map.lookup i args')
    in foldr addLet (apps' f argsANF) (args `zip` [(0::Int)..])
  go :: AnnotatedTerm v a -> AnnotatedTerm v a
  go e@(Apps' f args)
    | (isRef f || isVar f) && all isVar args = e
    | not (isRef f || isVar f) =
      let f' = ABT.fresh e (Var.named "f")
      in let1' False [(f', go f)] (go $ apps' (var (ann f) f') args)
    | otherwise = fixAp t f args
  go e@(Handle' h body)
    | isVar h = handle (ann e) h (go body)
    | otherwise = let h' = ABT.fresh e (Var.named "handler")
                  in let1' False [(h', go h)] (handle (ann e) (var (ann h) h') (go body))
  go e@(If' cond t f)
    | isVar cond = iff (ann e) cond (go t) (go f)
    | otherwise = let cond' = ABT.fresh e (Var.named "cond")
                  in let1' False [(cond', go cond)] (iff (ann e) (var (ann cond) cond') (go t) (go f))
  go e@(Match' scrutinee cases)
    | isVar scrutinee = match (ann e) scrutinee (fmap go <$> cases)
    | otherwise = let scrutinee' = ABT.fresh e (Var.named "scrutinee")
                  in let1' False [(scrutinee', go scrutinee)] (match (ann e) (var (ann scrutinee) scrutinee') cases)
  go e@(And' x y)
    | isVar x = and (ann e) x (go y)
    | otherwise =
        let x' = ABT.fresh e (Var.named "argX")
        in let1' False [(x', go x)] (and (ann e) (var (ann x) x') (go y))
  go e@(Or' x y)
    | isVar x = or (ann e) x (go y)
    | otherwise =
        let x' = ABT.fresh e (Var.named "argX")
        in let1' False [(x', go x)] (or (ann e) (var (ann x) x') (go y))
  go e@(ABT.Tm' f) = case e of
    Lam' _ -> e -- ANF conversion is shallow - don't descend into closed lambdas
    _ -> ABT.tm' (ann e) (go <$> f)
  go e@(ABT.Var' _) = e
  go e@(ABT.out -> ABT.Cycle body) = ABT.cycle' (ann e) (go body)
  go e@(ABT.out -> ABT.Abs v body) = ABT.abs' (ann e) v (go body)
  go e = e

