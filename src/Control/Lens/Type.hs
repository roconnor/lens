{-# LANGUAGE CPP #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE LiberalTypeSynonyms #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}

#ifndef MIN_VERSION_mtl
#define MIN_VERSION_mtl(x,y,z) 1
#endif

-------------------------------------------------------------------------------
-- |
-- Module      :  Control.Lens.Type
-- Copyright   :  (C) 2012 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  Rank2Types
--
-- A @'Lens' a b c d@ is a purely functional reference.
--
-- While a 'Control.Lens.Traversal.Traversal' could be used for
-- 'Control.Lens.Getter.Getting' like a valid 'Control.Lens.Fold.Fold',
-- it wasn't a valid 'Control.Lens.Getter.Getter' as 'Applicative' wasn't a superclass of
-- 'Control.Lens.Getter.Gettable'.
--
-- 'Functor', however is the superclass of both.
--
-- @type 'Lens' a b c d = forall f. 'Functor' f => (c -> f d) -> a -> f b@
--
-- Every 'Lens' is a valid 'Setter', choosing @f@ =
-- 'Control.Lens.Getter.Mutator'.
--
-- Every 'Lens' can be used for 'Control.Lens.Getter.Getting' like a
-- 'Control.Lens.Fold.Fold' that doesn't use the 'Applicative' or
-- 'Control.Lens.Getter.Gettable'.
--
-- Every 'Lens' is a valid 'Control.Lens.Traversal.Traversal' that only uses
-- the 'Functor' part of the 'Applicative' it is supplied.
--
-- Every 'Lens' can be used for 'Control.Lens.Getter.Getting' like a valid
-- 'Control.Lens.Getter.Getter', since 'Functor' is a superclass of 'Control.Lens.Getter.Gettable'
--
-- Since every 'Lens' can be used for 'Control.Lens.Getter.Getting' like a
-- valid 'Control.Lens.Getter.Getter' it follows that it must view exactly one element in the
-- structure.
--
-- The lens laws follow from this property and the desire for it to act like
-- a 'Data.Traversable.Traversable' when used as a
-- 'Control.Lens.Traversal.Traversal'.
-------------------------------------------------------------------------------
module Control.Lens.Type
  (
  -- * Lenses
    Lens
  , Simple
  , lens
  , (%%~)
  , (%%=)

  , resultAt

  -- * Lateral Composition
  , merged
  , alongside

  -- * Setting Functionally with Passthrough
  , (<%~), (<+~), (<-~), (<*~), (<//~)
  , (<^~), (<^^~), (<**~)
  , (<||~), (<&&~)

  -- * Setting State with Passthrough
  , (<%=), (<+=), (<-=), (<*=), (<//=)
  , (<^=), (<^^=), (<**=)
  , (<||=), (<&&=)

  -- * Cloning Lenses
  , cloneLens

  -- * Simplified and In-Progress
  , LensLike
  , Overloaded
  , SimpleLens
  , SimpleLensLike
  , SimpleOverloaded
  ) where

import Control.Applicative              as Applicative
import Control.Lens.Internal
import Control.Monad.State.Class        as State

infixr 4 %%~
infix  4 %%=
infixr 4 <+~, <*~, <-~, <//~, <^~, <^^~, <**~, <&&~, <||~, <%~
infix  4 <+=, <*=, <-=, <//=, <^=, <^^=, <**=, <&&=, <||=, <%=


-------------------------------------------------------------------------------
-- Lenses
-------------------------------------------------------------------------------

-- | A 'Lens' is actually a lens family as described in
-- <http://comonad.com/reader/2012/mirrored-lenses/>.
--
-- With great power comes great responsibility and a 'Lens'is subject to the
-- three common sense lens laws:
--
-- 1) You get back what you put in:
--
-- @'Control.Lens.Getter.view' l ('Control.Lens.Setter.set' l b a)  = b@
--
-- 2) Putting back what you got doesn't change anything:
--
-- @'Control.Lens.Setter.set' l ('Control.Lens.Getter.view' l a) a  = a@
--
-- 3) Setting twice is the same as setting once:
--
-- @'Control.Lens.Setter.set' l c ('Control.Lens.Setter.set' l b a) = 'Control.Lens.Setter.set' l c a@
--
-- These laws are strong enough that the 4 type parameters of a 'Lens' cannot
-- vary fully independently. For more on how they interact, read the "Why is
-- it a Lens Family?" section of
-- <http://comonad.com/reader/2012/mirrored-lenses/>.
--
-- Every 'Lens' can be used directly as a 'Setter' or
-- 'Control.Lens.Traversal.Traversal'.
--
-- You can also use a 'Lens' for 'Control.Lens.Getter.Getting' as if it were a
-- 'Control.Lens.Fold.Fold' or 'Control.Lens.Getter.Getter'.
--
-- Since every lens is a valid 'Control.Lens.Traversal.Traversal', the
-- traversal laws should also apply to any lenses you create.
--
-- @
-- l 'pure' = 'pure'
-- 'fmap' (l f) . l g = 'Data.Functor.Compose.getCompose' . l ('Data.Functor.Compose.Compose' . 'fmap' f . g)
-- @
--
-- @type 'Lens' a b c d = forall f. 'Functor' f => 'LensLike' f a b c d@
type Lens a b c d = forall f. Functor f => (c -> f d) -> a -> f b

