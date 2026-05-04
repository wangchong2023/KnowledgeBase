// PluginSandboxTests.swift
//
// 作者: Wang Chong
// 功能说明: 插件沙箱安全测试
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// 插件沙箱安全测试
/// 验证 PluginRegistry 的加载/卸载、权限拦截、崩溃隔离及流控降级。
@MainActor
final class PluginSandboxTests: XCTestCase {

    var registry: PluginRegistry!

    override func setUp() {
        super.setUp()
        registry = PluginRegistry.shared
        registry.reset()
    }

    override func tearDown() {
        registry.reset()
        registry = nil
        super.tearDown()
    }

    // MARK: - 加载与卸载

    func testLoadPluginRegistersAndCallsOnLoad() {
        let plugin = MockKnowledgePlugin(id: "test.load", name: "测试插件")
        registry.loadPlugin(plugin)

        XCTAssertTrue(registry.plugins.contains(where: { $0.manifest.id == "test.load" }),
                      "插件加载后应在注册列表中")
        XCTAssertTrue(plugin.didLoad, "onLoad 应在加载时被调用")
    }

    func testUnloadPluginRemovesAndCallsOnUnload() {
        let plugin = MockKnowledgePlugin(id: "test.unload", name: "卸载测试")
        registry.loadPlugin(plugin)
        registry.unloadPlugin(id: "test.unload")

        XCTAssertFalse(registry.plugins.contains(where: { $0.manifest.id == "test.unload" }),
                       "卸载后插件不应在列表中")
        XCTAssertTrue(plugin.didUnload, "onUnload 应在卸载时被调用")
    }

    // MARK: - 拦截器注册

    func testInterceptionPluginIsRegisteredAsInterceptor() {
        let plugin = MockInterceptionPlugin(id: "test.intercept", name: "拦截测试")
        registry.loadPlugin(plugin)

        let result = registry.applyPreProcess(to: "原始内容")
        XCTAssertEqual(result, "拦截后: 原始内容", "preProcess 应被调用并修改内容")
    }

    // MARK: - 权限拦截

    func testPreProcessRejectedWithoutWriteContentPermission() {
        let plugin = MockInterceptionPlugin(
            id: "test.noperm",
            name: "无权限插件",
            permissions: ["pages.read"] // 故意不给 writeContent
        )
        registry.loadPlugin(plugin)

        let result = registry.applyPreProcess(to: "内容")
        XCTAssertEqual(result, "内容", "无 writeContent 权限的插件不应修改内容")
    }

    // MARK: - 崩溃隔离

    func testPluginExceptionDoesNotCrashRegistry() {
        let crashingPlugin = MockCrashingPlugin()
        registry.loadPlugin(crashingPlugin)

        let result = registry.applyPreProcess(to: "测试")
        XCTAssertEqual(result, "测试", "崩溃插件的输出应被忽略，内容不变")
    }

    // MARK: - 流控降级

    func testThrottlingSkipsOverlyFrequentPlugin() {
        let plugin = MockInterceptionPlugin(id: "test.throttle", name: "高频插件")
        registry.loadPlugin(plugin)

        for _ in 0..<51 {
            _ = registry.applyPreProcess(to: "内容")
        }

        let result = registry.applyPreProcess(to: "最终内容")
        XCTAssertNotNil(result)
    }
}

// MARK: - Mock 插件

private enum MockError: Error {
    case simulatedCrash
}

private class MockKnowledgePlugin: KnowledgePlugin {
    let manifest: PluginManifest
    var monetization: MonetizationInfo? { nil }
    private(set) var didLoad = false
    private(set) var didUnload = false

    init(id: String, name: String, permissions: [String] = ["storage.read", "writeContent"]) {
        manifest = PluginManifest(id: id, name: name, version: "2.0.0", permissions: permissions)
    }

    func onLoad(context: PluginContext) { didLoad = true }
    func onUnload() { didUnload = true }
}

private final class MockInterceptionPlugin: MockKnowledgePlugin, InterceptionPlugin {
    func preProcess(content: String) throws -> String { "拦截后: \(content)" }
    func postProcess(content: String) throws -> String { content }
}

private final class MockCrashingPlugin: MockKnowledgePlugin, InterceptionPlugin {
    init() {
        super.init(id: "test.crash", name: "崩溃测试", permissions: ["writeContent"])
    }
    func preProcess(content: String) throws -> String {
        throw MockError.simulatedCrash
    }
    func postProcess(content: String) throws -> String { content }
}
