import SwiftUI

/// 倒计时时长滑轮（时 / 分 / 秒）+ 快捷时长
struct DurationWheel: View {
    @Binding var duration: TimeInterval
    var showsQuickChips: Bool = true

    private var total: Int { max(0, Int(duration.rounded())) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                column(0..<24, value: total / 3600, unit: "时") { set(hour: $0) }
                column(0..<60, value: (total % 3600) / 60, unit: "分") { set(minute: $0) }
                column(0..<60, value: total % 60, unit: "秒") { set(second: $0) }
            }
            .frame(height: 120)
            .clipped()

            if showsQuickChips {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickValues, id: \.0) { item in
                            Button(item.0) { duration = item.1; Haptics.impact(.light) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var quickValues: [(String, TimeInterval)] {
        [("1.5 小时", 5400), ("2 小时", 2 * 3600),
         ("2.5 小时", 9000), ("3 小时", 3 * 3600)]
    }

    private func column(_ range: Range<Int>, value: Int, unit: String, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 2) {
            Picker("", selection: Binding(get: { value }, set: { onChange($0) })) {
                ForEach(range, id: \.self) { v in
                    Text(String(format: "%02d", v)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 74)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func set(hour: Int? = nil, minute: Int? = nil, second: Int? = nil) {
        let h = min(max(hour ?? total / 3600, 0), 23)
        let m = min(max(minute ?? (total % 3600) / 60, 0), 59)
        let s = min(max(second ?? total % 60, 0), 59)
        duration = TimeInterval(h * 3600 + m * 60 + s)
    }
}
