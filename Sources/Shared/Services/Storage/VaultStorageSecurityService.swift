// VaultStorageSecurityService.swift
//
// 作者: Wang Chong
// 功能说明: 金库安全服务 (QA & Security 视角：保护用户隐私)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import LocalAuthentication
import SwiftUI

/// 金库安全服务 (QA & Security 视角：保护用户隐私)
@MainActor
final class VaultStorageSecurityService: ObservableObject {
    @Published var isLocked = false
    @Published var biometricsAvailable = false
    
    private let context = LAContext()
    
    init() {
        checkBiometrics()
    }
    
    func checkBiometrics() {
        var error: NSError?
        biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// 执行生物识别认证，返回是否成功
    func authenticateWithBiometrics() async -> Bool {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: Localized.tr("security.unlockReason")) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    /// 执行生物识别解锁
    func unlock() {
        let reason = Localized.tr("security.unlockReason")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation { self.isLocked = false }
                    HapticManager.shared.trigger(.unlock)
                } else {
                    // 解锁失败逻辑
                    HapticManager.shared.trigger(.error)
                }
            }
        }
    }
    
    func lock() {
        withAnimation { isLocked = true }
        HapticManager.shared.trigger(.lock)
    }
}

extension VaultStorageSecurityService: @unchecked Sendable {}
