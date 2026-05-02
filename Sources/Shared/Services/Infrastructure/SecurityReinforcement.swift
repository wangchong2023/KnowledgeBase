import Foundation
import SQLite3

/// 数据库迁移管理器 (Reliability Item)
/// 负责处理 SQLite 架构的版本化升级。
final class DatabaseMigrationManager {
    static let shared = DatabaseMigrationManager()
    private let currentSchemaVersion = 2 // 当前代码预期的架构版本
    
    func migrate(db: OpaquePointer?) {
        let userVersion = getVersion(db: db)
        LogService.shared.debug("🗄️ [Migration] 当前数据库版本：\(userVersion)，目标版本：\(currentSchemaVersion)")
        
        if userVersion < 1 {
            // 执行初始建表逻辑（省略）
            setVersion(1, db: db)
        }
        
        if userVersion < 2 {
            // 版本 2 升级示例：增加页面可信度字段
            execute(sql: "ALTER TABLE wiki_pages ADD COLUMN confidence FLOAT DEFAULT 1.0;", db: db)
            setVersion(2, db: db)
        }
    }
    
    private func getVersion(db: OpaquePointer?) -> Int {
        var version: Int = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return version
    }
    
    private func setVersion(_ version: Int, db: OpaquePointer?) {
        execute(sql: "PRAGMA user_version = \(version);", db: db)
    }
    
    private func execute(sql: String, db: OpaquePointer?) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}

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
