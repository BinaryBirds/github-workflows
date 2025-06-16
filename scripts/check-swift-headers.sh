#!/usr/bin/env bash
set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

DEFAULT_AUTHOR="Binary Birds"
FIX_MODE=0
HAS_ERRORS=0

# Parse flags
while [ $# -gt 0 ]; do
  case "$1" in
    --fix)
      FIX_MODE=1
      ;;
    --author)
      shift
      DEFAULT_AUTHOR="$1"
      ;;
  esac
  shift
done

if [ "$FIX_MODE" -eq 1 ]; then
  log "Fix mode enabled — header lines will be updated or inserted."
else
  log "Checking Swift file headers..."
fi

ROOT_DIR_NAME_RAW=$(basename "$PWD")
PROJECT_NAME="$(printf "%s%s" "$(echo "$ROOT_DIR_NAME_RAW" | cut -c1 | tr '[:lower:]' '[:upper:]')" "$(echo "$ROOT_DIR_NAME_RAW" | cut -c2-)" )"

normalize_date() {
  raw="$1"
  if command -v gdate >/dev/null 2>&1; then
    gdate -d "$raw" +"%Y. %m. %d" 2>/dev/null
  else
    date -d "$raw" +"%Y. %m. %d" 2>/dev/null
  fi
}

get_file_creation_date() {
  file="$1"
  if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
    git log -1 --format="%ad" --date=format:"%Y. %m. %d" -- "$file"
  else
    date +"%Y. %m. %d"
  fi
}

is_header_present() {
  line1=$(sed -n '1p' "$1")
  line2=$(sed -n '2p' "$1")
  line3=$(sed -n '3p' "$1")
  line4=$(sed -n '4p' "$1")
  line5=$(sed -n '5p' "$1")

  echo "$line1" | grep -q "^//$" || return 1
  echo "$line2" | grep -q "^//  " || return 1
  echo "$line3" | grep -q "^//  " || return 1
  echo "$line4" | grep -q "^//$" || return 1
  echo "$line5" | grep -q "^//  Created by " || return 1
  return 0
}

check_or_fix_header() {
  file="$1"
  filename=$(basename "$file")
  [ "$filename" = "Package.swift" ] && return 0

  line1=$(sed -n '1p' "$file")
  line2=$(sed -n '2p' "$file")
  line3=$(sed -n '3p' "$file")
  line4=$(sed -n '4p' "$file")
  line5=$(sed -n '5p' "$file")

  if echo "$line5" | grep -Eq "^//  Created by .+ on [0-9]{4}\. [0-9]{2}\. [0-9]{2}\.\.$"; then
    author=$(echo "$line5" | sed -E 's|^//  Created by (.+) on .+\.\.$|\1|' | sed 's/ *$//')
    date=$(echo "$line5" | sed -E 's|^//  Created by .+ on (.+)\.\.$|\1|' | sed 's/ *$//')
  else
    author=$(echo "$line5" | sed -nE 's|^//  Created by (.+) on .+\.$|\1|p' | sed 's/ *$//')
    date_raw=$(echo "$line5" | sed -nE 's|^//  Created by .+ on (.+)\.$|\1|p' | sed 's/ *$//')
    
    [ -z "$author" ] && author="$DEFAULT_AUTHOR"
    date=$(normalize_date "$date_raw")
    [ -z "$date" ] && date=$(get_file_creation_date "$file")
  fi

  expected1="//"
  expected2="//  $filename"
  expected3="//  $PROJECT_NAME"
  expected4="//"
  expected5="//  Created by $author on $date.."

  if is_header_present "$file"; then
    modified=0

    if [ "$line1" != "$expected1" ]; then
      error "❌ $file - Line 1 is incorrect (expected: $expected1)"
      [ "$FIX_MODE" -eq 1 ] && line1="$expected1"
      modified=1
    fi
    if [ "$line2" != "$expected2" ]; then
      error "❌ $file - Line 2 is incorrect (expected: $expected2)"
      [ "$FIX_MODE" -eq 1 ] && line2="$expected2"
      modified=1
    fi
    if [ "$line3" != "$expected3" ]; then
      error "❌ $file - Line 3 is incorrect (expected: $expected3)"
      [ "$FIX_MODE" -eq 1 ] && line3="$expected3"
      modified=1
    fi
    if [ "$line4" != "$expected4" ]; then
      error "❌ $file - Line 4 is incorrect (expected: $expected4)"
      [ "$FIX_MODE" -eq 1 ] && line4="$expected4"
      modified=1
    fi
    if [ "$line5" != "$expected5" ]; then
      error "❌ $file - Line 5 is incorrect (expected: $expected5)"
      [ "$FIX_MODE" -eq 1 ] && line5="$expected5"
      modified=1
    fi

    if [ "$modified" -eq 1 ]; then
      if [ "$FIX_MODE" -eq 1 ]; then
        tmpfile=$(mktemp)
        echo "$line1" > "$tmpfile"
        echo "$line2" >> "$tmpfile"
        echo "$line3" >> "$tmpfile"
        echo "$line4" >> "$tmpfile"
        echo "$line5" >> "$tmpfile"
        tail -n +6 "$file" >> "$tmpfile"
        mv "$tmpfile" "$file"
        log "🔧 Fixed: $file"
      else
        return 1
      fi
    fi
  else
    if [ "$FIX_MODE" -eq 1 ]; then
      tmpfile=$(mktemp)
      echo "$expected1" > "$tmpfile"
      echo "$expected2" >> "$tmpfile"
      echo "$expected3" >> "$tmpfile"
      echo "$expected4" >> "$tmpfile"
      echo "$expected5" >> "$tmpfile"
      echo "" >> "$tmpfile"
      cat "$file" >> "$tmpfile"
      mv "$tmpfile" "$file"
      log "➕ Header added: $file"
    else
      error "❌ $file - Header missing or malformed"
      return 1
    fi
  fi
  return 0
}

