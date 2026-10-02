import Foundation

/// 倒计时计时器：基于结束时刻计算，暂停/继续不丢进度
final class CountdownTimer: ObservableObject {
    let total: TimeInterval

    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    private var endDate: Date?
    private var timer: Timer?

    init(total: TimeInterval) {
        self.total = max(0, total)
        self.remaining = self.total
        resume()
    }

    var progress: Double {
        guard total > 0 else { return isFinished ? 1 : 0 }
        return min(max(1 - remaining / total, 0), 1)
    }

    var endDateEstimated: Date? {
        guard isRunning else { return nil }
        return endDate
    }

    func resume() {
        guard !isFinished, remaining > 0 else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(remaining)
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func pause() {
        invalidate()
        if let endDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        endDate = nil
        isRunning = false
    }

    func stop() {
        invalidate()
        endDate = nil
        isRunning = false
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let endDate else { return }
        let left = max(0, endDate.timeIntervalSinceNow)
        remaining = left
        if left <= 0 {
            remaining = 0
            isFinished = true
            stop()
        }
    }
}
