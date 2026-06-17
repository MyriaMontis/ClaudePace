import Foundation

/// 対応言語（デフォルトは英語）
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, es, zh, ja, hi, ar, fr, ru, id, de, tr, ko
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: "English"
        case .es: "Español"
        case .zh: "中文"
        case .ja: "日本語"
        case .hi: "हिन्दी"
        case .ar: "العربية"
        case .fr: "Français"
        case .ru: "Русский"
        case .id: "Indonesia"
        case .de: "Deutsch"
        case .tr: "Türkçe"
        case .ko: "한국어"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .en: "en_US"
        case .es: "es_ES"
        case .zh: "zh_CN"
        case .ja: "ja_JP"
        case .hi: "hi_IN"
        case .ar: "ar_SA"
        case .fr: "fr_FR"
        case .ru: "ru_RU"
        case .id: "id_ID"
        case .de: "de_DE"
        case .tr: "tr_TR"
        case .ko: "ko_KR"
        }
    }

    /// 数字と単位の間にスペースを入れるか（中・日は入れない）
    var usesSpace: Bool { self != .zh && self != .ja }
}

enum Loc {

    /// テーブルの言語順
    static let order: [AppLanguage] = [.en, .es, .zh, .ja, .hi, .ar, .fr, .ru, .id, .de, .tr, .ko]

    static func t(_ key: String, _ lang: AppLanguage) -> String {
        guard let arr = table[key],
              let i = order.firstIndex(of: lang),
              i < arr.count else { return key }
        return arr[i]
    }

