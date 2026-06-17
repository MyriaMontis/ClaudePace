import SwiftUI

/// ペースの段階
enum PaceLevel: String {
    case safe   // 余裕あり
    case good   // 良いペース
    case warn   // ペース注意
    case over   // 使いすぎ
}

/// 「理想ペース」と「現在の消費量」の差分から状態(level)を判定する。
/// タイトル・アイコン・色は ContentView 側で言語・カスタム設定に応じて解決する。
struct PaceStatus {

    let level: PaceLevel

    /// しきい値のデフォルト値（理想ペースとの差%）
    static let defaultLow: Double  = -5   // 🔵余裕あり ↔ 🟢良いペース
    static let defaultMid: Double  = 3    // 🟢良いペース ↔ 🟠ペース注意
    static let defaultHigh: Double = 8    // 🟠ペース注意 ↔ 🔴使いすぎ

    /// 既定色（16進）
    static let defaultColorSafe = "#007AFF"
    static let defaultColorGood = "#34C759"
    static let defaultColorWarn = "#FF9500"
    static let defaultColorOver = "#FF3B30"

    /// diff = 現在の消費量 - 理想ペース
    static func evaluate(current: Double,
                         ideal: Double,
                         low: Double = defaultLow,
                         mid: Double = defaultMid,
                         high: Double = defaultHigh) -> PaceStatus {
        let diff = current - ideal
        if diff < low {
            return PaceStatus(level: .safe)
        } else if diff <= mid {
            return PaceStatus(level: .good)
        } else if diff <= high {
            return PaceStatus(level: .warn)
        } else {
            return PaceStatus(level: .over)
        }
    }
}
