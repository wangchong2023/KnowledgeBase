import SwiftUI

/// 任务中心视图
/// 展示当前正在运行及最近完成的任务列表（含 AI 任务与导入任务）。
struct TaskCenterView: View {
    @ObservedObject var taskCenter = TaskCenter.shared
    @Environment(KMStore.self) var store
    
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
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if !taskCenter.tasks.isEmpty {
                    Button(Localized.tr("aitask.clearAll")) {
                        taskCenter.tasks.removeAll()
                    }
                }
            }
        }
#else
        .toolbar {
            ToolbarItem {
                if !taskCenter.tasks.isEmpty {
                    Button(Localized.tr("aitask.clearAll")) {
                        taskCenter.tasks.removeAll()
                    }
                }
            }
        }
#endif
        .background(Color.wikiBackground)
        .onAppear {
            taskCenter.markAllAsRead()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 32) {
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
                Text(Localized.tr("aitask.empty.title"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.wikiText)
                
                Text(Localized.tr("aitask.empty.desc"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text(Localized.tr("aitask.howToTrigger"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.wikiSecondary)
                    .padding(.bottom, 4)
                
                guideRow(icon: "stethoscope", color: .red, title: Localized.tr("aitask.guide.health"), desc: Localized.tr("aitask.guide.health.desc"))
                guideRow(icon: "arrow.down.doc.fill", color: .blue, title: Localized.tr("aitask.guide.ingest"), desc: Localized.tr("aitask.guide.ingest.desc"))
                guideRow(icon: "wand.and.stars", color: .purple, title: Localized.tr("aitask.guide.archive"), desc: Localized.tr("aitask.guide.archive.desc"))
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
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