    static func weekday(_ wd: Int, _ lang: AppLanguage) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.localeIdentifier)
        let syms = f.shortStandaloneWeekdaySymbols ?? f.shortWeekdaySymbols ?? []
        let idx = (wd - 1) % 7
        return idx < syms.count ? syms[idx] : "\(wd)"
    }

    static func hour(_ hour: Int, _ lang: AppLanguage) -> String {
        var c = DateComponents(); c.hour = hour; c.minute = 0
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: c) else { return "\(hour)" }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.localeIdentifier)
        f.setLocalizedDateFormatFromTemplate("j")
        return f.string(from: date)
    }

    static func remaining(mode: Int, hoursLeft: Double, _ lang: AppLanguage) -> String {
        let prefix = t("resets_in", lang)
        let sep = lang.usesSpace ? " " : ""
        let dU = t("unit_day", lang), hU = t("unit_hour", lang)
        let mU = t("unit_min", lang), sU = t("unit_sec", lang)
        func join(_ p: [String]) -> String { p.joined(separator: sep) }

        switch mode {
        case 1:
            return "\(prefix) \(Int(hoursLeft.rounded()))\(hU)"
        case 2:
            let tm = Int((hoursLeft * 60).rounded())
            let d = tm / 1440, h = (tm % 1440) / 60, m = tm % 60
            var p: [String] = []
            if d > 0 { p.append("\(d)\(dU)") }
            if d > 0 || h > 0 { p.append("\(h)\(hU)") }
            p.append("\(m)\(mU)")
            return "\(prefix) \(join(p))"
        case 3:
            let ts = Int(hoursLeft * 3600)
            let d = ts / 86400, h = (ts % 86400) / 3600, m = (ts % 3600) / 60, s = ts % 60
            var p: [String] = []
            if d > 0 { p.append("\(d)\(dU)") }
            if d > 0 || h > 0 { p.append("\(h)\(hU)") }
            if d > 0 || h > 0 || m > 0 { p.append("\(m)\(mU)") }
            p.append("\(s)\(sU)")
            return "\(prefix) \(join(p))"
        default:
            let total = Int(hoursLeft.rounded())
            let d = total / 24, h = total % 24
            if d > 0 { return "\(prefix) \(d)\(dU)\(sep)\(h)\(hU)" }
            return "\(prefix) \(h)\(hU)"
        }
    }

    /// 短い期間表記。1時間未満は分、それ以上は時間に丸めて表示
    /// （例: 45分 / 15時間 / 2日3時間）
    static func span(hours: Double, _ lang: AppLanguage) -> String {
        let totalMin = max(Int((hours * 60).rounded()), 0)
        let dU = t("unit_day", lang), hU = t("unit_hour", lang), mU = t("unit_min", lang)
        let sep = lang.usesSpace ? " " : ""

        // 1時間未満は分で
        if totalMin < 60 { return "\(totalMin)\(mU)" }

        // 1時間以上は時間に丸めて、分は省略（急かさない）
        let totalHr = Int((Double(totalMin) / 60).rounded())
        let d = totalHr / 24, h = totalHr % 24
        if d > 0 {
            return h > 0 ? "\(d)\(dU)\(sep)\(h)\(hU)" : "\(d)\(dU)"
        }
        return "\(h)\(hU)"
    }

    // 値の順: [en, es, zh, ja, hi, ar, fr, ru, id, de, tr, ko]
    static let table: [String: [String]] = [
        "welcome": ["Welcome","Bienvenido","欢迎","ようこそ","स्वागत है","مرحبًا","Bienvenue","Добро пожаловать","Selamat datang","Willkommen","Hoş geldiniz","환영합니다"],
        "language": ["Language","Idioma","语言","言語","भाषा","اللغة","Langue","Язык","Bahasa","Sprache","Dil","언어"],
        "ob_intro": ["First, set your weekly reset point.","Primero, indica tu punto de reinicio semanal.","首先，请设置你的每周重置起点。","まず、あなたの「週のリセット起点」を教えてください。","सबसे पहले, अपना साप्ताहिक रीसेट समय सेट करें।","أولاً، حدد وقت إعادة التعيين الأسبوعي.","D'abord, définissez votre point de réinitialisation hebdomadaire.","Сначала укажите время еженедельного сброса.","Pertama, atur titik reset mingguan Anda.","Lege zuerst deinen wöchentlichen Reset-Zeitpunkt fest.","Önce haftalık sıfırlama başlangıcını ayarlayın.","먼저 주간 초기화 시점을 설정하세요."],
        "ob_note": ["Claude's weekly reset varies by user.\nCheck claude.ai/settings/usage or Claude Desktop settings.","El reinicio semanal de Claude varía según el usuario.\nConsúltalo en claude.ai/settings/usage o en los ajustes de Claude Desktop.","Claude 的每周重置因人而异。\n可在 claude.ai/settings/usage 或 Claude 桌面版设置中查看。","Claudeの週次リセットは人によって異なります。\nclaude.ai/settings/usage または Claudeデスクトップ設定で確認できます。","Claude का साप्ताहिक रीसेट हर उपयोगकर्ता के लिए अलग होता है।\nइसे claude.ai/settings/usage या Claude Desktop सेटिंग में देखें।","تختلف إعادة التعيين الأسبوعية لـ Claude حسب المستخدم.\nتحقق في claude.ai/settings/usage أو إعدادات Claude Desktop.","La réinitialisation hebdomadaire de Claude varie selon l'utilisateur.\nVoir claude.ai/settings/usage ou les réglages de Claude Desktop.","Еженедельный сброс Claude различается у каждого пользователя.\nСм. claude.ai/settings/usage или настройки Claude Desktop.","Reset mingguan Claude berbeda tiap pengguna.\nCek di claude.ai/settings/usage atau pengaturan Claude Desktop.","Claudes wöchentlicher Reset ist je Nutzer verschieden.\nSiehe claude.ai/settings/usage oder die Claude-Desktop-Einstellungen.","Claude'un haftalık sıfırlaması kullanıcıya göre değişir.\nclaude.ai/settings/usage veya Claude Desktop ayarlarından kontrol edin.","Claude의 주간 초기화는 사용자마다 다릅니다.\nclaude.ai/settings/usage 또는 Claude 데스크톱 설정에서 확인하세요."],
        "ob_canCustomize": ["✨ What you can customize","✨ Lo que puedes personalizar","✨ 可自定义的内容","✨ カスタマイズできること","✨ आप क्या अनुकूलित कर सकते हैं","✨ ما يمكنك تخصيصه","✨ Ce que vous pouvez personnaliser","✨ Что можно настроить","✨ Yang bisa disesuaikan","✨ Was du anpassen kannst","✨ Neleri özelleştirebilirsin","✨ 커스터마이즈할 수 있는 것"],
        "ob_feat_color": ["Freely change colors & thresholds (4 levels)","Cambia colores y umbrales (4 niveles)","自由更改颜色和阈值（4级）","色と境界（4段階）を自由に変更","रंग और सीमाएँ (4 स्तर) बदलें","غيّر الألوان والحدود (4 مستويات)","Modifiez couleurs et seuils (4 niveaux)","Меняйте цвета и пороги (4 уровня)","Ubah warna & ambang (4 tingkat)","Farben & Schwellen ändern (4 Stufen)","Renkleri ve eşikleri değiştir (4 düzey)","색상과 경계(4단계)를 자유롭게 변경"],
        "ob_feat_reset": ["Set reset start (day & time)","Configura el inicio del reinicio (día y hora)","设置重置起点（星期与时间）","リセット起点（曜日・時刻）を設定","रीसेट समय सेट करें (दिन और समय)","حدد بداية إعادة التعيين (اليوم والوقت)","Définissez le début de réinit. (jour et heure)","Задайте начало сброса (день и время)","Atur awal reset (hari & waktu)","Reset-Start festlegen (Tag & Zeit)","Sıfırlama başlangıcını ayarla (gün ve saat)","초기화 시점(요일·시간) 설정"],
        "ob_feat_remaining": ["Tap remaining time to switch (d+h / h / m / s)","Toca el tiempo restante para cambiar (d+h / h / m / s)","点击剩余时间切换显示（天+时/时/分/秒）","残り表示をタップで切替（日+時間／時間／分／秒）","शेष समय पर टैप कर बदलें","انقر الوقت المتبقي للتبديل","Touchez le temps restant pour changer","Нажмите на остаток для переключения","Ketuk sisa waktu untuk beralih","Tippe auf Restzeit zum Wechseln","Kalan süreye dokunarak değiştir","남은 시간을 탭하여 전환"],
        "ob_feat_icon": ["Pick your own status icons","Elige tus iconos de estado","选择你的状态图标","ステータスのアイコンを選択","अपने स्टेटस आइकन चुनें","اختر أيقونات الحالة الخاصة بك","Choisissez vos icônes d'état","Выберите свои значки статуса","Pilih ikon status Anda","Wähle deine Status-Symbole","Durum simgelerini seç","상태 아이콘 선택"],
        "ob_feat_menubar": ["Choose menu bar display (ideal/current) & tint","Elige qué muestra la barra (ideal/actual) y color","选择菜单栏显示（理想/当前）与着色","メニューバーの表示（理想/現在）と着色を選択","मेन्यू बार प्रदर्शन (आदर्श/वर्तमान) और रंग चुनें","اختر عرض شريط القوائم (مثالي/حالي) واللون","Choisir l'affichage de la barre (idéal/actuel) et couleur","Выбор показа в строке меню (норма/текущий) и цвета","Pilih tampilan bilah menu (ideal/saat ini) & warna","Menüleisten-Anzeige (Ideal/Aktuell) & Farbe wählen","Menü çubuğu gösterimi (ideal/mevcut) ve renk seç","메뉴 막대 표시(이상/현재)와 색상 선택"],
        "catchup": ["Hold off ~%@ to catch up to ideal","Aguanta ~%@ para volver al ritmo ideal","再忍 %@ 即可回到理想节奏","あと%@我慢すれば理想に追いつきます","लगभग %@ रुकें तो आदर्श गति पर आ जाएँगे","انتظر ~%@ للعودة إلى الوتيرة المثالية","Patientez ~%@ pour revenir au rythme idéal","Подождите ~%@, чтобы вернуться к норме","Tahan ~%@ untuk kembali ke tempo ideal","Warte ~%@, um wieder im Soll zu sein","~%@ bekle, ideale dön","%@ 정도 참으면 이상 페이스에 맞춰집니다"],
        "start": ["Get Started","Empezar","开始","はじめる","शुरू करें","ابدأ","Commencer","Начать","Mulai","Los geht's","Başla","시작하기"],
        "ob_footer": ["※ Change anything later from Settings (slider icon).","※ Cambia todo luego en Ajustes (icono deslizante).","※ 之后可在设置（滑块图标）随时更改。","※ あとから設定（スライダーのアイコン）でいつでも変更できます","※ बाद में सेटिंग (स्लाइडर आइकन) से बदलें।","※ يمكنك تغيير كل شيء لاحقًا من الإعدادات.","※ Modifiez tout plus tard dans Réglages.","※ Всё можно изменить позже в настройках.","※ Ubah semuanya nanti di Pengaturan.","※ Alles später in den Einstellungen ändern.","※ Her şeyi sonra Ayarlar'dan değiştir.","※ 나중에 설정(슬라이더 아이콘)에서 변경할 수 있습니다."],

        "appTitle": ["Claude Weekly Pace","Ritmo semanal de Claude","Claude 每周用量","Claude 週間利用ペース","Claude साप्ताहिक गति","وتيرة Claude الأسبوعية","Rythme hebdo Claude","Недельный темп Claude","Tempo Mingguan Claude","Claude Wochen-Tempo","Claude Haftalık Tempo","Claude 주간 사용 페이스"],
        "st_safe": ["Plenty left","Vas sobrado","很充裕","余裕あり","काफी बाकी","متبقٍ كثير","Large marge","Много запаса","Masih banyak","Viel übrig","Bolca var","여유 있음"],
        "st_good": ["Good pace","Buen ritmo","节奏良好","良いペース","अच्छी गति","وتيرة جيدة","Bon rythme","Хороший темп","Tempo bagus","Gutes Tempo","İyi tempo","좋은 페이스"],
        "st_warn": ["Caution","Cuidado","注意节奏","ペース注意","सावधान","تنبيه","Attention","Осторожно","Hati-hati","Achtung","Dikkat","주의"],
        "st_over": ["Overusing","Uso excesivo","使用过快","使いすぎ","अधिक उपयोग","إفراط","Surutilisation","Перерасход","Berlebihan","Zu viel","Aşırı kullanım","과다 사용"],
        "diff_over": ["%d%% over ideal","%d%% por encima","超出理想 %d%%","理想より +%d%% オーバー","आदर्श से %d%% ऊपर","%d%% فوق المثالي","%d%% au-dessus de l'idéal","На %d%% выше нормы","%d%% di atas ideal","%d%% über ideal","İdealin %d%% üstünde","이상보다 %d%% 초과"],
        "diff_under": ["%d%% under ideal","%d%% por debajo","低于理想 %d%%","理想より %d%% 余裕あり","आदर्श से %d%% नीचे","%d%% تحت المثالي","%d%% sous l'idéal","На %d%% ниже нормы","%d%% di bawah ideal","%d%% unter ideal","İdealin %d%% altında","이상보다 %d%% 여유"],
        "diff_on": ["Right on track","Justo en el ideal","正好达标","理想ぴったり","बिलकुल सही","تمامًا على المسار","Pile dans l'idéal","Точно в норме","Tepat sasaran","Genau im Soll","Tam hedefte","딱 적정"],
        "lbl_current": ["Current usage","Uso actual","当前用量","現在の消費量","वर्तमान उपयोग","الاستخدام الحالي","Utilisation actuelle","Текущий расход","Pemakaian saat ini","Aktuelle Nutzung","Mevcut kullanım","현재 사용량"],
        "lbl_ideal": ["Ideal pace","Ritmo ideal","理想节奏","理想ペース","आदर्श गति","الوتيرة المثالية","Rythme idéal","Идеальный темп","Tempo ideal","Ideales Tempo","İdeal tempo","이상 페이스"],
        "lbl_enter": ["Enter current usage","Introduce el uso actual","输入当前用量","現在の消費量を入力","वर्तमान उपयोग दर्ज करें","أدخل الاستخدام الحالي","Saisir l'utilisation actuelle","Введите текущий расход","Masukkan pemakaian saat ini","Aktuelle Nutzung eingeben","Mevcut kullanımı gir","현재 사용량 입력"],
        "close": ["Close","Cerrar","关闭","閉じる","बंद करें","إغلاق","Fermer","Закрыть","Tutup","Schließen","Kapat","닫기"],

        "resets_in": ["Resets in","Se reinicia en","重置剩余","リセットまで","रीसेट में","تُعاد خلال","Réinit. dans","Сброс через","Reset dalam","Reset in","Sıfırlama:","초기화까지"],
        "unit_day": ["d","d","天","日","दिन","ي","j","д","h","d","g","일"],
        "unit_hour": ["h","h","小时","時間","घं","س","h","ч","j","h","sa","시간"],
        "unit_min": ["m","min","分","分","मि","د","min","мин","mnt","min","dk","분"],
        "unit_sec": ["s","s","秒","秒","से","ث","s","с","dtk","s","sn","초"],

        "set_title": ["Customize","Personalizar","自定义","値のカスタマイズ","अनुकूलित करें","تخصيص","Personnaliser","Настройки","Sesuaikan","Anpassen","Özelleştir","커스터마이즈"],
        "set_resetStart": ["Weekly reset start","Inicio del reinicio semanal","每周重置起点","週のリセット起点","साप्ताहिक रीसेट समय","بداية إعادة التعيين الأسبوعية","Début de réinit. hebdo","Начало недельного сброса","Awal reset mingguan","Wöchentlicher Reset-Start","Haftalık sıfırlama başlangıcı","주간 초기화 시점"],
        "set_checkUsage": ["Check claude.ai/settings/usage or Claude Desktop settings","Consúltalo en claude.ai/settings/usage o ajustes de Claude Desktop","可在 claude.ai/settings/usage 或 Claude 桌面版设置中查看","claude.ai/settings/usage または Claudeデスクトップ設定で確認できます","claude.ai/settings/usage या Claude Desktop सेटिंग में देखें","تحقق في claude.ai/settings/usage أو إعدادات Claude Desktop","Voir claude.ai/settings/usage ou réglages Claude Desktop","См. claude.ai/settings/usage или настройки Claude Desktop","Cek claude.ai/settings/usage atau pengaturan Claude Desktop","Siehe claude.ai/settings/usage oder Claude-Desktop-Einstellungen","claude.ai/settings/usage veya Claude Desktop ayarlarına bak","claude.ai/settings/usage 또는 Claude 데스크톱 설정에서 확인"],
        "set_thresholds": ["Color thresholds (% vs ideal)","Umbrales de color (% vs ideal)","颜色阈值（与理想的差%）","色の境界（理想ペースとの差%）","रंग सीमाएँ (% बनाम आदर्श)","حدود الألوان (% مقابل المثالي)","Seuils de couleur (% vs idéal)","Пороги цвета (% от нормы)","Ambang warna (% vs ideal)","Farbschwellen (% vs Ideal)","Renk eşikleri (% ideale göre)","색상 경계(이상과의 차이 %)"],
        "set_colors": ["Colors","Colores","颜色","色のカスタマイズ","रंग","الألوان","Couleurs","Цвета","Warna","Farben","Renkler","색상"],
        "set_icons": ["Icons","Iconos","图标","アイコンのカスタマイズ","आइकन","الأيقونات","Icônes","Значки","Ikon","Symbole","Simgeler","아이콘"],
        "set_menubar": ["Menu bar tint","Color de la barra de menús","菜单栏着色","メニューバーの着色","मेन्यू बार रंग","تلوين شريط القوائم","Teinte barre de menus","Цвет в строке меню","Warna bilah menu","Menüleisten-Farbe","Menü çubuğu rengi","메뉴 막대 색상"],
        "set_menubarShow": ["Menu bar shows","La barra muestra","菜单栏显示","メニューバー表示","मेन्यू बार","يعرض الشريط","Barre affiche","В строке меню","Bilah menu","Menüleiste zeigt","Menü çubuğu","메뉴 막대 표시"],
        "mb_ideal": ["Ideal","Ideal","理想","理想","आदर्श","المثالي","Idéal","Норма","Ideal","Ideal","İdeal","이상"],
        "mb_current": ["Current","Actual","当前","現在","वर्तमान","الحالي","Actuel","Текущий","Saat ini","Aktuell","Mevcut","현재"],
        "reset": ["Reset","Restablecer","重置","リセット","रीसेट","إعادة","Réinit.","Сброс","Reset","Zurücksetzen","Sıfırla","초기화"],
        "reset_all": ["Reset everything","Restablecer todo","全部重置","全て初回状態に戻す","सब रीसेट करें","إعادة الكل","Tout réinitialiser","Сбросить всё","Reset semua","Alles zurücksetzen","Tümünü sıfırla","전체 초기화"],
        "done": ["Done","Hecho","完成","完了","हो गया","تم","Terminé","Готово","Selesai","Fertig","Tamam","완료"],
    ]
}
