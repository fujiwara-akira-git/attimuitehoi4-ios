# TTS generation and embedding

このドキュメントは、Google Cloud Text-to-Speech を使って `Localizable.strings` から高品質な MP3 を生成し、Xcode プロジェクトのリソースとして埋め込む手順と設定のメモです。

## 重要な位置
- スクリプト: `scripts/generate_tts.py`
- オーケストレーター: `scripts/generate_and_embed_tts.py`
- UI ラッパー（簡易）: `scripts/run_tts_for_ui.py`
- 音声リソース配置: `Attimuitehoi4-ios/Attimuitehoi4-ios/Resources/TTS/<lang>/` (例: `.../Resources/TTS/ja`)

## 環境準備
1. Google Cloud Console で Text-to-Speech API を有効化する。
2. サービスアカウントを作成し、`GOOGLE_APPLICATION_CREDENTIALS` 環境変数を指す JSON キーをローカルに保存する。
   - 既にレポジトリに鍵を残してしまった場合は、鍵をローテートし、履歴から削除してください（git filter-repo や BFG を使用）。
3. Python 3 と所定の依存モジュールを用意する（requirements.txt を参照／追加済みであればそれを使う）。

## 基本的な使い方
生成して埋め込む最短コマンド例:

1) 生成から埋め込みまで実行（例: 日本語 + 英語）

```
python3 scripts/generate_and_embed_tts.py --langs ja,en --out tts_output
```

2) 既に生成済みのファイルをプロジェクトにコピーするだけ（開発者毎の再生成を回避したい場合）:

```
python3 scripts/generate_and_embed_tts.py --langs ja,en --out tts_output --skip-generate
```

## UI から呼ぶ（開発者向け簡易ラッパー）
アプリの UI（`ContentView.swift` など）で選択したラベル（`girl`, `boy`, `robot` など）をそのまま渡してスクリプトを実行できるように、簡易ラッパー `scripts/run_tts_for_ui.py` を用意しました。ローカル開発用で、CI からの呼び出しにも使えます。

例:

```
python3 scripts/run_tts_for_ui.py --roles girl,boy --langs ja --out tts_output
```

このラッパーは内部で `scripts/generate_and_embed_tts.py` を呼び出します。より細かい上書き（voice id の指定や rate/pitch の変更）は直接 `generate_and_embed_tts.py` を使ってください。

## プリセット（role → voice のマッピング）
スクリプトには "役割(role)" プリセットが組み込まれており、UI で `girl`/`boy`/`robot` といったラベルを選ぶだけで信頼できる音声IDが選択されます。プリセットは各言語ごとに異なる音声 ID をマッピングします。

デフォルト例（実装で採用している代表例）:

- girl
  - ja: ja-JP-Neural2-C
  - en: en-US-Neural2-D
- boy
  - ja: ja-JP-Neural2-B
  - en: en-US-Neural2-B
- robot
  - ja: ja-JP-Chirp3-HD-Achernar
  - en: en-US-Chirp3-HD-Polaris

スクリプト実行時に `--roles girl,boy` を渡すと、各ロールごとに個別の出力ディレクトリ（例: `tts_roles/girl/ja`）が作られます。

## プリセットを上書きする
プリセットを上書きしたい場合は `generate_and_embed_tts.py` の `--voice-map` を使って言語ごとに voice-id を指定できます。

例: 日本語を `ja-JP-Neural2-C` に、英語を `en-US-Neural2-D` に固定して生成する:

```
python3 scripts/generate_tts.py --langs ja,en --out tts_output --voice-map "ja:ja-JP-Neural2-C,en:en-US-Neural2-D"
```

その他、`--rate` / `--pitch` のフラグで話速やピッチを調整できます。

## ファイル命名ポリシー
- 出力ファイルは言語サフィックスを付与して生成されます: `<key>_<lang>.mp3`（例: `janken_pon_ja.mp3`）。
- 既存のプロジェクト内の MP3 は migration ロジックで自動的にリネームされ、重複による Xcode のビルドエラー（Multiple commands produce）を回避します。

## トラブルシューティング
- xcodebuild で "Multiple commands produce" エラーが出る場合: 古い MP3 が言語サフィックスなしで残っている可能性があります。`generate_and_embed_tts.py --skip-generate` を実行してマイグレーションを有効にしてください。
- プロジェクトが特定のローカルパスを参照していて lstat エラーが出る場合: `Attimuitehoi4-ios.xcodeproj/project.pbxproj` の PBXFileReference path を repo 相対パスに揃えてください（変更は既に本リポジトリで行われています）。

