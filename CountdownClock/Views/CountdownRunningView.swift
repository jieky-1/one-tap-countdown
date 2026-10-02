import SwiftUI
import UIKit

struct CountdownRunningView: View {
    @ObservedObject var timer: CountdownTimer
    let startAt: Date
    let inNight: Bool
    let onClose: () -> Void

    @State private var showFinish = false
    /// 到点算术题（两位数加法）
    @State private var operandA = 0
    @State private var operandB = 0
    @State private var answer = ""
    @State private var showWrongAnswer = false
    @FocusState private var answerFocused: Bool

    private var correctAnswer: String { String(operandA + operandB) }

    private var accent: Color { inNight ? .indigo : .accentColor }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(uiColor: .systemBackground), accent.opacity(0.18)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("关闭") { onClose() }
                        .buttonStyle(.bordered)
                        .clipShape(Capsule())
                        .disabled(timer.isFinished)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(LinearGradient(colors: [accent, accent.opacity(0.45)],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.12), value: timer.progress)

                    VStack(spacing: 10) {
                        Text(TimeUtils.formatClockDuration(timer.remaining))
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(inNight ? "夜间时长" : "日间时长")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(TimeUtils.endText(start: startAt, duration: timer.total))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 270, height: 270)

                Text("开始于 \(TimeUtils.formatTime(startAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button {
                        if timer.isRunning { timer.pause() } else { timer.resume() }
                    } label: {
                        Label(timer.isRunning ? "暂停" : "继续",
                              systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                            .frame(minWidth: 110)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        onClose()
                    } label: {
                        Label("结束", systemImage: "xmark")
                            .frame(minWidth: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(timer.isFinished)
                }
                // 到点后只能靠答对算术题退出，避免直接关掉响铃
                .disabled(timer.isFinished)

                Spacer(minLength: 0)
            }
            .padding(24)

            if showFinish {
                finishOverlay
                    .transition(.opacity)
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            AlarmController.shared.stop()
        }
        .onChange(of: timer.isFinished) { finished in
            guard finished else { return }
            operandA = Int.random(in: 10...99)
            operandB = Int.random(in: 10...99)
            answer = ""
            showWrongAnswer = false
            Haptics.success()
            AlarmController.shared.start()          // 答对前一直响
            withAnimation { showFinish = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { answerFocused = true }
        }
    }

    private var finishOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(accent)
                Text("时间到")
                    .font(.largeTitle.weight(.bold))
                Text("倒计时 \(TimeUtils.formatDuration(timer.total)) 已完成")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(operandA) + \(operandB) = ?")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()

                TextField("答案", text: $answer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .focused($answerFocused)
                    .onChange(of: answer) { value in
                        if value == correctAnswer {
                            AlarmController.shared.stop()
                            onClose()                 // 答对 → 自动返回主界面
                        } else {
                            showWrongAnswer = value.count >= correctAnswer.count
                        }
                    }

                if showWrongAnswer {
                    Text("答案不对，再算一次")
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else {
                    Text("答对后自动返回主界面")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(40)
        }
    }
}
