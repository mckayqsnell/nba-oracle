#!/usr/bin/env bash
set -euo pipefail

# Generate .env files from 1Password.
#
# Convention:
#   - Each env var = one 1Password item.
#   - Item title       = ENV_VAR_NAME (e.g. DATABASE_URL)
#   - Item password    = the value
#   - Item tags        = `backend` and/or `frontend` (controls which file)
#   - Vault per env    = NBA-Oracle-LOCAL, NBA-Oracle-PROD
#
# Usage: generate-env.sh <env> <target>
#   env:    local | prod
#   target: backend | frontend

VAULT_PREFIX="NBA-Oracle"

ENV="${1:?missing env (local|prod)}"
TARGET="${2:?missing target (backend|frontend)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

case "$ENV" in
    local) VAULT="${VAULT_PREFIX}-LOCAL" ;;
    prod)  VAULT="${VAULT_PREFIX}-PROD" ;;
    *)     echo -e "${RED}Unknown env '$ENV' (use local|prod)${NC}"; exit 1 ;;
esac

case "$TARGET" in
    backend)  OUTPUT_FILE=".env.${ENV}" ;;
    frontend) OUTPUT_FILE="frontend/.env.${ENV}" ;;
    *)        echo -e "${RED}Unknown target '$TARGET' (use backend|frontend)${NC}"; exit 1 ;;
esac

# Pin to a specific 1Password account so commands work when multiple accounts
# share the same email (e.g. personal + family + work).
if [ -f .1password.yml ]; then
    ACCOUNT=$(grep '^account:' .1password.yml | awk '{print $2}' | head -1 || echo "")
    if [ -n "$ACCOUNT" ]; then
        export OP_ACCOUNT="$ACCOUNT"
    fi
fi

echo -e "${CYAN}Generating ${OUTPUT_FILE}${NC} from vault ${CYAN}${VAULT}${NC} (tag: ${CYAN}${TARGET}${NC})"

if ! op vault get "$VAULT" >/dev/null 2>&1; then
    echo -e "${RED}Vault '${VAULT}' not found (or not signed in)${NC}"
    echo "  Run: op signin"
    exit 1
fi

# Check item count BEFORE writing a header — skip cleanly if nothing to do.
# Frontend-local intentionally has no items today; don't fail the run for it.
ITEMS=$(op item list --vault="$VAULT" --tags="$TARGET" --format json 2>/dev/null | jq -r '.[].title')

if [ -z "$ITEMS" ]; then
    echo -e "${YELLOW}  No items tagged '${TARGET}' in vault '${VAULT}' — skipping${NC}"
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
cat > "$OUTPUT_FILE" << EOF
# ================================================
# Environment: ${ENV} (${TARGET})
# Source: 1Password/${VAULT} (tag: ${TARGET})
# Generated: $(date)
# ================================================
# DO NOT COMMIT THIS FILE
# Regenerate: task env ENV=${ENV} TARGET=${TARGET}
# ================================================

EOF

# Read every item tagged with $TARGET in $VAULT, in parallel.
# Supports both 1Password categories we use:
#   - "API Credential"  → value in field `credential`
#   - "Password"        → value in field `password`
# Try credential first (newer UI default), fall back to password.
echo "$ITEMS" | \
    xargs -P 10 -I {} sh -c '
        ITEM="$1"
        VAULT_NAME="'"$VAULT"'"
        VALUE=$(op read "op://${VAULT_NAME}/${ITEM}/credential" 2>/dev/null \
             || op read "op://${VAULT_NAME}/${ITEM}/password"   2>/dev/null \
             || true)
        if [ -z "$VALUE" ]; then
            echo "  ! Failed to read ${ITEM} (no credential/password field)" >&2
            exit 0
        fi
        printf "%s=%s\n" "${ITEM}" "${VALUE}"
    ' _ {} | grep -E '^[A-Z_][A-Z0-9_]*=' >> "$OUTPUT_FILE" || true

VAR_COUNT=$(grep -cE '^[A-Z_][A-Z0-9_]*=' "$OUTPUT_FILE" 2>/dev/null || true)
VAR_COUNT="${VAR_COUNT:-0}"

if [ "$VAR_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No valid env vars written to ${OUTPUT_FILE}${NC}"
    echo "  Items must have a credential/password field and an UPPER_SNAKE_CASE title."
    rm -f "$OUTPUT_FILE"
    exit 1
fi

echo -e "${GREEN}Wrote ${VAR_COUNT} variables to ${OUTPUT_FILE}${NC}"
