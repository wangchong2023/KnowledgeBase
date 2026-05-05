// WatchDictationView.swift
//
// 作者: Wang Chong
// 功能说明: 手表端语音采集视图
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - 手表端语音采集
/// Apple Watch 语音笔记采集视图
/// 负责在手表端通过系统语音输入获取文本，并通过 WatchConnectivity 实时同步至主应用
struct WatchDictationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KMStore.self) var store
    @State private var text = ""
    
    var body: some View {
        VStack {
            TextField(L10n.Watch.tr("dictate.hint"), text: $text)
                .padding()
            
            Spacer()
            
            HStack {
                Button(L10n.Common.tr("cancel")) { dismiss() }
                    .tint(.red)
                
                Button(L10n.Common.tr("save")) {
                    saveAndSync()
                }
                .tint(.green)
                .disabled(text.isEmpty)
            }
        }
        .navigationTitle(L10n.Watch.tr("capture"))
    }
    
    private func saveAndSync() {
        let newPage = WikiPage(title: "Dictation \(Date().formatted())", content: text)
        store.addPage(newPage)
        
        // 增强：通过 WCSession 实时推送到 iPhone
        WatchConnectivityService.shared.sendContent(text)
        
        // 触发手表端震动反馈
        WKInterfaceDevice.current().play(.success)
        
        dismiss()
    }
}
