// Character+CJK.swift
//
// 作者: Wang Chong
// 功能说明: 判定是否为中日韩 (CJK) 字符 (Engineering Utility)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

extension Character {
    /// 判定是否为中日韩 (CJK) 字符 (Engineering Utility)
    var isCJKCharacter: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||  // CJK Unified Ideographs
            (0x3400...0x4DBF).contains(scalar.value) ||  // CJK Extension A
            (0x3000...0x303F).contains(scalar.value) ||  // CJK Symbols and Punctuation
            (0xFF00...0xFFEF).contains(scalar.value) ||  // Halfwidth and Fullwidth Forms
            (0x2E80...0x2EFF).contains(scalar.value) ||  // CJK Radicals Supplement
            (0x3040...0x309F).contains(scalar.value) ||  // Hiragana
            (0x30A0...0x30FF).contains(scalar.value) ||  // Katakana
            (0xAC00...0xD7AF).contains(scalar.value)     // Korean Syllables
        }
    }
}
