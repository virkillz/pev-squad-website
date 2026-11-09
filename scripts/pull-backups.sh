#!/usr/bin/env bash
# Download production backups (DB dumps + uploads mirror) from the droplet to this Mac.
#
#   scripts/pull-backups.sh            # -> ~/Backups/pev_squad
#   scripts/pull-backups.sh /some/dir  # -> custom destination
#
# Incremental: only new/changed files are transferred. Old local dumps are kept
# (the server prunes to 7 days; your local copy keeps whatever you've pulled).
set -euo pipefail

SERVER="deploy@159.223.73.156"
DEST="${1:-$HOME/Backups/pev_squad}"

mkdir -p "$DEST"
chmod 700 "$DEST"   # dumps contain user emails and password hashes

rsync -az "$SERVER:/var/backups/pev_squad/" "$DEST/"

echo
echo "Backups in $DEST:"
ls -1t "$DEST/db" | head -10
echo "uploads: $(find "$DEST/uploads" -type f | wc -l | tr -d ' ') files"
