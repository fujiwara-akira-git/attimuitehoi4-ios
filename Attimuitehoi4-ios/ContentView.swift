import SwiftUI
import AVFAudio
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// 復元された完全実装: じゃんけん -> あっちむいてホイ の流れを含む
// - 指定アセットを厳密に使用
// - じゃんけん結果は両手を約2秒表示
// - 小さなサムネイル HStack は表示しない

struct ContentView: View {
    // MARK: - Types
    enum Hand: String, CaseIterable {
        case goo
        case choki
        case pa
    }

    enum Direction: String, CaseIterable {
        case up
        case right
        case down
        case left
    }

    enum Phase {
        case idle   // waiting for user to press Start
        case ready
        case janken
        case aimm
        case result
    }

    // MARK: - State
    @State private var phase: Phase = .idle
    @State private var playerHand: Hand? = nil
    @State private var cpuHand: Hand? = nil
    @State private var isCpuAttacker: Bool = false
    @State private var playerDirection: Direction? = nil
    @State private var cpuDirection: Direction? = nil
    @State private var message: String = ""
    @State private var showQuitAlert: Bool = false
    @State private var lastMessageKey: String? = nil
    @State private var isTransitioning: Bool = false
    @State private var finalWinner: String? = nil // "player" or "cpu"
    @State private var playerScore: Int = 0
    @State private var cpuScore: Int = 0
    // Cloud observer token
    @State private var cloudObserver: NSObjectProtocol? = nil
    @State private var didShowInitial: Bool = false
    @State private var showAimmButtons: Bool = true
    @State private var showSettingsSheet: Bool = false
    // Developer UI state (removed)
    // Settings
    @State private var cloudSyncEnabled: Bool = true
    // internal codes for options (language-independent)
    @State private var selectedVoice: String = "girl"
    @State private var selectedVoiceID: String? = UserDefaults.standard.string(forKey: "selectedVoiceID")
    @State private var speedSetting: String = "normal"
    @State private var voiceQuality: String = "metan"
    // App language (ja/en) persisted in UserDefaults
    @AppStorage("appLanguage") private var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "ja"

    var body: some View {
        VStack(spacing: 12) {
            // 上部: メッセージボックス
            Text(message)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 3))

            // If in idle state and message is empty, show a prompt instructing user to press Start
            .onAppear {
                if phase == .idle && message.isEmpty {
                        setMessage(key: "start_prompt")
                }
            }

            // 上段: CPU 画像ブロック
            VStack(spacing: 8) {
                // じゃんけんの手を表示するフェーズでは、CPU 領域には
                // 指定の手画像（googal / pagal / chokigal）のみを表示する
                if phase == .janken, let cpuHand = cpuHand {
                    Image(cpuJankenHandName(for: cpuHand))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                } else {
                    // 通常時は顔（またはあっちむいてホイ時の指差し/向き画像）を表示
                    Image(cpuFaceImageName())
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                }
            }

            // 下段: プレイヤー画像ブロック
            VStack(spacing: 8) {
                // じゃんけんフェーズでは、プレイヤー領域の顔欄に手画像を表示し、
                // 手と顔が同時に表示されないようにする
                if phase == .janken, let playerHand = playerHand {
                    Image(playerJankenHandName(for: playerHand))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                } else {
                    // 通常時は顔（またはあっちむいてホイ時の指差し/向き画像）を表示
                    Image(playerFaceImageName())
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                }
            }

