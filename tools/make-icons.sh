#!/bin/bash
# icons/icon.svg から、ホーム画面・タブ用のPNGを作る(Google Chrome を画面なしで動かして描く)。
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP=$(mktemp -d)
for size in 180 192 512 32; do
  printf '<html><body style="margin:0;overflow:hidden"><img src="file://%s/icons/icon.svg" style="display:block;width:%spx;height:%spx"></body></html>' "$PWD" $size $size > "$TMP/i.html"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$TMP/profile" --allow-file-access-from-files \
    --window-size=$size,$size --force-device-scale-factor=1 --screenshot="$TMP/$size.png" "file://$TMP/i.html" >/dev/null 2>&1 &
  pid=$!
  for i in $(seq 1 40); do [ -s "$TMP/$size.png" ] && sleep 0.5 && break; sleep 0.5; done
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  case $size in
    180) cp "$TMP/$size.png" icons/apple-touch-icon.png ;;
    32)  cp "$TMP/$size.png" icons/favicon-32.png ;;
    *)   cp "$TMP/$size.png" icons/icon-$size.png ;;
  esac
  echo "作成: $size"
done
rm -rf "$TMP"
