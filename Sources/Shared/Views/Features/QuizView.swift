// QuizView.swift
//
// 作者: Wang Chong
// 功能说明: struct QuizModel
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

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
            VStack(spacing: 8) {
                // Title Header
                Text(quiz.title)
                    .font(.title3.bold())
                    .padding(.top, 8)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                                        label: optionLabel(for: index),
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
                                let correctIdx = quiz.questions[currentIndex].answer
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: selectedOption == correctIdx ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(selectedOption == correctIdx ? .green : .red)
                                        Text(selectedOption == correctIdx ? L10n.Common.tr("correct") : L10n.Common.tr("incorrect"))
                                            .font(.subheadline.bold())
                                    }

                                    Text("\(optionLabel(for: correctIdx)) \(quiz.questions[currentIndex].options[correctIdx])")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.green)

                                    Text(fixExplanationNumbering(quiz.questions[currentIndex].explanation, correctIndex: correctIdx))
                                        .font(.caption)
                                        .foregroundStyle(.wikiSecondary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
                            Text(currentIndex + 1 < quiz.questions.count ? L10n.Common.tr("nextQuestion") : L10n.Common.tr("viewResults"))
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
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("cancel")) { dismiss() }
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
    
    private func optionLabel(for index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let i = letters.index(letters.startIndex, offsetBy: min(index, letters.count - 1))
        return "\(letters[i])."
    }

    /// 将解释文本中的数字答案引用替换为字母（如"正确答案：1" → "正确答案：A"）
    private func fixExplanationNumbering(_ explanation: String, correctIndex: Int) -> String {
        let letter = optionLabel(for: correctIndex).replacingOccurrences(of: ".", with: "")
        let targetNums = Set([correctIndex, correctIndex + 1])
        let pattern = #"(正确答案|答案|正确选项|选项|答案是|答案为|Correct Answer|Answer|Correct Option|Option|The answer is)[是为：:\s]*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return explanation }
        let nsRange = NSRange(explanation.startIndex..<explanation.endIndex, in: explanation)
        let matches = regex.matches(in: explanation, range: nsRange)
        var result = explanation
        for match in matches.reversed() {
            let numNSRange = match.range(at: 2)
            guard let numRange = Range(numNSRange, in: result),
                  let num = Int(result[numRange]),
                  targetNums.contains(num) else { continue }
            result.replaceSubrange(numRange, with: letter)
        }
        return result
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
    let label: String
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("\(label) \(text)")
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
