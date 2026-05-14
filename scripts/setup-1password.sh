#!/usr/bin/env bash
set -euo pipefail

# Install dependencies, sign into 1Password, and pin a specific account to
# .1password.yml so generate-env.sh knows which account to read from when
# the same email is on multiple 1Password accounts.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}1Password Setup${NC}"
echo "==============="
echo ""

# Step 1: Dependencies
echo "Checking dependencies..."
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}  brew${NC}"
fi

if ! command -v op >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing 1Password CLI...${NC}"
    brew install 1password-cli
else
    echo -e "${GREEN}  op${NC}"
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing jq...${NC}"
    brew install jq
else
    echo -e "${GREEN}  jq${NC}"
fi

echo ""

# Step 2: Sign in
if ! op account list >/dev/null 2>&1; then
    echo -e "${YELLOW}Sign in to 1Password...${NC}"
    op signin
else
    echo -e "${GREEN}Already signed in to 1Password${NC}"
fi

echo ""

# Step 3: Pick the account that owns the NBA-Oracle vaults
echo -e "${CYAN}Select 1Password account${NC}"
ACCOUNTS=$(op account list --format json)
COUNT=$(echo "$ACCOUNTS" | jq '. | length')

if [ "$COUNT" -eq 0 ]; then
    echo -e "${RED}No 1Password accounts found${NC}"
    exit 1
elif [ "$COUNT" -eq 1 ]; then
    SELECTED=$(echo "$ACCOUNTS" | jq -r '.[0].user_uuid')
    EMAIL=$(echo "$ACCOUNTS" | jq -r '.[0].email')
    echo -e "${GREEN}Using: $EMAIL${NC}"
else
    echo "Available accounts:"
    echo ""
    echo "$ACCOUNTS" | jq -r 'to_entries | .[] | "  \(.key + 1)) \(.value.email)  (\(.value.url))"'
    echo ""
    while true; do
        printf "Select account number [1]: "
        read -r choice
        choice="${choice:-1}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$COUNT" ]; then
            SELECTED=$(echo "$ACCOUNTS" | jq -r ".[$((choice-1))].user_uuid")
            EMAIL=$(echo "$ACCOUNTS" | jq -r ".[$((choice-1))].email")
            URL=$(echo "$ACCOUNTS" | jq -r ".[$((choice-1))].url")
            break
        else
            echo -e "${RED}Invalid selection${NC}"
        fi
    done
    echo -e "${GREEN}Using: $EMAIL ($URL)${NC}"
fi

echo ""

# Step 4: Persist account UUID
cat > .1password.yml << EOF
# Pins which 1Password account generate-env.sh talks to.
# Regenerate via: task env:setup
account: $SELECTED
EOF
echo -e "${GREEN}Wrote .1password.yml${NC}"

echo ""
echo -e "${GREEN}Setup complete${NC}"
echo ""
echo "Next steps:"
echo "  - Verify vaults exist: op vault get NBA-Oracle-LOCAL && op vault get NBA-Oracle-PROD"
echo "  - Generate env files:  task env"