## セキュリティと CI
- サービスアカウントの JSON は決してコミットしないでください。既に公開してしまった場合は鍵を即ローテートして、履歴から削除してください。
- CI では、`GOOGLE_APPLICATION_CREDENTIALS` をセキュアなシークレットストアに保存し、ビルド時に注入してください。

---
追加の希望（UI から直接生成をトリガーするボタン、プリセットの編集 UI、CI の自動化ジョブなど）があれば教えてください。軽微な拡張（例: `generate_and_embed_tts.py` に HTTP フックを追加してプロジェクト内ボタンで生成をトリガーする）は低リスクなので代行できます。
TTS 資産生成手順

このプロジェクトでは、Google Cloud Text-to-Speech を用いて高品質な MP3 音声を事前生成し、アプリのバイナリへ埋め込んでいます。

目的
- ローカルで安定した音声再生を行うために、高品質 MP3 を事前生成して Resources に追加します。

スクリプト
- `scripts/generate_tts.py` — Localizable.strings を読み、指定した言語ごとに TTS を生成して `--out` に出力します。
- `scripts/generate_and_embed_tts.py` — 複数言語の生成を行い、生成物を `Attimuitehoi4-ios/Attimuitehoi4-ios/Resources/TTS/<lang>/` にコピーして git に追加・コミット・push します。既存のプロジェクト内ファイル名を言語サフィックス（`_<lang>`）で移行する機能もあります。

準備
1. Google Cloud プロジェクトを作成し、Cloud Text-to-Speech API を有効にします。
2. サービスアカウントを作成し、JSON キーをダウンロードします。
   - 最低限必要なロールは `Cloud Text-to-Speech API User`（もしくはプロジェクトへの権限）です。
3. ローカル環境で `GOOGLE_APPLICATION_CREDENTIALS` という環境変数を設定して、ダウンロードした JSON へのパスを指定します。
   - macOS (zsh) の例:

```zsh
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/path/to/service-account.json"
```

セキュリティ上の注意
- サービスアカウント JSON をリポジトリにコミットしないでください。誤ってコミットした場合は、速やかにキーをローテーションして（GCP 側でキーを無効化/削除）から Git 履歴の修正を行ってください。
- CI で生成を行う場合は、Secrets/Variables 機能を用いて JSON の内容を安全に渡すか、CI のサービスアカウントを使う設定を検討してください。

基本的な使い方
1. 生成して埋め込み（推奨、一度に実行）:

```zsh
python3 scripts/generate_and_embed_tts.py --langs ja,en --out tts_output
```

- オプション:
  - `--skip-generate` — 既に生成済みのファイルを使ってプロジェクトへコピー/移行だけ行います。
  - `--voice-map` — `ja:ja-JP-Wavenet-A,en:en-US-Wavenet-A` のように言語ごとの音声IDを指定できます。
  - `--rate` / `--pitch` — 生成時の話速・ピッチを指定します。

2. 生成後、スクリプトは自動で `git add`/`git commit`/`git push` を試みます。必要に応じて手動で差分を確認してから push することもできます。

備考: Xcode 側の設定
- 生成ファイルは `Attimuitehoi4-ios/Attimuitehoi4-ios/Resources/TTS/<lang>/` に置かれます。通常はこのフォルダを Xcode に追加しておけば、将来的にファイルが追加されても Project Navigator に反映されます。もし Copy Bundle Resources に直接登録している場合は、重複や名前衝突に注意してください（本スクリプトは言語サフィックス `_ja` / `_en` を付与して衝突を回避します）。

トラブルシューティング
- Cloud TTS が "API not enabled" と言われる場合: GCP コンソールで Cloud Text-to-Speech API を有効化してください。
- 生成時に権限エラーが出る場合: サービスアカウントのキーが正しいか、環境変数 `GOOGLE_APPLICATION_CREDENTIALS` が指しているファイルが存在するか確認してください。
- Xcode ビルドで "Multiple commands produce" のようなエラーが出た場合: これは同名ファイルが複数の場所から同じバンドルパスへコピーされようとしたときに起こります。スクリプトはファイル名に言語サフィックスを付けることでこの問題を回避するようにしています。

追加サポート
- CI で自動生成するワークフローを作る場合、どの CI を使うか教えてください。私が GitHub Actions / Bitrise / CircleCI などのサンプル workflow を用意します。

---
ドキュメントを更新しました。必要ならこの README を `README.md` に統合する、またはプロジェクトの主 README に短い説明とリンクを追加することを行えます。