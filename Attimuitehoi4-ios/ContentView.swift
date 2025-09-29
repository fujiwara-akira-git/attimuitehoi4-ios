import SwiftUI

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
    @State private var message: String = "最初はグー！"
    @State private var isTransitioning: Bool = false
    @State private var finalWinner: String? = nil // "player" or "cpu"
    @State private var playerScore: Int = 0
    @State private var cpuScore: Int = 0
    @State private var didShowInitial: Bool = false
    @State private var showAimmButtons: Bool = true

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

            // 下部: スコアとリセット
            HStack {
                Text("スコア: あなた \(playerScore)  — CPU \(cpuScore)")
                    .font(.subheadline)
                    .padding(12)
                            .disabled(isTransitioning)

                Spacer()

                Button(action: {
                    playerScore = 0
                    cpuScore = 0
                    resetAll()
                }) {
                    Text("reset")
                        .font(.subheadline)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 2))
                }
            }
        }
        .padding()
        .onAppear {
            // 最初に「最初はグー！」を表示して、お互いグーを見せる
            guard !didShowInitial else { return }
            didShowInitial = true
            self.playerHand = .goo
            self.cpuHand = .goo
            self.message = "最初はグー！"
            // 少し待って通常モードへ
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.playerHand = nil
                self.cpuHand = nil
                self.message = "ジャンケンポン！"
                self.phase = .ready
            }
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
                self.message = "あいこでしょ！"
                self.isTransitioning = false
                self.phase = .ready
            }

        case .player:
            // プレイヤー勝ちの表示中は攻撃者がプレイヤーである旨を表示
            self.message = "あなたが指差し"
            isCpuAttacker = false
            // あっちむいてホイ で勝敗を確定するためスコアの加算はここでは行わない
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // 入る直前に正面画像を表示
                self.playerHand = nil
                self.cpuHand = nil
                self.didShowInitial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.phase = .aimm
                    self.message = "指を上下左右に向けて"
                    self.showAimmButtons = true
                    self.isTransitioning = false
                }
            }

        case .cpu:
            // CPU勝ちの表示中は攻撃者がCPUである旨を表示
            self.message = "わたしが指差し"
            isCpuAttacker = true
            // スコアは aimm で勝者が確定した時に増やす
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.playerHand = nil
                self.cpuHand = nil
                self.didShowInitial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.phase = .aimm
                    self.message = "あっちむいてほい！"
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

        if isCpuAttacker {
            // CPU が攻撃者 -> プレイヤーは防御を選択したので、
            // プレイヤーの顔を向ける（playerDirection がセット）と同時に
            // CPU の指差しを表示するため cpuDirection をここでセットする。
            // これにより表示はほぼ同時に切り替わる。
            self.cpuDirection = self.cpuPickDirection()
            evaluateAimm(attackerIsPlayer: false)
        } else {
            // プレイヤーが攻撃者 -> CPU の指差しを決めて評価
            cpuDirection = cpuPickDirection()
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
    self.message = "あっちむいてほい！"
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
                    self.message = "あなたの勝ち！"
                    self.playerScore += 1
                } else {
                    self.message = "わたしの勝ち！"
                    self.cpuScore += 1
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.resetAll()
                }
            }
        }

        // 判定ヘルパー
        // CPU が攻撃者のときは defender の左右を入れ替えて比較する
        let defenderEffective: Direction = {
            if attackerIsPlayer { return d }
            switch d {
            case .left: return .right
            case .right: return .left
            default: return d
            }
        }()

        let isVertical = (a == .up && defenderEffective == .up) || (a == .down && defenderEffective == .down)
        let isHorizontalSame = (a == .right && defenderEffective == .right) || (a == .left && defenderEffective == .left)
        let isCrossHorizontal = (a == .right && defenderEffective == .left) || (a == .left && defenderEffective == .right)

        if attackerIsPlayer {
            // プレイヤー攻撃時: 同一（上下同士、または左右同士）でプレイヤー勝ち。
            // 左右が交差している場合は勝負つかず。
            if isVertical || isHorizontalSame {
                finishWithWinner(true)
            } else if isCrossHorizontal {
                // 勝負つかず
                self.playerHand = nil
                self.cpuHand = nil
                self.showAimmButtons = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.playerDirection = nil
                    self.cpuDirection = nil
                    self.message = "勝負つかずもういちど！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.playerHand = .goo
                        self.cpuHand = .goo
                        self.message = "最初はグー！"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            self.playerHand = nil
                            self.cpuHand = nil
                            self.phase = .ready
                            self.isTransitioning = false
                            self.message = "ジャンケンポン！"
                        }
                    }
                }
            } else {
                // その他の不一致（例: up vs right 等）は勝負つかず
                self.playerHand = nil
                self.cpuHand = nil
                self.showAimmButtons = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.playerDirection = nil
                    self.cpuDirection = nil
                    self.message = "勝負つかずもういちど！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.playerHand = .goo
                        self.cpuHand = .goo
                        self.message = "最初はグー！"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            self.playerHand = nil
                            self.cpuHand = nil
                            self.phase = .ready
                            self.isTransitioning = false
                            self.message = "ジャンケンポン！"
                        }
                    }
                }
            }
        } else {
            // CPU が攻撃者のとき: 縦一致 -> CPU 勝ち
            // 左右が交差 (right/left or left/right) -> CPU 勝ち
            // 左右同一 (right/right or left/left) -> 勝負つかず
            if isVertical || isCrossHorizontal {
                finishWithWinner(false)
            } else if isHorizontalSame {
                // 勝負つかず
                self.playerHand = nil
                self.cpuHand = nil
                self.showAimmButtons = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.playerDirection = nil
                    self.cpuDirection = nil
                    self.message = "勝負つかずもういちど！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.playerHand = .goo
                        self.cpuHand = .goo
                        self.message = "最初はグー！"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            self.playerHand = nil
                            self.cpuHand = nil
                            self.phase = .ready
                            self.isTransitioning = false
                            self.message = "ジャンケンポン！"
                        }
                    }
                }
            } else {
                // その他の不一致 -> 勝負つかず
                self.playerHand = nil
                self.cpuHand = nil
                self.showAimmButtons = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.playerDirection = nil
                    self.cpuDirection = nil
                    self.message = "勝負つかずもういちど！"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.playerHand = .goo
                        self.cpuHand = .goo
                        self.message = "最初はグー！"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            self.playerHand = nil
                            self.cpuHand = nil
                            self.phase = .ready
                            self.isTransitioning = false
                            self.message = "ジャンケンポン！"
                        }
                    }
                }
            }
        }
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
        message = "最初はグー！"
        // リセットから戻る途中は遷移扱いにする
        isTransitioning = true

        // 少し待ってから通常状態へ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.playerHand = nil
            self.cpuHand = nil
            self.phase = .ready
            self.isTransitioning = false
            self.message = "ジャンケンポン！"
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
            print("[DEBUG] cpuFaceImageName -> \(name) (result) phase=\(phase) finalWinner=\(String(describing: finalWinner))")
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
                    print("[DEBUG] cpuFaceImageName -> \(name) (cpu attacker) phase=\(phase) cpuDirection=\(String(describing: cpuDirection))")
                    return name
                }
                let name = "Girl_front"
                print("[DEBUG] cpuFaceImageName -> \(name) (cpu attacker, no direction) phase=\(phase) cpuDirection=\(String(describing: cpuDirection))")
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
                    print("[DEBUG] cpuFaceImageName -> \(name) (cpu defender) phase=\(phase) cpuDirection=\(String(describing: cpuDirection))")
                    return name
                }
                let name = "Girl_front"
                print("[DEBUG] cpuFaceImageName -> \(name) (cpu defender, no direction) phase=\(phase) cpuDirection=\(String(describing: cpuDirection))")
                return name
            }
        }

        // それ以外は正面画像
        let name = "Girl_front"
        print("[DEBUG] cpuFaceImageName -> \(name) (default) phase=\(phase) cpuDirection=\(String(describing: cpuDirection)) isCpuAttacker=\(isCpuAttacker)")
        return name
    }

    private func playerFaceImageName() -> String {
        // 結果フェーズでは勝敗画像を必ず表示する
        if phase == .result, let winner = finalWinner {
            let name = (winner == "player") ? "boywin" : "boylose"
            print("[DEBUG] playerFaceImageName -> \(name) (result) phase=\(phase) finalWinner=\(String(describing: finalWinner))")
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
                    print("[DEBUG] playerFaceImageName -> \(name) (player attacker) phase=\(phase) playerDirection=\(String(describing: playerDirection))")
                    return name
                }
                let name = "boyfront"
                print("[DEBUG] playerFaceImageName -> \(name) (player attacker, no direction) phase=\(phase) playerDirection=\(String(describing: playerDirection))")
                return name
            } else {
                // プレイヤーが防御 -> 顔を向ける画像 (youup/youright/youdown/youleft)
                if let d = playerDirection {
                    let name: String
                    switch d {
                    case .up: name = "youup"
                    // 右/左は入れ替える（CPUが攻撃者のときの視覚的要望）
                    case .right: name = "youleft"
                    case .down: name = "youdown"
                    case .left: name = "youright"
                    }
                    print("[DEBUG] playerFaceImageName -> \(name) (player defender) phase=\(phase) playerDirection=\(String(describing: playerDirection))")
                    return name
                }
                let name = "boyfront"
                print("[DEBUG] playerFaceImageName -> \(name) (player defender, no direction) phase=\(phase) playerDirection=\(String(describing: playerDirection))")
                return name
            }
        }

        let name = "boyfront"
        print("[DEBUG] playerFaceImageName -> \(name) (default) phase=\(phase) playerDirection=\(String(describing: playerDirection)) isCpuAttacker=\(isCpuAttacker)")
        return name
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
