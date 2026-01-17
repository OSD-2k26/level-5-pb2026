#!/bin/bash
set -e

ARTIFACT="artifact.txt"

# 1. Ensure we have all remote info
git fetch --all --quiet

# 2. Check for branches using remote refs specifically
required=(alpha beta gamma main)
for b in "${required[@]}"; do
  # Check if the remote branch exists in the fetch data
  if ! git rev-parse --verify "origin/$b" >/dev/null 2>&1; then
    echo "❌ Required branch '$b' not found on remote (origin/$b)"
    exit 1
  fi
done

# Helper: Find the commit where artifact was ADDED
intro_commit () {
  # Use origin/ prefix to ensure we check the remote tracking branch
  git log "origin/$1" --diff-filter=A --pretty=format:%H -- "$ARTIFACT" | tail -n 1
}

# 3. Check if artifact exists in the LATEST commit of origin/main
# Instead of checking out, we just cat the file from the tree
git cat-file -e "origin/main:$ARTIFACT" 2>/dev/null || {
  echo "❌ artifact.txt not found in origin/main"
  exit 1
}

# ... [Your existing logic for ALPHA/BETA/GAMMA commits] ...
# Make sure to use "origin/alpha", etc., inside your logic

# Must be created in alpha
ALPHA_COMMIT=$(intro_commit alpha)
[ -n "$ALPHA_COMMIT" ] || {
  echo "❌ artifact not created in alpha"
  exit 1
}

# Must appear in beta, gamma, main
BETA_COMMIT=$(intro_commit beta)
GAMMA_COMMIT=$(intro_commit gamma)
MAIN_COMMIT=$(intro_commit main)

for c in "$BETA_COMMIT" "$GAMMA_COMMIT" "$MAIN_COMMIT"; do
  [ -n "$c" ] || {
    echo "❌ artifact missing in one or more branches"
    exit 1
  }
done

# Patch identity check (proves cherry-pick, not copy)
PATCH_ALPHA=$(git show "$ALPHA_COMMIT" --pretty=format: -- "$ARTIFACT")
PATCH_BETA=$(git show "$BETA_COMMIT" --pretty=format: -- "$ARTIFACT")
PATCH_GAMMA=$(git show "$GAMMA_COMMIT" --pretty=format: -- "$ARTIFACT")
PATCH_MAIN=$(git show "$MAIN_COMMIT" --pretty=format: -- "$ARTIFACT")

[ "$PATCH_ALPHA" = "$PATCH_BETA" ] || {
  echo "❌ alpha → beta not cherry-picked"
  exit 1
}

[ "$PATCH_BETA" = "$PATCH_GAMMA" ] || {
  echo "❌ beta → gamma not cherry-picked"
  exit 1
}

[ "$PATCH_GAMMA" = "$PATCH_MAIN" ] || {
  echo "❌ gamma → main not cherry-picked"
  exit 1
}

# No merges allowed
git log --merges -- "$ARTIFACT" | grep . && {
  echo "❌ merge used (not allowed)"
  exit 1
}

echo "✅ HARD LEVEL Ω PASSED — Branch Labyrinth Conquered"
