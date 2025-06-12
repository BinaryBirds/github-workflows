#!/bin/bash

# Usage: ./apply_to_all_repos.sh github_owner GITHUB_TOKEN

if [ $# -ne 2 ]; then
  echo "Usage: $0 github_owner GITHUB_TOKEN"
  exit 1
fi

OWNER=$1
TOKEN=$2
SCRIPT="./apply_protection.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "❌ Required script '$SCRIPT' not found or not executable."
  exit 1
fi

# Detect if OWNER is a User or Organization
OWNER_TYPE=$(curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/users/$OWNER" | jq -r '.type')

if [ "$OWNER_TYPE" == "Organization" ]; then
  REPO_URL_BASE="https://api.github.com/orgs/$OWNER/repos?type=all"
elif [ "$OWNER_TYPE" == "User" ]; then
  AUTH_USER=$(curl -s -H "Authorization: token $TOKEN" \
    https://api.github.com/user | jq -r '.login')

  if [ "$OWNER" == "$AUTH_USER" ]; then
    REPO_URL_BASE="https://api.github.com/user/repos?affiliation=owner"
  else
    echo "❌ Cannot list private repositories for another user's account: $OWNER"
    exit 1
  fi
else
  echo "❌ Failed to determine if $OWNER is a user or organization."
  exit 1
fi

PAGE=1
TOTAL=0
SKIPPED=0
PROTECTED=0

while :; do
  RESPONSE=$(curl -s -H "Authorization: token $TOKEN" \
    "${REPO_URL_BASE}&per_page=100&page=$PAGE")

  COUNT=$(echo "$RESPONSE" | jq length)
  if [ "$COUNT" -eq 0 ]; then
    break
  fi

  echo "🔍 Found $COUNT repositories on page $PAGE..."

  while read -r REPO_DATA; do
    FULL_NAME=$(echo "$REPO_DATA" | jq -r '.full_name')
    ARCHIVED=$(echo "$REPO_DATA" | jq -r '.archived')

    if [ "$ARCHIVED" == "true" ]; then
      echo "⏭️ Skipping archived repo: $FULL_NAME"
      ((SKIPPED++))
      continue
    fi

    echo "➡️ Applying protection to: $FULL_NAME"
    bash "$SCRIPT" "$FULL_NAME" "$TOKEN"
    STATUS=$?

    if [ "$STATUS" -eq 0 ]; then
      echo "✅ Protection applied to: $FULL_NAME"
      ((PROTECTED++))
    else
      echo "❌ Failed to apply protection to: $FULL_NAME"
    fi

    echo ""
    ((TOTAL++))
  done < <(echo "$RESPONSE" | jq -c '.[]')

  PAGE=$((PAGE + 1))
done

echo "🎯 Summary:"
echo " - Total repos processed: $TOTAL"
echo " - Protection applied:     $PROTECTED"
echo " - Skipped (archived):     $SKIPPED"