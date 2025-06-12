#!/bin/bash

# Usage: ./apply_protection.sh owner/repo GITHUB_TOKEN

if [ $# -ne 2 ]; then
  echo "Usage: $0 owner/repo GITHUB_TOKEN"
  exit 1
fi

REPO=$1
TOKEN=$2
PAYLOAD_FILE="branch-protection.json"

if [ ! -f "$PAYLOAD_FILE" ]; then
  echo "❌ Payload file '$PAYLOAD_FILE' not found."
  exit 1
fi

# Get default branch from GitHub API
DEFAULT_BRANCH=$(curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO" | jq -r '.default_branch')

if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" == "null" ]; then
  echo "❌ Failed to retrieve default branch for $REPO."
  exit 1
fi

# Check if branch is already protected
PROTECTION_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO/branches/$DEFAULT_BRANCH/protection")

if [[ "$PROTECTION_STATUS" =~ ^2 ]]; then
  echo "ℹ️ Branch protection already enabled for $REPO ($DEFAULT_BRANCH). Skipping."
  exit 2
fi

# Apply protection rules
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/branches/$DEFAULT_BRANCH/protection" \
  -d @"$PAYLOAD_FILE")

# Extract status and response
HTTP_STATUS="${RESPONSE##*HTTP_STATUS:}"
BODY="${RESPONSE%HTTP_STATUS:*}"

if [[ "$HTTP_STATUS" =~ ^2 ]]; then
  echo "✅ Protection applied to $REPO."
  exit 0
else
  echo "❌ Failed to apply protection to $REPO (HTTP $HTTP_STATUS)"
  echo "🚨 Response:"
  echo "$BODY" | jq .
  exit 1
fi