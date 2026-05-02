import Foundation
import LocalAuthentication
import SwiftUI

/// 金库安全服务 (QA & Security 视角：保护用户隐私)
final class VaultSecurityService: ObservableObject {
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
    
    /// 执行生物识别解锁
    func unlock() {
        let reason = "解锁您的知识金库"
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
