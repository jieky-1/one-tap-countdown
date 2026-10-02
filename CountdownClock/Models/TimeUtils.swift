import Foundation

/// 时间计算工具：统一处理“分钟数（0..<1440）”与跨日逻辑
struct ResolvedCountdown {
    /// 倒计时开始（已解析到具体的某一天）
    let start: Date
    /// 结束时刻 = 开始 + 时长
    let end: Date
    /// 真实倒计时时长 = 结束时刻 - 当前时间，<= 0 表示倒计时已到
    let remaining: TimeInterval
}

enum TimeUtils {
    static let minutesPerDay = 24 * 60

    /// 取某个时刻在一天中的分钟数
    static func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// 以 base 的年月日为基准，替换为指定分钟数
    static func date(base: Date, minutesOfDay minutes: Int) -> Date {
        let m = ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay
        var c = Calendar.current.dateComponents([.year, .month, .day], from: base)
        c.hour = m / 60
        c.minute = m % 60
        c.second = 0
        return Calendar.current.date(from: c) ?? base
    }

    /// 24 小时制文本，如 23:05
    static func formatClock(_ minutes: Int) -> String {
        let m = ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// 时:分:秒（小时为 0 时省略小时），用于倒计时展示
    static func formatClockDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(ceil(interval)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// 中文时长，如 8 小时 30 分
    static func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(round(interval)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) 小时") }
        if m > 0 { parts.append("\(m) 分") }
        if h == 0 && m == 0 { parts.append("\(s) 秒") }
        return parts.joined(separator: " ")
    }

    /// 解析用户直接输入的时间，支持 "7"、"730"、"07:30"、"7:3"
    static func parseTime(_ text: String) -> Int? {
        let digits = text.filter { $0.isNumber }
        switch digits.count {
        case 1, 2:
            guard let h = Int(digits), h < 24 else { return nil }
            return h * 60
        case 3:
            guard let h = Int(digits.prefix(1)), let m = Int(digits.suffix(2)), m < 60 else { return nil }
            return h * 60 + m
        case 4:
            guard let h = Int(digits.prefix(2)), h < 24,
                  let m = Int(digits.suffix(2)), m < 60 else { return nil }
            return h * 60 + m
        default:
            return nil
        }
    }

    /// 解析真实倒计时：结束时刻 = 倒计时开始 + 时长，真实剩余 = 结束时刻 - 当前时间。
    /// 开始时间只有“时刻”，需在 昨天/今天/明天 三个候选里挑“结束时刻离现在最近”的一个，
    /// 以正确处理跨日（如 23:00 起 8 小时 → 次日 07:00 结束）。
    static func resolve(startMinutes: Int, duration: TimeInterval, now: Date = Date()) -> ResolvedCountdown {
        let cal = Calendar.current
        var best: ResolvedCountdown?
        for offset in [-1, 0, 1] {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.day = (comps.day ?? 0) + offset
            comps.hour = startMinutes / 60
            comps.minute = startMinutes % 60
            comps.second = 0
            guard let s = cal.date(from: comps) else { continue }
            let e = s.addingTimeInterval(duration)
            let diff = e.timeIntervalSince(now)
            if best == nil || abs(diff) < abs(best!.remaining) {
                best = ResolvedCountdown(start: s, end: e, remaining: diff)
            }
        }
        return best ?? ResolvedCountdown(start: date(base: now, minutesOfDay: startMinutes),
                                         end: date(base: now, minutesOfDay: startMinutes).addingTimeInterval(duration),
                                         remaining: duration)
    }

    /// 结束时刻描述，自动处理跨日 / 跨多日
    static func endText(start: Date, duration: TimeInterval) -> String {
        let end = start.addingTimeInterval(duration)
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: end)).day ?? 0
        switch days {
        case 0: return "预计 \(formatTime(end)) 结束"
        case 1: return "预计次日 \(formatTime(end)) 结束"
        default: return "预计 \(days) 天后 \(formatTime(end)) 结束"
        }
    }
}
