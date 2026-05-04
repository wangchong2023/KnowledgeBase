// SecurityManager.swift
//
// 作者: Wang Chong
// 功能说明: 安全管理器：负责数据签名、加密与完整性校验。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import CryptoKit

/// 安全管理器：负责数据签名、加密与完整性校验。
final class SecurityManager: Sendable {
    static let shared = SecurityManager()

    private let salt: String
    private let signatureKeyPrefix = "km.integrity.sig."

    init(salt: String = "KM-Integrity-Salt-2026") {
        self.salt = salt
    }

    /// 计算文件的 HMAC 签名
    func calculateHMAC(for fileURL: URL) throws -> String {
        let fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        guard let saltData = salt.data(using: .utf8) else {
            throw SecurityError.invalidSalt
        }
        let key = SymmetricKey(data: saltData)
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
            LogService.shared.addLog(action: .error, target: "SecurityManager", details: "Failed to update signature: \(error.localizedDescription)")
        }
    }
}

enum SecurityError: LocalizedError {
    case invalidSalt

    var errorDescription: String? {
        switch self {
        case .invalidSalt:
            return "Failed to derive key from salt: invalid encoding"
        }
    }
}
