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
# Account name from the 1Password app's sidebar (the SDK rejects account IDs).
ACCOUNT = _require("BARN_OP_ACCOUNT")
HOME_DOMAIN = _require("BARN_HOME_DOMAIN")

REPO_URL = "github.com/joenavetta/barn"
TAG_ROOT = "barn"
INTEGRATION_NAME = "barn-op"
INTEGRATION_VERSION = "0.1.0"
