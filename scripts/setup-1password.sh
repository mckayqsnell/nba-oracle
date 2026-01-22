#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   1Password Environment Setup       ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Step 1: Check dependencies
echo -e "${CYAN}Step 1: Checking dependencies${NC}"
echo "------------------------------"

if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}Homebrew installed${NC}"
fi

if ! command -v op >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing 1Password CLI...${NC}"
    brew install 1password-cli
else
    echo -e "${GREEN}1Password CLI installed${NC}"
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing jq...${NC}"
    brew install jq
else
    echo -e "${GREEN}jq installed${NC}"
fi

if ! command -v yq >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing yq...${NC}"
    brew install yq
else
    echo -e "${GREEN}yq installed${NC}"
fi

echo ""

# Step 2: Sign in to 1Password
echo -e "${CYAN}Step 2: 1Password Authentication${NC}"
echo "---------------------------------"

if ! op account list >/dev/null 2>&1; then
    echo -e "${YELLOW}Please sign in to 1Password${NC}"
    echo ""
    echo "You'll need:"
    echo "  - Your 1Password account email"
    echo "  - Your Secret Key (from Emergency Kit)"
    echo "  - Your Master Password"
    echo ""
    op signin
else
    echo -e "${GREEN}Already signed in to 1Password${NC}"
fi

echo ""

# Step 3: Select 1Password Account
echo -e "${CYAN}Step 3: Select 1Password Account${NC}"
echo "---------------------------------"

ACCOUNTS=$(op account list --format json)
ACCOUNT_COUNT=$(echo "$ACCOUNTS" | jq '. | length')

if [ "$ACCOUNT_COUNT" -eq "0" ]; then
    echo -e "${RED}No accounts found. Please sign in to 1Password first.${NC}"
    exit 1
elif [ "$ACCOUNT_COUNT" -eq "1" ]; then
    SELECTED_ACCOUNT=$(echo "$ACCOUNTS" | jq -r '.[0].user_uuid')
    ACCOUNT_EMAIL=$(echo "$ACCOUNTS" | jq -r '.[0].email')
    echo -e "${GREEN}Using account: $ACCOUNT_EMAIL${NC}"
else
    echo "Available accounts:"
    echo ""
    i=1
    while read -r account; do
        EMAIL=$(echo "$account" | jq -r '.email')
        USER_UUID=$(echo "$account" | jq -r '.user_uuid')
        printf "  %d) %s\n" "$i" "$EMAIL"
        ((i++))
    done < <(echo "$ACCOUNTS" | jq -c '.[]')
    echo ""

    while true; do
        printf "Select account number [1]: "
        read -r account_choice
        account_choice="${account_choice:-1}"

        if [[ "$account_choice" =~ ^[0-9]+$ ]] && [ "$account_choice" -ge "1" ] && [ "$account_choice" -le "$ACCOUNT_COUNT" ]; then
            SELECTED_ACCOUNT=$(echo "$ACCOUNTS" | jq -r ".[$((account_choice-1))].user_uuid")
            ACCOUNT_EMAIL=$(echo "$ACCOUNTS" | jq -r ".[$((account_choice-1))].email")
            break
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and $ACCOUNT_COUNT.${NC}"
        fi
    done
    echo -e "${GREEN}Using account: $ACCOUNT_EMAIL${NC}"
fi

echo ""

# Step 4: Select vault
echo -e "${CYAN}Step 4: Select 1Password Vault${NC}"
echo "-------------------------------"

echo "Fetching available vaults..."
VAULTS=$(op vault list --account="$SELECTED_ACCOUNT" --format json | jq -r '.[].name' | sort)

if [ -z "$VAULTS" ]; then
    echo -e "${RED}No vaults found. Please create a vault in 1Password first.${NC}"
    exit 1
fi

echo "Available vaults:"
echo ""
i=1
echo "$VAULTS" | while IFS= read -r vault; do
    printf "  %d) %s\n" "$i" "$vault"
    ((i++))
done
echo ""

DEFAULT_VAULT="NBA-Oracle"
if echo "$VAULTS" | grep -q "^${DEFAULT_VAULT}$"; then
    DEFAULT_PROMPT=" [${DEFAULT_VAULT}]"
else
    DEFAULT_PROMPT=""
fi

while true; do
    printf "Select vault number (or type vault name)${DEFAULT_PROMPT}: "
    read -r vault_choice

    if [ -z "$vault_choice" ] && [ -n "$DEFAULT_VAULT" ] && echo "$VAULTS" | grep -q "^${DEFAULT_VAULT}$"; then
        SELECTED_VAULT="$DEFAULT_VAULT"
        break
    fi

    if [[ "$vault_choice" =~ ^[0-9]+$ ]]; then
        SELECTED_VAULT=$(echo "$VAULTS" | sed -n "${vault_choice}p")
        if [ -n "$SELECTED_VAULT" ]; then
            break
        else
            echo -e "${RED}Invalid number. Please try again.${NC}"
        fi
    else
        if echo "$VAULTS" | grep -q "^${vault_choice}$"; then
            SELECTED_VAULT="$vault_choice"
            break
        else
            echo -e "${RED}Vault '${vault_choice}' not found. Please try again.${NC}"
        fi
    fi
done

echo -e "${GREEN}Using vault: $SELECTED_VAULT${NC}"
echo ""

# Step 5: Configure environments
echo -e "${CYAN}Step 5: Environment Configuration${NC}"
echo "----------------------------------"

ITEM_NAME="nba-oracle-api"
echo "1Password item: $ITEM_NAME"
echo ""

echo "Which environments do you need?"
echo "  1) local only"
echo "  2) local, prod (recommended)"
echo ""

printf "Select option [2]: "
read -r env_choice
env_choice="${env_choice:-2}"

case "$env_choice" in
    1)
        ENVIRONMENTS="local"
        ;;
    2)
        ENVIRONMENTS="local prod"
        ;;
    *)
        ENVIRONMENTS="local prod"
        ;;
esac

echo -e "${GREEN}Environments: $ENVIRONMENTS${NC}"
echo ""

# Step 6: Save configuration
echo -e "${CYAN}Step 6: Saving Configuration${NC}"
echo "-----------------------------"

ENV_ARRAY=$(echo "$ENVIRONMENTS" | yq -o yaml -I2 'split(" ")')

cat > .1password.yml << EOF
# 1Password Environment Configuration
# Generated: $(date -u)

# The 1Password account to use
account: $SELECTED_ACCOUNT

# The vault where your environment variables are stored
vault: $SELECTED_VAULT

# The 1Password item name (Secure Note) containing your secrets
item: $ITEM_NAME

# List of environments (sections within the 1Password item)
environments:
$(echo "$ENV_ARRAY" | sed 's/^/  /')
EOF

echo -e "${GREEN}Configuration saved to .1password.yml${NC}"
echo ""

# Final summary
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Setup Complete!                   ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  Account:      $ACCOUNT_EMAIL"
echo "  Vault:        $SELECTED_VAULT"
echo "  Item:         $ITEM_NAME"
echo "  Environments: $ENVIRONMENTS"
echo ""
echo "Next steps:"
echo "  1. Create a Secure Note named '$ITEM_NAME' in vault '$SELECTED_VAULT'"
echo "  2. Add sections for: $ENVIRONMENTS"
echo "  3. Add environment variables to each section"
echo "  4. Run 'task env' to generate .env files"