            // 選択ボタン群（じゃんけん or あっちむいてほい）
            Group {
                if phase == .ready || phase == .janken {
                    HStack(spacing: 18) {
                        Button(action: { playerPicked(.goo) }) {
                            Image("goo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 76, height: 76)
                        }
                        .disabled(isTransitioning)

                        Button(action: { playerPicked(.choki) }) {
                            Image("choki")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 76, height: 76)
                        }
                        .disabled(isTransitioning)

                        Button(action: { playerPicked(.pa) }) {
                            Image("pa")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 76, height: 76)
                        }
                        .disabled(isTransitioning)
                    }
                } else if phase == .aimm && showAimmButtons {
                    // あっちむいてほい フェーズ。ただし「勝負つかずもういちど！」表示中は
                    // 指のボタンを非表示にする（画面遷移の演出のため）。
                    HStack(spacing: 18) {
                        Button(action: { playerPoint(.up) }) {
                            Image("top")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 66, height: 66)
                        }
                        .disabled(isTransitioning)

                        Button(action: { playerPoint(.right) }) {
                            Image("right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 66, height: 66)
                        }
                        .disabled(isTransitioning)

                        Button(action: { playerPoint(.down) }) {
                            Image("down")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 66, height: 66)
                        }
                        .disabled(isTransitioning)

                        Button(action: { playerPoint(.left) }) {
                            Image("left")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 66, height: 66)
                        }
                        .disabled(isTransitioning)
                    }
                } else if phase == .aimm {
                    // あっちむいてほい フェーズだが showAimmButtons が false のときは
                    // 指ボタンを一切表示しない（演出中のため）。
                    EmptyView()
                } else if phase == .result {
                    // 結果表示は上段/下段で既に画像を差し替えているためここは空でもよい
                    EmptyView()
                }
            }
            .padding(.top, 8)
                            .disabled(isTransitioning)
            // (Top controls removed - Start/Quit moved to bottom controls per design)

            // spacer to separate game area from controls
            Spacer().frame(height: 18)

            // Main bottom controls: big score box, then Start/Quit, then Reset/Settings
            VStack(spacing: 12) {
                // Large score box
                VStack(alignment: .center, spacing: 6) {
                    Text("スコア")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 24) {
                        VStack(alignment: .center) {
                            Text("あなた")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(playerScore)")
                                .font(.largeTitle)
                                .bold()
                        }

                        Divider()
                            .frame(height: 44)

                        VStack(alignment: .center) {
                            Text("わたし")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(cpuScore)")
                                .font(.title)
                                .bold()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.quaternaryLabel)))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("スコア: あなた \(playerScore) わたし \(cpuScore)"))
                }

                // Start / Quit row
                HStack(spacing: 16) {
                    Button(action: {
                            // Start the game: user must press Start to begin. ResetAll triggers the
                            // initial "最初はグー！" animation and transitions to .ready when done.
                            didShowInitial = true
                            resetAll()
                        }) {
                        Text(localized("start_button"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 2))
                    }

                    Button(action: {
                        // Show confirmation dialog before quitting
                        showQuitAlert = true
                    }) {
                        Text(localized("quit_button"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 2))
                    }
                }

                // Reset / Settings row
                HStack(spacing: 16) {
                    Button(action: {
                        playerScore = 0
                        cpuScore = 0
                        resetAll()
                    }) {
                        Text(localized("reset_button"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 1))
                    }

                    Button(action: {
                        let defaults = UserDefaults.standard
                        cloudSyncEnabled = defaults.bool(forKey: "cloudSyncEnabled")
                        selectedVoice = defaults.string(forKey: "selectedVoice") ?? "girl"
                        speedSetting = defaults.string(forKey: "speedSetting") ?? "normal"
                        voiceQuality = defaults.string(forKey: "voiceQuality") ?? "metan"
                        showSettingsSheet = true
                    }) {
                        Text(localized("settings_button"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal)
            // (cloud buttons removed)
        }
        .padding()
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                Form {
                    Section(header: Text(localized("cloud_section_header"))) {
                        Toggle(localized("cloud_toggle"), isOn: $cloudSyncEnabled)
                    }

                    Section(header: Text(localized("voice_section_header"))) {
                        Picker(localized("voice_picker_label"), selection: $selectedVoice) {
                            Text(localized("voice_girl")).tag("girl")
                            Text(localized("voice_boy")).tag("boy")
                            Text("AI音声").tag("ai")
                            Text(localized("voice_robot")).tag("robot")
                        }
                        .pickerStyle(.segmented)
                        
                        // Voice Quality Selection
                        Picker("音声品質", selection: $voiceQuality) {
                            Text("標準").tag("standard")
                            Text("高品質").tag("enhanced")
                            Text("AI音声").tag("neural")
                            Text("四国めたん").tag("metan")
                        }
                        .pickerStyle(.segmented)


                        // 女の子・男の子・AI voice選択
                        if selectedVoice == "girl" || selectedVoice == "boy" || selectedVoice == "ai" {
                            let quality = SpeechHelper.VoiceQuality(rawValue: voiceQuality) ?? .metan
                            let voices = SpeechHelper.shared.availableVoices(language: appLanguage, type: selectedVoice, quality: quality)
                            if !voices.isEmpty {
                                Picker(selectedVoice == "girl" ? localized("voice_girl") : 
                                      selectedVoice == "boy" ? localized("voice_boy") : "AI音声", 
                                      selection: $selectedVoiceID) {
                                    ForEach(voices, id: \ .identifier) { v in
                                        Text("\(v.name) (\(v.quality == .enhanced ? "高品質" : "標準"))").tag(v.identifier as String?)
                                    }
                                }
                            } else {
                                Text("選択した品質の音声が利用できません")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }

                    Section(header: Text(localized("speed_section_header"))) {
                        Picker(localized("speed_picker_label"), selection: $speedSetting) {
                            Text(localized("speed_slow")).tag("slow")
                            Text(localized("speed_normal")).tag("normal")
                            Text(localized("speed_fast")).tag("fast")
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text(localized("language_section_header"))) {
                        Picker(localized("language_picker_label"), selection: $appLanguage) {
                            Text("日本語").tag("ja")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.segmented)
                    }

                }
                .navigationTitle(localized("settings_title"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localized("save")) {
                            // persist settings
                            let defaults = UserDefaults.standard
                            defaults.set(cloudSyncEnabled, forKey: "cloudSyncEnabled")
                            defaults.set(selectedVoice, forKey: "selectedVoice")
                            defaults.set(speedSetting, forKey: "speedSetting")
                            defaults.set(voiceQuality, forKey: "voiceQuality")
                            defaults.set(appLanguage, forKey: "appLanguage")
                            defaults.set(selectedVoiceID, forKey: "selectedVoiceID")
                            // SpeechHelperはstatelessなのでselectedVoiceIDの保存のみ
                            // Optionally enable/disable cloud sync behavior here
                            showSettingsSheet = false
                            // Apply language selection immediately
                            applyLanguageSelection()
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button(localized("close")) {
                            showSettingsSheet = false
                        }
                    }
                }
            }
        }
        .onAppear {
            // Do not auto-start the game on appear. The user must press Start.
            if cloudSyncEnabled {
                loadScoresFromCloud()
                cloudObserver = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default, queue: .main) { notif in
                    handleCloudChange(notification: notif)
                }
            } else {
                // ローカルのみ
                let defaults = UserDefaults.standard
                self.playerScore = defaults.integer(forKey: "playerScore")
                self.cpuScore = defaults.integer(forKey: "cpuScore")
            }
        }
        .onChange(of: message) { new in
            // existing message-based onChange left intentionally empty; speaking is handled by lastMessageKey
        }

        // Speak when the logical message key changes. For some keys we always force Japanese pronunciation.
        .onChange(of: lastMessageKey) { key in
            guard let key = key else { return }
            // keys that should always be spoken in Japanese regardless of UI language
            let alwaysSpeakJapanese: Set<String> = ["aimm_title", "initial_goo", "janken_tie"]

            let speakLang = alwaysSpeakJapanese.contains(key) ? "ja" : appLanguage
            let forceInterrupt = alwaysSpeakJapanese.contains(key)

            let speed: Float
            switch speedSetting {
            case "slow": speed = 0.35
            case "fast": speed = 0.65
            default: speed = 0.5
            }

            let textToSpeak = localized(key, language: speakLang)
            let quality = SpeechHelper.VoiceQuality(rawValue: voiceQuality) ?? .metan
            SpeechHelper.shared.speak(textToSpeak, language: speakLang, voiceType: selectedVoice, voiceID: selectedVoiceID, speed: speed, forceInterrupt: forceInterrupt, quality: quality, messageKey: key)
        }
        .alert(isPresented: $showQuitAlert) {
            Alert(
                title: Text(localized("quit_confirm_title")),
                message: Text(localized("quit_confirm_message")),
                primaryButton: .destructive(Text(localized("yes"))) {
                    // Call central quit handler
                    quitConfirmed()
                },
                secondaryButton: .cancel(Text(localized("no")))
            )
        }
    }

    // MARK: - Game logic

    private func playerPicked(_ hand: Hand) {
        guard !isTransitioning else { return }
    phase = .janken
    playerHand = hand
    cpuHand = cpuPickHand()
        isTransitioning = true

        let result = determineJanken(player: hand, cpu: cpuHand!)

        switch result {
        case .tie:
            // 表示中は文言を出さない（message は既に ""）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.playerHand = nil
                self.cpuHand = nil
                self.message = "" // 一度空文字に
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    setMessage(key: "janken_tie")
                }
                self.isTransitioning = false
                self.phase = .ready
            }

        case .player:
            // プレイヤー勝ちの表示中は攻撃者がプレイヤーである旨を表示
            setMessage(key: "you_attack")
            isCpuAttacker = false
            // あっちむいてホイ で勝敗を確定するためスコアの加算はここでは行わない
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // 入る直前に正面画像を表示
                self.playerHand = nil
                self.cpuHand = nil
                self.didShowInitial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.phase = .aimm
                    setMessage(key: "aimm_title")
                    self.showAimmButtons = true
                    self.isTransitioning = false
                }
            }

        case .cpu:
            // CPU勝ちの表示中は攻撃者がCPUである旨を表示
            setMessage(key: "cpu_attack")
            isCpuAttacker = true
            // スコアは aimm で勝者が確定した時に増やす
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.playerHand = nil
                self.cpuHand = nil
                self.didShowInitial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.phase = .aimm
                    setMessage(key: "aimm_title")
                    self.showAimmButtons = true
                    self.isTransitioning = false
                    self.cpuActAsAttackerIfNeeded()
                }
            }
        }
    }

    private func playerPoint(_ dir: Direction) {
        guard !isTransitioning else { return }
        isTransitioning = true
        playerDirection = dir
    // debug logs removed

        if isCpuAttacker {
            // CPU が攻撃者 -> プレイヤーは防御を選択したので、
            // プレイヤーの顔を向ける（playerDirection がセット）と同時に
            // CPU の指差しを表示するため cpuDirection をここでセットする。
            // これにより表示はほぼ同時に切り替わる。
            self.cpuDirection = self.cpuPickDirection()
            // debug logs removed
            evaluateAimm(attackerIsPlayer: false)
        } else {
            // プレイヤーが攻撃者 -> CPU の指差しを決めて評価
            cpuDirection = cpuPickDirection()
            // debug logs removed
            evaluateAimm(attackerIsPlayer: true)
        }
    }

    private func cpuActAsAttackerIfNeeded() {
        guard phase == .aimm && isCpuAttacker else { return }
        // CPU が攻撃者のときは、あっちむいてほい に入った直後は
        // CPU の指差し画像を表示せず（cpuDirection を nil のまま）
        // `Girl_front` を表示しておき、プレイヤーの防御入力を待つ。
        // プレイヤーが入力したタイミングで playerPoint() 側が cpuDirection を
        // 同時にセットして表示する設計に変更する。
        // ここではプレイヤーが選べるように待機状態にするだけ。
        isTransitioning = false
        self.cpuDirection = nil
    setMessage(key: "aimm_title")
    // debug logs removed
    }

    // MARK: - Localization helpers
    // Load a localized string for the currently selected appLanguage (appLanguage is "ja" or "en")
    private func localized(_ key: String) -> String {
        // Find bundle for language
        if let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj"), let b = Bundle(path: path) {
            return NSLocalizedString(key, bundle: b, comment: "")
        }
        return NSLocalizedString(key, comment: "")
    }

    // Fetch localized string for a specific language code (e.g. "ja" or "en")
    private func localized(_ key: String, language: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"), let b = Bundle(path: path) {
            return NSLocalizedString(key, bundle: b, comment: "")
        }
        return NSLocalizedString(key, comment: "")
    }

    // Apply the currently selected language to UI-visible messages immediately
    private func applyLanguageSelection() {
        // Update message and any static UI texts that were set programmatically
        if phase == .ready {
            setMessage(key: "janken_pon")
        } else if phase == .aimm {
            setMessage(key: "aimm_title")
        } else if phase == .result {
            // leave result message as-is; resetAll will reapply when returning
        } else if phase == .janken {
            // no-op; janken flow will set messages as necessary
        } else {
            setMessage(key: "initial_goo")
        }
    }

    private func evaluateAimm(attackerIsPlayer: Bool) {
        let attackerDir = attackerIsPlayer ? playerDirection : cpuDirection
        let defenderDir = attackerIsPlayer ? cpuDirection : playerDirection
        // 両者の向きが決まっていることを確認
        guard let a = attackerDir, let d = defenderDir else { return }

        // 要求に基づく分岐ルールを実装する
        // - プレイヤーが攻撃者のとき (attackerIsPlayer == true):
        //     - up/down の一致: プレイヤーの勝ち
        //     - right/right or left/left の一致: プレイヤーの勝ち
        //     - right/left や left/right の交差: 勝負つかず
        // - CPU が攻撃者のとき (attackerIsPlayer == false):
        //     - up/down の一致: CPU の勝ち
        //     - right/left や left/right の交差: CPU の勝ち
        //     - right/right or left/left の一致: 勝負つかず

        func finishWithWinner(_ winnerIsPlayer: Bool) {
            finalWinner = winnerIsPlayer ? "player" : "cpu"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.phase = .result
                if winnerIsPlayer {
                    setMessage(key: "you_win")
                    self.playerScore += 1
                    saveScoresToCloud()
                } else {
                    setMessage(key: "cpu_win")
                    self.cpuScore += 1
                    saveScoresToCloud()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.resetAll()
                }
            }
        }

    // debug logs removed
        // シンプルルール: 攻撃側と防御側の向きが同じ（up/up, down/down, left/left, right/right）なら
        // 攻撃側の勝ちとする。その他は「勝負つかず」とする。
        if a == d {
            // 攻撃側の勝ち
            finishWithWinner(attackerIsPlayer)
        } else {
            // 勝負つかずの演出（共通化）
            self.playerHand = nil
            self.cpuHand = nil
            self.showAimmButtons = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.playerDirection = nil
                self.cpuDirection = nil
                setMessage(key: "draw_retry")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.playerHand = .goo
                    self.cpuHand = .goo
                    setMessage(key: "initial_goo")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.playerHand = nil
                        self.cpuHand = nil
                        self.phase = .ready
                        self.isTransitioning = false
                        setMessage(key: "janken_pon")
                    }
                }
            }
        }
    }

    // MARK: - iCloud helpers (NSUbiquitousKeyValueStore)
    private let cloudPlayerKey = "playerScore"
    private let cloudCpuKey = "cpuScore"

    private func saveScoresToCloud() {
        // Always persist locally first
        let defaults = UserDefaults.standard
        defaults.set(playerScore, forKey: "playerScore")
        defaults.set(cpuScore, forKey: "cpuScore")

        // If cloud sync is enabled and an iCloud account is available, write to iCloud as well
        if cloudSyncEnabled && FileManager.default.ubiquityIdentityToken != nil {
            let store = NSUbiquitousKeyValueStore.default
            store.set(playerScore, forKey: cloudPlayerKey)
            store.set(cpuScore, forKey: cloudCpuKey)
            let ok = store.synchronize()
            if !ok {
                print("[saveScoresToCloud] NSUbiquitousKeyValueStore.synchronize() returned false")
            }
        } else {
            // iCloud not available or disabled; keep local UserDefaults as source of truth
            if cloudSyncEnabled {
                print("[saveScoresToCloud] cloudSyncEnabled but iCloud not available; saved to UserDefaults instead")
            }
        }
    }

    private func loadScoresFromCloud() {
        let defaults = UserDefaults.standard
        // Prefer iCloud values when enabled and available
        if cloudSyncEnabled && FileManager.default.ubiquityIdentityToken != nil {
            let store = NSUbiquitousKeyValueStore.default
            let p = store.longLong(forKey: cloudPlayerKey)
            let c = store.longLong(forKey: cloudCpuKey)
            if p != 0 || c != 0 {
                self.playerScore = Int(p)
                self.cpuScore = Int(c)
                // Also mirror to UserDefaults for local persistence
                defaults.set(self.playerScore, forKey: "playerScore")
                defaults.set(self.cpuScore, forKey: "cpuScore")
                return
            } else {
                print("[loadScoresFromCloud] iCloud available but no values found; falling back to UserDefaults")
            }
        }

        // Fallback to local storage
        self.playerScore = defaults.integer(forKey: "playerScore")
        self.cpuScore = defaults.integer(forKey: "cpuScore")
    }

    private func handleCloudChange(notification: Notification) {
        // Reload all cloud values
        loadScoresFromCloud()
    }


    // MARK: - Helpers

    private func resetAll() {
        // 決着後にじゃんけんへ戻る際は「最初はグー！」を表示してから
        // 少し待って通常の「ジャンケンポン！」状態（.ready）へ戻す
        finalWinner = nil
        // まず指向きはクリア
        playerDirection = nil
        cpuDirection = nil
        // 指ボタンは初期状態に戻す
        showAimmButtons = true

        // 両者グーを表示して "最初はグー！" とする
        playerHand = .goo
        cpuHand = .goo
    setMessage(key: "initial_goo")
        // リセットから戻る途中は遷移扱いにする
        isTransitioning = true

        // 少し待ってから通常状態へ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.playerHand = nil
            self.cpuHand = nil
            self.phase = .ready
            self.isTransitioning = false
            setMessage(key: "janken_pon")
        }
    }

    // Set the visible message by key and remember the key for TTS logic
    private func setMessage(key: String) {
        // Always update visible message immediately
        self.message = localized(key)

        // If the key is the same as the previous one, clear it first so SwiftUI's onChange
        // will fire even for repeated identical messages (e.g. repeated ties).
        if self.lastMessageKey == key {
            self.lastMessageKey = nil
            DispatchQueue.main.async {
                self.lastMessageKey = key
            }
        } else {
            self.lastMessageKey = key
        }
    }

    // Handle confirmed quit: save scores, attempt to suspend app (iOS) and then exit.
    private func quitConfirmed() {
        // Ensure scores are saved
        saveScoresToCloud()

#if canImport(UIKit)
        // Try to send app to background first (more graceful on simulator/device)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let sel = NSSelectorFromString("suspend")
            if UIApplication.shared.responds(to: sel) {
                UIApplication.shared.perform(sel)
            }
            // After a short delay, force exit to ensure process termination during development
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                exit(0)
            }
        }
