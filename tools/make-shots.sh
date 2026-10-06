#!/bin/bash
# 使い方の説明に載せる画面写真を撮る(Google Chrome を画面なしで動かす)。
# 先に BabyShopEnglish フォルダで「python3 -m http.server 8765」を起動しておくこと。
# 写真は tutorial/*.jpg に、指す部品の位置は tutorial/marks.json に書き出す(写真と同じ Chrome で測るので、ずれない)。
# marks.json の version は写真の版番号。アプリは写真をこの番号付きで読むので、古い写真と新しい位置が混ざらない。
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE="http://127.0.0.1:8765/tools/shot.html"
TMP=$(mktemp -d)
# 画面なしの Chrome は、指定した高さのうち下の 90px ほどが写らない。縦に広く取って撮り、上から 812px ぶんを切り出す
FLAGS=(--headless=new --disable-gpu --hide-scrollbars --mute-audio --user-data-dir="$TMP/profile" --window-size=375,1000 --virtual-time-budget=6000)
mkdir -p tutorial
swiftc -O tools/crop-top.swift -o "$TMP/crop-top" 2>/dev/null || { echo "tools/crop-top.swift をビルドできませんでした(Xcode のコマンドラインツールが必要)"; exit 1; }
# 撮影し終わっても Chrome が終了しないことがあるので、結果ができたら止める
run_chrome(){ # $1=出来上がりを待つファイル $2=中に含まれるべき文字(空なら中身があればよい) 残り=Chromeの引数
  local file=$1 want=$2; shift 2
  "$CHROME" "$@" > "$TMP/stdout" 2>/dev/null &
  local pid=$!
  for i in $(seq 1 60); do
    if [ -s "$file" ] && { [ -z "$want" ] || grep -q "$want" "$file"; }; then sleep 0.5; break; fi
    sleep 0.5
  done
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
}
printf '{\n "version": "%s",\n "marks": {\n' "$(date +%Y%m%d%H%M%S)" > "$TMP/marks.json"
sep=""
failed=0
for s in home cat flash pron add my; do
  run_chrome "$TMP/$s.png" "" "${FLAGS[@]}" --force-device-scale-factor=2 --screenshot="$TMP/$s.png" "$BASE?s=$s"
  run_chrome "$TMP/stdout" "</html>" "${FLAGS[@]}" --dump-dom "$BASE?s=$s&rects=1"
  rects=$(tr -d '\n' < "$TMP/stdout" | sed -n 's:.*<pre id="out">\([^<]*\)</pre>.*:\1:p')
  rm -f "$TMP/stdout"
  if [ -s "$TMP/$s.png" ] && [ -n "$rects" ]; then
    "$TMP/crop-top" "$TMP/$s.png" "$TMP/$s-crop.png" 1624
    sips -s format jpeg -s formatOptions 72 -Z 1000 "$TMP/$s-crop.png" --out "tutorial/$s.jpg" >/dev/null
    printf '%s  "%s": %s' "$sep" "$s" "$rects" >> "$TMP/marks.json"
    sep=$',\n'
    echo "撮影: $s $rects"
  else
    echo "失敗: $s"
    failed=1
  fi
done
printf '\n }\n}\n' >> "$TMP/marks.json"
# 1つでも失敗したら位置データは書き換えない(欠けた位置データと写真が混ざらないように)
if [ $failed -eq 0 ]; then cp "$TMP/marks.json" tutorial/marks.json; else echo "失敗した画面があるので tutorial/marks.json は更新していません。もう一度実行してください"; fi
rm -f tutorial/marks.js
rm -rf "$TMP"
