// TaskCenterView.swift
//
// 作者: Wang Chong
// 功能说明: 任务中心视图
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 任务中心视图
/// 展示当前正在运行及最近完成的任务列表（含 AI 任务与导入任务）。
struct TaskCenterView: View {
    @ObservedObject var taskCenter = TaskCenter.shared
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    
    var body: some View {
        ZStack {
            Color.wikiBackground.ignoresSafeArea()
            
            if taskCenter.tasks.isEmpty {
                ScrollView {
                    VStack(spacing: 20) {
                        statusDashboard
                        emptyState
                            .padding(.top, 20)
                    }
                }
            } else {
                List {
                    Section {
                        statusDashboard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                    } header: {
                        Text(L10n.AI.Task.tr("categories"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.wikiText)
                    }
                    
                    Section {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            let metrics = taskCenter.metrics(for: type)
                            let tasks = taskCenter.tasks.filter { $0.type == type }
                            
                            DisclosureGroup {
                            if tasks.isEmpty {
                                Text(L10n.AI.Task.tr("noHistory"))
                                    .font(.caption)
                                        .foregroundStyle(.wikiSecondary)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(tasks.sorted(by: { $0.startTime > $1.startTime })) { task in
                                        TaskRow(task: task)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                taskCenter.markAsRead(task.id)
                                                if let pageID = task.associatedPageID {
                                                    router.navigateToPage(id: pageID)
                                                }
                                            }
                                    }
                                    .onDelete { indices in
                                        let sortedTasks = tasks.sorted(by: { $0.startTime > $1.startTime })
                                        indices.forEach { index in
                                            taskCenter.removeTask(sortedTasks[index].id)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(taskColor(for: type).opacity(0.1))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: type.icon)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(taskColor(for: type))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L10n.AI.Task.tr("type.\(type.rawValue)"))
                                            .font(.subheadline.bold())
                                        Text(L10n.AI.Task.trf("history.count", metrics.total))
                                            .font(.caption2)
                                            .foregroundStyle(.wikiSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if metrics.running > 0 {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("\(metrics.running)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(taskColor(for: type))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(taskColor(for: type).opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text(L10n.AI.Task.tr("list.title"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.wikiText)
                            .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
            }
            }
        .navigationTitle(L10n.AI.Task.centerTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .background(Color.wikiBackground)
        .onAppear {
            taskCenter.markAllAsRead()
        }
    }
    
    // MARK: - Status Dashboard
    private var statusDashboard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            summaryCard(type: .ingest, color: .blue)
            summaryCard(type: .healthCheck, color: .red)
            summaryCard(type: .aiScan, color: .orange)
            summaryCard(type: .synthesis, color: .purple)
        }
        .padding(.horizontal, 20)
    }
    
    private func taskColor(for type: TaskType) -> Color {
        type.uiColor
    }
    
    private func summaryCard(type: TaskType, color: Color) -> some View {
        let metrics = taskCenter.metrics(for: type)
        let runningCount = metrics.running
        
        return VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                
                if runningCount > 0 {
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(color, lineWidth: 2)
                        .frame(width: 42, height: 42)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            VStack(spacing: 4) {
                Text(L10n.AI.Task.tr("type.\(type.rawValue)"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.wikiSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(metrics.completed)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.wikiText)
                    Text("/ \(metrics.total)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.wikiSecondary.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(runningCount > 0 ? color.opacity(0.3) : Color.wikiBorder.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.wikiAccent.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "tray.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.wikiAccent.opacity(0.8), .wikiAccent.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: 4)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(.purple)
                    .offset(x: 35, y: -35)
            }
            
            VStack(spacing: 12) {
                Text(L10n.AI.Task.emptyTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.wikiText)
                
                Text(L10n.AI.Task.emptyDesc)
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.AI.Task.tr("howToTrigger"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.wikiSecondary)
                    .padding(.bottom, 4)
                
                guideRow(icon: "stethoscope", color: .red, title: L10n.AI.Task.tr("guide.health"), desc: L10n.AI.Task.tr("guide.health.desc"))
                guideRow(icon: "bolt.shield.fill", color: .orange, title: L10n.AI.Task.tr("guide.aiscan"), desc: L10n.AI.Task.tr("guide.aiscan.desc"))
                guideRow(icon: "tray.and.arrow.down.fill", color: .blue, title: L10n.AI.Task.tr("guide.ingest"), desc: L10n.AI.Task.tr("guide.ingest.desc"))
                guideRow(icon: "wand.and.stars", color: .purple, title: L10n.AI.Task.tr("guide.synthesis"), desc: L10n.AI.Task.tr("guide.synthesis.desc"))
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
    
    private func guideRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            Spacer()
        }
    }
}

private struct TaskRow: View {
    let task: GlobalTask
    
    var body: some View {
        HStack(spacing: 16) {
            // 类型图标与状态
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(task.type == .ai ? Color.purple.opacity(0.1) : Color.wikiAccent.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: task.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(task.type == .ai ? .purple : .wikiAccent)
                    .frame(width: 44, height: 44)
                
                if !task.isRead && (task.status == .completed || isFailed) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.wikiCard, lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.name)
                        .font(.subheadline.bold())
                    if task.associatedPageID != nil {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                            .foregroundStyle(.wikiAccent)
                    }
                }
                
                Text(task.target)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                statusText
                Text(task.startTime.formatted(.dateTime.year().month().day().hour().minute().second()))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.wikiSecondary.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
        .opacity(task.isRead ? 0.8 : 1.0)
    }
    
    private var isFailed: Bool {
        if case .failed = task.status { return true }
        return false
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch task.status {
        case .pending:
            Text(L10n.AI.Task.tr("status.pending"))
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        case .running(let progress):
            HStack(spacing: 4) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 40)
                Text(L10n.AI.Task.tr("status.running"))
                    .font(.caption2)
                    .foregroundStyle(.wikiAccent)
            }
        case .completed:
            Text(L10n.AI.Task.tr("status.completed"))
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed(let error):
            Text(L10n.AI.Task.tr("status.failed"))
                .font(.caption2)
                .foregroundStyle(.red)
                .help(error)
        }
    }
}
// MARK: - UI Extensions
extension TaskType {
    var uiColor: Color {
        switch self.defaultColor {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        default: return .wikiAccent
        }
    }
}
