#!/usr/bin/env bash
# changelog.sh — Generate a structured CHANGELOG.md from git history
# Usage: bash changelog.sh [--since <tag-or-ref>] [--out <file>]
set -euo pipefail

OUT_FILE="CHANGELOG.md"
SINCE_REF=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_FILE="$2"; shift 2 ;;
    --since) SINCE_REF="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: bash changelog.sh [--since <tag>] [--out <file>]"
      echo "  --since <ref>   Only include commits after this ref (tag/branch/commit)"
      echo "  --out <file>    Output file (default: CHANGELOG.md)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: not inside a git repository"
  exit 1
fi

# Gather tags sorted newest-first
TAGS=()
while IFS= read -r tag; do
  TAGS+=("$tag")
done < <(git tag --sort=-v:refname 2>/dev/null || true)

# Gather commits
# Format: DATE||HASH||SUBJECT
COMMITS_FILE=$(mktemp)
trap "rm -f $COMMITS_FILE" EXIT

git log --oneline --format="%ad||%h||%s" --date=short --all > "$COMMITS_FILE"

if [[ -n "$SINCE_REF" ]]; then
  COMMITS_FILE_FILTERED=$(mktemp)
  trap "rm -f $COMMITS_FILE_FILTERED" EXIT
  since_date=$(git log -1 --format="%ad" --date=short "$SINCE_REF" 2>/dev/null || echo "")
  if [[ -n "$since_date" ]]; then
    while IFS= read -r line; do
      commit_date="${line%%||*}"
      if [[ "$commit_date" > "$since_date" ]] || [[ "$commit_date" == "$since_date" ]]; then
        echo "$line" >> "$COMMITS_FILE_FILTERED"
      fi
    done < "$COMMITS_FILE"
    COMMITS_FILE="$COMMITS_FILE_FILTERED"
  fi
fi

# Build changelog
CHANGELOG=$(mktemp)
trap "rm -f $CHANGELOG" EXIT

printf '# Changelog\n' > "$CHANGELOG"

# Helper: classify a commit message into a category
classify_commit() {
  local subject="$1"
  local lower_subject
  lower_subject=$(echo "$subject" | tr '[:upper:]' '[:lower:]')

  if echo "$lower_subject" | grep -qE '^(feat|feature)\b'; then
    echo "Added"
  elif echo "$lower_subject" | grep -qE '^fix\b'; then
    echo "Fixed"
  elif echo "$lower_subject" | grep -qE '^(refactor|perf|performance|style|format|docs?)\b'; then
    echo "Changed"
  elif echo "$lower_subject" | grep -qE '^(revert|remove|deprecate|delete)\b'; then
    echo "Removed"
  elif echo "$lower_subject" | grep -qE '^(chore|build|ci|test|deps?)\b'; then
    echo "Other"
  else
    echo "Changed"
  fi
}

# Helper: strip conventional commit prefix and optionally extract scope
clean_subject() {
  local subject="$1"
  # Remove prefix (e.g. "feat:", "fix(scope):", "docs(readme):")
  cleaned=$(echo "$subject" | sed -E 's/^[a-zA-Z_-]+(\([^)]*\))?:\s*//')
  echo "$cleaned"
}

# Helper: extract scope if present
extract_scope() {
  local subject="$1"
  scope=$(echo "$subject" | sed -nE 's/^[a-zA-Z_-]+\(([^)]+)\).*/\1/p')
  echo "$scope"
}

