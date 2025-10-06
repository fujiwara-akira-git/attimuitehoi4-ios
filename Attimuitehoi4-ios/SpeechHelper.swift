import Foundation
import AVFoundation

class SpeechHelper {
    static let shared = SpeechHelper()
    private let synth = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    enum VoiceQuality: String, CaseIterable {
        case standard = "standard"
        case enhanced = "enhanced"
        case neural = "neural"
        case metan = "metan"
        
        var displayName: String {
            switch self {
            case .standard: return "標準"
            case .enhanced: return "高品質"
            case .neural: return "AI音声"
            case .metan: return "四国めたん"
            }
        }
    }

    // カスタム音声ファイル再生
    private func playCustomAudio(for messageKey: String, language: String) -> Bool {
        let filename = "\(messageKey)_\(language)"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "wav") ?? 
              Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            print("Custom audio file not found: \(filename)")
            return false
        }
        
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            return true
        } catch {
            print("Error playing custom audio: \(error)")
            return false
        }
    }
    
    // 利用可能な女の子・男の子voice一覧取得
    func availableVoices(language: String, type: String, quality: VoiceQuality = .metan) -> [AVSpeechSynthesisVoice] {
        let lang = (language == "en") ? "en-US" : "ja-JP"
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == lang }
        
        // Neural/Enhanced voices filtering
        let voices: [AVSpeechSynthesisVoice]
        switch quality {
        case .neural:
            // iOS 17+ Neural voices
            voices = allVoices.filter { voice in
                voice.identifier.contains("neural") || 
                voice.identifier.contains("premium") ||
                voice.quality == .enhanced
            }
        case .enhanced:
            voices = allVoices.filter { $0.quality == .enhanced }
        case .metan:
            // For metan voices, return enhanced voices (will be overridden by custom audio files)
            voices = allVoices.filter { $0.quality == .enhanced }
        case .standard:
            voices = allVoices
        }
        
        let girlKeywords = ["hina", "child", "girl", "kids", "cute", "kyoko", "mei"]
        let boyKeywords = ["otoya", "child", "boy", "kids", "kenji", "hattori"]
        
        switch type {
        case "girl": return voices.filter { v in girlKeywords.contains { v.name.lowercased().contains($0) } }
        case "boy": return voices.filter { v in boyKeywords.contains { v.name.lowercased().contains($0) } }
        case "ai": return voices.filter { $0.quality == .enhanced || $0.identifier.contains("neural") }
        default: return voices
        }
    }

    // TTS再生（AI機能・カスタム音声対応）
    func speak(_ text: String, language: String = "ja", voiceType: String = "girl", voiceID: String? = nil, speed: Float = AVSpeechUtteranceDefaultSpeechRate, forceInterrupt: Bool = false, quality: VoiceQuality = .metan, messageKey: String? = nil) {
        // 四国めたん音声の場合はカスタム音声ファイルを再生
        if quality == .metan, let key = messageKey {
            if playCustomAudio(for: key, language: language) {
                return // カスタム音声再生成功
            }
            // フォールバック: カスタム音声が再生できない場合は通常のTTSを使用
        }
        
        // If requested, interrupt any currently speaking utterance to ensure this one plays immediately
        if forceInterrupt && (synth.isSpeaking || audioPlayer?.isPlaying == true) {
            synth.stopSpeaking(at: .immediate)
            audioPlayer?.stop()
        }
        
        let lang = (language == "en") ? "en-US" : "ja-JP"
        let utterance = AVSpeechUtterance(string: text)
        
        // Voice selection with AI enhancement
        if let vid = voiceID, let v = AVSpeechSynthesisVoice(identifier: vid) {
            utterance.voice = v
        } else {
            utterance.voice = selectVoice(for: voiceType, language: lang, quality: quality)
        }
        
        // Enhanced parameters for AI voices
        switch voiceType {
        case "girl":
            utterance.pitchMultiplier = quality == .neural ? 1.3 : 1.5
            utterance.rate = speed * (quality == .neural ? 0.9 : 0.85)
        case "boy":
            utterance.pitchMultiplier = quality == .neural ? 1.1 : 1.2
            utterance.rate = speed * (quality == .neural ? 0.95 : 1.0)
        case "ai":
            utterance.pitchMultiplier = 1.0
            utterance.rate = speed * 0.9
        default:
            utterance.pitchMultiplier = 1.0
            utterance.rate = speed
        }
        
        // Enhanced quality settings
        if quality == .neural || quality == .enhanced {
            utterance.volume = 0.9
            utterance.preUtteranceDelay = 0.1
        }
        
        synth.speak(utterance)
    }

    private func selectVoice(for voiceType: String, language: String, quality: VoiceQuality = .metan) -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        
        // AI/Neural voice selection
        if quality == .neural || quality == .metan || voiceType == "ai" {
            // Try to find Neural/Premium voices first
            let aiVoices = allVoices.filter { voice in
                voice.identifier.contains("neural") ||
                voice.identifier.contains("premium") ||
                voice.quality == .enhanced
            }
            
            if language == "ja-JP" {
                // Prefer specific high-quality Japanese voices
                if let neuralVoice = aiVoices.first(where: { $0.identifier.contains("kyoko") || $0.identifier.contains("hina") }) {
                    return neuralVoice
                }
            }
            
            if !aiVoices.isEmpty {
                return aiVoices.first
            }
        }
        
        // Standard voice selection
        if voiceType == "girl" {
            if language == "ja-JP" {
                // Try enhanced Hina first
                if quality == .enhanced, let v = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Hina-premium") { return v }
                if let v = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Hina-compact") { return v }
                
                let keywords = ["hina", "kyoko", "mei", "child", "girl", "kids", "cute"]
                return allVoices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
            } else if language == "en-US" {
                let keywords = ["child", "kids", "girl", "cute", "samantha"]
                return allVoices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
            }
        }
        
        if voiceType == "boy" {
            if language == "ja-JP" {
                if quality == .enhanced, let v = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Otoya-premium") { return v }
                if let v = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Otoya-compact") { return v }
                
                let keywords = ["otoya", "kenji", "hattori", "child", "kids", "boy"]
                return allVoices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
            } else if language == "en-US" {
                let keywords = ["child", "kids", "boy", "aaron"]
                return allVoices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
            }
        }
        
        return AVSpeechSynthesisVoice(language: language) ?? allVoices.first
    }
}
