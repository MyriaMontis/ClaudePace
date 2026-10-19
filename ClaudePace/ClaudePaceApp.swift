import SwiftUI
import AppKit

@main
struct ClaudePaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 画面はパネル側で出すので、ここは空の Settings シーンのみ
        Settings { EmptyView() }
    }
}

/// 枠なしウィンドウは既定でキーになれず、テキスト入力を受け取れないため上書きする。
final class PacePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 縁取りだけを描くオーバーレイ。クリックは下の中身へ素通しする。
final class BorderOverlayView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateLayer() {
        // ライト/ダークの切り替えに追従させるため、色はここで解決する。
        // ダークは現状が完成形なので触らない。太さもライトだけ上げる。
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.borderColor = (isDark ? NSColor(white: 1, alpha: 0.22)
                                     : NSColor(white: 0, alpha: 0.18)).cgColor
        layer?.borderWidth = isDark ? 0.5 : 1.0
    }
}

/// パネルの中身。質感と角丸はガラス側で作る。
final class PanelContentController: NSViewController {
    private let host: NSHostingController<AnyView>
    /// 設定の開閉などで中身の高さが変わったときに呼ばれる
    var onPreferredSizeChange: ((NSSize) -> Void)?

    var fittingSize: NSSize { host.view.fittingSize }

    init(rootView: AnyView) {
        host = NSHostingController(rootView: rootView)
        host.sizingOptions = [.preferredContentSize]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) は未使用") }

    // 純正のメニューバーパネル（Wi-Fi・ミラーリング等)の丸みに合わせる
    static let cornerRadius: CGFloat = 16

    override func loadView() {
        // 純正のメニューバー項目は Liquid Glass で描かれている。
        // NSVisualEffectView は旧世代のすりガラスで、色は乗るが背後の輪郭を溶かして消すため、
        // どのマテリアルを選んでも純正の見た目には届かない。
        let glass = NSGlassEffectView()
        glass.cornerRadius = Self.cornerRadius
        // 純正（画面ミラーリング等）と同じ .regular。背後は色のにじみ程度までぼかされ、文字は透けない。
        // （以前の .clear + 乳白 tint は macOS 27 で背後の文字がそのまま読めるほど透けた）
        // tint なしならライト/ダークにもシステムが追従する。
        glass.style = .regular
        view = glass
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        // 中身に角丸クリップは掛けない。中身は余白があり角まで届かないうえ、
        // クリップの縁がガラスの角とサブピクセルでズレて薄い縫い目に見える。
        (view as? NSGlassEffectView)?.contentView = host.view
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // 極細の縁取り。ガラス本体のレイヤーをいじると背面サンプリングが壊れるため、
        // クリック素通しのオーバーレイに描く（contentView の外なので z 順も安定）。
        let border = BorderOverlayView()
        border.wantsLayer = true
        border.layer?.borderWidth = 0.5
        border.layer?.cornerRadius = Self.cornerRadius
        border.layer?.cornerCurve = .continuous
        border.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(border)
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: view.topAnchor),
            border.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            border.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        let size = viewController.preferredContentSize
        preferredContentSize = size
        onPreferredSizeChange?(size)
    }

    /// SwiftUI はビュー階層の構築とサイズ計算を初回表示時にやるため、
    /// その分だけ最初の1回が遅い。起動時に先に済ませておく。
    func prewarm() { host.view.layoutSubtreeIfNeeded() }
}

