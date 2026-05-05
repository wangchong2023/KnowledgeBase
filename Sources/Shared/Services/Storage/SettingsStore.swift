// SettingsStore.swift
//
// 作者: Wang Chong
// 功能说明: 全局设置存储，管理隐私模式、安全验证及显示偏好。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.
import SwiftUI
import Observation
import Combine

/// 全局设置存储，管理隐私模式、安全验证及显示偏好。
@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init() {
        WikiEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.reset()
                }
            }
            .store(in: &cancellables)
    }
    // ── 隐私与安全 ──
    @ObservationIgnored private var _isPrivacyModeEnabled: Bool = UserDefaults.standard.object(forKey: "isPrivacyModeEnabled") as? Bool ?? true
    var isPrivacyModeEnabled: Bool {
        get {
            access(keyPath: \.isPrivacyModeEnabled)
            return _isPrivacyModeEnabled
        }
        set {
            withMutation(keyPath: \.isPrivacyModeEnabled) {
                _isPrivacyModeEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: "isPrivacyModeEnabled")
            }
        }
    }
    
    @ObservationIgnored private var _isBiometricEnabled: Bool = UserDefaults.standard.object(forKey: "isBiometricEnabled") as? Bool ?? true
    var isBiometricEnabled: Bool {
        get {
            access(keyPath: \.isBiometricEnabled)
            return _isBiometricEnabled
        }
        set {
            withMutation(keyPath: \.isBiometricEnabled) {
                _isBiometricEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: "isBiometricEnabled")
            }
        }
    }
    
    // ── 性能与调试 ──
    var showPerfDashboard = false
    
    // ── 引导状态 ──
    var hasShownGraphCoachMark: Bool {
        get { UserDefaults.standard.bool(forKey: "hasShownGraphCoachMark") }
        set { UserDefaults.standard.set(newValue, forKey: "hasShownGraphCoachMark") }
    }

    // ── iCloud 同步偏好 ──
    var iCloudConflictResolution: String {
        get { UserDefaults.standard.string(forKey: "knowledge-management_conflict_resolution") ?? "merge" }
        set { UserDefaults.standard.set(newValue, forKey: "knowledge-management_conflict_resolution") }
    }

    var iCloudAutoSync: Bool {
        get { UserDefaults.standard.bool(forKey: "knowledge-management_auto_sync") }
        set { UserDefaults.standard.set(newValue, forKey: "knowledge-management_auto_sync") }
    }

    // ── 协作用户名 ──
    var collabUsername: String {
        get { UserDefaults.standard.string(forKey: "knowledge-management_username") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "knowledge-management_username") }
    }
    
    func reset() {
        isPrivacyModeEnabled = true
        isBiometricEnabled = true
        showPerfDashboard = false
        hasShownGraphCoachMark = false
        UserDefaults.standard.removeObject(forKey: "knowledge-management_conflict_resolution")
        UserDefaults.standard.removeObject(forKey: "knowledge-management_auto_sync")
        UserDefaults.standard.removeObject(forKey: "knowledge-management_username")
    }
}
