import Foundation
import CryptoKit

/// 安全管理器：负责数据签名、加密与完整性校验。
final class SecurityManager: Sendable {
    static let shared = SecurityManager()
    
    // 在实际生产中，应从 Secure Enclave 获取或派生
    private let salt = "KM-Integrity-Salt-2026"
    private let signatureKeyPrefix = "km.integrity.sig."
    
    /// 计算文件的 HMAC 签名
    func calculateHMAC(for fileURL: URL) throws -> String {
        let fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let key = SymmetricKey(data: salt.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: fileData, using: key)
        return Data(signature).base64EncodedString()
    }
    
    /// 保存签名到 UserDefaults (或 Keychain)
    func saveSignature(_ signature: String, forFileName fileName: String) {
        UserDefaults.standard.set(signature, forKey: signatureKeyPrefix + fileName)
    }
    
    /// 验证文件完整性
    func verifyIntegrity(for fileURL: URL) -> Bool {
        let fileName = fileURL.lastPathComponent
        guard let storedSig = UserDefaults.standard.string(forKey: signatureKeyPrefix + fileName) else {
            // 如果没有存储签名，可能是第一次运行，允许通过并初始化签名
            return true 
        }
        
        do {
            let currentSig = try calculateHMAC(for: fileURL)
            return currentSig == storedSig
        } catch {
            return false
        }
    }
    
    /// 更新签名
    func updateSignature(for fileURL: URL) {
        do {
            let sig = try calculateHMAC(for: fileURL)
            saveSignature(sig, forFileName: fileURL.lastPathComponent)
        } catch {
            print("Failed to update signature: \(error)")
        }
    }
}
