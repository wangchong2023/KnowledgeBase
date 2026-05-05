// PromptWorkshopView.swift
//
// 作者: Wang Chong
// 功能说明: struct PromptWorkshopView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

struct PromptWorkshopView: View {
    @StateObject private var promptService = PromptService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isIntroExpanded = true
    @State private var isMindmapExpanded = false
    @State private var isQuizExpanded = false
    @State private var isSlidesExpanded = false
    @State private var isReportExpanded = false
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            // ── 认知补全：功能简介 (可收缩) ──
            Section {
                DisclosureGroup(isExpanded: $isIntroExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Localized.tr("prompt.workshop.intro.desc"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                            .lineSpacing(4)
                            .padding(.top, 4)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "flask.fill")
                            .font(.title3)
                            .foregroundStyle(.wikiAccent)
                        Text(Localized.tr("prompt.workshop.intro.title"))
                            .font(.headline)
                    }
                }
            }
            .listRowBackground(Color.wikiAccent.opacity(0.05))

            // ── 模块 1：我的快捷指令 (默认展开) ──
            Section {
                ForEach($promptService.userShortcuts) { $item in
                    HStack {
                        TextField(Localized.tr("prompt.workshop.input.placeholder"), text: $item.text)
                            .font(.subheadline)
                        
                        if promptService.userShortcuts.count > 1 {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.wikiSecondary.opacity(0.5))
                        }
                    }
                }
                .onDelete { indices in
                    promptService.userShortcuts.remove(atOffsets: indices)
                }
                .onMove { from, to in
                    promptService.userShortcuts.move(fromOffsets: from, toOffset: to)
                }
                
                Button(action: { 
                    promptService.userShortcuts.append(ShortcutItem(text: Localized.tr("prompt.workshop.add")))
                }) {
                    Label(Localized.tr("prompt.workshop.add"), systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.wikiAccent)
                }
            } header: {
                Label(Localized.tr("prompt.workshop.shortcuts.title"), systemImage: "pin.fill")
            } footer: {
                Text(Localized.tr("prompt.workshop.shortcuts.footer"))
            }

            
            Section {
                Button(role: .destructive, action: { showResetAlert = true }) {
                    HStack {
                        Spacer()
                        Text(Localized.tr("prompt.reset.factory"))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(Localized.tr("prompt.factory.title"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onDisappear {
            promptService.save()
            HapticFeedback.shared.trigger(.success)
        }
        .alert(Localized.tr("prompt.resetConfirm"), isPresented: $showResetAlert) {
            Button(L10n.Common.tr("reset"), role: .destructive) {
                promptService.reset()
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("prompt.resetWarning"))
        }
    }
}
