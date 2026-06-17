import SwiftUI
import Combine
import AppKit

struct ContentView: View {

    // 入力・設定（永続化）
    @AppStorage("currentUsage") private var currentUsage: Double = 0
    @AppStorage("didOnboard")   private var didOnboard: Bool = false
    @AppStorage("lang")         private var langRaw: String = AppLanguage.en.rawValue

    // リセット起点（曜日 1=日 … 7=土 / 時 / 分）
    @AppStorage("resetWeekday") private var resetWeekday: Int = PaceCalculator.defaultWeekday
    @AppStorage("resetHour")    private var resetHour: Int    = PaceCalculator.defaultHour
    @AppStorage("resetMinute")  private var resetMinute: Int  = PaceCalculator.defaultMinute

    // 色判定の境界（差分%）
    @AppStorage("thLow")  private var thLow: Double  = PaceStatus.defaultLow
    @AppStorage("thMid")  private var thMid: Double  = PaceStatus.defaultMid
    @AppStorage("thHigh") private var thHigh: Double = PaceStatus.defaultHigh

    // カスタム色（16進）
    @AppStorage("colorSafe") private var colorSafe: String = PaceStatus.defaultColorSafe
    @AppStorage("colorGood") private var colorGood: String = PaceStatus.defaultColorGood
    @AppStorage("colorWarn") private var colorWarn: String = PaceStatus.defaultColorWarn
    @AppStorage("colorOver") private var colorOver: String = PaceStatus.defaultColorOver

    // カスタムアイコン（SF Symbol名）
    @AppStorage("iconSafe") private var iconSafe: String = "tortoise.fill"
    @AppStorage("iconGood") private var iconGood: String = "checkmark.circle.fill"
    @AppStorage("iconWarn") private var iconWarn: String = "exclamationmark.triangle.fill"
    @AppStorage("iconOver") private var iconOver: String = "flame.fill"

    // メニューバーに表示する値（"ideal" または "current"）
    @AppStorage("menubarShow") private var menubarShow: String = "ideal"

    // メニューバーを状態色で着色するか（既定: 余裕ありのみOFF＝白）
    @AppStorage("tintSafe") private var tintSafe: Bool = false
    @AppStorage("tintGood") private var tintGood: Bool = true
    @AppStorage("tintWarn") private var tintWarn: Bool = true
    @AppStorage("tintOver") private var tintOver: Bool = true

    /// リセット残りの表示形式（0:日+時間 / 1:時間 / 2:分 / 3:秒）
    @State private var resetMode = 0
    @State private var showSettings = false
    @FocusState private var usageFocused: Bool

    // ColorPicker用のライブ色
    @State private var cSafe = Color.blue
    @State private var cGood = Color.green
    @State private var cWarn = Color.orange
    @State private var cOver = Color.red
    @State private var colorsLoaded = false

    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let iconChoices = [
        "tortoise.fill", "hare.fill", "checkmark.circle.fill", "hand.thumbsup.fill",
        "star.fill", "leaf.fill", "flame.fill", "exclamationmark.triangle.fill",
        "bolt.fill", "gauge.medium", "heart.fill", "moon.fill",
        "sun.max.fill", "cup.and.saucer.fill", "flag.fill", "bell.fill"
    ]

    private var lang: AppLanguage { AppLanguage(rawValue: langRaw) ?? .en }
    private func L(_ key: String) -> String { Loc.t(key, lang) }

    private var ideal: Double {
        PaceCalculator.idealPercent(weekday: resetWeekday, hour: resetHour, minute: resetMinute, from: now)
    }
    private var diff: Double { currentUsage - ideal }
    private var status: PaceStatus {
        PaceStatus.evaluate(current: currentUsage, ideal: ideal,
                            low: thLow, mid: thMid, high: thHigh)
    }
    private var statusColor: Color { color(for: status.level) }

