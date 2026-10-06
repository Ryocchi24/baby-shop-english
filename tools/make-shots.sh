#!/bin/bash
# 使い方の説明に載せる画面写真を撮る(Google Chrome を画面なしで動かす)。
# 先に BabyShopEnglish フォルダで「python3 -m http.server 8765」を起動しておくこと。
# 写真は tutorial/*.jpg に、印を付ける位置は tutorial/marks.js に書き出す(写真と同じ Chrome で測るので、ずれない)。
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BASE="http://127.0.0.1:8765/tools/shot.html"
TMP=$(mktemp -d)
FLAGS=(--headless=new --disable-gpu --hide-scrollbars --mute-audio --user-data-dir="$TMP/profile" --window-size=375,812 --virtual-time-budget=6000)
mkdir -p tutorial
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
echo "// 使い方の説明の印の位置(画面に対する%で 左・上・幅・高さ)。tools/make-shots.sh が書き出す(手で編集しない)" > "$TMP/marks.js"
echo "window.TUTORIAL_MARKS = {" >> "$TMP/marks.js"
for s in home cat flash pron add my; do
  run_chrome "$TMP/$s.png" "" "${FLAGS[@]}" --force-device-scale-factor=2 --screenshot="$TMP/$s.png" "$BASE?s=$s"
  run_chrome "$TMP/stdout" "</html>" "${FLAGS[@]}" --dump-dom "$BASE?s=$s&rects=1"
  rects=$(tr -d '\n' < "$TMP/stdout" | sed -n 's:.*<pre id="out">\([^<]*\)</pre>.*:\1:p')
  rm -f "$TMP/stdout"
  if [ -s "$TMP/$s.png" ] && [ -n "$rects" ]; then
    sips -s format jpeg -s formatOptions 72 -Z 1000 "$TMP/$s.png" --out "tutorial/$s.jpg" >/dev/null
    echo "  $s: $rects," >> "$TMP/marks.js"
    echo "撮影: $s $rects"
  else
    echo "失敗: $s"
  fi
done
echo "};" >> "$TMP/marks.js"
cp "$TMP/marks.js" tutorial/marks.js
rm -rf "$TMP"
