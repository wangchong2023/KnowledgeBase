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
            case .welcome: return Localized.trf("onboarding.step.welcome.title", Localized.tr("app.name"))
            case .linking: return Localized.tr("onboarding.step.linking.title")
            case .aiLab: return Localized.tr("onboarding.step.aiLab.title")
            case .graph: return Localized.tr("onboarding.step.graph.title")
            case .vault: return Localized.tr("onboarding.step.vault.title")
            }
        }
        
        var description: String {
            switch self {
            case .welcome: return Localized.tr("onboarding.step.welcome.desc")
            case .linking: return Localized.tr("onboarding.step.linking.desc")
            case .aiLab: return Localized.tr("onboarding.step.aiLab.desc")
            case .graph: return Localized.tr("onboarding.step.graph.desc")
            case .vault: return Localized.tr("onboarding.step.vault.desc")
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
                        Text(step == .vault ? Localized.tr("onboarding.action.start") : Localized.tr("onboarding.action.next"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.wikiAccent)
                            .clipShape(Capsule())
                    }
                    
                    Button(Localized.tr("onboarding.action.skip")) {
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