/// メニューバー常駐（NSStatusItem）＋パネル表示を担うデリゲート。
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem?

    private var panel: PacePanel?
    private var content: PanelContentController?
    /// 他プロセスのクリックはローカルイベントに来ないため、専用のモニタで拾う。
    private var outsideClickMonitor: Any?
    private var isClosing = false
    /// 最後に閉じた時刻。アイコンのクリックで閉じた直後に、同じクリックで開き直さないため
    private var lastClosedAt: Date?

    private var isPanelShown: Bool { panel?.isVisible == true }

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
        // メニューの代わりに自前パネルを出す公式の仕組み（macOS 27）。
        // 左クリックでの開閉と、アイコンの選択背景（純正メニューと同じカプセル）をシステムが担う
        statusItem?.expandedInterfaceDelegate = self
        updateStatusTitle()

        setupPanel()

        // 設定変更をメニューバー表示に即反映
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateStatusTitle),
            name: UserDefaults.didChangeNotification, object: nil)

        // ⌘Tab などで他アプリに移ったら閉じる（クリックはモニタ側で拾う）
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification, object: nil)

        // 理想ペースは時間で変わるので定期更新（リセット跨ぎの検知もここで）
        checkAutoReset()
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAutoReset()
            self?.updateStatusTitle()
        }

        // 初回起動ならパネルを自動で開く（オンボーディング）
        // メニューバーのアイコン位置が確定してから出すため少し待つ
        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showPopover()
            }
        }
    }

    /// NSPopover ではなく枠なしパネルで出す。
    /// NSPopover は必ず吹き出しの矢印が付き、純正のメニューバー項目と見た目が揃わないため。
    private func setupPanel() {
        let controller = PanelContentController(rootView: AnyView(ContentView()))
        content = controller

        let p = PacePanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        p.contentViewController = controller
        p.isOpaque = false
        p.backgroundColor = .clear      // 角丸を見せるため背景は透過
        // 影はガラス（Liquid Glass）が自前で持っている。ウィンドウ影を重ねると
        // 角丸と影の形が僅かにズレて、角だけ薄い縁のように見える。
        p.hasShadow = false
        p.level = .popUpMenu
        p.isMovable = false
        p.hidesOnDeactivate = false     // 閉じ方は自前で制御する
        p.animationBehavior = .none     // 開くのは即時、閉じるフェードは自前
        p.becomesKeyOnlyIfNeeded = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.delegate = self
        panel = p

        // 設定の開閉で高さが変わる。ウィンドウは左下基準で伸びるので、
        // 放っておくと上端がメニューバーに突き刺さる。上端を固定して追従させる。
        controller.onPreferredSizeChange = { [weak self] size in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            panel.setContentSize(size)
            self.positionPanel()
        }

        controller.prewarm()
    }

    /// 週のリセット時刻を跨いだら使用量を自動で0%に戻す。
    /// Claude 側はリセットで必ず0%になるので、表示だけ古い値が残るのを防ぐ。
    private func checkAutoReset() {
        let d = UserDefaults.standard
        let weekday = d.object(forKey: "resetWeekday") as? Int ?? PaceCalculator.defaultWeekday
        let hour    = d.object(forKey: "resetHour")    as? Int ?? PaceCalculator.defaultHour
        let minute  = d.object(forKey: "resetMinute")  as? Int ?? PaceCalculator.defaultMinute

        let reset = PaceCalculator.lastReset(weekday: weekday, hour: hour, minute: minute)
        // 起点設定ごと記録し、設定変更でリセット時刻が動いただけの時は0%にしない
        let anchor = "\(weekday)-\(hour)-\(minute)"

        if d.string(forKey: "lastSeenResetAnchor") == anchor,
           let seen = d.object(forKey: "lastSeenReset") as? Date,
           reset.timeIntervalSince(seen) > 1 {
            d.set(0.0, forKey: "currentUsage") // 新しい週に入った
        }
        d.set(reset, forKey: "lastSeenReset")
        d.set(anchor, forKey: "lastSeenResetAnchor")
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

    /// 右クリック=終了メニュー（左クリックはシステムのセッション経由で開閉する）
    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent?.type == .rightMouseUp else { return }
        showQuitMenu()
    }

    /// 右クリックの「終了」メニュー
    func showQuitMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "終了",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        // アイコンは別プロセスで描かれるため、statusItem.menu + performClick ではメニューが出ない。
        // アイコンの直下に直接ポップアップする
        guard let button = statusItem?.button, let window = button.window else { return }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        menu.popUp(positioning: nil, at: NSPoint(x: frame.minX, y: frame.minY - 4), in: nil)
    }

    func showPopover() {
        guard let panel, let content else { return }
        isClosing = false

        // 位置決めの前に実サイズを確定させる（表示後だとズレが見える）
        content.prewarm()
        panel.setContentSize(content.fittingSize)
        positionPanel()

        // 即出しだと唐突なので、ごく短いフェードで入れる（閉じる側より速め）
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        startOutsideClickMonitor()

        // キー化は次のループで（先にパネルを出す方が体感が速い）。
        // アプリ自体はアクティブにしない：nonactivating パネルはキーにさえなれば
        // 数値入力欄にキーボードが届く。NSApp.activate すると前面アプリから
        // フォーカスを奪い、そのウィンドウの信号機ボタンがグレーになる（純正メニューは奪わない）。
        DispatchQueue.main.async {
            panel.makeKey()
        }
    }

    func closePopover() {
        guard let panel, panel.isVisible, !isClosing else { return }
        isClosing = true
        lastClosedAt = Date()
        // 外クリック・⌘Tab 等で閉じたら、システム側のセッションも終わらせる（アイコンの背景が消える）
        statusItem?.expandedInterfaceSession?.cancel()
        stopOutsideClickMonitor()
        // 純正のメニューと同じく、閉じるときだけ余韻を残す
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.isClosing else { return }
            panel.orderOut(nil)
            panel.alphaValue = 1
            self.isClosing = false
        })
    }

    /// メニューバーのボタン直下に配置する（画面端でははみ出さないよう寄せる）。
    /// アイコンが「«」の折りたたみやノッチの裏で見えていないと座標が画面外を指すので、
    /// その場合はメイン画面の上部中央に出す。どちらでも必ず画面内に収める
    private func positionPanel() {
        guard let panel else { return }
        var anchor: NSRect?
        var screen: NSScreen?
        if let button = statusItem?.button, let buttonWindow = button.window {
            let btn = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if let s = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: btn.midX, y: btn.midY)) }) {
                anchor = btn
                screen = s
            }
        }
        guard let vf = (screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let size = panel.frame.size
        var x = (anchor?.midX ?? vf.midX) - size.width / 2
        var y = (anchor?.minY ?? vf.maxY) - size.height - 6
        x = min(max(x, vf.minX + 8), vf.maxX - size.width - 8)
        y = max(y, vf.minY + 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func appDidResignActive() {
        guard isPanelShown else { return }
        closePopover()
    }

    /// アプリをアクティブにしないので、⌘Tab 等で他アプリに移ったことは
    /// パネルがキーを失ったことで知る。カラーパネルなど自アプリの別ウィンドウに
    /// キーが移っただけなら閉じない（キーの移動が終わってから判定する）
    func windowDidResignKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === panel else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isPanelShown, NSApp.keyWindow == nil else { return }
            self.closePopover()
        }
    }

    // 自アプリ内（カラーパネル等）のクリックはローカル扱いなので、このモニタは発火しない。
    // ＝設定を開いたまま色を選んでもパネルは閉じない。
    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}

extension AppDelegate: NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin expandedInterfaceSession: NSStatusItemExpandedInterfaceSession) {
        // macOS 27 ではアイコンが別プロセスで描かれ、開いている時のアイコンのクリックは
        // 外クリック扱いで先に閉じる。その同じクリックでシステムが開き直そうとするので止める
        if let closed = lastClosedAt, Date().timeIntervalSince(closed) < 0.3 {
            expandedInterfaceSession.cancel()
            return
        }
        // 右クリック・control+クリックでもセッションが始まるので、その場合はメニューに切り替える
        let event = NSApp.currentEvent
        if NSEvent.pressedMouseButtons & 0b10 != 0
            || event?.type == .rightMouseDown || event?.type == .rightMouseUp
            || NSEvent.modifierFlags.contains(.control) {
            expandedInterfaceSession.cancel()
            DispatchQueue.main.async { self.showQuitMenu() }
            return
        }
        showPopover()
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        closePopover()
    }
}
