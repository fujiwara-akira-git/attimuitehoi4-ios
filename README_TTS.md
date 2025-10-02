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