"""
Encrypt provisioning/group_vars/all/secrets.yml using Ansible Vault format (AES256).

Implements the Ansible Vault 1.1 wire format directly so it works on Windows
without needing Unix-only modules (fcntl, os.get_blocking).

Usage:
    python encrypt_secrets.py

Reads the vault password from .vault_pass in the repo root.
Overwrites secrets.yml in place with the encrypted version.
"""

import os
import hashlib
import hmac
import binascii
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend

REPO_ROOT = Path(__file__).parent
SECRETS_FILE = REPO_ROOT / "provisioning" / "group_vars" / "all" / "secrets.yml"
VAULT_PASS_FILE = REPO_ROOT / ".vault_pass"


def pkcs7_pad(data, block_size=16):
    pad_len = block_size - (len(data) % block_size)
    return data + bytes([pad_len] * pad_len)


def ansible_vault_encrypt(plaintext: bytes, password: bytes) -> str:
    """
    Encrypt plaintext using the Ansible Vault 1.1 / AES256 format.

    The format is:
      $ANSIBLE_VAULT;1.1;AES256
      <hex-encoded body wrapped at 80 chars>

    The body (before hex encoding) is:
      hex(salt) + newline + hmac_hex + newline + hex(ciphertext)

    Key derivation: PBKDF2-SHA256(password, salt, 10000 iterations, 80 bytes)
      -> key1 (32 bytes): AES encryption key
      -> key2 (32 bytes): HMAC key
      -> iv   (16 bytes): AES-CTR initialisation vector (padded to 128-bit)
    """
    salt = os.urandom(32)

    # Derive key material
    derived = hashlib.pbkdf2_hmac("sha256", password, salt, 10000, dklen=80)
    key1 = derived[:32]
    key2 = derived[32:64]
    iv = derived[64:80]

    cipher = Cipher(algorithms.AES(key1), modes.CTR(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    ciphertext = encryptor.update(pkcs7_pad(plaintext)) + encryptor.finalize()

    # HMAC-SHA256 over ciphertext
    mac = hmac.new(key2, ciphertext, hashlib.sha256).hexdigest().encode()

    # Assemble body: hex(salt) + \n + mac_hex + \n + hex(ciphertext)
    body = binascii.hexlify(salt) + b"\n" + mac + b"\n" + binascii.hexlify(ciphertext)

    # Hex-encode the whole body, then wrap at 80 chars
    hex_body = binascii.hexlify(body).decode()
    wrapped = "\n".join(hex_body[i : i + 80] for i in range(0, len(hex_body), 80))

    return "$ANSIBLE_VAULT;1.1;AES256\n" + wrapped + "\n"


def main():
    if not VAULT_PASS_FILE.exists():
        raise FileNotFoundError(f".vault_pass not found at {VAULT_PASS_FILE}")

    if not SECRETS_FILE.exists():
        raise FileNotFoundError(f"secrets.yml not found at {SECRETS_FILE}")

    password = VAULT_PASS_FILE.read_bytes().strip()
    plaintext = SECRETS_FILE.read_bytes()

    # Guard: don't double-encrypt
    if plaintext.startswith(b"$ANSIBLE_VAULT"):
        print("secrets.yml is already encrypted — nothing to do.")
        return

    encrypted = ansible_vault_encrypt(plaintext, password)
    SECRETS_FILE.write_text(encrypted, encoding="utf-8", newline="\n")

    first_line = SECRETS_FILE.read_text().splitlines()[0]
    print(f"Encrypted successfully. First line: {first_line}")


if __name__ == "__main__":
    main()
