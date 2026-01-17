#!/bin/bash
set -e

ARTIFACT="artifact.txt"

# 1. Sync with the remote to see all student branches
echo "📡 Fetching remote branches..."
git fetch origin --quiet

# 2. Define required branches
# We use origin/ prefix because local branches don't exist in CI
required=("origin/alpha" "origin/beta" "origin/gamma" "origin/main")

for b in "${required[@]}"; do
  if ! git rev-parse --verify "$b" >/dev/null 2>&1; then
    echo "❌ Required branch '$b' not found on GitHub."
    echo "Double check: Did you push all branches? (git push origin --all)"
    exit 1
  fi
done

# Helper function to find the commit where the file was first added
intro_commit () {
  git log "$1" --diff-filter=A --pretty=format:%H -- "$ARTIFACT" | tail -n 1
}

echo "🔍 Analyzing artifact journey..."

# Get the specific commits from each remote branch
ALPHA_C=$(intro_commit origin/alpha)
BETA_C=$(intro_commit origin/beta)
GAMMA_C=$(intro_commit origin/gamma)
MAIN_C=$(intro_commit origin/main)

# Check if file exists in all spots
for c in "$ALPHA_C" "$BETA_C" "$GAMMA_C" "$MAIN_C"; do
  if [ -z "$c" ]; then
    echo "❌ Artifact trace lost. The file must exist in alpha, beta, gamma, and main."
    exit 1
  fi
done

echo "🧪 Verifying cherry-pick integrity (Patch Identity)..."

# Extract patches directly from the git database
P_ALPHA=$(git show "$ALPHA_C" --pretty=format: -- "$ARTIFACT")
P_BETA=$(git show "$BETA_C" --pretty=format: -- "$ARTIFACT")
P_GAMMA=$(git show "$GAMMA_C" --pretty=format: -- "$ARTIFACT")
P_MAIN=$(git show "$MAIN_C" --pretty=format: -- "$ARTIFACT")

if [ "$P_ALPHA" != "$P_BETA" ]; then echo "❌ alpha -> beta: Not a cherry-pick."; exit 1; fi
if [ "$P_BETA" != "$P_GAMMA" ]; then echo "❌ beta -> gamma: Not a cherry-pick."; exit 1; fi
if [ "$P_GAMMA" != "$P_MAIN" ]; then echo "❌ gamma -> main: Not a cherry-pick."; exit 1; fi

echo "🛡️ Checking for illegal merges..."

# Check if the artifact reached main via a merge commit
if git log origin/main --merges --format=%H -- "$ARTIFACT" | grep -q .; then
  echo "❌ Violation: Merge commit detected in the artifact's history."
  exit 1
fi

echo "✅ HARD LEVEL Ω PASSED — Branch Labyrinth Conquered"