IGNORE_FILE=".swiftheaderignore"
EXCLUDE_PATTERNS=()

if [ -f "$IGNORE_FILE" ]; then
  log "Using exclusion list from $IGNORE_FILE"
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -n "$line" && ! "$line" =~ ^# ]] && EXCLUDE_PATTERNS+=(":(exclude)$line")
  done < "$IGNORE_FILE"
else
  log "No exclusion file found, using default exclusions"
  EXCLUDE_PATTERNS+=(":(exclude).*")
  EXCLUDE_PATTERNS+=(":(exclude)*.txt")
  EXCLUDE_PATTERNS+=(":(exclude)*.sh")
  EXCLUDE_PATTERNS+=(":(exclude)*.html")
  EXCLUDE_PATTERNS+=(":(exclude)*.yaml")
  EXCLUDE_PATTERNS+=(":(exclude)README.md")
  EXCLUDE_PATTERNS+=(":(exclude)Package.resolved")
  EXCLUDE_PATTERNS+=(":(exclude)Makefile")
  EXCLUDE_PATTERNS+=(":(exclude)LICENSE")
  EXCLUDE_PATTERNS+=(":(exclude)Package.swift")
  EXCLUDE_PATTERNS+=(":(exclude)Docker/**")
fi

PATHS_TO_CHECK_FOR_LICENSE=()
while IFS= read -r -d '' file; do
  PATHS_TO_CHECK_FOR_LICENSE+=("$file")
done < <(git ls-files -z "${EXCLUDE_PATTERNS[@]}")

for file in "${PATHS_TO_CHECK_FOR_LICENSE[@]}"; do
  if ! check_or_fix_header "$file"; then
    HAS_ERRORS=1
  fi
done

if [ "$HAS_ERRORS" -eq 1 ]; then
  [ "$FIX_MODE" -eq 1 ] && log "⚠️ Some headers were fixed." || error "❌ Some files have header issues."
  exit 1
else
  [ "$FIX_MODE" -eq 1 ] && log "✅ Headers inserted or updated where necessary." || log "✅ All headers are valid."
  exit 0
fi