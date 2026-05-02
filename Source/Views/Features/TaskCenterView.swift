import SwiftUI

/// 任务中心视图
/// 展示当前正在运行及最近完成的任务列表（含 AI 任务与导入任务）。
struct TaskCenterView: View {
    @ObservedObject var taskCenter = TaskCenter.shared
    @EnvironmentObject var store: KMStore
    
    var body: some View {
        List {
            if taskCenter.tasks.isEmpty {
                emptyState
            } else {
                ForEach(taskCenter.tasks) { task in
                    TaskRow(task: task)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            taskCenter.markAsRead(task.id)
                            if let pageID = task.associatedPageID {
                                store.selectedPageID = pageID
                                store.selectedTool = nil
                            }
                        }
                }
                .onDelete { indices in
                    indices.forEach { index in
                        taskCenter.removeTask(taskCenter.tasks[index].id)
                    }
                }
            }
        }
        .navigationTitle(Localized.tr("aitask.center.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !taskCenter.tasks.isEmpty {
                    Button(Localized.tr("aitask.clearAll")) {
                        taskCenter.tasks.removeAll()
                    }
                }
            }
        }
        .background(Color.wikiBackground)
        .onAppear {
            taskCenter.markAllAsRead()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.wikiAccent.opacity(0.6), .wikiAccent.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 8) {
                Text(Localized.tr("aitask.empty.title"))
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                
                Text(Localized.tr("aitask.empty.desc"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .listRowBackground(Color.clear)
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
                Text(task.startTime.formatted(.dateTime.hour().minute().second()))
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
            Text(Localized.tr("aitask.status.pending"))
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        case .running(let progress):
            HStack(spacing: 4) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 40)
                Text(Localized.tr("aitask.status.running"))
                    .font(.caption2)
                    .foregroundStyle(.wikiAccent)
            }
        case .completed:
            Text(Localized.tr("aitask.status.completed"))
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed(let error):
            Text(Localized.tr("aitask.status.failed"))
                .font(.caption2)
                .foregroundStyle(.red)
                .help(error)
        }
    }
}
