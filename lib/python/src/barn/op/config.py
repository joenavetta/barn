"""Settings for barn-op, from the environment.

Defaults live in config/barn.env, which bin/barn-op loads before starting
Python; anything already set in the shell overrides them.
"""

import os


def _require(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(
            f"error: {name} is not set. Run barn-op through bin/barn-op, which loads "
            "config/barn.env, or set it in your environment."
        )
    return value


VAULT = _require("BARN_OP_VAULT")
# Service account token (bin/ launchers load it from the macOS Keychain). When
# it's set, barn uses it; otherwise the desktop app, signed in to ACCOUNT.
SERVICE_ACCOUNT_TOKEN = os.environ.get("OP_SERVICE_ACCOUNT_TOKEN") or None
# Account name from the 1Password app's sidebar (the SDK rejects account IDs).
# Only needed for desktop app auth.
ACCOUNT = os.environ.get("BARN_OP_ACCOUNT") or None
HOME_DOMAIN = _require("BARN_HOME_DOMAIN")

REPO_URL = "github.com/joenavetta/barn"
TAG_ROOT = "barn"
INTEGRATION_NAME = "barn-op"
INTEGRATION_VERSION = "0.1.0"
