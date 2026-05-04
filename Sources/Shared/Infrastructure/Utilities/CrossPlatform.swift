// CrossPlatform.swift
//
// 作者: Wang Chong
// 功能说明: 跨平台剪贴板包装器 (PM 视角：确保 Mac/iPad 核心交互一致性)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 跨平台剪贴板包装器 (PM 视角：确保 Mac/iPad 核心交互一致性)
enum WikiPasteboard {
    /// 获取或设置系统剪贴板文本
    static var string: String? {
        get {
            #if canImport(UIKit)
            return UIPasteboard.general.string
            #elseif canImport(AppKit)
            return NSPasteboard.general.string(forType: .string)
            #else
            return nil
            #endif
        }
        set {
            #if canImport(UIKit)
            UIPasteboard.general.string = newValue
            #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            if let s = newValue {
                NSPasteboard.general.setString(s, forType: .string)
            }
            #endif
        }
    }
}

/// 跨平台图片包装器
#if canImport(UIKit)
typealias WikiImage = UIImage
#elseif canImport(AppKit)
typealias WikiImage = NSImage
#endif

extension WikiImage {
    /// 统一转换为 CGImage 以供 Vision 等框架使用
    var wikiCGImage: CGImage? {
        #if canImport(UIKit)
        return self.cgImage
        #elseif canImport(AppKit)
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
}

