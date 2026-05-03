import SwiftUI

/// 任务中心视图
/// 展示当前正在运行及最近完成的任务列表（含 AI 任务与导入任务）。
struct TaskCenterView: View {
    @ObservedObject var taskCenter = TaskCenter.shared
    @Environment(KMStore.self) var store
    
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
                            Text(Localized.tr("aitask.categories"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.wikiText)
                                .textCase(nil)
                        }
                        
                        Section {
                            ForEach(TaskType.allCases, id: \.self) { type in
                                let tasks = taskCenter.tasks.filter { $0.type == type }
                                let runningCount = tasks.filter { if case .running = $0.status { return true }; return false }.count
                                
                                DisclosureGroup {
                                    if tasks.isEmpty {
                                        Text(Localized.tr("aitask.noHistory"))
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
                                                        store.selectedPageID = pageID
                                                        store.selectedTool = nil
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
                                            Text(Localized.tr("aitask.type.\(type.rawValue)"))
                                                .font(.subheadline.bold())
                                            Text(Localized.trf("aitask.history.count", tasks.count))
                                                .font(.caption2)
                                                .foregroundStyle(.wikiSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if runningCount > 0 {
                                            HStack(spacing: 4) {
                                                ProgressView()
                                                    .controlSize(.small)
                                                Text("\(runningCount)")
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
                            Text(Localized.tr("aitask.list.title"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.wikiText)
                                .textCase(nil)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        .navigationTitle(Localized.tr("aitask.center.title"))
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
        switch type {
        case .ingest: return .blue
        case .healthCheck: return .red
        case .aiScan, .ai: return .orange
        case .synthesis: return .purple
        }
    }
    
    private func summaryCard(type: TaskType, color: Color) -> some View {
        let relevantTasks = taskCenter.tasks.filter { $0.type == type }
        let runningCount = relevantTasks.filter {
            if case .running = $0.status { return true }
            return false
        }.count
        let totalCount = relevantTasks.count
        let completedCount = relevantTasks.filter { $0.status == .completed }.count
        
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
                Text(Localized.tr("aitask.type.\(type.rawValue)"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.wikiSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(completedCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.wikiText)
                    Text("/ \(totalCount)")
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
                guideRow(icon: "bolt.shield.fill", color: .orange, title: Localized.tr("aitask.guide.aiscan"), desc: Localized.tr("aitask.guide.aiscan.desc"))
                guideRow(icon: "tray.and.arrow.down.fill", color: .blue, title: Localized.tr("aitask.guide.ingest"), desc: Localized.tr("aitask.guide.ingest.desc"))
                guideRow(icon: "wand.and.stars", color: .purple, title: Localized.tr("aitask.guide.synthesis"), desc: Localized.tr("aitask.guide.synthesis.desc"))
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
