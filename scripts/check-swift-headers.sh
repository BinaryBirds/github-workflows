#!/usr/bin/env bash
# Swift Header Checker / Fixer
#
# - Verifies that Swift source files contain a standardized header
# - Can optionally fix or insert headers in-place (--fix)
# - Uses git to determine file creation dates where possible
# - Supports excluding files via .swiftheaderignore
#
# Intended usage:
#   - CI: fail if headers are missing or malformed
#   - Local: optionally auto-fix headers

set -euo pipefail

# Logging helpers (stderr, consistent formatting)
log()   { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

# Configuration / state
DEFAULT_AUTHOR="Binary Birds"
FIX_MODE=0          # 0 = check only, 1 = fix headers
HAS_ERRORS=0        # Tracks whether any file failed validation

# Argument parsing
# --fix           Enable automatic header fixing/insertion
# --author NAME   Override default author name
while [ $# -gt 0 ]; do
  case "$1" in
    --fix)
      FIX_MODE=1
      ;;
    --author)
      shift
      [ -z "${1:-}" ] && fatal "--author requires a value"
      DEFAULT_AUTHOR="$1"
      ;;
    *)
      fatal "Unknown argument: $1"
      ;;
  esac
  shift
done

if [ "$FIX_MODE" -eq 1 ]; then
  log "Fix mode enabled — header lines will be updated or inserted."
else
  log "Checking Swift file headers..."
fi

# Project name
# We intentionally use the repository directory name as-is.
# Repo names may be kebab-case, camelCase, or mixed.
PROJECT_NAME="$(basename "$PWD")"

# Date helpers
# normalize_date:
#   Attempts to normalize arbitrary date formats into:
#     YYYY. MM. DD
#
# get_file_creation_date:
#   Uses git history if the file is tracked, otherwise falls back to today
normalize_date() {
  local raw="$1"
  if command -v gdate >/dev/null 2>&1; then
    gdate -d "$raw" +"%Y. %m. %d" 2>/dev/null
  else
    date -d "$raw" +"%Y. %m. %d" 2>/dev/null
  fi
}

get_file_creation_date() {
  local file="$1"
  if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
    git log -1 --format="%ad" --date=format:"%Y. %m. %d" -- "$file"
  else
    date +"%Y. %m. %d"
  fi
}

# Header detection
#
# A valid header must match this structure exactly:
#
# //
# //  Filename.swift
# //  ProjectName
# //
# //  Created by Author on YYYY. MM. DD..
#
# This strictness is intentional.
is_header_present() {
  local file="$1"
  local line1 line2 line3 line4 line5

  line1=$(sed -n '1p' "$file")
  line2=$(sed -n '2p' "$file")
  line3=$(sed -n '3p' "$file")
  line4=$(sed -n '4p' "$file")
  line5=$(sed -n '5p' "$file")

  echo "$line1" | grep -q "^//$" || return 1
  echo "$line2" | grep -q "^//  " || return 1
  echo "$line3" | grep -q "^//  " || return 1
  echo "$line4" | grep -q "^//$" || return 1
  echo "$line5" | grep -q "^//  Created by " || return 1
  return 0
}

