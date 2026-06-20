#!/usr/bin/env bash
# pin-images-to-digest.sh - Migrate compose files from tags to digest pinning
# Usage: ./pin-images-to-digest.sh [--dry-run] [--backup]

set -euo pipefail

DRY_RUN=false
BACKUP=false

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --backup) BACKUP=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

COMPOSE_DIR="stacks"
BACKUP_DIR=".backup-$(date +%Y%m%d-%H%M%S)"

# Find all compose files
mapfile -t COMPOSE_FILES < <(find "$COMPOSE_DIR" -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null)

if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
  echo "No compose files found in $COMPOSE_DIR"
  exit 1
fi

echo "Found ${#COMPOSE_FILES[@]} compose files"
[[ "$BACKUP" == true ]] && echo "Backup will be created in $BACKUP_DIR"
[[ "$DRY_RUN" == true ]] && echo "DRY RUN MODE - no changes will be made"

TOTAL_CHANGED=0
TOTAL_ALREADY_PINNED=0

for file in "${COMPOSE_FILES[@]}"; do
  echo ""
  echo "Processing: $file"

  # Create backup if requested
  if [[ "$BACKUP" == true ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
  fi

  # Process the file
  # Use a temporary file for modifications
  TEMP_FILE=$(mktemp)
  CHANGED=0
  ALREADY_PINNED=0

  while IFS= read -r line; do
    # Match image: lines with tags but not digests
    if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*)([^@[:space:]]+):([^@[:space:]]+)([[:space:]]*.*)$ ]]; then
      INDENT="${BASH_REMATCH[1]}"
      IMAGE="${BASH_REMATCH[2]}"
      TAG="${BASH_REMATCH[3]}"
      REST="${BASH_REMATCH[4]}"

      # Skip if already has digest
      if [[ "$line" =~ @sha256: ]]; then
        echo "  Already pinned: $IMAGE:$TAG"
        ((ALREADY_PINNED++))
        echo "$line" >> "$TEMP_FILE"
        continue
      fi

      # Skip special tags that shouldn't be pinned (like latest, stable)
      if [[ "$TAG" =~ ^(latest|stable|edge|main|master)$ ]]; then
        echo "  ⚠️  Skipping special tag: $IMAGE:$TAG (consider pinning manually)"
        echo "$line" >> "$TEMP_FILE"
        continue
      fi

      echo "  🔍 Resolving digest for $IMAGE:$TAG..."

      # Try to get digest from local Docker or registry
      DIGEST=""
      if ! "$DRY_RUN"; then
        # Try local image first
        DIGEST=$(docker image inspect "$IMAGE:$TAG" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d@ -f2 || true)
      fi

      if [[ -n "$DIGEST" ]]; then
        echo "  ✅ Resolved digest: $DIGEST"
        NEW_LINE="${INDENT}image: ${IMAGE}@${DIGEST}${REST}"
        echo "$NEW_LINE" >> "$TEMP_FILE"
        ((CHANGED++))
        ((TOTAL_CHANGED++))
      else
        echo "  ⚠️  Could not resolve digest for $IMAGE:$TAG (image not local or not found)"
        echo "      Keeping tag, consider manual pinning"
        echo "$line" >> "$TEMP_FILE"
      fi
    else
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "$file"

  # Apply changes
  if [[ $CHANGED -gt 0 ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  Would change $CHANGED image references (dry run)"
    else
      mv "$TEMP_FILE" "$file"
      echo "  ✅ Updated $CHANGED image references in $file"
    fi
  else
    echo "  No changes needed"
    rm -f "$TEMP_FILE"
  fi

  TOTAL_ALREADY_PINNED=$((TOTAL_ALREADY_PINNED + ALREADY_PINNED))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "  Files processed: ${#COMPOSE_FILES[@]}"
echo "  References changed: $TOTAL_CHANGED"
echo "  Already pinned: $TOTAL_ALREADY_PINNED"
[[ "$DRY_RUN" == true ]] && echo "  (DRY RUN - no changes applied)"
[[ "$BACKUP" == true ]] && echo "  Backups saved to: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "1. Review changes: git diff"
echo "2. Test: make config"
echo "3. Deploy: make up-all"
echo "4. Verify: make verify-v1"