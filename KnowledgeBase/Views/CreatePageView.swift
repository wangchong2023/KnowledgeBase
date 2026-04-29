import SwiftUI

struct CreatePageView: View {
    @EnvironmentObject var store: KMStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var type: PageType = .concept
    @State private var tags = ""
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("页面标题", text: $title)
                        .font(.body)
                        .accessibilityIdentifier("页面标题")
                    
                    // Type picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PageType.allCases) { pageType in
                                Button(action: { type = pageType }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: pageType.icon)
                                            .font(.caption)
                                        Text(pageType.displayName)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(type == pageType ? pageType.themedColor.opacity(0.25) : Color.wikiCard)
                                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                                    .foregroundStyle(type == pageType ? pageType.themedColor : .wikiSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                                            .stroke(type == pageType ? pageType.themedColor.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    TextField("标签（逗号分隔）", text: $tags)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                } header: {
                    HStack {
                        Text("内容")
                        Spacer()
                        Text("支持 [[双向链接]] 语法")
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                
                // Quick templates
                Section {
                    Button(action: applyEntityTemplate) {
                        Label("实体模板", systemImage: "person.text.rectangle.fill")
                    }
                    Button(action: applyConceptTemplate) {
                        Label("概念模板", systemImage: "lightbulb.fill")
                    }
                    Button(action: applyComparisonTemplate) {
                        Label("对比模板", systemImage: "arrow.left.arrow.right.circle.fill")
                    }
                } header: {
                    Text("快速模板")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle("创建页面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        createPage()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func createPage() {
        let tagList = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let page = store.createPage(
            title: title,
            type: type,
            content: content,
            tags: tagList
        )
        
        store.selectedPageID = page.id
        dismiss()
    }
    
    private func applyEntityTemplate() {
        content = """
        # \(title)
        
        ## 概述
        
        ## 核心贡献
        
        ## 关键理念
        
        ## 相关链接
        
        """
    }
    
    private func applyConceptTemplate() {
        content = """
        # \(title)
        
        ## 定义
        
        ## 核心要点
        
        | 维度 | 说明 |
        |------|------|
        |  |  |
        
        ## 相关链接
        
        """
    }
    
    private func applyComparisonTemplate() {
        content = """
        # \(title)
        
        ## 对比维度
        
        | 维度 | A | B |
        |------|---|---|
        |  |  |  |
        
        ## 结论
        
        ## 相关链接
        
        """
    }
}
