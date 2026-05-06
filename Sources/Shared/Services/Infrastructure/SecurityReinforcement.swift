// SecurityReinforcement.swift
//
// 作者: Wang Chong
// 功能说明: 日志脱敏层 (Security Item)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 日志脱敏层 (Security Item)
struct LogMasker {
    /// 脱敏 PII 信息（如 API Key, 用户邮箱等）
    static func mask(_ content: String) -> String {
        var masked = content
        // 匹配并隐藏 API Key 模式
        let apiKeyPattern = "sk-[a-zA-Z0-9]{32,}"
        if let regex = try? NSRegularExpression(pattern: apiKeyPattern) {
            let range = NSRange(location: 0, length: masked.utf16.count)
            masked = regex.stringByReplacingMatches(in: masked, options: [], range: range, withTemplate: "sk-****")
        }
        return masked
    }
}
