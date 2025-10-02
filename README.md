# あっちむいてホイ4 iOS版

## 使い方（日本語）
1. アプリを起動すると「最初はグー！」のメッセージが表示されます。
2. じゃんけんの手（グー・チョキ・パー）を選択します。
3. 勝敗が決まると、あっちむいてホイの指差し（上・右・下・左）を選びます。
4. CPUと同じ向きを指した場合、攻撃側の勝ち。違う場合は「勝負つかず」でもう一度。
5. スコアは画面下部に表示されます。リセットボタンでスコアを0にできます。
6. 設定ボタンから言語（日本語/英語）、音声（女の子/男の子/ロボット）、速度、クラウド同期を変更できます。

## 細かいルール（日本語）
- じゃんけんで勝った方が攻撃側、負けた方が防御側。
- あっちむいてホイで攻撃側と防御側の指差し方向が一致したら攻撃側の勝ち。
- 一致しなければ「勝負つかず」となり、再度じゃんけんからやり直し。
- スコアはクラウド同期ONでiCloudに保存され、複数端末で共有可能。
- 音声は設定で声種・速度を選択可能。

---

# Attimuitehoi4 for iOS

## How to Use (English)
1. Launch the app to see the "Saisho wa Goo!" message.
2. Select your hand (Rock, Scissors, Paper) for Janken.
3. After the result, choose a direction (Up, Right, Down, Left) for Attimuitehoi.
4. If the CPU points in the same direction, the attacker wins. Otherwise, it's a draw and you retry.
5. Scores are shown at the bottom. Use the reset button to clear scores.
6. Use the settings button to change language (Japanese/English), voice (Girl/Boy/Robot), speed, and cloud sync.

## Detailed Rules (English)
- The winner of Janken becomes the attacker, the loser is the defender.
- In Attimuitehoi, if both point in the same direction, the attacker wins.
- If not, it's a draw and the game restarts from Janken.
- Scores are saved to iCloud when cloud sync is ON, and shared across devices.
- Voice type and speed can be changed in settings.

## TTS generation and embedding

You can auto-generate TTS MP3 files from the project's Localizable.strings and embed them into the app resources using the scripts in `scripts/`.

Generate and embed (example):

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
pip install -r scripts/requirements.txt
python3 scripts/generate_and_embed_tts.py --langs ja,en --out tts_output
```

This will generate MP3s using Google Cloud Text-to-Speech and copy them into `Attimuitehoi4-ios/Attimuitehoi4-ios/Resources/TTS/<lang>/` and attempt to git commit/push them.
