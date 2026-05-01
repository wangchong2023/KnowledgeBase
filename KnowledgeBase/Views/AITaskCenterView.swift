import SwiftUI

struct AITaskCenterView: View {
    @ObservedObject var taskCenter = AITaskCenter.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if taskCenter.tasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(.wikiSecondary)
                        Text("暂无运行中的任务")
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(taskCenter.tasks) { task in
                        TaskRow(task: task)
                    }
                    .onDelete { indices in
                        indices.forEach { index in
                            taskCenter.removeTask(taskCenter.tasks[index].id)
                        }
                    }
                }
            }
            .navigationTitle("AI 任务中控")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !taskCenter.tasks.isEmpty {
                        Button("全部清除") {
                            taskCenter.tasks.removeAll()
                        }
                    }
                }
            }
            .background(Color.wikiBackground)
        }
    }
}

private struct TaskRow: View {
    let task: AITask
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.wikiBorder, lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                statusIcon
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline.bold())
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
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .pending:
            Image(systemName: "hourglass")
                .foregroundStyle(.wikiSecondary)
        case .running(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .tint(.wikiAccent)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch task.status {
        case .pending:
            Text("等待中")
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        case .running:
            Text("处理中...")
                .font(.caption2)
                .foregroundStyle(.wikiAccent)
        case .completed:
            Text("已完成")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed(let error):
            Text("失败")
                .font(.caption2)
                .foregroundStyle(.red)
                .help(error)
        }
    }
}
