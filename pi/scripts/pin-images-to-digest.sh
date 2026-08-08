#!/usr/bin/env bash
# pin-images-to-digest.sh - Migrate compose files from tags to digest pinning
# Usage: ./pin-images-to-digest.sh [--dry-run] [--backup]
#
# Pins tagged image refs to the digest currently in the local Docker store,
# and records a "# pinned-from: image:tag" comment above each pinned line so
# update.sh can later pull the latest tag and re-pin (via this same script).

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/pi/stacks"
BACKUP_DIR=".backup-$(date +%Y%m%d-%H%M%S)"

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

resolve_digest() {
  # $1 = image:tag -> prints sha256:... from local store (or empty)
  docker image inspect "$1" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d@ -f2
}

for file in "${COMPOSE_FILES[@]}"; do
  echo ""
  echo "Processing: $file"

  if [[ "$BACKUP" == true ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
  fi

  TEMP_FILE=$(mktemp)
  CHANGED=0
  ALREADY_PINNED=0
  PENDING_IMAGE=""
  PENDING_TAG=""

  while IFS= read -r line; do
    # Remember "# pinned-from: image:tag" comments so the next image line can
    # be re-pinned to the current tag digest after an update.
    if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*pinned-from:[[:space:]]*([^:[:space:]]+):([^[:space:]]+) ]]; then
      PENDING_IMAGE="${BASH_REMATCH[1]}"
      PENDING_TAG="${BASH_REMATCH[2]}"
      echo "$line" >> "$TEMP_FILE"
      continue
    fi

    # Already-pinned line: image: repo@sha256:...
    if [[ "$line" =~ ^([[:space:]]*)image:[[:space:]]*([^@[:space:]]+)@sha256:[0-9a-f]{64}([[:space:]]*.*)$ ]]; then
      INDENT="${BASH_REMATCH[1]}"
      IMAGE="${BASH_REMATCH[2]}"
      REST="${BASH_REMATCH[3]}"
      if [[ -n "$PENDING_IMAGE" ]]; then
        OLD="${line#*@}"
        NEW="$(resolve_digest "${PENDING_IMAGE}:${PENDING_TAG}")"
        if [[ -n "$NEW" && "$NEW" != "$OLD" ]]; then
          if [[ "$DRY_RUN" == true ]]; then
            echo "  🔄 Would re-pin ${PENDING_IMAGE}:${PENDING_TAG} to $NEW"
            echo "$line" >> "$TEMP_FILE"
          else
            echo "  🔄 Re-pinned ${PENDING_IMAGE}:${PENDING_TAG}"
            echo "${INDENT}image: ${IMAGE}@${NEW}${REST}" >> "$TEMP_FILE"
            ((CHANGED=CHANGED+1))
            ((TOTAL_CHANGED=TOTAL_CHANGED+1))
          fi
        elif [[ -n "$NEW" ]]; then
          echo "  ✅ ${PENDING_IMAGE}:${PENDING_TAG} already current"
          echo "$line" >> "$TEMP_FILE"
        else
          echo "  ⚠️  Could not resolve ${PENDING_IMAGE}:${PENDING_TAG} - keeping existing pin"
          echo "$line" >> "$TEMP_FILE"
        fi
      else
        echo "  Already pinned: $IMAGE"
        ((ALREADY_PINNED=ALREADY_PINNED+1))
        echo "$line" >> "$TEMP_FILE"
      fi
      PENDING_IMAGE=""
      PENDING_TAG=""
      continue
    fi

    # Tagged line: image: image:tag
    if [[ "$line" =~ ^([[:space:]]*)image:[[:space:]]*([^@[:space:]]+):([^@[:space:]]+)([[:space:]]*.*)$ ]]; then
      INDENT="${BASH_REMATCH[1]}"
      IMAGE="${BASH_REMATCH[2]}"
      TAG="${BASH_REMATCH[3]}"
      REST="${BASH_REMATCH[4]}"

      # Skip floating tags that should not be pinned
      if [[ "$TAG" =~ ^(latest|stable|edge|main|master)$ ]]; then
        echo "  Skipping floating tag: $IMAGE:$TAG (not pinned)"
        echo "$line" >> "$TEMP_FILE"
        PENDING_IMAGE=""
        PENDING_TAG=""
        continue
      fi

      # Skip locally built images (reproducible from version-controlled
      # build context/Dockerfile; their digest is just the local image ID).
      if [[ "$IMAGE" == local/* ]]; then
        echo "  Skipping local build: $IMAGE:$TAG (not pinned)"
        echo "$line" >> "$TEMP_FILE"
        PENDING_IMAGE=""
        PENDING_TAG=""
        continue
      fi

      echo "  Resolving digest for $IMAGE:$TAG..."
      DIGEST=""
      if [[ "$DRY_RUN" == false ]]; then
        DIGEST="$(resolve_digest "${IMAGE}:${TAG}")"
      fi

      if [[ -n "$DIGEST" ]]; then
        echo "  Pinned $IMAGE:$TAG -> $DIGEST"
        if [[ "$DRY_RUN" == true ]]; then
          echo "$line" >> "$TEMP_FILE"
        else
          echo "# pinned-from: ${IMAGE}:${TAG}" >> "$TEMP_FILE"
          echo "${INDENT}image: ${IMAGE}@${DIGEST}${REST}" >> "$TEMP_FILE"
          ((CHANGED=CHANGED+1))
          ((TOTAL_CHANGED=TOTAL_CHANGED+1))
        fi
      else
        echo "  Could not resolve digest for $IMAGE:$TAG (image not local) - keeping tag"
        echo "$line" >> "$TEMP_FILE"
      fi
      PENDING_IMAGE=""
      PENDING_TAG=""
      continue
    fi

    echo "$line" >> "$TEMP_FILE"
  done < "$file"

  if [[ $CHANGED -gt 0 ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  Would change $CHANGED image references (dry run)"
    else
      mv "$TEMP_FILE" "$file"
      echo "  Updated $CHANGED image references in $file"
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
echo "2. Test: docker compose --env-file <env> config (each stack)"
echo "3. Verify: pi/scripts/health-check.sh"
echo "4. Update flow: update.sh pulls pinned-from tags, re-pins, then recreates"
