// AsyncStatus.swift
//
// 作者: Wang Chong
// 功能说明: 统一管理异步任务的状态枚举
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 统一管理异步任务的状态枚举
enum AsyncStatus<T>: Equatable where T: Equatable {
    case idle
    case loading(String) // 带有描述信息的加载中
    case success(T)
    case failure(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
