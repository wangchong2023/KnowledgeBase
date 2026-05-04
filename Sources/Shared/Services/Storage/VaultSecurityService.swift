import Foundation
import LocalAuthentication
import Combine

/// 金库安全服务 (QA & Security 视角：保护用户隐私)
@MainActor
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
        let reason = Localized.tr("security.unlockReason")
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isLocked = false
                    HapticManager.shared.trigger(.unlock)
                } else {
                    // 解锁失败逻辑
                    HapticManager.shared.trigger(.error)
                }
            }
        }
    }
    
    func lock() {
        isLocked = true
        HapticManager.shared.trigger(.lock)
    }
}

extension VaultSecurityService: @unchecked Sendable {}
