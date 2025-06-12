#!/bin/bash

# Usage: ./secure_protect_repo.sh owner/repo GITHUB_TOKEN

if [ $# -ne 2 ]; then
  echo -e "\033[0;31m❌ Usage: $0 owner/repo GITHUB_TOKEN\033[0m"
  exit 1
fi

REPO=$1
TOKEN=$2

# === Color codes ===
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function check_success {
  local status=$1
  local message=$2
  if [[ "$status" == "200" || "$status" == "201" || "$status" == "204" ]]; then
    echo -e "${GREEN}✅ $message${NC}"
  else
    echo -e "${RED}❌ Failed: $message (HTTP $status)${NC}"
    exit 1
  fi
}

# === Get default branch ===
echo -e "${CYAN}🔍 Fetching default branch...${NC}"
DEFAULT_BRANCH=$(curl -s -H "Authorization: token $TOKEN" \
  https://api.github.com/repos/$REPO | jq -r '.default_branch')

if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" == "null" ]; then
  echo -e "${RED}❌ Failed to retrieve default branch. Check repository and token.${NC}"
  exit 1
else
  echo -e "${CYAN}ℹ️ Default branch: $DEFAULT_BRANCH${NC}"
fi

# === Define Protection Rules ===
read -r -d '' PAYLOAD <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "ci/test",
      "ci/lint",
      "ci/security-scan"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

#"restrictions": {
#  "users": [],
#  "teams": ["maintainers"]
#},

# === Apply Branch Protection ===
echo -e "${CYAN}🔍 Payload being sent:${NC}"
echo "$PAYLOAD" | jq .

echo -e "${CYAN}🔐 Applying branch protection rules...${NC}"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$REPO/branches/$DEFAULT_BRANCH/protection \
  -d "$PAYLOAD")

# Extract status code
HTTP_STATUS=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')
BODY=$(echo "$RESPONSE" | sed -e 's/HTTP_STATUS\:.*//g')

# Output response
if [[ "$HTTP_STATUS" =~ ^2 ]]; then
  echo -e "${GREEN}✅ Branch protection rules applied successfully!${NC}"
else
  echo -e "${RED}❌ Failed: Branch protection rules applied (HTTP $HTTP_STATUS)${NC}"
  echo -e "${RED}🚨 Response Body:${NC}"
  echo "$BODY" | jq .
  exit 1
fi

# === Enable Secret Scanning Push Protection ===
echo -e "${CYAN}🛡️ Enabling secret scanning push protection...${NC}"
STATUS=$(curl -X PATCH -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$REPO/security-and-analysis \
  -d '{"secret_scanning_push_protection": {"status": "enabled"}}')
check_success $STATUS "Secret scanning push protection enabled"

# === Enable Secret Scanning ===
echo -e "${CYAN}🧪 Enabling secret scanning...${NC}"
STATUS=$(curl -X PATCH -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$REPO/security-and-analysis \
  -d '{"secret_scanning": {"status": "enabled"}}')
check_success $STATUS "Secret scanning enabled"

# === Enable Dependabot Alerts ===
echo -e "${CYAN}📦 Enabling Dependabot alerts...${NC}"
STATUS=$(curl -X PUT -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$REPO/vulnerability-alerts)
check_success $STATUS "Dependabot vulnerability alerts enabled"

echo -e "${GREEN}🎉 All protections and security settings successfully applied to $REPO!${NC}"