#!/usr/bin/env bash
# =============================================================================
#  download_assets.sh — free, royalty-free asset downloader (NO API key)
# =============================================================================
#   Downloads CC0 / royalty-free packs from Kenney.nl using its public
#   "download-link" endpoint. All Kenney packs on this site are CC0
#   (public-domain-like: free to use in any engine, commercial projects,
#   no attribution required). No account, no API key needed.
#
#   Usage:
#     ./download_assets.sh <pack-slug> [target-dir]
#   Examples:
#     ./download_assets.sh interface-sounds assets/audio/interface-sounds
#     ./download_assets.sh impact-sounds   assets/audio/impact-sounds
#     ./download_assets.sh castle-kit      assets/3d/castle-kit
#
#   To find pack slugs: visit https://kenney.nl/assets and copy the URL
#   portion after /assets/ (e.g. https://kenney.nl/assets/castle-kit -> "castle-kit")
# =============================================================================

set -euo pipefail

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

SLUG="${1:?usage: download_assets.sh <pack-slug> [target-dir]}"
TARGET="${2:-assets/$SLUG}"

# --- 1. hex-encode "assets/<slug>" -> download id (as the site does) ---
DLID=$(python3 -c "import sys; print(sys.argv[1].encode().hex())" "assets/$SLUG")

echo "== resolving signed download link for '${SLUG}' ..."
JSON=$(curl -s -m 20 -A "$UA" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Referer: https://kenney.nl/assets/$SLUG" \
  "https://kenney.nl/download-link/$DLID")

URL=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('url',''))" <<<"$JSON")
if [ -z "$URL" ]; then
  echo "ERROR: could not get download link (bad slug? wrong id?). Server said: $JSON" >&2
  exit 1
fi

echo "== downloading '${SLUG}' -> ${TARGET}.zip ..."
mkdir -p "$(dirname "$TARGET")"
curl -sL -m 120 -A "$UA" "$URL" -o "$TARGET.zip" -w "  http=%{http_code} size=%{size_download} bytes\n"

if [ "$(head -c 2 "$TARGET.zip")" != "PK" ]; then
  echo "ERROR: downloaded file is not a ZIP. Aborting." >&2
  exit 1
fi

echo "== extracting ..."
mkdir -p "$TARGET"
unzip -o -q "$TARGET.zip" -d "$TARGET"
echo "== done: $(find "$TARGET" -type f | wc -l) files in $TARGET"
ls -la "$TARGET" | head -15
