"""The few Cloudflare API calls barn-cf needs, over the standard library.

Account-owned API tokens only (/accounts/{account_id}/tokens/...):
  GET /accounts/{account_id}/tokens/verify            -> the calling token's id and status
  GET /accounts/{account_id}/tokens/{token_id}        -> token details (name, status, expiry)
  PUT /accounts/{account_id}/tokens/{token_id}/value  -> roll: new secret in `result`,
                                                         old secret stops working at once
The admin token needs the account permission "Account API Tokens Write"
(dashboard: Account > API Tokens > Edit).
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any

API = os.environ.get("BARN_CF_API", "https://api.cloudflare.com/client/v4")
TIMEOUT = 30


class CloudflareError(RuntimeError):
    pass


@dataclass
class TokenInfo:
    id: str
    name: str
    status: str
    expires_on: str | None = None


def _request(method: str, path: str, token: str, body: dict | None = None) -> Any:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "barn-cf",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            payload = json.load(resp)
    except urllib.error.HTTPError as e:
        try:
            payload = json.load(e)
        except Exception:
            raise CloudflareError(f"{method} {path}: HTTP {e.code}") from e
        raise CloudflareError(f"{method} {path}: HTTP {e.code}: {_errors(payload)}") from e
    except urllib.error.URLError as e:
        raise CloudflareError(f"{method} {path}: {e.reason}") from e
    if not payload.get("success"):
        raise CloudflareError(f"{method} {path}: {_errors(payload)}")
    return payload.get("result")


def _errors(payload: dict) -> str:
    errs = payload.get("errors") or []
    return "; ".join(f"{e.get('code')}: {e.get('message')}" for e in errs) or "unknown error"


def verify(account_id: str, token: str) -> TokenInfo:
    """Check a token works; returns its own id and status."""
    r = _request("GET", f"/accounts/{account_id}/tokens/verify", token)
    return TokenInfo(id=r["id"], name="", status=r.get("status", ""), expires_on=r.get("expires_on"))


def get_token(account_id: str, token_id: str, admin_token: str) -> TokenInfo:
    r = _request("GET", f"/accounts/{account_id}/tokens/{token_id}", admin_token)
    return TokenInfo(
        id=r["id"], name=r.get("name", ""), status=r.get("status", ""),
        expires_on=r.get("expires_on"),
    )


def roll_token(account_id: str, token_id: str, admin_token: str) -> str:
    """Roll the token's secret. Returns the new value; the old one is dead from here on."""
    value = _request("PUT", f"/accounts/{account_id}/tokens/{token_id}/value", admin_token, {})
    if not isinstance(value, str) or not value:
        raise CloudflareError("roll succeeded but the response had no token value")
    return value