#else
        // On non-UIKit platforms, just exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exit(0)
        }
#endif
    }

    private func cpuPickHand() -> Hand {
        Hand.allCases.randomElement()!
    }

    private func cpuPickDirection() -> Direction {
        Direction.allCases.randomElement()!
    }

    // あっちむいてほい の一致判定ヘルパー。
    // 通常は同じ向きで一致とする。
    // swapLR が true の場合、右/左を入れ替えて一致とみなす（right<->left が一致）。
    private func dirsMatch(_ a: Direction, _ b: Direction, swapLR: Bool = false) -> Bool {
        if a == b { return true }
        if swapLR {
            // 右と左を入れ替えて一致とする
            if (a == .right && b == .left) || (a == .left && b == .right) {
                return true
            }
        }
        return false
    }

    private enum JankenResult { case player, cpu, tie }

    private func determineJanken(player: Hand, cpu: Hand) -> JankenResult {
        if player == cpu { return .tie }
        switch (player, cpu) {
        case (.goo, .choki), (.choki, .pa), (.pa, .goo):
            return .player
        default:
            return .cpu
        }
    }

    // MARK: - Asset mapping (strict)

    private func cpuJankenHandName(for hand: Hand) -> String {
        switch hand {
        case .goo: return "googal"
        case .choki: return "chokigal"
        case .pa: return "pagal"
        }
    }

    private func playerJankenHandName(for hand: Hand) -> String {
        switch hand {
        case .goo: return "goo"
        case .choki: return "choki"
        case .pa: return "pa"
        }
    }

    private func cpuFaceImageName() -> String {
        // 結果フェーズでは勝敗画像を必ず表示する
        if phase == .result, let winner = finalWinner {
            let name = (winner == "cpu") ? "wingal" : "losegal"
            
            return name
        }

        // あっちむいてほい のとき
        if phase == .aimm {
            if isCpuAttacker {
                // CPUが攻撃者 -> 指差し画像 (upgal/rightgal/downgal/leftgal) を使うが
                // 指差す前は Girl_front を表示
                if let d = cpuDirection {
                    let name: String
                    switch d {
                    case .up: name = "upgal"
                    case .right: name = "rightgal"
                    case .down: name = "downgal"
                    case .left: name = "leftgal"
                    }
                    
                    return name
                }
                let name = "Girl_front"
                    
                return name
            } else {
                // CPUが防御側 -> 顔を向ける画像 (Girl_up/Girl_right/Girl_down/Girl_left)
                if let d = cpuDirection {
                    let name: String
                    switch d {
                    case .up: name = "Girl_up"
                    case .right: name = "Girl_right"
                    case .down: name = "Girl_down"
                    case .left: name = "Girl_left"
                    }
                    
                    return name
                }
                let name = "Girl_front"
                
                return name
            }
        }

        // それ以外は正面画像
        let name = "Girl_front"
        
        return name
    }

    private func playerFaceImageName() -> String {
        // 結果フェーズでは勝敗画像を必ず表示する
        if phase == .result, let winner = finalWinner {
            let name = (winner == "player") ? "boywin" : "boylose"
            
            return name
        }

        if phase == .aimm {
            if !isCpuAttacker {
                // プレイヤーが攻撃者 -> 指差し画像 (top/right/down/left)
                if let d = playerDirection {
                    let name: String
                    switch d {
                    case .up: name = "top"
                    case .right: name = "right"
                    case .down: name = "down"
                    case .left: name = "left"
                    }
                    
                    return name
                }
                let name = "boyfront"
                
                return name
            } else {
                // プレイヤーが防御 -> 顔を向ける画像 (youup/youright/youdown/youleft)
                if let d = playerDirection {
                    let name: String
                    switch d {
                    case .up: name = "youup"
                    case .right: name = "youright"
                    case .down: name = "youdown"
                    case .left: name = "youleft"
                    }
                    
                    return name
                }
                let name = "boyfront"
                
                return name
            }
        }

        let name = "boyfront"
        
        return name
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
