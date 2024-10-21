#!/usr/bin/env bash
set -o pipefail

log() { printf -- "** %s\n" "$*" >&2; }

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel)"
contributors=$(git shortlog -es | cut -f2 | sed 's/^/- /' )

echo "???"

log "Creating file..."

cat > "$REPO_ROOT/CONTRIBUTORS.txt" <<- EOF
	### Contributors

	$contributors

	**Updating this list**

	Please do not edit this file manually. It is generated using \`bash ./scripts/generate-contributors-list.sh\`. 
	If a name is misspelled or appearing multiple times: add an entry in \`./.mailmap\`.
EOF

log "✅ CONTRIBUTORS.txt created with no errors."