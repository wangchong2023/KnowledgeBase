import SwiftUI

struct QuizModel: Codable, Identifiable {
    var id: String { title }
    let title: String
    let questions: [QuizQuestion]
}

struct QuizQuestion: Codable, Identifiable {
    let id: Int
    let text: String
    let options: [String]
    let answer: Int
    let explanation: String
}

struct QuizView: View {
    let quiz: QuizModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex = 0
    @State private var selectedOption: Int? = nil
    @State private var showResult = false
    @State private var score = 0
    @State private var isCompleted = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !isCompleted {
                    // Progress Header
                    VStack(spacing: 8) {
                        HStack {
                            Text(Localized.trf("quiz.questionFormat", currentIndex + 1, quiz.questions.count))
                                .font(.caption.bold())
                                .foregroundStyle(.wikiAccent)
                            Spacer()
                            Text(Localized.trf("quiz.scoreFormat", score))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                        
                        ProgressView(value: Double(currentIndex + 1), total: Double(quiz.questions.count))
                            .tint(.wikiAccent)
                    }
                    .padding(.horizontal)
                    
                    // Question Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(quiz.questions[currentIndex].text)
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                                .lineSpacing(4)
                            
                            VStack(spacing: 12) {
                                ForEach(0..<quiz.questions[currentIndex].options.count, id: \.self) { index in
                                    OptionRow(
                                        text: quiz.questions[currentIndex].options[index],
                                        isSelected: selectedOption == index,
                                        isCorrect: quiz.questions[currentIndex].answer == index,
                                        showResult: showResult,
                                        action: {
                                            if !showResult {
                                                selectOption(index)
                                            }
                                        }
                                    )
                                }
                            }
                            
                            if showResult {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: selectedOption == quiz.questions[currentIndex].answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(selectedOption == quiz.questions[currentIndex].answer ? .green : .red)
                                        Text(selectedOption == quiz.questions[currentIndex].answer ? Localized.tr("misc.correct") : Localized.tr("misc.incorrect"))
                                            .font(.subheadline.bold())
                                    }
                                    
                                    Text(quiz.questions[currentIndex].explanation)
                                        .font(.caption)
                                        .foregroundStyle(.wikiSecondary)
                                        .padding()
                                        .background(Color.wikiAccent.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Footer Action
                    if showResult {
                        Button(action: nextQuestion) {
                            Text(currentIndex + 1 < quiz.questions.count ? Localized.tr("misc.nextQuestion") : Localized.tr("misc.viewResults"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.wikiAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding()
                    }
                } else {
                    // Completion View
                    VStack(spacing: 24) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.wikiAccent)
                        
                        VStack(spacing: 8) {
                            Text(Localized.tr("quiz.completed"))
                                .font(.title.bold())
                            Text(Localized.tr("quiz.yourScore"))
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                            Text("\(score) / \(quiz.questions.count)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(.wikiAccent)
                        }
                        
                        Button(action: { dismiss() }) {
                            Text(Localized.tr("quiz.backToPage"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.wikiAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(quiz.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("misc.cancel")) { dismiss() }
                }
            }
            .background(Color.wikiBackground)
        }
    }
    
    private func selectOption(_ index: Int) {
        withAnimation {
            selectedOption = index
            showResult = true
            if index == quiz.questions[currentIndex].answer {
                score += 1
            }
        }
    }
    
    private func nextQuestion() {
        if currentIndex + 1 < quiz.questions.count {
            withAnimation {
                currentIndex += 1
                selectedOption = nil
                showResult = false
            }
        } else {
            withAnimation {
                isCompleted = true
            }
        }
    }
}

private struct OptionRow: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer()
                if showResult {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.wikiAccent)
                }
            }
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if !showResult {
            return isSelected ? Color.wikiAccent.opacity(0.1) : Color.wikiCard
        }
        if isCorrect { return Color.green.opacity(0.1) }
        if isSelected { return Color.red.opacity(0.1) }
        return Color.wikiCard
    }
    
    private var borderColor: Color {
        if !showResult {
            return isSelected ? .wikiAccent : .clear
        }
        if isCorrect { return .green }
        if isSelected { return .red }
        return .clear
    }
}
