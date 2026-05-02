import SwiftUI
import Combine

/// 用户引导服务 (产品视角：价值呈现与留存)
final class OnboardingService: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @Published var currentStep: OnboardingStep?
    
    enum OnboardingStep: Int, CaseIterable, Identifiable {
        case welcome = 0
        case linking = 1
        case aiLab = 2
        case graph = 3
        case vault = 4
        
        var id: Int { self.rawValue }
        
        var title: String {
            switch self {
            case .welcome: return "👋 欢迎使用 智元"
            case .linking: return "🔗 双向链接"
            case .aiLab: return "🧪 AI 实验室"
            case .graph: return "🕸️ 知识图谱"
            case .vault: return "🛡️ 隐私金库"
            }
        }
        
        var description: String {
            switch self {
            case .welcome: return "您的第二大脑，致力于将离动资料转化为联动智慧。"
            case .linking: return "使用 [[ 语法在笔记间建立联系，形成知识网络。"
            case .aiLab: return "一键生成思维导图、演示文稿和深度报告。"
            case .graph: return "在 3D 空间中俯瞰您的知识星系。"
            case .vault: return "端侧加密与生物识别，守护您的每一行灵感。"
            }
        }
        
        var icon: String {
            switch self {
            case .welcome: return "brain.head.profile"
            case .linking: return "link"
            case .aiLab: return "flask"
            case .graph: return "network"
            case .vault: return "lock.shield"
            }
        }
    }
    
    func nextStep() {
        if let current = currentStep, let next = OnboardingStep(rawValue: current.rawValue + 1) {
            withAnimation { currentStep = next }
        } else if currentStep == nil {
            withAnimation { currentStep = .welcome }
        } else {
            completeOnboarding()
        }
    }
    
    func completeOnboarding() {
        withAnimation {
            currentStep = nil
            hasCompletedOnboarding = true
        }
    }
}

/// 引导蒙层组件
struct OnboardingOverlay: View {
    @ObservedObject var service: OnboardingService
    
    var body: some View {
        if let step = service.currentStep {
            ZStack {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture { service.nextStep() }
                
                VStack(spacing: 24) {
                    Image(systemName: step.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(.wikiAccent)
                    
                    VStack(spacing: 8) {
                        Text(step.title)
                            .font(.title2.bold())
                        Text(step.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Button(action: { service.nextStep() }) {
                        Text(step == .vault ? "开启探索" : "下一步")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.wikiAccent)
                            .clipShape(Capsule())
                    }
                    
                    Button("跳过") {
                        service.completeOnboarding()
                    }
                    .font(.footnote)
                    .foregroundStyle(.wikiSecondary)
                }
                .padding(40)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 20)
                .padding(20)
                .transition(.scale.combined(with: .opacity))
            }
            .zIndex(999)
        }
    }
}
