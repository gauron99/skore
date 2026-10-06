#!/usr/bin/env bash
# Ship a change: move main forward to it and push. A push to main is a
# release when it changes the app (on.push.paths in release.yml).
#
#   make ship                          @ if it has a diff and a description,
#                                      otherwise @- on those same terms
#   make ship REV=<change>             check, test, push that revision
#   make ship REV=<change> DRY_RUN=1   check and test, print the push
#
# Run from the repo root with the working copy on the shipped change
# (harness files such as CLAUDE.local.md may sit in a change on top).
# FLUTTER names the flutter binary; the Makefile passes its own.

set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
REV="${REV:-}"
DRY_RUN="${DRY_RUN:-}"

# Local-only files that never ship (paths from the repo root).
HARNESS='^(CLAUDE\.local\.md$|\.claude/|screenshots/|\.tools/)'
LINE='"  " ++ change_id.short() ++ " " ++ if(description, description.first_line(), "(no description)") ++ "\n"'
STATE='"  " ++ change_id.short() ++ " " ++ if(self.empty(), "empty", "non-empty") ++ ", " ++ if(description, description.first_line(), "(no description)") ++ "\n"'

die() {
  echo "ship: $*" >&2
  exit 1
}

indent() {
  sed 's/^/  /'
}

# One line per change in REVSET.
changes() {
  jj log --no-graph -T "$LINE" -r "$1"
}

# Change id when $1 is non-empty and described. Empty output otherwise.
ready_rev() {
  jj log --no-graph -T 'change_id.short() ++ "\n"' \
    -r "$1 & ~empty() & ~description(exact:\"\")" 2>/dev/null || true
}

# REV=<change> is that revision. With no REV, @ ships only when it has a
# diff and a description; otherwise @- must meet the same bar.
if [ -z "$REV" ]; then
  if [ -n "$(ready_rev @)" ]; then
    REV=@
  elif [ -n "$(ready_rev @-)" ]; then
    REV=@-
  else
    {
      echo "ship: no REV given, and neither @ nor @- is non-empty and described."
      jj log --no-graph -T "$STATE" -r @ || true
      jj log --no-graph -T "$STATE" -r @- || true
      echo "Name one with: make ship REV=<change>"
    } >&2
    exit 1
  fi
  echo "No REV given. Using $REV ($(jj log --no-graph -T 'change_id.short() ++ " " ++ description.first_line()' -r "$REV"))."
fi

echo "Fetching origin ..."
jj git fetch

commits="$(jj log --no-graph -T 'commit_id ++ "\n"' -r "$REV" 2>&1)" ||
  die "REV=$REV is not a revision: $commits"
[ "$(printf '%s' "$commits" | grep -c .)" -eq 1 ] ||
  die "REV=$REV is not exactly one change. Name one change."
commit="$commits"
change="$(jj log --no-graph -T 'change_id.short()' -r "$commit")"

if [ -n "$(jj log --no-graph -T commit_id -r "$commit & ::main@origin")" ]; then
  die "$change is already in main@origin. Nothing to ship."
fi
if [ -z "$(jj log --no-graph -T commit_id -r "main@origin & ::$commit")" ]; then
  die "$change is not on top of main@origin, and main only moves forward.
Rebase it first: jj rebase -b $change -d main@origin"
fi

range="main@origin..$commit"
problems=()

undescribed="$(changes "$range & description(exact:\"\")")"
if [ -n "$undescribed" ]; then
  problems+=("These changes have no description. Add one with jj describe <change>:
$undescribed")
fi

conflicted="$(changes "$range & conflicts()")"
if [ -n "$conflicted" ]; then
  problems+=("These changes have conflicts. Resolve them with jj resolve -r <change>:
$conflicted")
fi

harness=""
for c in $(jj log --no-graph -T 'change_id.short() ++ "\n"' -r "$range"); do
  names="$(jj diff -r "$c" --name-only)"
  files="$(grep -E "$HARNESS" <<< "$names" || true)"
  if [ -n "$files" ]; then
    harness+="$(changes "$c")
$(indent <<< "$(indent <<< "$files")")
"
  fi
done
if [ -n "$harness" ]; then
  problems+=("These changes touch CLAUDE.local.md, .claude/, screenshots/ or .tools/,
which never ship. Move those files to a change on top (jj split):
${harness%$'\n'}")
fi

names="$(jj diff --from "$commit" --to @ --name-only)"
drift="$(grep -vE "$HARNESS" <<< "$names" || true)"
if [ -n "$drift" ]; then
  problems+=("The working copy differs from $change, so the tests would not test it.
Check it out first (jj new $change). Differing files:
$(indent <<< "$drift")")
fi

if [ "${#problems[@]}" -gt 0 ]; then
  echo "ship: not shipping $change." >&2
  for problem in "${problems[@]}"; do
    printf '\n%s\n' "$problem" >&2
  done
  exit 1
fi

echo "Analyzing and testing $change ..."
"$FLUTTER" analyze
"$FLUTTER" test

# The paths that make a push a release, read from release.yml so the two
# cannot disagree.
globs="$(sed -n "/^    paths:/,/^  [^ ]/s/^      - '\(.*\)'$/\1/p" \
  .github/workflows/release.yml)"
[ -n "$globs" ] || die "cannot read on.push.paths from .github/workflows/release.yml"
fileset="$(echo "$globs" | sed 's/.*/root-glob:"&"/' | paste -sd'|')"
app_files="$(jj diff --from main@origin --to "$commit" --name-only "$fileset")"

echo
echo "Ships to main:"
changes "$range"
echo
if [ -n "$app_files" ]; then
  echo "This push makes a release (the next patch version). App files:"
  indent <<< "$app_files"
else
  echo "This push makes no release: nothing under $(echo "$globs" | paste -sd' ') changes."
fi

repo="$(jj git remote list | awk '$1 == "origin" { print $2 }' |
  sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
if [ -n "$app_files" ]; then
  watch="https://github.com/$repo/actions/workflows/release.yml"
else
  watch="https://github.com/$repo/actions"
fi

echo
if [ -n "$DRY_RUN" ] && [ "$DRY_RUN" != 0 ]; then
  echo "Dry run. Would now run:"
  echo "  jj bookmark set main -r $commit"
  echo "  jj git push --bookmark main"
  echo "Then watch: $watch"
  exit 0
fi

jj bookmark set main -r "$commit"
jj git push --bookmark main
echo
echo "Pushed. Watch: $watch"
