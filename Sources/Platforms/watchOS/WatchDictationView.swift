import SwiftUI

/// 手表端语音采集视图
struct WatchDictationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KMStore.self) var store
    @State private var text = ""
    
    var body: some View {
        VStack {
            TextField(Localized.tr("watch.dictate.hint"), text: $text)
                .padding()
            
            Spacer()
            
            HStack {
                Button(Localized.tr("misc.cancel")) { dismiss() }
                    .tint(.red)
                
                Button(Localized.tr("misc.save")) {
                    saveAndSync()
                }
                .tint(.green)
                .disabled(text.isEmpty)
            }
        }
        .navigationTitle(Localized.tr("watch.capture"))
    }
    
    private func saveAndSync() {
        let newPage = WikiPage(title: "Dictation \(Date().formatted())", content: text)
        store.addPage(newPage)
        
        // 增强：通过 WCSession 实时推送到 iPhone
        WatchConnectivityService.shared.sendContent(text)
        
        // 触发手表端震动反馈
        WKInterfaceDevice.current().play(.success)
        
        dismiss()
    }
}