# Group commits by version
print_version_section() {
  local version_label="$1"
  local version_date="$2"
  local commit_file="$3"
  local tag_ref="$4"

  # Gather commits for this version
  VERSION_COMMITS=$(mktemp)
  trap "rm -f $VERSION_COMMITS" EXIT

  if [[ -z "$tag_ref" ]]; then
    # All commits in commit_file
    cat "$commit_file" > "$VERSION_COMMITS"
  else
    # Commits reachable from tag but not from its parent tag
    prev_tag="$5"
    if [[ -z "$prev_tag" ]]; then
      cat "$commit_file" > "$VERSION_COMMITS"
    else
      git log --oneline --format="%ad||%h||%s" --date=short "$tag_ref" "^$prev_tag" > "$VERSION_COMMITS" 2>/dev/null || cat "$commit_file" > "$VERSION_COMMITS"
    fi
  fi

  # Read all commits into an array
  ADDED_ITEMS=()
  FIXED_ITEMS=()
  CHANGED_ITEMS=()
  REMOVED_ITEMS=()
  OTHER_ITEMS=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    date="${line%%||*}"
    rest="${line#*||}"
    hash="${rest%%||*}"
    subject="${rest#*||}"

    category=$(classify_commit "$subject")
    scope=$(extract_scope "$subject")
    cleaned=$(clean_subject "$subject")

    # Build display item
    if [[ -n "$scope" ]]; then
      item="- **${scope}:** ${cleaned} (${hash})"
    else
      item="- ${cleaned} (${hash})"
    fi

    case "$category" in
      Added)    ADDED_ITEMS+=("$item") ;;
      Fixed)    FIXED_ITEMS+=("$item") ;;
      Changed)  CHANGED_ITEMS+=("$item") ;;
      Removed)  REMOVED_ITEMS+=("$item") ;;
      Other)    OTHER_ITEMS+=("$item") ;;
    esac
  done < "$VERSION_COMMITS"

  # Only write section if there are commits
  total=$(( ${#ADDED_ITEMS[@]} + ${#FIXED_ITEMS[@]} + ${#CHANGED_ITEMS[@]} + ${#REMOVED_ITEMS[@]} + ${#OTHER_ITEMS[@]} ))
  [[ $total -eq 0 ]] && return

  echo "" >> "$CHANGELOG"
  echo "## [${version_label}] — ${version_date}" >> "$CHANGELOG"
  echo "" >> "$CHANGELOG"

  write_category "Added" "${ADDED_ITEMS[@]}"
  write_category "Fixed" "${FIXED_ITEMS[@]}"
  write_category "Changed" "${CHANGED_ITEMS[@]}"
  write_category "Removed" "${REMOVED_ITEMS[@]}"
  write_category "Other" "${OTHER_ITEMS[@]}"
}

write_category() {
  local cat_name="$1"
  shift
  local items=("$@")
  [[ ${#items[@]} -eq 0 ]] && return

  echo "### ${cat_name}" >> "$CHANGELOG"
  echo "" >> "$CHANGELOG"
  for item in "${items[@]}"; do
    echo "$item" >> "$CHANGELOG"
  done
  echo "" >> "$CHANGELOG"
}

# Build dated sections
TODAY=$(date +%Y-%m-%d)

if [[ ${#TAGS[@]} -gt 0 ]]; then
  # First: unreleased (commits since newest tag)
  newest_tag="${TAGS[0]}"
  UNRELEASED_FILE=$(mktemp)
  trap "rm -f $UNRELEASED_FILE" EXIT
  git log --oneline --format="%ad||%h||%s" --date=short "$newest_tag"..HEAD > "$UNRELEASED_FILE" 2>/dev/null || true

  if [[ -s "$UNRELEASED_FILE" ]]; then
    print_version_section "Unreleased" "$TODAY" "$UNRELEASED_FILE" "" ""
  fi

  # Then each tagged version
  for i in "${!TAGS[@]}"; do
    tag="${TAGS[$i]}"
    date=$(git log -1 --format="%ad" --date=short "$tag" 2>/dev/null || echo "$TODAY")
    prev_tag=""
    if [[ $((i + 1)) -lt ${#TAGS[@]} ]]; then
      prev_tag="${TAGS[$((i + 1))]}"
    fi
    TAG_FILE=$(mktemp)
    trap "rm -f $TAG_FILE" EXIT
    if [[ -z "$prev_tag" ]]; then
      git log --oneline --format="%ad||%h||%s" --date=short "$tag" > "$TAG_FILE" 2>/dev/null || true
    else
      git log --oneline --format="%ad||%h||%s" --date=short "$prev_tag".."$tag" > "$TAG_FILE" 2>/dev/null || true
    fi

    if [[ -s "$TAG_FILE" ]]; then
      print_version_section "$tag" "$date" "$TAG_FILE" "$tag" "$prev_tag"
    fi
  done
else
  # No tags: everything under Unreleased
  print_version_section "Unreleased" "$TODAY" "$COMMITS_FILE" "" ""
fi

# Write output
cp "$CHANGELOG" "$OUT_FILE"
echo "Wrote $OUT_FILE"
