import Combine
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()

    /// “倒计时开始”时刻，默认取当前时间
    @State private var startTime = Date()
    @State private var didEditStartTime = false
    /// 最近一次由程序自动同步的时间（用于区分“自动刷新”和“用户修改”）
    @State private var syncedMinutes: Int = -1
    /// 手动覆盖的时长（nil 表示使用自动匹配的默认时长）
    @State private var customDuration: TimeInterval?
    @State private var showNightSettings = false
    @State private var showCountdown = false
    @State private var timer: CountdownTimer?
    /// 每秒推进，用于刷新“真实剩余”
    @State private var now = Date()
    /// 调试用：由启动参数 -autostart 触发直接进入倒计时页（仅 CI/模拟器演示，正常启动不带参数无影响）
    @State private var autoStart = false
    /// 调试用：“倒计时开始”的输入方式（wheel / keyboard）
    @State private var startInputMode: TimeInputView.InputMode = .wheel
    /// 调试用：-sheet night|duration 启动后直接打开夜间区间设置页（duration 会滚动到默认时长区）
    @State private var debugSheet: String?
    /// 调试用：-nightoff 关闭“启用夜间区间”开关
    @State private var debugNightOff = false

    /// 支持启动参数（仅用于模拟器/CI 演示，正常启动不带参数完全无影响）：
    ///   -start HH:mm        指定“倒计时开始”
    ///   -duration <分钟>    指定倒计时时长
    ///   -autostart          启动后直接进入倒计时页面
    ///   -inputmode keyboard 启动后“倒计时开始”直接用键盘输入模式
    ///   -sheet night|duration 启动后直接弹出夜间区间设置页
    ///   -nightoff           启动后关闭“启用夜间区间”
    init() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        var start = Date()
        var edited = false
        if let text = value("-start"), let minutes = TimeUtils.parseTime(text) {
            start = TimeUtils.date(base: Date(), minutesOfDay: minutes)
            edited = true
        }
        _startTime = State(initialValue: start)
        _syncedMinutes = State(initialValue: TimeUtils.minutesOfDay(start))
        _didEditStartTime = State(initialValue: edited)
        if let text = value("-duration"), let minutes = Double(text) {
            _customDuration = State(initialValue: minutes * 60)
        }
        _autoStart = State(initialValue: args.contains("-autostart"))
        if let mode = value("-inputmode"), mode == "keyboard" {
            _startInputMode = State(initialValue: .keyboard)
        }
        if let sheet = value("-sheet"), sheet == "night" || sheet == "duration" {
            _debugSheet = State(initialValue: sheet)
        }
        _debugNightOff = State(initialValue: args.contains("-nightoff"))
    }

    private var startMinutes: Int { TimeUtils.minutesOfDay(startTime) }
    /// 真实倒计时：结束时刻 = 倒计时开始 + 时长；真实剩余 = 结束时刻 - 当前时间
    private var resolved: ResolvedCountdown {
        TimeUtils.resolve(startMinutes: startMinutes, duration: duration, now: now)
    }
    private var inNight: Bool { settings.night.contains(minutes: startMinutes) }
    private var autoDuration: TimeInterval { settings.night.duration(forMinutes: startMinutes) }
    private var duration: TimeInterval { customDuration ?? autoDuration }

    var body: some View {
        ZStack {
            backgroundLayer
            ScrollView {
                VStack(spacing: 18) {
                    topBar
                    startTimeCard
                    durationCard
                    startButton
                }
                .padding(20)
            }
        }
        .fullScreenCover(isPresented: $showCountdown) {
            if let timer {
                CountdownRunningView(timer: timer,
                                     startAt: resolved.start,
                                     inNight: inNight,
                                     onClose: closeCountdown)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .sheet(isPresented: $showNightSettings) {
            NightIntervalSettingsView(settings: settings, scrollTo: debugSheet == "duration" ? "duration" : nil)
        }
        .onAppear {
            if !didEditStartTime {
                startTime = Date()
                syncedMinutes = TimeUtils.minutesOfDay(startTime)
            }
            if debugNightOff { settings.night.isEnabled = false }
            if debugSheet != nil { showNightSettings = true }
            if autoStart { startFromLaunchArguments() }
        }
        .onChange(of: TimeUtils.minutesOfDay(startTime)) { minutes in
            didEditStartTime = (minutes != syncedMinutes)
        }
        // 默认时长被修改后，清掉手动覆盖值，让主界面立即按新默认值匹配
        .onChange(of: settings.night.nightDuration) { _ in customDuration = nil }
        .onChange(of: settings.night.dayDuration) { _ in customDuration = nil }
    }

    // MARK: - 视图组件

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(uiColor: .systemBackground),
                     (inNight ? Color.indigo : Color.accentColor).opacity(0.16)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: inNight)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showNightSettings = true
                Haptics.impact(.light)
            } label: {
                Label("夜间区间", systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: inNight ? "moon.fill" : "sun.max.fill")
            Text(inNight ? "夜间" : "日间")
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background((inNight ? Color.indigo : Color.orange).opacity(0.18), in: Capsule())
    }

    private var startTimeCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("倒计时开始")
                    .font(.headline)
                Spacer()
                Button("设为现在") {
                    startTime = Date()
                    didEditStartTime = false
                    syncedMinutes = TimeUtils.minutesOfDay(startTime)
                    Haptics.impact(.light)
                }
                .font(.subheadline)
            }

            TimeInputView(date: $startTime, mode: $startInputMode)

            Text(intervalDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var durationCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("倒计时时长")
                    .font(.headline)
                Spacer()
                if customDuration != nil {
                    Button("恢复默认") {
                        customDuration = nil
                        Haptics.impact(.light)
                    }
                    .font(.subheadline)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimeUtils.formatClockDuration(duration))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(autoTagText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if resolved.remaining <= 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("倒计时已到 · 已超时 \(TimeUtils.formatClockDuration(-resolved.remaining))")
                        .monospacedDigit()
                    Spacer()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)
                .padding(10)
                .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            DurationWheel(duration: Binding(
                get: { duration },
                set: { customDuration = $0 }
            ))

            Text(realTimeText)
                .font(.footnote)
                .foregroundStyle(resolved.remaining > 0 ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var startButton: some View {
        Button {
            let left = resolved.remaining
            guard left > 0 else { return }
            timer = CountdownTimer(total: left)
            showCountdown = true
            Haptics.impact(.medium)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: resolved.remaining > 0 ? "play.fill" : "checkmark.circle.fill")
                Text(resolved.remaining > 0 ? "开始倒计时" : "倒计时已到")
                    .font(.title3.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(resolved.remaining <= 0)
    }

    // MARK: - 文案

    private var autoTagText: String {
        guard settings.night.isEnabled else {
            return "夜间区间未启用 · 使用日间默认时长"
        }
        let kind = inNight ? "夜间" : "非夜间"
        if customDuration != nil {
            return "已手动调整（\(kind)默认 \(TimeUtils.formatDuration(autoDuration))）"
        }
        return "\(kind)区间默认时长 · 自动匹配"
    }

    private var realTimeText: String {
        let r = resolved
        guard r.remaining > 0 else {
            return "倒计时已到：结束时刻 \(TimeUtils.formatTime(r.end))，已超时 \(TimeUtils.formatClockDuration(-r.remaining))"
        }
        return "\(TimeUtils.endText(start: r.start, duration: duration)) · 真实剩余 \(TimeUtils.formatClockDuration(r.remaining))"
    }

    private var intervalDescription: String {
        guard settings.night.isEnabled else {
            return "夜间区间未启用，任何开始时间都使用日间默认时长。"
        }
        let s = TimeUtils.formatClock(settings.night.startMinutes)
        let e = TimeUtils.formatClock(settings.night.endMinutes)
        let cross = settings.night.crossesMidnight ? "（跨日）" : ""
        let belong = inNight ? "落在夜间区间内" : "不在夜间区间内"
        return "夜间区间 \(s) → \(e)\(cross)，当前开始时间 \(TimeUtils.formatClock(startMinutes)) \(belong)。"
    }

    /// -autostart 直接进入倒计时（按真实剩余）
    private func startFromLaunchArguments() {
        autoStart = false
        guard timer == nil, !showCountdown, resolved.remaining > 0 else { return }
        timer = CountdownTimer(total: resolved.remaining)
        showCountdown = true
    }

    private func closeCountdown() {
        timer?.stop()
        showCountdown = false
        timer = nil
    }
}
