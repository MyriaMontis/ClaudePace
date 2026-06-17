import Foundation

/// 利用ペースの計算ロジックをまとめた構造体。
/// ・リセット起点: 曜日・時・分を指定可能（既定: 日曜 0:00 JST）
/// ・1週間の総時間: 168時間
enum PaceCalculator {

    /// 1週間の総時間
    static let totalHours: Double = 168

    /// リセット起点のデフォルト（1=日曜 ... 7=土曜 / 時 / 分）
    static let defaultWeekday = 1
    static let defaultHour = 0
    static let defaultMinute = 0

    /// JST固定のカレンダー（日曜始まり）
    private static var jstCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        cal.firstWeekday = 1
        return cal
    }

    /// 直近のリセット時刻を返す。
    static func lastReset(weekday: Int = defaultWeekday,
                          hour: Int = defaultHour,
                          minute: Int = defaultMinute,
                          from now: Date = Date()) -> Date {
        let cal = jstCalendar
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = weekday
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        guard let candidate = cal.date(from: comps) else { return now }
        if candidate > now {
            return cal.date(byAdding: .weekOfYear, value: -1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func elapsedHours(weekday: Int = defaultWeekday,
                             hour: Int = defaultHour,
                             minute: Int = defaultMinute,
                             from now: Date = Date()) -> Double {
        now.timeIntervalSince(lastReset(weekday: weekday, hour: hour, minute: minute, from: now)) / 3600
    }

    static func idealPercent(weekday: Int = defaultWeekday,
                             hour: Int = defaultHour,
                             minute: Int = defaultMinute,
                             from now: Date = Date()) -> Double {
        let p = elapsedHours(weekday: weekday, hour: hour, minute: minute, from: now) / totalHours * 100
        return min(max(p, 0), 100)
    }

    static func hoursUntilReset(weekday: Int = defaultWeekday,
                                hour: Int = defaultHour,
                                minute: Int = defaultMinute,
                                from now: Date = Date()) -> Double {
        max(totalHours - elapsedHours(weekday: weekday, hour: hour, minute: minute, from: now), 0)
    }
}
