import Foundation
import AVFoundation

class SpeechHelper {
    static let shared = SpeechHelper()
    private let synth = AVSpeechSynthesizer()

    // 利用可能な女の子・男の子voice一覧取得
    func availableVoices(language: String, type: String) -> [AVSpeechSynthesisVoice] {
        let lang = (language == "en") ? "en-US" : "ja-JP"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == lang }
        let girlKeywords = ["hina", "child", "girl", "kids", "cute"]
        let boyKeywords = ["otoya", "child", "boy", "kids"]
        switch type {
        case "girl": return voices.filter { v in girlKeywords.contains { v.name.lowercased().contains($0) } }
        case "boy": return voices.filter { v in boyKeywords.contains { v.name.lowercased().contains($0) } }
        default: return []
        }
    }

    // TTS再生
    func speak(_ text: String, language: String = "ja", voiceType: String = "girl", voiceID: String? = nil, speed: Float = AVSpeechUtteranceDefaultSpeechRate) {
        let lang = (language == "en") ? "en-US" : "ja-JP"
        let utterance = AVSpeechUtterance(string: text)
        if let vid = voiceID, let v = AVSpeechSynthesisVoice(identifier: vid) {
            utterance.voice = v
        } else {
            utterance.voice = selectVoice(for: voiceType, language: lang)
        }
        switch voiceType {
        case "girl": utterance.pitchMultiplier = 1.5; utterance.rate = speed * 0.85
        case "boy": utterance.pitchMultiplier = 1.2; utterance.rate = speed
        default: utterance.pitchMultiplier = 1.0; utterance.rate = speed
        }
        synth.speak(utterance)
    }

    private func selectVoice(for voiceType: String, language: String) -> AVSpeechSynthesisVoice? {
        if voiceType == "girl" {
            if language == "ja-JP" {
                if let v = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Hina-compact") { return v }
                let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
                let keywords = ["hina", "child", "girl", "kids", "cute"]
                return voices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
            } else if language == "en-US" {
                let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
                let keywords = ["child", "kids", "girl", "cute"]
                return voices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
            }
        }
        if voiceType == "boy" && language == "ja-JP" {
            if let v = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Otoya-compact") { return v }
        }
        if language == "en-US" && voiceType == "boy" {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
            let keywords = ["child", "kids", "boy"]
            return voices.first(where: { v in keywords.contains { v.name.lowercased().contains($0) } })
        }
        return AVSpeechSynthesisVoice(language: language)
    }
}
