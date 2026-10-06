// 収録済みの単語・例文・フレーズのお手本音声を、無料の音声合成AI「Kokoro」(Apache-2.0)でこのMacの中で作る。お金はかからない。
//
//   使い方(BabyShopEnglish/tools フォルダで、最初の1回だけ npm install):
//     npm install
//     node make-audio.mjs --dry     … 作る件数を見るだけ
//     node make-audio.mjs           … 作成(初回は音声モデル約90MBをダウンロードする)
//
//   - audio/ に m4a(AAC) を書き出し、audio/manifest.js(アプリが読む一覧)を作り直す。
//   - すでにある音声は作り直さない。phrases-data.js の英文を書き換えたものだけ作り直すので、何度実行してもよい。
//   - 声は環境変数 TTS_VOICE で変えられる(既定 af_heart = アメリカ英語の女性。変えると全部作り直しになる)。
//   - wav → m4a の変換に macOS 標準の afconvert を使う。
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import vm from "node:vm";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const AUDIO_DIR = path.join(ROOT, "audio");
const MODEL = "onnx-community/Kokoro-82M-v1.0-ONNX";
const DTYPE = "q8";
const VOICE = process.env.TTS_VOICE || "af_heart";
const SPEED = 0.95; // 学習用に、ほんの少しだけゆっくり
const DRY = process.argv.includes("--dry");

// phrases-data.js をブラウザと同じように読み込む
const ctx = {};
vm.runInNewContext(fs.readFileSync(path.join(ROOT, "phrases-data.js"), "utf8") + "\nthis.PHRASE_BOOK = PHRASE_BOOK;", ctx);

const jobs = [];
for(const c of ctx.PHRASE_BOOK){
  c.items.forEach((row, i) => {
    const id = `${c.id}-${i + 1}`; // index.html と同じ振り方
    jobs.push({ id, part:"word", text:row[0] });
    if(c.kind === "word" && row[3]) jobs.push({ id, part:"ex", text:row[3] });
  });
}
for(const j of jobs){
  const hash = crypto.createHash("sha1").update([MODEL, DTYPE, VOICE, SPEED, j.text].join("\n")).digest("hex").slice(0, 8);
  j.file = `${j.id}${j.part === "ex" ? "-ex" : ""}.${hash}.m4a`;
}
const todo = jobs.filter(j => !fs.existsSync(path.join(AUDIO_DIR, j.file)));
console.log(`音声 ${jobs.length}件のうち、新しく作るのは ${todo.length}件`);
if(DRY) process.exit(0);

fs.mkdirSync(AUDIO_DIR, { recursive:true });
let failed = 0;
if(todo.length){
  const { KokoroTTS } = await import("kokoro-js");
  console.log("音声モデルを読み込んでいます…");
  const tts = await KokoroTTS.from_pretrained(MODEL, { dtype:DTYPE, device:"cpu" });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "kokoro-"));
  let done = 0;
  for(const job of todo){
    try{
      const wav = path.join(tmp, "out.wav");
      const audio = await tts.generate(job.text, { voice:VOICE, speed:SPEED });
      await audio.save(wav);
      execFileSync("afconvert", ["-f", "m4af", "-d", "aac", "-b", "64000", wav, path.join(AUDIO_DIR, job.file)]);
      done++;
      process.stdout.write(`\r${done}/${todo.length} 作成`);
    }catch(e){
      failed++;
      console.error(`\n失敗: ${job.id} (${job.part}) ${e.message}`);
    }
  }
  process.stdout.write("\n");
  fs.rmSync(tmp, { recursive:true, force:true });
}

// 一覧を作り直す(ファイルがあるものだけ載せる)。古くなった音声ファイルは消す
const manifest = {};
for(const j of jobs){
  if(!fs.existsSync(path.join(AUDIO_DIR, j.file))) continue;
  (manifest[j.id] = manifest[j.id] || {})[j.part] = { file:j.file, text:j.text };
}
const keep = new Set(jobs.map(j => j.file));
for(const f of fs.readdirSync(AUDIO_DIR)){
  if(/\.(mp3|m4a)$/.test(f) && !keep.has(f)) fs.unlinkSync(path.join(AUDIO_DIR, f));
}
fs.writeFileSync(path.join(AUDIO_DIR, "manifest.js"),
  "// お手本音声の一覧。tools/make-audio.mjs が書き出す(手で編集しない)\nwindow.AUDIO_MANIFEST = " + JSON.stringify(manifest, null, 1) + ";\n");
console.log(`完了: ${Object.keys(manifest).length}項目の音声を一覧に載せました${failed ? `（失敗 ${failed}件。もう一度実行すると続きから作ります）` : ""}`);
