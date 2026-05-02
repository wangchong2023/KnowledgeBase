import SwiftUI

/// PDF 导出报告视图 (UI Designer 视角：精致的排版与品牌化呈现)
struct ExportReportView: View {
    let pages: [WikiPage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 页眉：品牌标识
            HStack {
                Text(Localized.tr("report.appName"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.wikiAccent)
                Spacer()
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            .padding(.bottom, 20)
            
            Divider()
            
            // 报告标题
            Text(Localized.tr("report.title"))
                .font(.system(size: 32, weight: .black))
                .padding(.vertical, 10)
            
            Text(Localized.trf("report.nodeCount", pages.count))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
            
            // 内容详情
            ForEach(pages.prefix(10)) { page in // 示例仅导出前 10 页以防 PDF 过大
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: page.type.icon)
                            .foregroundStyle(page.type.themedColor)
                        Text(page.title)
                            .font(.headline)
                    }
                    
                    Text(page.content.prefix(300) + "...")
                        .font(.system(size: 12))
                        .foregroundStyle(.wikiText)
                        .lineLimit(5)
                        .padding(.leading, 24)
                    
                    if !page.tags.isEmpty {
                        HStack {
                            ForEach(page.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.wikiAccent.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.leading, 24)
                    }
                }
                .padding(.vertical, 10)
            }
            
            Spacer()
            
            // 页脚
            Divider()
            Text(Localized.tr("report.footer"))
                .font(.caption2)
                .foregroundStyle(.wikiBorder)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(40)
        .frame(width: 595, height: 842) // A4 纸张尺寸 (72 DPI)
        .background(Color.white)
    }
}
