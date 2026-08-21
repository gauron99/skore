#!/usr/bin/env bash
# One-time setup: generate skore's release signing keystore and push the four
# signing secrets to GitHub Actions, so every release is signed with the SAME
# key. That's what lets app updates install in place and keep the game data
# (a debug build mints a fresh key each CI run, which forces uninstall+wipe).
#
# Run from the repo root:  ./scripts/setup-signing.sh
#
# AFTER running, BACK UP the keystore file + password in a password manager.
# Lose them and you can never ship an in-place update again. You would
# have to uninstall (wiping the data) and start over with a new key.

set -euo pipefail

REPO="gauron99/skore"
KEYSTORE="$HOME/skore-release.jks"   # kept OUTSIDE the repo on purpose
ALIAS="skore"

command -v keytool >/dev/null || { echo "keytool not found (install a JDK)"; exit 1; }
command -v gh >/dev/null      || { echo "gh CLI not found / not logged in"; exit 1; }

PASS="${SKORE_KEYSTORE_PASSWORD:-}"
if [ -f "$KEYSTORE" ]; then
  echo "Reusing existing keystore at $KEYSTORE"
else
  if [ -z "$PASS" ]; then
    read -rsp "Choose a keystore password: " PASS; echo
    read -rsp "Confirm password: " PASS2; echo
    [ "$PASS" = "$PASS2" ] || { echo "Passwords do not match."; exit 1; }
  fi
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=Skore, OU=cards, O=gauron99, C=CZ" \
    -noprompt
  echo "Created $KEYSTORE"
fi

if [ -z "$PASS" ]; then
  read -rsp "Keystore password (to set the secrets): " PASS; echo
fi

echo "Setting signing secrets on $REPO ..."
base64 -w0 "$KEYSTORE" | gh secret set KEYSTORE_BASE64   -R "$REPO"
printf '%s' "$PASS"    | gh secret set KEYSTORE_PASSWORD -R "$REPO"
printf '%s' "$PASS"    | gh secret set KEY_PASSWORD      -R "$REPO"
printf '%s' "$ALIAS"   | gh secret set KEY_ALIAS         -R "$REPO"

echo
echo "✓ Secrets set: KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS"
echo "→ BACK UP $KEYSTORE and its password somewhere safe (password manager)."
echo "→ The keystore is git-ignored; never commit it."
