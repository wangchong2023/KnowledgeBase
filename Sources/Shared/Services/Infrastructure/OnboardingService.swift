import Foundation
import Combine

/// 用户引导服务 (产品视角：价值呈现与留存)
final class OnboardingService: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    @Published var currentStep: OnboardingStep?

    enum OnboardingStep: Int, CaseIterable, Identifiable {
        case graph = 0
        case aiLab = 1
        case vault = 2

        var id: Int { self.rawValue }

        var title: String {
            switch self {
            case .graph: return Localized.tr("onboarding.step.graph.title")
            case .aiLab: return Localized.tr("onboarding.step.aiLab.title")
            case .vault: return Localized.tr("onboarding.step.vault.title")
            }
        }

        var description: String {
            switch self {
            case .graph: return Localized.tr("onboarding.step.graph.desc")
            case .aiLab: return Localized.tr("onboarding.step.aiLab.desc")
            case .vault: return Localized.tr("onboarding.step.vault.desc")
            }
        }

        var icon: String {
            switch self {
            case .graph: return "network"
            case .aiLab: return "sparkles"
            case .vault: return "lock.shield"
            }
        }
    }

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func nextStep() {
        if let current = currentStep, let next = OnboardingStep(rawValue: current.rawValue + 1) {
            currentStep = next
        } else if currentStep == nil {
            currentStep = .graph
        } else {
            completeOnboarding()
        }
    }

    func completeOnboarding() {
        currentStep = nil
        hasCompletedOnboarding = true
    }

    func reset() {
        hasCompletedOnboarding = false
        currentStep = nil
    }
}
