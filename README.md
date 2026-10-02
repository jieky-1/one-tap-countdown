# 一键倒计时（iOS App）

![iOS Build Check](https://github.com/jieky-1/one-tap-countdown/actions/workflows/ios-build.yml/badge.svg)

SwiftUI 实现的 iOS 倒计时 App：中间是「倒计时开始」时间输入（**键盘直接输入** + **滑轮调整**两种），左上角「夜间区间」设置，按开始时间是否落在夜间区间自动选择不同的默认倒计时时长，并正确处理跨日。

## 功能对照

| 需求 | 实现位置 |
| --- | --- |
| 中间「倒计时开始」输入框，支持直接输入 + 滑轮 | `Views/TimeInputView.swift`（分段切换「滑轮 / 输入」，输入支持 `730`、`07:30` 等写法） |
| 左上角「夜间区间」设置按钮 | `Views/ContentView.swift` → `topBar`，弹出 `Views/NightIntervalSettingsView.swift` |
| 夜间 / 非夜间各一个默认倒计时时长 | `Models/AppSettings.swift` 的 `nightDuration` / `dayDuration`，设置页内滑轮编辑 |
| 按开始时间自动选择默认时长 | `NightInterval.duration(forMinutes:)`，主界面 `autoDuration` |
| 跨日问题 | `NightInterval.contains(minutes:)`（开始 > 结束即跨日：`minutes >= start \|\| minutes < end`），结束时刻提示见 `TimeUtils.endText` |

## 目录结构

```
CountdownClock/
├── OneTapCountdownApp.swift          # @main 入口
├── Models/
│   ├── AppSettings.swift             # 夜间区间配置 + UserDefaults 持久化 + 触感反馈
│   ├── CountdownTimer.swift          # 倒计时计时（基于结束时刻，暂停不丢进度）
│   └── TimeUtils.swift               # 分钟数换算、跨日判断、格式化、输入解析
└── Views/
    ├── ContentView.swift             # 主界面
    ├── TimeInputView.swift           # 时间输入（滑轮 / 键盘双模式）
    ├── DurationWheel.swift           # 时长滑轮 + 快捷时长
    ├── NightIntervalSettingsView.swift
    └── CountdownRunningView.swift    # 倒计时运行页（进度环 / 暂停 / 到点提示）
```

## 在 Xcode 中运行（需 macOS + Xcode 15+，iOS 16+）

工程已经配好，直接打开即可：

1. 双击 `OneTapCountdown.xcodeproj`（Xcode 15+）。
2. 左侧选 `OneTapCountdown` → Target `CountdownClock` → `Signing & Capabilities`，选上你的 Apple 账号（模拟器运行可不选）。
3. 顶部选一个模拟器（如 iPhone 15），`Cmd + R` 运行。

> 工程已配置 `GENERATE_INFOPLIST_FILE = YES`，无需手动建 Info.plist；Deployment Target = iOS 16.0；应用显示名「一键倒计时」。

### 没有 Mac 时：云端真编译校验
仓库已带 `.github/workflows/ios-build.yml`，推到 GitHub 后会自动在 `macos-latest` 上用 `xcodebuild` 真编译（iOS Simulator SDK，关闭签名），能在 Actions 日志里看到是否编译通过：

```bash
git init && git add . && git commit -m "one tap countdown"
git remote add origin <你的仓库地址> && git push -u origin main
```

### 手工建工程（可选）
若不想用现成工程：Xcode 新建 iOS App（SwiftUI / Swift），删掉模板 `ContentView.swift` 和 `@main` 文件，把 `CountdownClock/` 下源码按结构拖入即可。

## 逻辑说明

- **夜间判定**：把时间统一转成「一天中的分钟数」（0–1439）。
  - `开始 < 结束`（如 01:00 → 06:00）：`开始 <= t < 结束`
  - `开始 > 结束`（如 23:00 → 07:00）：`t >= 开始 || t < 结束`，即跨日
  - `开始 == 结束`：视为全天
  - 关闭「启用夜间区间」后，一律使用非夜间默认时长
- **默认时长**：夜间默认 8 小时，非夜间默认 30 分钟，均可在设置页修改并自动持久化。
- **手动覆盖**：主界面调整时长后即手工生效，点「恢复默认」回到自动匹配值。
- **开始时间**：默认取当前时间（每次回到主界面自动刷新，除非手动改过），可点「设为现在」或手动指定（用于提前判断该用哪套默认时长）。
- **真实倒计时时长**：`结束时刻 = 倒计时开始 + 倒计时时长`，`真实剩余 = 结束时刻 − 当前时间`（`TimeUtils.resolve`）。
  - 由于「倒计时开始」只有时刻没有日期，会在 昨天 / 今天 / 明天 三个候选里挑「结束时刻离现在最近」的那个，跨日场景才正确：例如开始 23:00 + 8 小时 → 次日 07:00 结束；现在 01:00 时真实剩余 6 小时，现在 08:00 时已到点。
  - `真实剩余 <= 0` → 主界面红色提示「倒计时已到：结束时刻 xx:xx 已过去 …」且开始按钮置灰；否则按真实剩余倒计时。
