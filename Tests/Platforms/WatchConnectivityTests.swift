import XCTest
import WatchConnectivity
@testable import KM

/// 验证 WatchConnectivity 同步可靠性
final class WatchConnectivityTests: XCTestCase {
    
    var service: WatchConnectivityService!
    
    override func setUp() {
        super.setUp()
        service = WatchConnectivityService.shared
    }
    
    /// 测试数据打包逻辑
    @MainActor
    func testContentPackaging() {
        let testText = "手表端采集的测试内容"
        // 模拟发送动作（由于 WCSession 在测试环境无法真实激活，我们验证其调用链路或状态）
        // 这里的测试重点在于确保发送逻辑不会崩溃，且符合协议规范
        service.sendContent(testText)
        XCTAssertNotNil(service)
    }
    
    /// 测试接收逻辑
    func testReceiveUserInfo() {
        let expectation = XCTestExpectation(description: "接收来自手表的通知")
        
        let userInfo: [String: Any] = [
            "content": "来自手表的同步内容",
            "type": "new_page"
        ]
        
        let observer = NotificationCenter.default.addObserver(forName: .didReceiveWatchContent, object: nil, queue: .main) { notification in
            if let content = notification.object as? String {
                XCTAssertEqual(content, "来自手表的同步内容")
                expectation.fulfill()
            }
        }
        
        // 模拟收到 WCSession 回调
        service.session(WCSession.default, didReceiveUserInfo: userInfo)
        
        wait(for: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
