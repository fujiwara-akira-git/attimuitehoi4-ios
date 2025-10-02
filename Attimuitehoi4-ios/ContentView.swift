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
        case ready
        case janken
        case aimm
        case result
    }

    // MARK: - State
    @State private var phase: Phase = .ready
    @State private var playerHand: Hand? = nil
    @State private var cpuHand: Hand? = nil
    @State private var isCpuAttacker: Bool = false
    @State private var playerDirection: Direction? = nil
    @State private var cpuDirection: Direction? = nil
    @State private var message: String = ""
    @State private var isTransitioning: Bool = false
    @State private var finalWinner: String? = nil // "player" or "cpu"
    @State private var playerScore: Int = 0
    @State private var cpuScore: Int = 0
    // Cloud observer token
    @State private var cloudObserver: NSObjectProtocol? = nil
    @State private var didShowInitial: Bool = false
    @State private var showAimmButtons: Bool = true
    @State private var showSettingsSheet: Bool = false
    // Developer UI state
    @State private var showDevConfirm: Bool = false
    @State private var devOutputPreview: String = ""
    // Settings
    @State private var cloudSyncEnabled: Bool = true
    // internal codes for options (language-independent)
    @State private var selectedVoice: String = "girl"
    @State private var selectedVoiceID: String? = UserDefaults.standard.string(forKey: "selectedVoiceID")
    @State private var speedSetting: String = "normal"
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
            Spacer()

            // Developer-only debug area (only available in DEBUG build on Simulator)
            #if DEBUG && targetEnvironment(simulator)
            VStack(spacing: 8) {
                Divider()
                Text("Developer")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: {
                    // show confirmation before running
                    showDevConfirm = true
                }) {
                    Text("Run TTS (dev, dry-run)")
                        .font(.subheadline)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 1))
                }

                // Show a small preview of the last-run output (first N lines)
                if !devOutputPreview.isEmpty {
                    ScrollView(.vertical) {
                        Text(devOutputPreview)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }
                    .frame(maxHeight: 140)
                }
            }
            .confirmationDialog("Run TTS generator? This will invoke a local script on your machine (dry-run).", isPresented: $showDevConfirm, titleVisibility: .visible) {
                Button("Run (dry-run)") {
                    // Prepare the shell command we'd run locally
                    let roles = selectedVoice
                    let langs = appLanguage
                    let cmd = "python3 scripts/run_tts_for_ui.py --roles \(roles) --langs \(langs) --out tts_dev_output --skip-generate --dry-run"

                    #if canImport(UIKit)
                    // On iOS (simulator) we cannot spawn processes from the app; copy the command to clipboard
                    UIPasteboard.general.string = cmd
                    DispatchQueue.main.async {
                        self.devOutputPreview = "Command copied to clipboard:\n\(cmd)"
                        self.message = "Dev TTS: command copied to clipboard"
                    }
                    #else
                    // On non-UIKit platforms (e.g. macOS) attempt to run the command and capture preview
                    DispatchQueue.global(qos: .utility).async {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                        process.arguments = ["sh", "-c", cmd]
                        let pipe = Pipe()
                        process.standardOutput = pipe
                        process.standardError = pipe
                        do {
                            try process.run()
                        } catch {
                            DispatchQueue.main.async {
                                self.devOutputPreview = "Failed to start script: \(error)"
                            }
                            return
                        }
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(decoding: data, as: UTF8.self)
                        let lines = output.split(separator: "\n").map { String($0) }
                        let filtered = lines.prefix(12).joined(separator: "\n")
                        DispatchQueue.main.async {
                            self.devOutputPreview = filtered
                            self.message = "Dev TTS: finished (preview shown)"
                        }
                    }
                    #endif
                }
                Button("Cancel", role: .cancel) { }
            }
            #endif

            
            // 下部: スコアとリセット
            HStack {
                Text(String(format: localized("score_format"), playerScore, cpuScore))
                    .font(.subheadline)
                    .padding(12)
                            .disabled(isTransitioning)

                Spacer()

                Button(action: {
                    playerScore = 0
                    cpuScore = 0
                    resetAll()
                }) {
                    Text(localized("reset_button"))
                        .font(.subheadline)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 2))
                }

                Button(action: {
                    // 設定シートを表示
                    // Load saved values when opening
                    let defaults = UserDefaults.standard
                    cloudSyncEnabled = defaults.bool(forKey: "cloudSyncEnabled")
                    selectedVoice = defaults.string(forKey: "selectedVoice") ?? "girl"
                    speedSetting = defaults.string(forKey: "speedSetting") ?? "normal"
                    showSettingsSheet = true
                }) {
                    Text(localized("settings_button"))
                        .font(.subheadline)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 2))
                }
            }
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
                            Text(localized("voice_robot")).tag("robot")
                        }
                        .pickerStyle(.segmented)

                        // 女の子・男の子voice選択
                        if selectedVoice == "girl" || selectedVoice == "boy" {
                            let voices = SpeechHelper.shared.availableVoices(language: appLanguage, type: selectedVoice)
                            Picker(selectedVoice == "girl" ? localized("voice_girl") : localized("voice_boy"), selection: $selectedVoiceID) {
                                ForEach(voices, id: \ .identifier) { v in
                                    Text(v.name).tag(v.identifier as String?)
                                }
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
            // 最初に「最初はグー！」を表示して、お互いグーを見せる
            guard !didShowInitial else { return }
            didShowInitial = true
            self.playerHand = .goo
            self.cpuHand = .goo
            self.message = localized("initial_goo")
            // 少し待って通常モードへ
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.playerHand = nil
                self.cpuHand = nil
                self.message = localized("janken_pon")
                self.phase = .ready
            }
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
            // speak the message in the selected app language
            let speed: Float
            switch speedSetting {
            case "slow": speed = 0.35
            case "fast": speed = 0.65
            default: speed = 0.5
            }
            SpeechHelper.shared.speak(message, language: appLanguage, voiceType: selectedVoice, voiceID: selectedVoiceID, speed: speed)
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
                    self.message = localized("janken_tie")
                }
                self.isTransitioning = false
                self.phase = .ready
            }

        case .player:
            // プレイヤー勝ちの表示中は攻撃者がプレイヤーである旨を表示
            self.message = localized("you_attack")
            isCpuAttacker = false
            // あっちむいてホイ で勝敗を確定するためスコアの加算はここでは行わない
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // 入る直前に正面画像を表示
                self.playerHand = nil
                self.cpuHand = nil
                self.didShowInitial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.phase = .aimm
                    self.message = localized("aimm_title")
                    self.showAimmButtons = true
                    self.isTransitioning = false
                }
            }

        case .cpu:
            // CPU勝ちの表示中は攻撃者がCPUである旨を表示
            self.message = localized("cpu_attack")
            isCpuAttacker = true
            // スコアは aimm で勝者が確定した時に増やす
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.playerHand = nil
                self.cpuHand = nil
                self.didShowInitial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.phase = .aimm
                    self.message = localized("aimm_title")
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
        self.message = localized("aimm_title")
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

    // Apply the currently selected language to UI-visible messages immediately
    private func applyLanguageSelection() {
        // Update message and any static UI texts that were set programmatically
        if phase == .ready {
            self.message = localized("janken_pon")
        } else if phase == .aimm {
            self.message = localized("aimm_title")
        } else if phase == .result {
            // leave result message as-is; resetAll will reapply when returning
        } else if phase == .janken {
            // no-op; janken flow will set messages as necessary
        } else {
            self.message = localized("initial_goo")
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
                    self.message = localized("you_win")
                    self.playerScore += 1
                    saveScoresToCloud()
                } else {
                    self.message = localized("cpu_win")
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
                self.message = localized("draw_retry")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.playerHand = .goo
                    self.cpuHand = .goo
                    self.message = localized("initial_goo")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.playerHand = nil
                        self.cpuHand = nil
                        self.phase = .ready
                        self.isTransitioning = false
                        self.message = localized("janken_pon")
                    }
                }
            }
        }
    }

    // MARK: - iCloud helpers (NSUbiquitousKeyValueStore)
    private let cloudPlayerKey = "playerScore"
    private let cloudCpuKey = "cpuScore"

    private func saveScoresToCloud() {
        if cloudSyncEnabled {
            let store = NSUbiquitousKeyValueStore.default
            store.set(playerScore, forKey: cloudPlayerKey)
            store.set(cpuScore, forKey: cloudCpuKey)
            store.synchronize()
        } else {
            let defaults = UserDefaults.standard
            defaults.set(playerScore, forKey: "playerScore")
            defaults.set(cpuScore, forKey: "cpuScore")
        }
    }

    private func loadScoresFromCloud() {
        if cloudSyncEnabled {
            let store = NSUbiquitousKeyValueStore.default
            let p = store.longLong(forKey: cloudPlayerKey)
            let c = store.longLong(forKey: cloudCpuKey)
            if p != 0 || c != 0 {
                self.playerScore = Int(p)
                self.cpuScore = Int(c)
            }
        } else {
            let defaults = UserDefaults.standard
            self.playerScore = defaults.integer(forKey: "playerScore")
            self.cpuScore = defaults.integer(forKey: "cpuScore")
        }
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
    message = localized("initial_goo")
        // リセットから戻る途中は遷移扱いにする
        isTransitioning = true

        // 少し待ってから通常状態へ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.playerHand = nil
            self.cpuHand = nil
            self.phase = .ready
            self.isTransitioning = false
            self.message = localized("janken_pon")
        }
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
