#!/bin/sh
set -e
## Regenerates the filter lists the iOS adblock engine (apple/lunascape/AdBlock, EngineHandler.swift) loads
## from Settings.bundle/AdblockResources/Easylist. The same sources as Lunascape Mobile's Android list
## (gu-corp/adblock-resources filter_lists/default.json) plus the uBlock Origin yearly and quick-fix lists:
##   list.txt      uBlock Origin, EasyList, EasyPrivacy, malware URLs, Brave's lists
##   list1458.txt  AdGuard Japanese
##   list7545.txt  Fanboy's Mobile Notifications
##   list8055.txt  EasyList Cookie List + uBlock Origin cookie notices
## Run from the repository root: sh scripts/update-ios-adblock-lists.sh

OUT=apple/Settings.bundle/AdblockResources/Easylist
UBO=https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters
ADGUARD_JA=https://filters.adtidy.org/extension/ublock/filters/7.txt
WORK=/tmp/$$
mkdir "$WORK"

curl -fsSL https://raw.githubusercontent.com/gu-corp/adblock-resources/develop/filter_lists/default.json \
  | jq -r '.[].url' | grep -vF "$ADGUARD_JA" > "$WORK/urls.txt"
for year in 2023 2024 2025 2026; do echo "$UBO/filters-$year.txt" >> "$WORK/urls.txt"; done
echo "$UBO/quick-fixes.txt" >> "$WORK/urls.txt"

: > "$WORK/list.txt"
while read -r url; do
  curl -fsSL "$url" >> "$WORK/list.txt"
  echo >> "$WORK/list.txt"
done < "$WORK/urls.txt"

curl -fsSL "$ADGUARD_JA" > "$WORK/list1458.txt"
curl -fsSL https://secure.fanboy.co.nz/fanboy-mobile-notifications.txt > "$WORK/list7545.txt"
{ curl -fsSL https://secure.fanboy.co.nz/fanboy-cookiemonster.txt; echo; curl -fsSL "$UBO/annoyances-cookies.txt"; } > "$WORK/list8055.txt"

for f in list.txt list1458.txt list7545.txt list8055.txt; do
  test -s "$WORK/$f"
  cp "$WORK/$f" "$OUT/$f"
  echo "$f: $(wc -l < "$OUT/$f") lines"
done
rm -rf "$WORK"
