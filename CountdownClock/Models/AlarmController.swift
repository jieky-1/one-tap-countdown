import AudioToolbox
import AVFoundation
import Foundation

/// 到点响铃：循环播放内置生成的大音量提示音 + 持续震动，直到答对算术题后 stop()
final class AlarmController {
    static let shared = AlarmController()

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var toneURL: URL?
    private init() {}

    func start() {
        guard timer == nil else { return }
        configureSession()
        startPlayer()
        vibrate()                                   // 立刻震一次
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.vibrate()
            if self?.player?.isPlaying == false { self?.player?.play() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 声音

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func startPlayer() {
        guard let url = toneURL ?? makeToneFile() else { return }
        toneURL = url
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 1.0                          // 音量拉满
        player.numberOfLoops = -1                    // 一直循环
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    /// 生成 1 秒双音方波 WAV（880 / 1175Hz，0.45s 响 + 0.15s 停），音量 0.85
    private func makeToneFile() -> URL? {
        let sampleRate = 44100
        let frames = sampleRate
        var samples = [Int16]()
        samples.reserveCapacity(frames)

        for i in 0..<frames {
            let t = Double(i) / Double(sampleRate)
            let cycle = t.truncatingRemainder(dividingBy: 0.6)
            let freq = cycle < 0.225 ? 880.0 : (cycle < 0.45 ? 1175.0 : 880.0)
            let on = cycle < 0.45
            let wave = sin(2 * Double.pi * freq * t) >= 0 ? 1.0 : -1.0   // 方波，听起来更响
            let value = (on ? wave * 0.85 : 0) * Double(Int16.max)
            samples.append(Int16(max(-32768, min(32767, value))))
        }

        let dataSize = frames * 2
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: le(UInt32(36 + dataSize)))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: le(UInt32(16)))      // fmt chunk size
        data.append(contentsOf: le16(1))             // PCM
        data.append(contentsOf: le16(1))             // mono
        data.append(contentsOf: le(UInt32(sampleRate)))
        data.append(contentsOf: le(UInt32(sampleRate * 2)))  // byte rate
        data.append(contentsOf: le16(2))             // block align
        data.append(contentsOf: le16(16))            // bits
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: le(UInt32(dataSize)))
        for s in samples { data.append(contentsOf: le16(UInt16(bitPattern: s))) }

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("alarm_tone.wav")
        try? data.write(to: url)
        return url
    }

    private func le(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)]
    }

    private func le16(_ v: UInt16) -> [UInt8] {
        [UInt8(v & 0xff), UInt8((v >> 8) & 0xff)]
    }

    // MARK: - 震动

    private func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
