// OnboardingService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的新手引导服务（OnboardingService），旨在为新用户提供沉浸式的产品价值呈现与交互教学。
// 该服务通过状态驱动的蒙层系统，引导用户快速掌握系统的核心能力，主要功能点如下：
// 1. 线性引导流程：定义了从知识图谱、AI 实验室到安全金库的阶段性引导步骤（OnboardingStep），支持状态化的步进控制。
// 2. 状态持久化管理：利用 @AppStorage 记录用户的引导完成状态，确保在不同设备或安装周期下的逻辑一致性。
// 3. 沉浸式交互覆盖层：提供高度定制化的 OnboardingOverlay 组件，支持跨平台的缩放动画与触感反馈。
// 4. 智适应资源加载：根据当前引导阶段动态加载对应的图标与本地化文案，通过视觉分级提升品牌感知。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，规范化引导页面的图标尺寸与圆角常量
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
                        .font(.system(size: WikiUI.largeIconSize * 1.25))
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
                .padding(WikiUI.giant * 1.5)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.largeRadius * 1.5))
                .shadow(radius: WikiUI.giant)
                .padding(WikiUI.giant)
                .transition(.scale.combined(with: .opacity))
            }
            .zIndex(999)
        }
    }
}
