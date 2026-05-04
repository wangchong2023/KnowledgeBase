// OnboardingService.swift
//
// 作者: Wang Chong
// 功能说明: 用户引导服务 (产品视角：价值呈现与留存)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Combine

/// 用户引导服务 (产品视角：价值呈现与留存)
final class OnboardingService: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
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
    
    func nextStep() {
        if let current = currentStep, let next = OnboardingStep(rawValue: current.rawValue + 1) {
            withAnimation { currentStep = next }
        } else if currentStep == nil {
            withAnimation { currentStep = .graph }
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
    
    func reset() {
        withAnimation {
            hasCompletedOnboarding = false
            currentStep = nil
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
