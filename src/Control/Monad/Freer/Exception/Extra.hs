{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeOperators #-}
-- |
-- Module:       $HEADER$
-- Description:  Extra goodies for Exc effect.
-- Copyright:    (c) 2017 Peter Trško
-- License:      BSD3
--
-- Stability:    experimental
-- Portability:  GHC specific language extensions.
--
-- <https://jaspervdj.be/posts/2015-01-20-haskell-design-patterns-extended-modules.html Extended module>
-- built on top of "Control.Monad.Freer.Exception".
module Control.Monad.Freer.Exception.Extra
    (
    -- * Re-export Module That's Beeing Extended
    --
    -- | Everything is beeing re-exported from it.
      module Control.Monad.Freer.Exception

    -- * Effect Evaluation
    , runErrorM
    , runErrorAsBase

    -- * Effect Operations
    , handleError
    , throwNothing
    , throwLeft

    -- ** Support For Lenses
    )
  where

import Control.Applicative (pure)
import Control.Exception (Exception)
import Control.Monad ((>>=))
import Data.Either (Either(Left, Right), either)
import Data.Maybe (Maybe, maybe)
import Data.Function (($), (.), flip)

import Control.Monad.Catch (MonadThrow, throwM)

import Control.Monad.Freer (Eff, Member, send)
import qualified Control.Monad.Freer.Internal as Internal
    ( Eff(Val, E)
    , decomp
    , qApp
    , tsingleton
    )
import Control.Monad.Freer.Exception

import Control.Monad.Freer.Base (BaseMember)


-- {{{ Effect Evaluation ------------------------------------------------------

-- | Evaluate 'Exc' effect in terms of base effect using specified base effect
-- operation.
runErrorAsBase
    :: BaseMember m effs
    => (forall r. e -> m r)
    -- ^ Throw exception in context of base effect.
    -> Eff (Exc e ': effs) a
    -> Eff effs a
runErrorAsBase throw = \case
    Internal.Val x -> pure x
    Internal.E u q -> case Internal.decomp u of
        Right (Exc e) -> send (throw e) >>= runErrorAsBase' . Internal.qApp q
        Left  u' -> Internal.E u' . Internal.tsingleton
            $ runErrorAsBase' . Internal.qApp q
  where
    runErrorAsBase' = runErrorAsBase throw
{-# INLINEABLE runErrorAsBase #-}

-- | Evaluate 'Exc' effect in terms of base effect, a monad that has
-- 'MonadThrow' capabilities.
--
-- This function is just a specialisation of 'runErrorAsBase':
--
-- @
-- 'runErrorM' = 'runErrorAsBase' 'throwM'
-- @
runErrorM
    :: forall e m effs a
    .  (Exception e, MonadThrow m, BaseMember m effs)
    => Eff (Exc e ': effs) a
    -> Eff effs a
runErrorM = runErrorAsBase throwM
{-# INLINE runErrorM #-}

-- }}} Effect Evaluation ------------------------------------------------------

-- {{{ Effect Operations ------------------------------------------------------

-- | A version of 'catchError' with the arguments flipped.
--
-- Usage example:
--
-- @
-- foo = 'handleError' errorHandler $ do
--     -- -->8--
--   where
--     errorHandler =
--         -- -->8--
-- @
handleError
    :: Member (Exc e) effs
    => (e -> Eff effs a)
    -> Eff effs a
    -> Eff effs a
handleError = flip catchError
{-# INLINE handleError #-}

-- | Throw exception when 'Nothing' is encountered.
throwNothing :: Member (Exc e) effs => e -> Maybe a -> Eff effs a
throwNothing e = maybe (throwError e) pure
{-# INLINE throwNothing #-}

-- | Throw exception when 'Left' is encountered.
throwLeft
    :: Member (Exc e) effs
    => (a -> e)
    -- ^ Convert 'Left' value in to an exception.
    -> Either a b
    -> Eff effs b
throwLeft f = either (throwError . f) pure
{-# INLINE throwLeft #-}

-- {{{ Effect Operations ------------------------------------------------------