# Header validation / fixing
#
# - Skips Package.swift
# - Validates each header line individually
# - In fix mode:
#     - Updates incorrect headers
#     - Inserts missing headers
check_or_fix_header() {
  local file="$1"
  local filename
  filename=$(basename "$file")

  [ "$filename" = "Package.swift" ] && return 0

  local line1 line2 line3 line4 line5
  line1=$(sed -n '1p' "$file")
  line2=$(sed -n '2p' "$file")
  line3=$(sed -n '3p' "$file")
  line4=$(sed -n '4p' "$file")
  line5=$(sed -n '5p' "$file")

  local author date date_raw

  if echo "$line5" | grep -Eq "^//  Created by .+ on [0-9]{4}\. [0-9]{2}\. [0-9]{2}\.\.$"; then
    author=$(echo "$line5" | sed -E 's|^//  Created by (.+) on .+\.\.$|\1|' | sed 's/ *$//')
    date=$(echo "$line5" | sed -E 's|^//  Created by .+ on (.+)\.\.$|\1|' | sed 's/ *$//')
  else
    author=$(echo "$line5" | sed -nE 's|^//  Created by (.+) on .+\.$|\1|p' | sed 's/ *$//')
    date_raw=$(echo "$line5" | sed -nE 's|^//  Created by .+ on (.+)\.$|\1|p' | sed 's/ *$//')

    [ -z "$author" ] && author="$DEFAULT_AUTHOR"

    date=$(normalize_date "$date_raw")
    if [ -z "$date" ]; then
      log "Could not normalize date '$date_raw' in $file, using git date"
      date=$(get_file_creation_date "$file")
    fi
  fi

  local expected1="//"
  local expected2="//  $filename"
  local expected3="//  $PROJECT_NAME"
  local expected4="//"
  local expected5="//  Created by $author on $date.."

  if is_header_present "$file"; then
    local modified=0

    [ "$line1" != "$expected1" ] && { error "❌ $file - Line 1 incorrect"; line1="$expected1"; modified=1; }
    [ "$line2" != "$expected2" ] && { error "❌ $file - Line 2 incorrect"; line2="$expected2"; modified=1; }
    [ "$line3" != "$expected3" ] && { error "❌ $file - Line 3 incorrect"; line3="$expected3"; modified=1; }
    [ "$line4" != "$expected4" ] && { error "❌ $file - Line 4 incorrect"; line4="$expected4"; modified=1; }
    [ "$line5" != "$expected5" ] && { error "❌ $file - Line 5 incorrect"; line5="$expected5"; modified=1; }

    if [ "$modified" -eq 1 ]; then
      if [ "$FIX_MODE" -eq 1 ]; then
        local tmpfile
        tmpfile=$(mktemp)
        printf "%s\n%s\n%s\n%s\n%s\n" \
          "$line1" "$line2" "$line3" "$line4" "$line5" > "$tmpfile"
        tail -n +6 "$file" >> "$tmpfile"
        mv "$tmpfile" "$file"
        log "Fixed: $file"
      else
        return 1
      fi
    fi
  else
    if [ "$FIX_MODE" -eq 1 ]; then
      local tmpfile
      tmpfile=$(mktemp)
      printf "%s\n%s\n%s\n%s\n%s\n\n" \
        "$expected1" "$expected2" "$expected3" "$expected4" "$expected5" > "$tmpfile"
      cat "$file" >> "$tmpfile"
      mv "$tmpfile" "$file"
      log "Header added: $file"
    else
      error "❌ $file - Header missing or malformed"
      return 1
    fi
  fi

  return 0
}

# File exclusion handling
#
# - If .swiftheaderignore exists, use it
# - Otherwise apply sensible default exclusions
# - Uses git pathspec exclusions
IGNORE_FILE=".swiftheaderignore"
EXCLUDE_PATTERNS=()

if [ -f "$IGNORE_FILE" ]; then
  log "Using exclusion list from $IGNORE_FILE"
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -n "$line" && ! "$line" =~ ^# ]] && EXCLUDE_PATTERNS+=(":(exclude)$line")
  done < "$IGNORE_FILE"
else
  log "No exclusion file found, using default exclusions"
  EXCLUDE_PATTERNS+=(
    ":(exclude).*"
    ":(exclude)*.txt"
    ":(exclude)*.png"
    ":(exclude)*.jpeg"
    ":(exclude)*.jpg"
    ":(exclude)*.sh"
    ":(exclude)*.html"
    ":(exclude)*.yaml"
    ":(exclude)README.md"
    ":(exclude)Package.resolved"
    ":(exclude)Makefile"
    ":(exclude)LICENSE"
    ":(exclude)Package.swift"
    ":(exclude)Docker/**"
  )
fi

# Process all tracked files
PATHS_TO_CHECK_FOR_LICENSE=()
while IFS= read -r -d '' file; do
  PATHS_TO_CHECK_FOR_LICENSE+=("$file")
done < <(git ls-files -z "${EXCLUDE_PATTERNS[@]}")

for file in "${PATHS_TO_CHECK_FOR_LICENSE[@]}"; do
  if ! check_or_fix_header "$file"; then
    HAS_ERRORS=1
  fi
done

# Final result
if [ "$HAS_ERRORS" -eq 1 ]; then
  [ "$FIX_MODE" -eq 1 ] && log "⚠️ Some headers were fixed." || error "❌ Some files have header issues."
  exit 1
else
  [ "$FIX_MODE" -eq 1 ] && log "✅ Headers inserted or updated where necessary." || log "✅ All headers are valid."
  exit 0
fi