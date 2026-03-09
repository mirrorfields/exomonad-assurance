{-# LANGUAGE OverloadedStrings #-}

module PRReviewHandler
  ( prReviewEventHandlers,
  )
where

import Control.Monad (void)
import Control.Monad.Freer (Eff)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Lazy qualified as TL
import ExoMonad.Effects.Log qualified as Log
import ExoMonad.Guest.Events (EventAction (..), EventHandlerConfig (..), PRReviewEvent (..), defaultEventHandlers)
import ExoMonad.Guest.Tool.SuspendEffect (suspendEffect_)
import ExoMonad.Guest.Types (HookEffects)

-- | Event handler config with PR review handling.
-- CI and timeout handlers use defaults (NoAction).
prReviewEventHandlers :: EventHandlerConfig
prReviewEventHandlers =
  defaultEventHandlers
    { onPRReview = prReviewHandler
    }

-- | Handle PR review events for dev/tl roles.
prReviewHandler :: PRReviewEvent -> Eff HookEffects EventAction
prReviewHandler (ReviewReceived n comments_) = do
  void $ suspendEffect_ @Log.LogInfo $ Log.InfoRequest
    { Log.infoRequestMessage = TL.fromStrict $
        "[PRReviewHandler] Review received on PR #" <> T.pack (show n)
    , Log.infoRequestFields = ""
    }
  let msg = "## Copilot Review on PR #" <> T.pack (show n) <> "\n\n"
         <> comments_
         <> "\n\nAddress these comments and push fixes."
  pure (InjectMessage msg)

prReviewHandler (ReviewApproved n) = do
  void $ suspendEffect_ @Log.LogInfo $ Log.InfoRequest
    { Log.infoRequestMessage = TL.fromStrict $
        "[PRReviewHandler] PR #" <> T.pack (show n) <> " approved by Copilot"
    , Log.infoRequestFields = ""
    }
  let msg = "PR #" <> T.pack (show n) <> " approved by Copilot review"
  pure (NotifyParentAction msg n)

prReviewHandler (ReviewTimeout n mins) = do
  void $ suspendEffect_ @Log.LogInfo $ Log.InfoRequest
    { Log.infoRequestMessage = TL.fromStrict $
        "[PRReviewHandler] PR #" <> T.pack (show n)
        <> " timed out after " <> T.pack (show mins) <> " minutes"
    , Log.infoRequestFields = ""
    }
  let msg = "PR #" <> T.pack (show n)
         <> " — no Copilot review after " <> T.pack (show mins)
         <> " minutes, proceeding with success"
  pure (NotifyParentAction msg n)
