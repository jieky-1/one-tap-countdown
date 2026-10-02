import SwiftUI

/// 时 / 分双列滑轮（一天中的分钟数）
struct TimeOfDayWheel: View {
    @Binding var minutes: Int

    private var hour: Binding<Int> {
        Binding(get: { minutes / 60 }, set: { set(hour: $0) })
    }
    private var minute: Binding<Int> {
        Binding(get: { minutes % 60 }, set: { set(minute: $0) })
    }

    var body: some View {
        HStack(spacing: 4) {
            column(0..<24, selection: hour, unit: "时")
            column(0..<60, selection: minute, unit: "分")
        }
        .frame(height: 130)
        .clipped()
    }

    private func column(_ range: Range<Int>, selection: Binding<Int>, unit: String) -> some View {
        HStack(spacing: 2) {
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 78)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func set(hour: Int? = nil, minute: Int? = nil) {
        let h = hour ?? minutes / 60
        let m = minute ?? minutes % 60
        minutes = min(max(h, 0), 23) * 60 + min(max(m, 0), 59)
    }
}

/// “倒计时开始”时间输入：支持直接输入（键盘）与滑轮调整两种方式
struct TimeInputView: View {
    @Binding var date: Date
    var onCommit: (() -> Void)? = nil

    enum InputMode: String, CaseIterable, Identifiable {
        case wheel = "滑轮"
        case keyboard = "输入"
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .wheel: return "slider.horizontal.3"
            case .keyboard: return "keyboard"
            }
        }
    }

    @State private var mode: InputMode = .wheel
    @State private var text: String = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var minutes: Binding<Int> {
        Binding(
            get: { TimeUtils.minutesOfDay(date) },
            set: { date = TimeUtils.date(base: date, minutesOfDay: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("输入方式", selection: $mode) {
                ForEach(InputMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            if mode == .wheel {
                TimeOfDayWheel(minutes: minutes)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("HH:mm", text: $text)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit(commit)
                            .textFieldStyle(.roundedBorder)
                        Button("确定") { commit() }
                            .buttonStyle(.borderedProminent)
                    }
                    Text("支持 730 / 07:30 / 7:30 等写法")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .onAppear { text = TimeUtils.formatClock(TimeUtils.minutesOfDay(date)) }
            }
        }
    }

    private func commit() {
        guard let parsed = TimeUtils.parseTime(text) else {
            errorMessage = "时间格式不正确，请输入 0:00 - 23:59"
            Haptics.warning()
            return
        }
        errorMessage = nil
        date = TimeUtils.date(base: date, minutesOfDay: parsed)
        text = TimeUtils.formatClock(parsed)
        isFocused = false
        Haptics.impact(.light)
        onCommit?()
    }
}
