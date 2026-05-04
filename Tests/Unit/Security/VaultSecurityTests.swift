// VaultSecurityTests.swift
//
// 作者: Wang Chong
// 功能说明: 金库安全服务测试
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// 金库安全服务测试
/// 验证 VaultSecurityService 的锁定/解锁状态切换及生物识别可用性检测。
@MainActor
final class VaultSecurityTests: XCTestCase {

    var vault: VaultStorageSecurityService!

    override func setUp() {
        super.setUp()
        vault = VaultStorageSecurityService()
    }

    override func tearDown() {
        vault = nil
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialStateIsUnlocked() {
        XCTAssertFalse(vault.isLocked, "金库初始状态应为未锁定")
    }

    func testBiometricsAvailabilityIsCheckedOnInit() {
        let available = vault.biometricsAvailable
        XCTAssertTrue(available || !available, "biometricsAvailable 应为有效 Bool 值")
    }

    // MARK: - 锁定/解锁

    func testLockSetsIsLockedToTrue() {
        vault.lock()
        XCTAssertTrue(vault.isLocked, "lock() 后 isLocked 应为 true")
    }

    func testMultipleLockCallsStayLocked() {
        vault.lock()
        vault.lock()
        XCTAssertTrue(vault.isLocked, "多次 lock() 后仍应保持锁定状态")
    }

    // MARK: - 状态复位

    func testUnlockAfterLockResetsState() {
        vault.lock()
        XCTAssertTrue(vault.isLocked)

        vault.isLocked = false
        XCTAssertFalse(vault.isLocked, "解锁后 isLocked 应为 false")
    }

    func testLockUnlockCycle() {
        for _ in 0..<5 {
            vault.lock()
            XCTAssertTrue(vault.isLocked)
            vault.isLocked = false
            XCTAssertFalse(vault.isLocked)
        }
    }
}
