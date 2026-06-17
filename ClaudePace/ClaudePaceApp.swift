import SwiftUI
import AppKit

@main
struct ClaudePaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 画面は NSPopover 側で出すので、ここは空の Settings シーンのみ
        Settings { EmptyView() }
    }
}

/// メニューバー常駐（NSStatusItem）＋ポップオーバー表示を担うデリゲート。
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory) // メニューバー専用（Dockに出さない）

        // ── メニューバーのボタン ──
        // 幅を固定して、%の桁数変化で隣のアイコンが揺れないようにする
        statusItem = NSStatusBar.system.statusItem(withLength: 60)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "ClaudePace")
            button.imagePosition = .imageLeading
            button.alignment = .left
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        updateStatusTitle()

        // ── ポップオーバー（中身は SwiftUI の ContentView）──
        let hosting = NSHostingController(rootView: ContentView())
        hosting.sizingOptions = [.preferredContentSize] // 中身に合わせて自動リサイズ
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentViewController = hosting
        popover = pop

        // 設定変更をメニューバー表示に即反映
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateStatusTitle),
            name: UserDefaults.didChangeNotification, object: nil)

        // 理想ペースは時間で変わるので定期更新
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateStatusTitle()
        }

        // 初回起動ならポップオーバーを自動で開く（オンボーディング）
        // メニューバーのアイコン位置が確定してから出すため少し待つ
        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showPopover()
            }
        }
    }

    /// メニューバーに「理想ペース%」を状態色つきで表示
    @objc func updateStatusTitle() {
        let d = UserDefaults.standard
        let current = d.double(forKey: "currentUsage")
        let weekday = d.object(forKey: "resetWeekday") as? Int ?? PaceCalculator.defaultWeekday
        let hour    = d.object(forKey: "resetHour")    as? Int ?? PaceCalculator.defaultHour
        let minute  = d.object(forKey: "resetMinute")  as? Int ?? PaceCalculator.defaultMinute

        let ideal = PaceCalculator.idealPercent(weekday: weekday, hour: hour, minute: minute)

        let low  = d.object(forKey: "thLow")  as? Double ?? PaceStatus.defaultLow
        let mid  = d.object(forKey: "thMid")  as? Double ?? PaceStatus.defaultMid
        let high = d.object(forKey: "thHigh") as? Double ?? PaceStatus.defaultHigh
        let status = PaceStatus.evaluate(current: current, ideal: ideal, low: low, mid: mid, high: high)

        let hex: String
        switch status.level {
        case .safe: hex = d.string(forKey: "colorSafe") ?? PaceStatus.defaultColorSafe
        case .good: hex = d.string(forKey: "colorGood") ?? PaceStatus.defaultColorGood
        case .warn: hex = d.string(forKey: "colorWarn") ?? PaceStatus.defaultColorWarn
        case .over: hex = d.string(forKey: "colorOver") ?? PaceStatus.defaultColorOver
        }
        // 状態ごとの着色ON/OFF（既定: 余裕ありのみOFF＝白/追従色）
        let tintKey: String, tintDefault: Bool
        switch status.level {
        case .safe: tintKey = "tintSafe"; tintDefault = false
        case .good: tintKey = "tintGood"; tintDefault = true
        case .warn: tintKey = "tintWarn"; tintDefault = true
        case .over: tintKey = "tintOver"; tintDefault = true
        }
        let tinted = d.object(forKey: tintKey) as? Bool ?? tintDefault
        // OFF時は黒で描いてテンプレート扱い → システムが白/黒に追従させる
        let drawColor = tinted ? NSColor(hex: hex) : NSColor.black

        guard let button = statusItem?.button else { return }

        // ステータスバーは attributedTitle の文字色を無視するため、
        // アイコン＋数字を1枚の画像に描画して表示する。
        // 表示する値は設定で「理想 / 現在」を選択（既定: 理想）
        let show = d.string(forKey: "menubarShow") ?? "ideal"
        let pct = Int((show == "current" ? current : ideal).rounded())
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        let text = NSAttributedString(string: "\(pct)%", attributes: [.font: font, .foregroundColor: drawColor])
        let textSize = text.size()

        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let gauge = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        let gSize = gauge?.size ?? .zero
        let spacing: CGFloat = 3
        let w = gSize.width + spacing + textSize.width
        let h = max(gSize.height, textSize.height) + 2

        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        if let gauge {
            let rect = NSRect(x: 0, y: (h - gSize.height) / 2, width: gSize.width, height: gSize.height)
            gauge.draw(in: rect)
            drawColor.set()
            rect.fill(using: .sourceAtop) // ゲージを着色
        }
        text.draw(at: NSPoint(x: gSize.width + spacing, y: (h - textSize.height) / 2))
        image.unlockFocus()
        image.isTemplate = !tinted // OFF時はテンプレート＝白/黒に追従

        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
    }

    /// 左クリック=開閉 / 右クリック=終了メニュー
    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "終了",
                                    action: #selector(NSApplication.terminate(_:)),
                                    keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // キー入力を受け取れるようにフォーカスを与える
        popover?.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover() {
        popover?.performClose(nil)
    }

    /// 設定中はカラーパネル操作でポップが閉じないよう固定する
    func setSticky(_ sticky: Bool) {
        popover?.behavior = sticky ? .applicationDefined : .transient
    }
}
