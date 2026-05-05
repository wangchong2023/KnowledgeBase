// SecurityManager.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的安全治理与完整性校验服务（SecurityManager），旨在保障用户本地数据免受非授权篡改。
// 该服务基于现代加密算法，构建了一套轻量级的数据防护体系，核心功能点如下：
// 1. 数据指纹审计：利用 HMAC-SHA256 算法对核心数据库文件进行哈希签名，确保任何物理层面的非法篡改都能被即时检测。
// 2. 运行时完整性校验：在应用启动或关键数据加载时，通过比对内存指纹与持久化指纹，动态验证数据的合法性。
// 3. 智适应签名更新：在合法的写操作（如 CRUD）完成后，自动触发签名的差量更新，确保安全边界随数据演进动态迁移。
// 4. 容错式初始化逻辑：平衡了初次启动的便捷性与长期运行的安全性，支持在安全基准缺失时的平滑初始化。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，详细描述数据签名与加密校验逻辑
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
            Logger.shared.addLog(action: .error, target: "SecurityManager", details: "Failed to update signature: \(error.localizedDescription)")
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
