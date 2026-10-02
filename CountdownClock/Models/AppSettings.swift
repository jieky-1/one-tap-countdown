import Foundation
import SwiftUI
import UIKit

/// 夜间区间 + 两套默认倒计时时长
struct NightInterval: Codable, Equatable {
    var isEnabled: Bool = true
    /// 区间开始（一天中的分钟数）
    var startMinutes: Int = 23 * 60
    /// 区间结束（一天中的分钟数）
    var endMinutes: Int = 7 * 60
    /// 夜间默认倒计时时长（秒）
    var nightDuration: TimeInterval = 8 * 60 * 60
    /// 非夜间（日间）默认倒计时时长（秒）
    var dayDuration: TimeInterval = 30 * 60

    /// 开始晚于结束 => 跨日区间（如 23:00 → 07:00）
    var crossesMidnight: Bool { startMinutes > endMinutes }
    /// 开始等于结束 => 视为全天
    var isAllDay: Bool { startMinutes == endMinutes }

    /// minutes 是否落在夜间区间内（已处理跨日）
    func contains(minutes: Int) -> Bool {
        guard isEnabled else { return false }
        if isAllDay { return true }
        if crossesMidnight {
            return minutes >= startMinutes || minutes < endMinutes
        }
        return minutes >= startMinutes && minutes < endMinutes
    }

    func duration(forMinutes minutes: Int) -> TimeInterval {
        contains(minutes: minutes) ? nightDuration : dayDuration
    }

    var rangeText: String {
        guard isEnabled else { return "未启用" }
        return "\(TimeUtils.formatClock(startMinutes)) → \(TimeUtils.formatClock(endMinutes))"
    }
}

final class AppSettings: ObservableObject {
    private static let storeKey = "oneTapCountdown.settings.v1"

    @Published var night: NightInterval {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let decoded = try? JSONDecoder().decode(NightInterval.self, from: data) {
            night = decoded
        } else {
            night = NightInterval()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(night) else { return }
        UserDefaults.standard.set(data, forKey: Self.storeKey)
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
