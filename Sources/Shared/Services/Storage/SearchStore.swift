// SearchStore.swift
//
// 作者: Wang Chong
// 功能说明: 搜索状态存储，负责处理搜索过滤、防抖及结果缓存。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Observation
import Combine

/// 搜索状态存储，负责处理搜索过滤、防抖及结果缓存。
@MainActor
@Observable
final class SearchStore {
    var searchText: String = "" {
        didSet { performDebouncedSearch(query: searchText) }
    }
    var searchResults: [WikiPage] = []
    var isSearching = false
    var lastSearchDiagnostic: SearchDiagnosticInfo?
    var isAdvancedSearching = false
    
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored @Inject private var linkService: LinkService
    @ObservationIgnored @Inject private var sqliteStore: SQLiteStore
    
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init() {
        WikiEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.clearAll()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 执行高级（混合）搜索
    func performAdvancedSearch(query: String) async -> [WikiPage] {
        isSearching = true
        defer { isSearching = false }
        
        let res = await linkService.hybridSearchWithDiagnostics(
            query: query,
            in: sqliteStore.pages,
            embeddingManager: sqliteStore.embeddingManager
        )
        
        lastSearchDiagnostic = res.diagnostic
        searchResults = res.results
        return res.results
    }
    
    private func performDebouncedSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        searchTask = Task {
            isSearching = true
            // 300ms 防抖
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            
            let res = await linkService.hybridSearchWithDiagnostics(
                query: query,
                in: sqliteStore.pages,
                embeddingManager: sqliteStore.embeddingManager
            )
            
            if !Task.isCancelled {
                searchResults = res.results
                lastSearchDiagnostic = res.diagnostic
                isSearching = false
            }
        }
    }
    
    func clearAll() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        lastSearchDiagnostic = nil
        isAdvancedSearching = false
    }
}
