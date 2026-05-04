import SwiftUI

extension Color {
    /// 将模型层的 colorName 字符串转换为 SwiftUI Color。
    /// 标准颜色直接映射到系统颜色，wiki* 前缀映射到主题颜色。
    static func fromModelColorName(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "pink": return .pink
        case "gray": return .gray
        case "wikiSource": return .wikiSource
        case "wikiAccent": return .wikiAccent
        case "wikiSecondary": return .wikiSecondary
        default: return .gray
        }
    }
}
