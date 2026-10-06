#!/bin/bash
# 使い方の説明に載せる画面写真を撮る(Google Chrome を画面なしで動かす)。
# 先に BabyShopEnglish フォルダで「python3 -m http.server 8765」を起動しておくこと。写真は tutorial/*.jpg に書き出す。
# 印を付ける部品の位置は、ブラウザで tools/shot.html?s=画面名&rects=1 を開くと表示される。
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE="http://127.0.0.1:8765/tools/shot.html"
TMP=$(mktemp -d)
mkdir -p tutorial
for s in ${@:-home cat flash pron add my}; do
  # 撮影し終わっても Chrome が終了しないことがあるので、写真ができたら止める
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --mute-audio --user-data-dir="$TMP/profile" \
    --window-size=375,812 --force-device-scale-factor=2 --virtual-time-budget=6000 \
    --screenshot="$TMP/$s.png" "$BASE?s=$s" >/dev/null 2>&1 &
  pid=$!
  for i in $(seq 1 60); do [ -s "$TMP/$s.png" ] && sleep 1 && break; sleep 0.5; done
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  if [ -s "$TMP/$s.png" ]; then
    sips -s format jpeg -s formatOptions 72 -Z 1000 "$TMP/$s.png" --out "tutorial/$s.jpg" >/dev/null && echo "撮影: $s"
  else
    echo "失敗: $s"
  fi
done
rm -rf "$TMP"
