import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject var store: KMStore
    @Inject var securityService: VaultSecurityService
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $store.isPrivacyModeEnabled) {
                    Label(Localized.tr("settings.privacyMode"), systemImage: "eye.slash.fill")
                }
                
                Button(action: {
                    securityService.lock()
                }) {
                    Label(Localized.tr("settings.lockVaultNow"), systemImage: "lock.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text(Localized.tr("settings.section.security"))
            } footer: {
                Text(Localized.tr("settings.privacyMode.desc"))
            }
            
            Section {
                Toggle(isOn: .constant(true)) {
                    Label("生物识别保护", systemImage: "faceid")
                }
                .disabled(true)
            } header: {
                Text("高级安全")
            } footer: {
                Text("开启后，修改隐私设置或解锁加密内容需要 FaceID/TouchID 验证。")
            }
        }
        .navigationTitle(Localized.tr("settings.vaultSecurity"))
    }
}
