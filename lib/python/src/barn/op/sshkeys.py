"""Generate SSH key pairs locally; only the private key goes to 1Password."""

from __future__ import annotations

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, rsa

KEY_TYPES = ("ed25519", "rsa4096")


def generate(key_type: str, comment: str) -> tuple[str, str]:
    """Return (private key as PKCS#8 PEM, OpenSSH public key line)."""
    if key_type == "ed25519":
        key = ed25519.Ed25519PrivateKey.generate()
    elif key_type == "rsa4096":
        key = rsa.generate_private_key(public_exponent=65537, key_size=4096)
    else:
        raise ValueError(f"unknown key type {key_type}")
    private_pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    public = key.public_key().public_bytes(
        serialization.Encoding.OpenSSH, serialization.PublicFormat.OpenSSH
    ).decode()
    return private_pem, f"{public} {comment}"
