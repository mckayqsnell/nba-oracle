#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Environment variable validation pattern
ENV_VAR_PATTERN='^[A-Z_][A-Z0-9_]*='

# Check if configuration file exists
if [ ! -f ".1password.yml" ]; then
    echo -e "${RED}Configuration file '.1password.yml' not found${NC}"
    echo ""
    echo "Run 'task setup' to create the configuration file."
    exit 1
fi

# Load configuration from YAML (supports both 'item' and legacy 'repository' field)
IFS=$'\t' read -r ACCOUNT VAULT ITEM < <(yq -r '[.account, .vault, (.item // .repository)] | @tsv' .1password.yml)

# Validate required fields
if [ -z "$VAULT" ] || [ "$VAULT" = "null" ]; then
    echo -e "${RED}Missing 'vault' in .1password.yml${NC}"
    exit 1
fi

if [ -z "$ITEM" ] || [ "$ITEM" = "null" ]; then
    echo -e "${RED}Missing 'item' in .1password.yml${NC}"
    exit 1
fi

ENV="${1:-local}"

# Set up account flag
ACCOUNT_FLAG=""
if [ -n "$ACCOUNT" ] && [ "$ACCOUNT" != "null" ]; then
    ACCOUNT_FLAG="--account=$ACCOUNT"
fi

ITEM_NAME="$ITEM"
OUTPUT_FILE=".env.${ENV}"

echo -e "${BLUE}Generating environment file from 1Password${NC}"
if [ -n "$ACCOUNT" ] && [ "$ACCOUNT" != "null" ]; then
    echo -e "   Account: ${CYAN}${ACCOUNT}${NC}"
fi
echo -e "   Vault:   ${CYAN}${VAULT}${NC}"
echo -e "   Item:    ${CYAN}${ITEM_NAME}${NC}"
echo -e "   Section: ${CYAN}${ENV}${NC}"
echo -e "   File:    ${CYAN}${OUTPUT_FILE}${NC}"
echo ""

# Check if item exists
if ! op item get "$ITEM_NAME" --vault="$VAULT" $ACCOUNT_FLAG >/dev/null 2>&1; then
    echo -e "${RED}Item '${ITEM_NAME}' not found in vault '${VAULT}'${NC}"
    echo ""
    echo "Create it manually in 1Password with:"
    echo "  Title: ${ITEM_NAME}"
    echo "  Vault: ${VAULT}"
    echo "  Type:  Secure Note"
    echo "  Add sections for each environment (${ENV}, etc.)"
    exit 1
fi

# Create the .env file with header
cat > "$OUTPUT_FILE" << EOF
# ================================================
# Environment: ${ENV}
# Generated: $(date)
# Source: 1Password/${VAULT}/${ITEM_NAME}/${ENV}
# ================================================
# DO NOT COMMIT THIS FILE TO GIT
# Regenerate with: task env ENV=${ENV}
# ================================================

EOF

# Fetch the item from 1Password
TEMP_FILE=$(mktemp)
op item get "$ITEM_NAME" --vault="$VAULT" $ACCOUNT_FLAG --format json > "$TEMP_FILE"

# Find the section ID for the requested environment
SECTION_IDS=($(jq -r --arg env "$ENV" '
    .sections[]? |
    select(.label == $env) |
    .id' "$TEMP_FILE"))

if [ "${#SECTION_IDS[@]}" -eq 0 ]; then
    SECTION_ID=""
elif [ "${#SECTION_IDS[@]}" -eq 1 ]; then
    SECTION_ID="${SECTION_IDS[0]}"
else
    echo -e "${RED}Multiple sections found with label '${ENV}'${NC}"
    rm -f "$TEMP_FILE"
    exit 1
fi

if [ -z "$SECTION_ID" ]; then
    echo -e "${YELLOW}Section '${ENV}' not found in 1Password item${NC}"
    echo ""
    echo "Available sections:"
    jq -r '.sections[]? | "  - \(.label)"' "$TEMP_FILE" 2>/dev/null || echo "  (none)"
    echo ""
    echo "To add the '${ENV}' section:"
    echo "  1. Open the item in 1Password"
    echo "  2. Add a new section named '${ENV}'"
    echo "  3. Add your environment variables"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Extract fields from the specified section
jq -r --arg section_id "$SECTION_ID" '
    .fields[]? |
    select(.section != null) |
    select(.section.id == $section_id) |
    select(.value != null and .value != "") |
    select(.type == "STRING" or .type == "CONCEALED" or .type == "EMAIL" or .type == "URL") |
    "\(.label)=\(.value)"' "$TEMP_FILE" | \
    grep -E "$ENV_VAR_PATTERN" >> "$OUTPUT_FILE" || true

# Count variables
VAR_COUNT=$(grep -c "$ENV_VAR_PATTERN" "$OUTPUT_FILE" || echo "0")

rm -f "$TEMP_FILE"

if [ "$VAR_COUNT" -eq "0" ]; then
    echo -e "${YELLOW}No environment variables found in section '${ENV}'${NC}"
    echo ""
    echo "Add fields to the '${ENV}' section in 1Password"
else
    echo -e "${GREEN}Generated ${OUTPUT_FILE} with ${VAR_COUNT} variables${NC}"
    echo ""
    echo "Variables:"
    grep "^[A-Za-z_][A-Za-z0-9_]*=" "$OUTPUT_FILE" | \
        sed 's/=.*//' | \
        sed 's/^/  - /' | \
        sort
fi
