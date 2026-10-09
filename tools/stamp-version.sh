#!/bin/bash
# index.html から読み込むデータのファイルに、中身から作った版番号(?v=…)を付け直す。
# ブラウザは同じアドレスのファイルを10分ほど使い回すため、付けないと「本体は新しいのにデータは古い」が起きる。
# 中身が変わったときだけ番号が変わる。git のコミット前に自動で実行される(.git/hooks/pre-commit)。
cd "$(dirname "$0")/.."
for f in phrases-data.js audio/manifest.js; do
  v=$(shasum "$f" | cut -c1-8)
  esc=$(printf '%s' "$f" | sed 's/[.\/]/\\&/g')
  sed -i '' -E "s#(<script src=\"${esc})(\\?v=[0-9a-f]*)?\"#\\1?v=${v}\"#" index.html
done
grep -o '<script src="[^"]*"' index.html
