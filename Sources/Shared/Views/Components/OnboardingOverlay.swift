import SwiftUI

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