    var body: some View {
        Group {
            if !didOnboard {
                onboardingView
            } else if showSettings {
                settingsView
            } else {
                mainView
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(
            Color.clear.contentShape(Rectangle()).onTapGesture { clearFocus() }
        )
        .onChange(of: showSettings) { _, isOpen in
            AppDelegate.shared?.setSticky(isOpen)
            if !isOpen { NSColorPanel.shared.close() }
        }
        .onReceive(timer) { now = $0 }
        .onAppear {
            if !colorsLoaded {
                cSafe = Color(hex: colorSafe); cGood = Color(hex: colorGood)
                cWarn = Color(hex: colorWarn); cOver = Color(hex: colorOver)
                colorsLoaded = true
            }
        }
    }

    // ════════════════════════════════════════
    //  メイン画面
    // ════════════════════════════════════════
    private var mainView: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Image(systemName: "gauge.with.dots.needle.50percent")
                Text(L("appTitle")).font(.headline)
                Spacer()
                Button {
                    clearFocus(); showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3").imageScale(.large)
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 12) {
                Image(systemName: iconFor(status.level))
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: status.level))
                        .font(.title3.bold())
                        .foregroundStyle(statusColor)
                    Text(diffText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture { clearFocus() }

            // オーバー時：あと何時間我慢すれば理想に追いつくか（1分以上で表示）
            let catchHours = max(diff, 0) / 100 * PaceCalculator.totalHours
            if catchHours * 60 >= 1 {
                HStack(spacing: 5) {
                    Image(systemName: "hourglass").font(.caption2)
                    Text(String(format: L("catchup"), Loc.span(hours: catchHours, lang)))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            paceBar

            VStack(spacing: 6) {
                row(label: L("lbl_current"), value: currentUsage, color: statusColor)
                row(label: L("lbl_ideal"), value: ideal, color: .secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(L("lbl_enter")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Slider(value: Binding(
                        get: { currentUsage },
                        set: { currentUsage = $0.rounded() }
                    ), in: 0...100)
                    TextField("", value: $currentUsage, format: .number)
                        .frame(width: 40)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .focused($usageFocused)
                        .onSubmit { clearFocus() }
                    Text("%")
                    Stepper("", value: $currentUsage, in: 0...100, step: 1)
                        .labelsHidden()
                        .fixedSize()
                }
            }

            HStack {
                Text(Loc.remaining(mode: resetMode,
                                   hoursLeft: PaceCalculator.hoursUntilReset(weekday: resetWeekday, hour: resetHour, minute: resetMinute, from: now),
                                   lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { resetMode = (resetMode + 1) % 4 }
                Spacer()
                Button(L("close")) { AppDelegate.shared?.closePopover() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
    }

    // ════════════════════════════════════════
    //  初回オンボーディング
    // ════════════════════════════════════════
    private var onboardingView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.wave.fill").foregroundStyle(.blue)
                Text(L("welcome")).font(.headline)
            }

            // 言語選択（Menuプルダウン。Pickerだと選択中心配置で「^」が出るため）
            HStack {
                Menu {
                    ForEach(AppLanguage.allCases) { l in
                        Button {
                            langRaw = l.rawValue
                        } label: {
                            if l.rawValue == langRaw {
                                Label(l.displayName, systemImage: "checkmark")
                            } else {
                                Text(l.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text(lang.displayName)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
            }

            Text(L("ob_intro")).font(.subheadline)
            Text(L("ob_note"))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            resetPickerRow

            menubarShowPicker

            VStack(alignment: .leading, spacing: 4) {
                Text(L("ob_canCustomize")).font(.caption.bold())
                featureLine("paintpalette", L("ob_feat_color"))
                featureLine("calendar", L("ob_feat_reset"))
                featureLine("timer", L("ob_feat_remaining"))
                featureLine("face.smiling", L("ob_feat_icon"))
                featureLine("menubar.rectangle", L("ob_feat_menubar"))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            Button { didOnboard = true } label: {
                Text(L("start")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(L("ob_footer")).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func featureLine(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(.blue).frame(width: 16)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // ════════════════════════════════════════
    //  設定画面
    // ════════════════════════════════════════
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("set_title")).font(.headline)
                Spacer()
                Button { showSettings = false } label: {
                    Image(systemName: "chevron.left.circle").imageScale(.large)
                }
                .buttonStyle(.borderless)
            }

            // リセット起点
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(L("set_resetStart")) { resetAnchor() }
                Text(L("set_checkUsage")).font(.caption2).foregroundStyle(.secondary)
                resetPickerRow
            }

            Divider()

            // 色の境界
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(L("set_thresholds")) { resetThresholds() }
                thresholdRow(from: .safe, to: .good, value: $thLow, range: -50...0)
                thresholdRow(from: .good, to: .warn, value: $thMid, range: 0...30)
                thresholdRow(from: .warn, to: .over, value: $thHigh, range: 0...50)
            }

            Divider()

            // 色のカスタマイズ
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(L("set_colors")) { resetColors() }
                colorRow(.safe, color: $cSafe, store: $colorSafe)
                colorRow(.good, color: $cGood, store: $colorGood)
                colorRow(.warn, color: $cWarn, store: $colorWarn)
                colorRow(.over, color: $cOver, store: $colorOver)
            }

            Divider()

            // アイコンのカスタマイズ
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(L("set_icons")) { resetIcons() }
                iconRow(.safe, store: $iconSafe)
                iconRow(.good, store: $iconGood)
                iconRow(.warn, store: $iconWarn)
                iconRow(.over, store: $iconOver)
            }

            Divider()

            // メニューバーの着色（状態ごとにON/OFF）
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(L("set_menubar")) { resetTint() }
                menubarShowPicker
                tintRow(.safe, isOn: $tintSafe)
                tintRow(.good, isOn: $tintGood)
                tintRow(.warn, isOn: $tintWarn)
                tintRow(.over, isOn: $tintOver)
            }

            HStack {
                Button(L("reset_all")) { resetEverything() }
                    .font(.caption2).buttonStyle(.borderless).foregroundStyle(.red)
                Spacer()
                Button(L("done")) { showSettings = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // ════════════════════════════════════════
    //  パーツ
    // ════════════════════════════════════════
    private var resetPickerRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $resetWeekday) {
                ForEach(1...7, id: \.self) { wd in Text(Loc.weekday(wd, lang)).tag(wd) }
            }
            .labelsHidden()
            .fixedSize()
            Stepper(Loc.hour(resetHour, lang)) {
                resetHour = (resetHour + 1) % 24
            } onDecrement: {
                resetHour = (resetHour + 23) % 24
            }
            .fixedSize()
            Stepper("\(resetMinute)\(Loc.t("unit_min", lang))") {
                resetMinute = (resetMinute + 1) % 60
            } onDecrement: {
                resetMinute = (resetMinute + 59) % 60
            }
            .fixedSize()
        }
    }

    private func sectionHeader(_ title: String, reset: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.subheadline.bold())
            Spacer()
            Button(L("reset"), action: reset).font(.caption2).buttonStyle(.borderless)
        }
    }

    private func thresholdRow(from: PaceLevel, to: PaceLevel,
                              value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            HStack(spacing: 6) {
                Circle().fill(color(for: from)).frame(width: 12, height: 12)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                Circle().fill(color(for: to)).frame(width: 12, height: 12)
                Spacer()
                Text("\(fmt(value.wrappedValue))%").font(.subheadline.monospacedDigit().bold())
            }
        }
    }

    private func colorRow(_ level: PaceLevel, color: Binding<Color>, store: Binding<String>) -> some View {
        HStack {
            Text(title(for: level)).font(.subheadline).frame(width: 90, alignment: .leading)
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color.wrappedValue) { _, v in store.wrappedValue = v.toHex() }
            Spacer()
        }
    }

    private func iconRow(_ level: PaceLevel, store: Binding<String>) -> some View {
        HStack {
            Text(title(for: level)).font(.subheadline).frame(width: 90, alignment: .leading)
            Menu {
                ForEach(iconChoices, id: \.self) { sym in
                    Button { store.wrappedValue = sym } label: { Label(sym, systemImage: sym) }
                }
            } label: {
                Image(systemName: store.wrappedValue)
                    .imageScale(.large)
                    .foregroundStyle(color(for: level))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            Spacer()
        }
    }

    private var menubarShowPicker: some View {
        HStack {
            Text(L("set_menubarShow")).font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $menubarShow) {
                Text(L("mb_ideal")).tag("ideal")
                Text(L("mb_current")).tag("current")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private func tintRow(_ level: PaceLevel, isOn: Binding<Bool>) -> some View {
        HStack {
            Circle().fill(color(for: level)).frame(width: 10, height: 10)
            Text(title(for: level)).font(.subheadline)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
        }
    }

    private func color(for level: PaceLevel) -> Color {
        switch level {
        case .safe: cSafe
        case .good: cGood
        case .warn: cWarn
        case .over: cOver
        }
    }

    private func iconFor(_ level: PaceLevel) -> String {
        switch level {
        case .safe: iconSafe
        case .good: iconGood
        case .warn: iconWarn
        case .over: iconOver
        }
    }

    private func title(for level: PaceLevel) -> String {
        switch level {
        case .safe: L("st_safe")
        case .good: L("st_good")
        case .warn: L("st_warn")
        case .over: L("st_over")
        }
    }

    // ── リセット系 ──
    private func resetAnchor() {
        resetWeekday = PaceCalculator.defaultWeekday
        resetHour = PaceCalculator.defaultHour
        resetMinute = PaceCalculator.defaultMinute
    }
    private func resetThresholds() {
        thLow = PaceStatus.defaultLow; thMid = PaceStatus.defaultMid; thHigh = PaceStatus.defaultHigh
    }
    private func resetColors() {
        cSafe = Color(hex: PaceStatus.defaultColorSafe); cGood = Color(hex: PaceStatus.defaultColorGood)
        cWarn = Color(hex: PaceStatus.defaultColorWarn); cOver = Color(hex: PaceStatus.defaultColorOver)
        colorSafe = PaceStatus.defaultColorSafe; colorGood = PaceStatus.defaultColorGood
        colorWarn = PaceStatus.defaultColorWarn; colorOver = PaceStatus.defaultColorOver
    }
    private func resetIcons() {
        iconSafe = "tortoise.fill"; iconGood = "checkmark.circle.fill"
        iconWarn = "exclamationmark.triangle.fill"; iconOver = "flame.fill"
    }
    private func resetTint() {
        menubarShow = "ideal"
        tintSafe = false; tintGood = true; tintWarn = true; tintOver = true
    }
    private func resetEverything() {
        resetAnchor(); resetThresholds(); resetColors(); resetIcons(); resetTint()
        currentUsage = 0
        resetMode = 0
        langRaw = AppLanguage.en.rawValue   // デフォルトは英語
        NSColorPanel.shared.close()
        showSettings = false
        didOnboard = false
    }

    private func clearFocus() {
        usageFocused = false
        DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    private func fmt(_ v: Double) -> String { v > 0 ? "+\(Int(v))" : "\(Int(v))" }

    private var diffText: String {
        let v = Int(abs(diff).rounded())
        if diff > 0 { return String(format: L("diff_over"), v) }
        else if diff < 0 { return String(format: L("diff_under"), v) }
        else { return L("diff_on") }
    }

    private var paceBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2))
                Capsule().fill(statusColor)
                    .frame(width: geo.size.width * CGFloat(currentUsage / 100))
                Rectangle().fill(Color.primary.opacity(0.6))
                    .frame(width: 2)
                    .offset(x: geo.size.width * CGFloat(ideal / 100))
            }
        }
        .frame(height: 10)
    }

    private func row(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            Text("\(Int(value.rounded()))%")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

#Preview {
    ContentView()
}
