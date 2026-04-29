import SwiftUI

struct LintView: View {
    @EnvironmentObject var store: KMStore
    @State private var isRunning = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Run button
                VStack(spacing: 12) {
                    Button(action: runLint) {
                        HStack(spacing: 8) {
                            if isRunning {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "stethoscope")
                            }
                            Text(isRunning ? L.tr("lint.checking") : L.tr("lint.runCheck"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.wikiComparison, .red.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                        .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("run-lint")
                    .disabled(isRunning)
                    .padding()
                    
                    if !store.lintIssues.isEmpty {
                        Text(L.trf("lint.foundIssues", store.lintIssues.count))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                .background(Color.wikiCard)
                
                // Issues list
                if store.lintIssues.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                        Text(L.tr("lint.noIssues"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.wikiText)
                        Text(L.tr("lint.noIssuesHint"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Spacer()
                    }
                } else {
                    List {
                        // Errors
                        let errors = store.lintIssues.filter { $0.severity == .error }
                        if !errors.isEmpty {
                            Section {
                                ForEach(errors) { issue in
                                    LintIssueRow(issue: issue)
                                }
                            } header: {
                                Label(L.trf("lint.errors", errors.count), systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        // Warnings
                        let warnings = store.lintIssues.filter { $0.severity == .warning }
                        if !warnings.isEmpty {
                            Section {
                                ForEach(warnings) { issue in
                                    LintIssueRow(issue: issue)
                                }
                            } header: {
                                Label(L.trf("lint.warnings", warnings.count), systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        // Info
                        let infos = store.lintIssues.filter { $0.severity == .info }
                        if !infos.isEmpty {
                            Section {
                                ForEach(infos) { issue in
                                    LintIssueRow(issue: issue)
                                }
                            } header: {
                                Label(L.trf("lint.tips", infos.count), systemImage: "info.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.wikiBackground)
            .navigationTitle(L.tr("lint.title"))
        }
    }
    
    private func runLint() {
        isRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            store.runLint()
            isRunning = false
        }
    }
}

// MARK: - Lint Issue Row
struct LintIssueRow: View {
    let issue: LintIssue
    @EnvironmentObject var store: KMStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: issue.severity.icon)
                    .foregroundStyle(issue.severity.color)
                
                Text(issue.message)
                    .font(.subheadline)
                    .foregroundStyle(.wikiText)
            }
            
            if !issue.suggestion.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(issue.suggestion)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.leading, 24)
            }
            
            if let pageID = issue.pageID,
               let _ = store.pageByID(pageID) {
                Button(action: { store.selectedPageID = pageID }) {
                    Text(L.tr("lint.goToPage"))
                        .font(.caption2)
                        .foregroundStyle(.wikiAccent)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}
