#!/usr/bin/env bash
# Local checks before cutting a GitHub Release. The tag vX.Y.Z on main is
# what starts .github/workflows/release.yml, which builds the signed APK.
#
#   ./scripts/release.sh check              # verify, do not tag
#   ./scripts/release.sh create [X.Y.Z]     # check, then gh release create
#
# make release-check / make release VERSION=X.Y.Z wrap this.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEYSTORE="${SKORE_KEYSTORE:-$HOME/skore-release.jks}"
PASSFILE="${SKORE_KEYSTORE_PASSWORD_FILE:-$HOME/skore-release.password}"
REQUIRED_SECRETS=(KEYSTORE_BASE64 KEYSTORE_PASSWORD KEY_PASSWORD KEY_ALIAS)

die() { echo "release: $*" >&2; exit 1; }
ok() { echo "  ok  $*"; }
need() { command -v "$1" >/dev/null || die "$1 not on PATH"; }

repo_name() {
  gh repo view --json nameWithOwner --jq .nameWithOwner
}

latest_tag() {
  gh release list --limit 1 --json tagName --jq '.[0].tagName // empty'
}

next_patch() {
  local latest="${1#v}"
  [[ "$latest" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] ||
    die "cannot bump '$1' (expected vX.Y.Z)"
  echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"
}

normalize_version() {
  local v="${1#v}"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "version '$1' is not X.Y.Z"
  echo "$v"
}

check_tools() {
  echo "Tools"
  need gh
  need jj
  need flutter
  need keytool
  gh auth status -h github.com >/dev/null 2>&1 ||
    die "gh is not logged in to github.com"
  ok "gh, jj, flutter, keytool"
}

check_clean_main() {
  echo "Source"
  if [ -n "$(jj diff --name-only)" ]; then
    jj status >&2
    die "uncommitted changes. Commit first."
  fi
  local wc parent main empty
  wc="$(jj log -r @ -T 'commit_id' --no-graph)"
  parent="$(jj log -r @- -T 'commit_id' --no-graph)"
  main="$(jj log -r main -T 'commit_id' --no-graph)"
  empty="$(jj log -r @ -T 'empty' --no-graph)"
  if [ "$empty" = "true" ] && [ "$parent" = "$main" ]; then
    :
  elif [ "$wc" = "$main" ]; then
    :
  else
    die "bookmark main does not point at this commit. Run: jj bookmark set main -r @"
  fi
  local short
  short="$(jj log -r main -T 'commit_id' --no-graph | cut -c1-8)"
  ok "working copy clean, main is $short"
}

check_keystore() {
  echo "Signing keystore"
  [ -f "$KEYSTORE" ] ||
    die "missing $KEYSTORE. Run ./scripts/setup-signing.sh once and back it up."
  if [ -f "$PASSFILE" ]; then
    keytool -list -keystore "$KEYSTORE" -storepass "$(cat "$PASSFILE")" >/dev/null ||
      die "cannot unlock $KEYSTORE with $PASSFILE"
    ok "$KEYSTORE unlocks"
  else
    ok "$KEYSTORE present (no password file; skipped unlock)"
  fi
}

check_secrets() {
  echo "GitHub Actions secrets"
  local listed missing=()
  listed="$(gh secret list --json name --jq '.[].name')"
  local name
  for name in "${REQUIRED_SECRETS[@]}"; do
    echo "$listed" | grep -qx "$name" || missing+=("$name")
  done
  if [ "${#missing[@]}" -ne 0 ]; then
    die "missing secrets: ${missing[*]}. Run ./scripts/setup-signing.sh"
  fi
  ok "${REQUIRED_SECRETS[*]}"
}

check_tests() {
  echo "Tests"
  flutter test
  flutter analyze
  ok "flutter test + analyze"
}

run_checks() {
  check_tools
  check_clean_main
  check_keystore
  check_secrets
  check_tests
  echo "All release checks passed."
}

push_main_if_needed() {
  local local_id origin_id
  local_id="$(jj log -r main -T 'commit_id' --no-graph)"
  origin_id="$(jj log -r 'main@origin' -T 'commit_id' --no-graph)"
  if [ "$local_id" = "$origin_id" ]; then
    ok "origin/main already has this commit"
    return
  fi
  echo "Pushing bookmark main ..."
  jj git push --bookmark main
}

create_release() {
  local version="$1"
  local tag="v${version}"
  local repo
  repo="$(repo_name)"

  if gh release view "$tag" >/dev/null 2>&1; then
    die "GitHub release $tag already exists"
  fi
  if git ls-remote --tags origin "refs/tags/$tag" | grep -q .; then
    die "tag $tag already exists on origin"
  fi

  push_main_if_needed
  echo "Creating GitHub release $tag on main ..."
  gh release create "$tag" --target main --generate-notes
  echo
  echo "Release $tag created. CI builds the signed APK from that tag."
  echo "APK (once the Release APK workflow finishes):"
  echo "  https://github.com/${repo}/releases/tag/${tag}"
  echo "Watch: gh run watch --repo ${repo}"
}

usage() {
  cat <<EOF
Usage: $0 check | create [X.Y.Z]

  check            signing, secrets, clean main, tests. No tag.
  create [X.Y.Z]   run checks, push main if needed, gh release create.
                   Omit X.Y.Z to bump the patch of the latest GitHub release.
EOF
}

cmd="${1:-}"
shift || true
case "$cmd" in
  check)
    run_checks
    ;;
  create)
    run_checks
    version="${1:-}"
    if [ -z "$version" ]; then
      latest="$(latest_tag)"
      [ -n "$latest" ] || die "no previous release; pass X.Y.Z"
      version="$(next_patch "$latest")"
      echo "No VERSION given; next patch is $version (latest $latest)"
    else
      version="$(normalize_version "$version")"
    fi
    create_release "$version"
    ;;
  -h|--help|help|"")
    usage
    [ "$cmd" = "help" ] || [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ] || exit 1
    ;;
  *)
    usage >&2
    die "unknown command '$cmd'"
    ;;
esac
