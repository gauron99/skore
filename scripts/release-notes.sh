#!/usr/bin/env bash
# Release notes for a vX.Y.Z tag: the subject of every commit since the
# previous v* tag (oldest first, merges skipped), then one link to the full
# diff. The first release, with no earlier tag, lists every commit.
#
#   scripts/release-notes.sh vX.Y.Z [REV]
#
# REV (default HEAD) is the commit being released; the tag does not have to
# exist yet. Run inside a git clone with full history and tags.
# .github/workflows/release.yml writes each GitHub release body with it.

set -euo pipefail

tag="${1:?usage: $0 vX.Y.Z [REV]}"
rev="${2:-HEAD}"

# owner/repo: set in GitHub Actions, else read from the origin remote.
repo="${GITHUB_REPOSITORY:-$(git remote get-url origin |
  sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')}"

prev="$(git describe --tags --abbrev=0 --match 'v[0-9]*' --exclude "$tag" \
  "$rev" 2>/dev/null || true)"

subjects="$(git log --reverse --no-merges --format='- %s' \
  "${prev:+$prev..}$rev")"
echo "${subjects:-No changes since $prev.}"
echo
if [ -n "$prev" ]; then
  echo "**Full Changelog**: https://github.com/$repo/compare/$prev...$tag"
else
  echo "**Full Changelog**: https://github.com/$repo/commits/$tag"
fi
