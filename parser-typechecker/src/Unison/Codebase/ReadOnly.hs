{-# LANGUAGE PartialTypeSignatures #-}
{-# OPTIONS_GHC -Wno-partial-type-signatures #-}
{-# LANGUAGE ViewPatterns #-}

module Unison.Codebase.ReadOnly where

import qualified Unison.Reference as Reference
import qualified Unison.Referent as Referent
import qualified Unison.UnisonFile as UF
import qualified Unison.Codebase.Branch as Branch
import qualified Unison.Util.Monoid as Monoid
import Unison.Term (Term)
import Unison.Type (Type)
import qualified Unison.Type as Type
import Unison.DataDeclaration (Decl)
import qualified Unison.DataDeclaration as DD
import qualified Data.Map as Map
import Data.Map (Map)
import Data.Set (Set)
import Data.Trie (Trie)
import qualified Data.Trie as Trie
import Unison.ShortHash (ShortHash)
import Unison.Codebase.ShortBranchHash (ShortBranchHash)
import Unison.Codebase.Branch (Branch)
import Data.Foldable (toList)
import Control.Lens (view, _1)
import Debug.Trace (trace)
import Unison.Util.Relation (Relation)
import qualified Unison.Util.Relation as Relation
import qualified Unison.ConstructorType as CT
import Unison.Var (Var)
import Data.ByteString (ByteString)
import Data.Text.Encoding (encodeUtf8)
import Unison.Reference (Reference)
import Unison.Hash as Hash
import qualified Data.Set as Set
import qualified Unison.ShortHash as SH

-- a read-only codebase
data Codebase m v a = Codebase
  { getTerm :: Reference.Id -> m (Maybe (Term v a))
  , getTypeOfTermImpl :: Reference.Id -> m (Maybe (Type v a))
  , getTypeDeclaration :: Reference.Id -> m (Maybe (Decl v a))
  , getBranchForHash   :: Branch.Hash -> m (Maybe (Branch m))
  , dependentsImpl :: Reference -> m (Set Reference.Id)
  , watches :: UF.WatchKind -> m [Reference.Id]
  , getWatch :: UF.WatchKind -> Reference.Id -> m (Maybe (Term v a))
  , termsOfTypeImpl :: Reference -> m (Set Referent.Id)
  , termsMentioningTypeImpl :: Reference -> m (Set Referent.Id)
  , hashLength :: m Int
  , termReferencesByPrefix :: ShortHash -> m (Set Reference.Id)
  , typeReferencesByPrefix :: ShortHash -> m (Set Reference.Id)
  , termReferentsByPrefix :: ShortHash -> m (Set Referent.Id)
  , branchHashLength :: m Int
  , branchHashesByPrefix :: ShortBranchHash -> m (Set Branch.Hash)
  }

fromTypechecked :: forall m v a.
  (Applicative m, Var v, Show v) => [UF.TypecheckedUnisonFile v a] -> Codebase m v a
fromTypechecked files =  Codebase
  { getTerm = pure . flip Map.lookup terms
  , getTypeOfTermImpl = pure . flip Map.lookup typeOfTerms
  , getTypeDeclaration = pure . flip Map.lookup typeDeclarations
  , getBranchForHash = const (pure Nothing)
  , dependentsImpl = error "todo: ReadOnly.dependentsImpl"
  , watches = pure . toList . Map.keysSet . Monoid.fromMaybe . flip Map.lookup watches
  , getWatch = \k r -> pure . Map.lookup r . Monoid.fromMaybe $ Map.lookup k watches
  , termsOfTypeImpl = pure . flip Relation.lookupDom termsOfType
  , termsMentioningTypeImpl = error "todo: ReadOnly.termsMentioningTypeImpl"
  , hashLength = pure 10
  , termReferencesByPrefix = \sh ->
      pure
      . Set.filter ( SH.isPrefixOf sh
                   . Reference.toShortHash
                   . Reference.DerivedId )
      . mconcat
      . Trie.elems
      . findHash sh
      $ termsTrie
  , typeReferencesByPrefix = \sh ->
      pure
      . Set.filter ( SH.isPrefixOf sh
                   . Reference.toShortHash
                   . Reference.DerivedId )
      . mconcat
      . Trie.elems
      . findHash sh
      $ typesTrie
  , termReferentsByPrefix = \sh ->
      pure
      . Set.filter ( SH.isPrefixOf sh
                   . Referent.toShortHash
                   . fmap Reference.DerivedId )
      . mconcat
      . Trie.elems
      . findHash sh
      $ referentsTrie
  , branchHashLength = pure 10
  , branchHashesByPrefix = error "todo: ReadOnly.branchHashesByPrefix"
  }
  where
  findHash :: ShortHash -> Trie b -> Trie b
  findHash sh@SH.ShortHash{} = Trie.submap . encodeUtf8 $ SH.prefix sh
  findHash SH.Builtin{} = const Trie.empty
  terms :: Map Reference.Id (Term v a)
  typeOfTerms :: Map Reference.Id (Type v a)
  (terms, typeOfTerms) = foldMap doFile files where
    doFile = foldMap doTerm . UF.hashTermsId
    doTerm (id, tm, tp) = (Map.singleton id tm, Map.singleton id tp)
  termsOfType :: Relation Reference Referent.Id
  termsOfType = foldMap doFile files where
    -- Semigroup a => Semigroup (x -> a)
    doFile = foldMap doTerm . UF.hashTermsId
           <> foldMap (doCtor CT.Data id) . UF.dataDeclarationsId'
           <> foldMap (doCtor CT.Effect DD.toDataDecl) . UF.effectDeclarationsId'
    doTerm :: (Reference.Id, Term v a, Type v a)
           -> Relation Reference Referent.Id
    doTerm (id, _tm, tp) =
        Relation.singleton (Type.toReference tp) (Referent.Ref' id)
    doCtor :: CT.ConstructorType
           -> (x -> DD.DataDeclaration' v a)
           -> (Reference.Id, x)
           -> Relation Reference Referent.Id
    doCtor ct f (id, dd) =
      Relation.fromList [ (Type.toReference tp, Referent.Con' id i ct)
                        | (i,(_, _, tp)) <- [0..] `zip` DD.constructors' (f dd)]
  typeDeclarations :: Map Reference.Id (Decl v a)
  typeDeclarations = foldMap doFile files where
    doFile = foldMap doDatas . UF.dataDeclarationsId'
           <> foldMap doEffects . UF.effectDeclarationsId'
    doDatas (id, dd) = Map.singleton id (Right dd)
    doEffects (id, ed) = Map.singleton id (Left ed)
  watches :: Map UF.WatchKind (Map Reference.Id (Term v a))
  watches = foldMap doFile files where
    doFile uf = foldMap doComponent (UF.watchComponents uf) where
      doComponent :: (UF.WatchKind, [(v, _, _)])
                  -> Map UF.WatchKind (Map Reference.Id (Term v a))
      doComponent (k, elems) = let
        vs = fmap (view _1) elems
        terms :: [(Reference.Id, Term v a)]
        terms = vs >>= \v -> case Map.lookup v (UF.hashTermsId uf) of
          Just (r, tm, _tp) -> [(r, tm)]
          Nothing -> trace ("UF.watchComponents contained a var ("
              ++ show v ++ ") which wasn't in UF.hashTermsId.") []
        in Map.singleton k (Map.fromList terms)
  -- `Trie Reference.Id` won't work, because Reference.Id has some relevant
  -- suffix stuff too.  (A `Trie Hash` would work, if we were just looking up
  -- hashes, but we aren't.) So, we'll look up a `Set Reference.Id` (or `Set
  -- Referent.Id`) by Hash!
  termsTrie :: Trie (Set Reference.Id)
  typesTrie :: Trie (Set Reference.Id)
  referentsTrie :: Trie (Set Referent.Id)
  (termsTrie, typesTrie) =
    ( Trie.fromList . map idToBS $ Map.keys terms
    , Trie.fromList . map idToBS $ Map.keys typeDeclarations )
    where
    idToBS :: Reference.Id -> (ByteString, Set Reference.Id)
    idToBS r@(Reference.Id h _ _) =
      (encodeUtf8 (Hash.base32Hex h), Set.singleton r)
  referentsTrie =
    fmap (Set.map Referent.Ref') termsTrie <>
      Trie.fromList (Map.toList typeDeclarations >>= conBS)
    where
    conBS :: (Reference.Id, DD.Decl v a) -> [(ByteString, Set Referent.Id)]
    conBS (r, d) = fmap idToBS (DD.declConstructorReferents r d)
    idToBS :: Referent.Id -> (ByteString, Set Referent.Id)
    idToBS rtid@(Referent.toReference' -> Reference.Id h _ _) =
      (encodeUtf8 (Hash.base32Hex h), Set.singleton rtid)


--fuse :: forall m v a. Monad m => Codebase m v a -> C.Codebase m v a -> C.Codebase m v a
--fuse ro rw = C.Codebase
--  { C.getTerm = firstOf (getTerm ro) (C.getTerm rw)
--  , C.getTypeOfTermImpl = firstOf (getTypeOfTermImpl ro) (C.getTypeOfTermImpl rw)
--  , C.getTypeDeclaration = firstOf (getTypeDeclaration ro) (C.getTypeDeclaration rw)
--  , C.putTerm = C.putTerm rw
--  , C.putTypeDeclaration = C.putTypeDeclaration rw
--  , C.getRootBranch = C.getRootBranch rw
--  , C.putRootBranch = C.putRootBranch rw
--  , C.rootBranchUpdates = C.rootBranchUpdates rw
--  , C.getBranchForHash = firstOf (getBranchForHash ro) (C.getBranchForHash rw)
--  , C.dependentsImpl = unionOf (dependentsImpl ro) (C.dependentsImpl rw)
--  , C.watches = unionOf (watches ro) (C.watches rw)
--  , C.getWatch = \t -> firstOf (getWatch ro t) (C.getWatch rw t)
--  , C.putWatch = C.putWatch rw
--  , C.getReflog = C.getReflog rw
--  , C.appendReflog = C.appendReflog rw
--  , C.termsOfTypeImpl = unionOf (termsOfTypeImpl ro) (C.termsOfTypeImpl rw)
--  , C.termsMentioningTypeImpl = unionOf (termsMentioningTypeImpl ro) (C.termsMentioningTypeImpl rw)
--  , C.termReferentsByPrefix = unionOf (termReferentsByPrefix ro) (C.termReferentsByPrefix rw)
--  , C.termReferencesByPrefix = unionOf (termReferencesByPrefix ro) (C.termReferencesByPrefix rw)
--  , C.typeReferencesByPrefix = unionOf (typeReferencesByPrefix ro) (C.typeReferencesByPrefix rw)
--  , C.branchHashesByPrefix = unionOf (branchHashesByPrefix ro) (C.branchHashesByPrefix rw)
--  , C.hashLength = pure 10 -- would have to combine two tries; `max` won't cut it
--  , C.branchHashLength = pure 10 -- same thing
--  , C.syncFromDirectory = error "delete me"
--  , C.syncToDirectory = error "delete me"
--  }
--  where
--  firstOf a b i =
--    a i >>= maybe (b i) (pure . Just)
--  unionOf a b i = (<>) <$> a i <*> b i