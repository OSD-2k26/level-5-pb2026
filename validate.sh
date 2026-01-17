#!/bin/bash
set -e

ARTIFACT="artifact.txt"

echo "🔍 Initializing Validation..."

# 1. Force fetch all branches and update remote tracking
git fetch origin --quiet

# 2. Get the actual list of remote branches from origin
# We remove 'origin/' prefix to match your 'required' list
REMOTE_BRANCH_LIST=$(git branch -r | sed 's/origin\///' | tr -d ' ')

required=(alpha beta gamma main)

for b in "${required[@]}"; do
  if ! echo "$REMOTE_BRANCH_LIST" | grep -q -w "$b"; then
    echo "❌ Required branch '$b' not found in remote history."
    echo "Found branches: $REMOTE_BRANCH_LIST"
    exit 1
  fi
done

# Helper: commit where artifact is ADDED (using origin/ prefix)
intro_commit () {
  git log "origin/$1" --diff-filter=A --pretty=format:%H -- "$ARTIFACT" | tail -n 1
}

echo "📡 Checking artifact existence across branches..."

# Check artifact in main (checking the remote ref directly)
git ls-tree -r "origin/main" --name-only | grep -q "$ARTIFACT" || {
  echo "❌ artifact.txt not found in origin/main"
  exit 1
}

# Find commits in remote branches
ALPHA_COMMIT=$(intro_commit alpha)
BETA_COMMIT=$(intro_commit beta)
GAMMA_COMMIT=$(intro_commit gamma)
MAIN_COMMIT=$(intro_commit main)

for c in "ALPHA:$ALPHA_COMMIT" "BETA:$BETA_COMMIT" "GAMMA:$GAMMA_COMMIT" "MAIN:$MAIN_COMMIT"; do
  name=${c%%:*}
  hash=${c#*:}
  if [ -z "$hash" ]; then
    echo "❌ artifact missing or never added in branch: ${name,,}"
    exit 1
  fi
done

echo "🧪 Comparing patch identities (Cherry-pick verification)..."

# Patch identity check (must reference origin/)
PATCH_ALPHA=$(git show "$ALPHA_COMMIT" --pretty=format: -- "$ARTIFACT")
PATCH_BETA=$(git show "$BETA_COMMIT" --pretty=format: -- "$ARTIFACT")
PATCH_GAMMA=$(git show "$GAMMA_COMMIT" --pretty=format: -- "$ARTIFACT")
PATCH_MAIN=$(git show "$MAIN_COMMIT" --pretty=format: -- "$ARTIFACT")

[ "$PATCH_ALPHA" = "$PATCH_BETA" ] || { echo "❌ alpha → beta not cherry-picked"; exit 1; }
[ "$PATCH_BETA" = "$PATCH_GAMMA" ] || { echo "❌ beta → gamma not cherry-picked"; exit 1; }
[ "$PATCH_GAMMA" = "$PATCH_MAIN" ] || { echo "❌ gamma → main not cherry-picked"; exit 1; }

# No merges allowed on the artifact path
# We check the log of origin/main to see if any merges affected the artifact
if git log "origin/main" --merges --format=%H -- "$ARTIFACT" | grep -q .; then
  echo "❌ merge used (not allowed)"
  exit 1
fi

echo "✅LEVEL 5 PASSED"