-- | A 'Simple' 'Lens', 'Simple' 'Control.Lens.Traversal.Traversal', ... can
-- be used instead of a 'Lens','Control.Lens.Traversal.Traversal', ...
-- whenever the type variables don't change upon setting a value.
--
-- @
-- 'Data.Complex.Lens.imaginary' :: 'Simple' 'Lens' ('Data.Complex.Complex' a) a
-- 'Data.List.Lens.traverseHead' :: 'Simple' 'Control.Lens.Lens.Traversal' [a] a
-- @
--
-- Note: To use this alias in your own code with @'LensLike' f@ or
-- 'Control.Lens.Setter.Setter', you may have to turn on @LiberalTypeSynonyms@.
type Simple f a b = f a a b b

-- | @type 'SimpleLens' = 'Simple' 'Lens'@
type SimpleLens a b = Lens a a b b

-- | @type 'SimpleLensLike' f = 'Simple' ('LensLike' f)@
type SimpleLensLike f a b = LensLike f a a b b

--------------------------
-- Constructing Lenses
--------------------------

-- | Build a 'Lens' from a getter and a setter.
--
-- > lens :: Functor f => (a -> c) -> (a -> d -> b) -> (c -> f d) -> a -> f b
lens :: (a -> c) -> (a -> d -> b) -> Lens a b c d
lens ac adb cfd a = adb a <$> cfd (ac a)
{-# INLINE lens #-}

-------------------------------------------------------------------------------
-- LensLike
-------------------------------------------------------------------------------

-- |
-- Many combinators that accept a 'Lens' can also accept a
-- 'Control.Lens.Traversal.Traversal' in limited situations.
--
-- They do so by specializing the type of 'Functor' that they require of the
-- caller.
--
-- If a function accepts a @'LensLike' f a b c d@ for some 'Functor' @f@,
-- then they may be passed a 'Lens'.
--
-- Further, if @f@ is an 'Applicative', they may also be passed a
-- 'Control.Lens.Traversal.Traversal'.
type LensLike f a b c d = (c -> f d) -> a -> f b

-- | ('%%~') can be used in one of two scenarios:
--
-- When applied to a 'Lens', it can edit the target of the 'Lens' in a
-- structure, extracting a functorial result.
--
-- When applied to a 'Control.Lens.Traversal.Traversal', it can edit the
-- targets of the 'Traversals', extracting an applicative summary of its
-- actions.
--
-- For all that the definition of this combinator is just:
--
-- @('%%~') = 'id'@
--
-- @
-- (%%~) :: 'Functor' f =>     'Control.Lens.Iso.Iso' a b c d       -> (c -> f d) -> a -> f b
-- (%%~) :: 'Functor' f =>     'Lens' a b c d      -> (c -> f d) -> a -> f b
-- (%%~) :: 'Applicative' f => 'Control.Lens.Traversal.Traversal' a b c d -> (c -> f d) -> a -> f b
-- @
--
-- It may be beneficial to think about it as if it had these even more
-- restrictive types, however:
--
-- When applied to a 'Control.Lens.Traversal.Traversal', it can edit the
-- targets of the 'Traversals', extracting a supplemental monoidal summary
-- of its actions, by choosing @f = ((,) m)@
--
-- @
-- (%%~) ::             'Control.Lens.Iso.Iso' a b c d       -> (c -> (e, d)) -> a -> (e, b)
-- (%%~) ::             'Lens' a b c d      -> (c -> (e, d)) -> a -> (e, b)
-- (%%~) :: 'Monoid' m => 'Control.Lens.Traversal.Traversal' a b c d -> (c -> (m, d)) -> a -> (m, b)
-- @
(%%~) :: LensLike f a b c d -> (c -> f d) -> a -> f b
(%%~) = id
{-# INLINE (%%~) #-}

-- | Modify the target of a 'Lens' in the current state returning some extra
-- information of @c@ or modify all targets of a
-- 'Control.Lens.Traversal.Traversal' in the current state, extracting extra
-- information of type @c@ and return a monoidal summary of the changes.
--
-- @('%%=') = ('state' '.')@
--
-- It may be useful to think of ('%%='), instead, as having either of the
-- following more restricted type signatures:
--
-- @
-- (%%=) :: 'MonadState' a m             => 'Control.Lens.Iso.Iso' a a c d       -> (c -> (e, d) -> m e
-- (%%=) :: 'MonadState' a m             => 'Lens' a a c d      -> (c -> (e, d) -> m e
-- (%%=) :: ('MonadState' a m, 'Monoid' e) => 'Control.Lens.Traversal.Traversal' a a c d -> (c -> (e, d) -> m e
-- @
(%%=) :: MonadState a m => LensLike ((,) e) a a c d -> (c -> (e, d)) -> m e
#if MIN_VERSION_mtl(2,1,1)
l %%= f = State.state (l f)
#else
l %%= f = do
  (e, b) <- State.gets (l f)
  State.put b
  return e
#endif
{-# INLINE (%%=) #-}

-------------------------------------------------------------------------------
-- Common Lenses
-------------------------------------------------------------------------------

-- | This lens can be used to change the result of a function but only where
-- the arguments match the key given.
resultAt :: Eq e => e -> Simple Lens (e -> a) a
resultAt e afa ea = go <$> afa a where
  a = ea e
  go a' e' | e == e'   = a'
           | otherwise = a
{-# INLINE resultAt #-}

-- | Merge two lenses, getters, setters, folds or traversals.
merged :: Functor f
       => LensLike f a b c c
       -> LensLike f a' b' c c
       -> LensLike f (Either a a') (Either b b') c c
merged l _ f (Left a)   = Left <$> l f a
merged _ r f (Right a') = Right <$> r f a'
{-# INLINE merged #-}

-- | 'alongside' makes a 'Lens' from two other lenses (or isomorphisms)
alongside :: Lens a b c d
           -> Lens a' b' c' d'
           -> Lens (a,a') (b,b') (c,c') (d,d')
alongside l r f (a, a') = case l (IndexedStore id) a of
  IndexedStore db c -> case r (IndexedStore id) a' of
    IndexedStore db' c' -> (\(d,d') -> (db d, db' d')) <$> f (c,c')
{-# INLINE alongside #-}

-------------------------------------------------------------------------------
-- Cloning Lenses
-------------------------------------------------------------------------------

-- |
-- Cloning a 'Lens' is one way to make sure you arent given
-- something weaker, such as a 'Control.Lens.Traversal.Traversal' and can be
-- used as a way to pass around lenses that have to be monomorphic in @f@.
--
-- Note: This only accepts a proper 'Lens'.
--
-- \"Costate Comonad Coalgebra is equivalent of Java's member variable
-- update technology for Haskell\" -- \@PLT_Borat on Twitter
cloneLens :: Functor f
      => LensLike (IndexedStore c d) a b c d
      -> (c -> f d) -> a -> f b
cloneLens f cfd a = case f (IndexedStore id) a of
  IndexedStore db c -> db <$> cfd c
{-# INLINE cloneLens #-}

-------------------------------------------------------------------------------
-- Overloading function application
-------------------------------------------------------------------------------

-- | @type 'LensLike' f a b c d = 'Overloaded' (->) f a b c d@
type Overloaded k f a b c d = k (c -> f d) (a -> f b)

-- | @type 'SimpleOverloaded' k f a b = 'Simple' ('Overloaded' k f) a b@
type SimpleOverloaded k f a b = Overloaded k f a a b b

-------------------------------------------------------------------------------
-- Setting and Remembering
-------------------------------------------------------------------------------

-- | Modify the target of a 'Lens' and return the result
--
-- When you do not need the result of the addition, ('Control.Lens.Setter.+~') is more flexible.
(<%~) :: LensLike ((,)d) a b c d -> (c -> d) -> a -> (d, b)
l <%~ f = l $ \c -> let d = f c in (d, d)
{-# INLINE (<%~) #-}

-- | Increment the target of a numerically valued 'Lens' and return the result
--
-- When you do not need the result of the addition, ('Control.Lens.Setter.+~') is more flexible.
(<+~) :: Num c => LensLike ((,)c) a b c c -> c -> a -> (c, b)
l <+~ c = l <%~ (+ c)
{-# INLINE (<+~) #-}

-- | Decrement the target of a numerically valued 'Lens' and return the result
--
-- When you do not need the result of the subtraction, ('Control.Lens.Setter.-~') is more flexible.
(<-~) :: Num c => LensLike ((,)c) a b c c -> c -> a -> (c, b)
l <-~ c = l <%~ subtract c
{-# INLINE (<-~) #-}

-- | Multiply the target of a numerically valued 'Lens' and return the result
--
-- When you do not need the result of the multiplication, ('Control.Lens.Setter.*~') is more
-- flexible.
(<*~) :: Num c => LensLike ((,)c) a b c c -> c -> a -> (c, b)
l <*~ c = l <%~ (* c)
{-# INLINE (<*~) #-}

-- | Divide the target of a fractionally valued 'Lens' and return the result.
--
-- When you do not need the result of the division, ('Control.Lens.Setter.//~') is more flexible.
(<//~) :: Fractional c => LensLike ((,)c) a b c c -> c -> a -> (c, b)
l <//~ c = l <%~ (/ c)
{-# INLINE (<//~) #-}

-- | Raise the target of a numerically valued 'Lens' to a non-negative
-- 'Integral' power and return the result
--
-- When you do not need the result of the division, ('Control.Lens.Setter.^~') is more flexible.
(<^~) :: (Num c, Integral d) => LensLike ((,)c) a b c c -> d -> a -> (c, b)
l <^~ d = l <%~ (^ d)
{-# INLINE (<^~) #-}

-- | Raise the target of a fractionally valued 'Lens' to an 'Integral' power
-- and return the result.
--
-- When you do not need the result of the division, ('Control.Lens.Setter.^^~') is more flexible.
(<^^~) :: (Fractional c, Integral d) => LensLike ((,)c) a b c c -> d -> a -> (c, b)
l <^^~ d = l <%~ (^^ d)
{-# INLINE (<^^~) #-}

-- | Raise the target of a floating-point valued 'Lens' to an arbitrary power
-- and return the result.
--
-- When you do not need the result of the division, ('Control.Lens.Setter.**~') is more flexible.
(<**~) :: Floating c => LensLike ((,)c) a b c c -> c -> a -> (c, b)
l <**~ c = l <%~ (** c)
{-# INLINE (<**~) #-}

-- | Logically '||' a Boolean valued 'Lens' and return the result
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.||~') is more flexible.
(<||~) :: LensLike ((,)Bool) a b Bool Bool -> Bool -> a -> (Bool, b)
l <||~ c = l <%~ (|| c)
{-# INLINE (<||~) #-}

-- | Logically '&&' a Boolean valued 'Lens' and return the result
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.&&~') is more flexible.
(<&&~) :: LensLike ((,)Bool) a b Bool Bool -> Bool -> a -> (Bool, b)
l <&&~ c = l <%~ (&& c)
{-# INLINE (<&&~) #-}

-------------------------------------------------------------------------------
-- Setting and Remembering State
-------------------------------------------------------------------------------

-- | Modify the target of a 'Lens' into your monad's state by a user supplied
-- function and return the result.
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.%=') is more flexible.
(<%=) :: MonadState a m => LensLike ((,)d) a a c d -> (c -> d) -> m d
l <%= f = l %%= (\c -> let d = f c in (d,d))
{-# INLINE (<%=) #-}

-- | Add to the target of a numerically valued 'Lens' into your monad's state
-- and return the result.
--
-- When you do not need the result of the multiplication, ('Control.Lens.Setter.+=') is more
-- flexible.
(<+=) :: (MonadState a m, Num b) => SimpleLensLike ((,)b) a b -> b -> m b
l <+= b = l <%= (+ b)
{-# INLINE (<+=) #-}

-- | Subtract from the target of a numerically valued 'Lens' into your monad's
-- state and return the result.
--
-- When you do not need the result of the multiplication, ('Control.Lens.Setter.-=') is more
-- flexible.
(<-=) :: (MonadState a m, Num b) => SimpleLensLike ((,)b) a b -> b -> m b
l <-= b = l <%= subtract b
{-# INLINE (<-=) #-}

-- | Multiply the target of a numerically valued 'Lens' into your monad's
-- state and return the result.
--
-- When you do not need the result of the multiplication, ('Control.Lens.Setter.*=') is more
-- flexible.
(<*=) :: (MonadState a m, Num b) => SimpleLensLike ((,)b) a b -> b -> m b
l <*= b = l <%= (* b)
{-# INLINE (<*=) #-}

-- | Divide the target of a fractionally valued 'Lens' into your monad's state
-- and return the result.
--
-- When you do not need the result of the division, ('Control.Lens.Setter.//=') is more flexible.
(<//=) :: (MonadState a m, Fractional b) => SimpleLensLike ((,)b) a b -> b -> m b
l <//= b = l <%= (/ b)
{-# INLINE (<//=) #-}

-- | Raise the target of a numerically valued 'Lens' into your monad's state
-- to a non-negative 'Integral' power and return the result.
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.**=') is more flexible.
(<^=) :: (MonadState a m, Num b, Integral c) => SimpleLensLike ((,)b) a b -> c -> m b
l <^= c = l <%= (^ c)
{-# INLINE (<^=) #-}

-- | Raise the target of a fractionally valued 'Lens' into your monad's state
-- to an 'Integral' power and return the result.
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.^^=') is more flexible.
(<^^=) :: (MonadState a m, Fractional b, Integral c) => SimpleLensLike ((,)b) a b -> c -> m b
l <^^= c = l <%= (^^ c)
{-# INLINE (<^^=) #-}

-- | Raise the target of a floating-point valued 'Lens' into your monad's
-- state to an arbitrary power and return the result.
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.**=') is more flexible.
(<**=) :: (MonadState a m, Floating b) => SimpleLensLike ((,)b) a b -> b -> m b
l <**= b = l <%= (** b)
{-# INLINE (<**=) #-}

-- | Logically '||' a Boolean valued 'Lens' into your monad's state and return
-- the result.
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.||=') is more flexible.
(<||=) :: MonadState a m => SimpleLensLike ((,)Bool) a Bool -> Bool -> m Bool
l <||= b = l <%= (|| b)
{-# INLINE (<||=) #-}

-- | Logically '&&' a Boolean valued 'Lens' into your monad's state and return
-- the result.
--
-- When you do not need the result of the operation, ('Control.Lens.Setter.&&=') is more flexible.
(<&&=) :: MonadState a m => SimpleLensLike ((,)Bool) a Bool -> Bool -> m Bool
l <&&= b = l <%= (&& b)
{-# INLINE (<&&=) #-}

