import SwiftUI

/// 夜间区间设置：区间起止时间 + 夜间/非夜间两套默认倒计时时长
struct NightIntervalSettingsView: View {
    @ObservedObject var settings: AppSettings
    /// 调试用：打开后自动滚动到指定区域（"duration" = 默认倒计时时长）
    var scrollTo: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        intervalSection
                        durationSection
                            .id("duration")
                    }
                    .padding(18)
                }
                .onAppear {
                    guard let target = scrollTo else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                    }
                }
            }
            .navigationTitle("夜间区间设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("启用夜间区间", isOn: $settings.night.isEnabled)
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("开始时间")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimeOfDayWheel(minutes: $settings.night.startMinutes)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("结束时间")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimeOfDayWheel(minutes: $settings.night.endMinutes)
            }

            Text(hintText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("默认倒计时时长")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("夜间区间内", systemImage: "moon.fill")
                        .foregroundStyle(.indigo)
                    Spacer()
                    Text(TimeUtils.formatDuration(settings.night.nightDuration))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                DurationWheel(duration: $settings.night.nightDuration, showsQuickChips: false)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("非夜间区间", systemImage: "sun.max.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(TimeUtils.formatDuration(settings.night.dayDuration))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                DurationWheel(duration: $settings.night.dayDuration, showsQuickChips: false)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var hintText: String {
        guard settings.night.isEnabled else { return "关闭后，所有时间都使用「非夜间区间」的默认时长。" }
        let s = TimeUtils.formatClock(settings.night.startMinutes)
        let e = TimeUtils.formatClock(settings.night.endMinutes)
        if settings.night.isAllDay {
            return "开始与结束时间相同，视为全天均为夜间区间。"
        }
        if settings.night.crossesMidnight {
            return "当前为跨日区间：\(s) 至次日 \(e)（例如 \(s) 之后、次日 \(e) 之前都属于夜间）。"
        }
        return "当前区间：\(s) 至 \(e)，开始时间在该范围内即使用夜间默认时长。"
    }
}
