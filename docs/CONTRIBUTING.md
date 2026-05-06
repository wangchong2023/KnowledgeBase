# 智宇 (KM) 开发者贡献指南 (Contributing Guidelines)

## 1. 环境搭建 (Setup)

```bash
# 克隆仓库
git clone <repo-url> && cd km

# 安装依赖
brew install xcodegen swiftlint    # 项目生成与代码检查

# 生成 Xcode 项目（配置变更后必须执行）
xcodegen generate

# 打开项目，选择 KM scheme
open KM.xcodeproj
```

**系统要求**：Xcode 16+，Swift 6，macOS 14+。

## 2. 构建与测试

```bash
# 构建 iOS
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS'

# 构建 macOS (Catalyst)
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'platform=macOS'

# 运行全部单元测试
xcodebuild test -project KM.xcodeproj -scheme KM \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES

# 运行单个测试类
xcodebuild test -project KM.xcodeproj -scheme KM \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:KMTests/KMStoreStorageTests

# 代码检查
swiftlint --strict
```

## 3. 代码审查流程 (Code Review)

1. **自检清单**（提交前）：
   - [ ] `swiftlint --strict` 零告警
   - [ ] `xcodebuild build` 零 Error，零 Warning
   - [ ] 新增逻辑具备对应 XCTest 用例
   - [ ] 测试覆盖率 >= 85%
   - [ ] 无 `print()` / `debugPrint()` 残留
   - [ ] 无硬编码密钥或凭据
2. **分支命名**：`feature/*` / `bugfix/*` / `hotfix/*`
3. **PR 描述**：包含变更摘要、测试计划、关联 Issue
4. **CI 门禁**：PR 必须通过 L1 静态检查、L2 单元测试、L3 性能红线后方可合入

## 4. 工程价值观
*   **注释先行**：核心函数必须包含 [层级标注] 和中文逻辑说明。
*   **安全至上**：禁止绕过 Actor 访问 mutable 状态。
*   **文档同步**：代码变更必须同步更新相应的 `docs/` 文档。

## 2. 代码规范 (Coding Standards)
*   **命名**：遵循 Swift API Design Guidelines，使用语义明确的长命名。
*   **并发**：优先使用 `async/await` 和 `actor`，严禁使用锁 (Locks) 或信号量。
*   **UI**：组件必须支持 Dark Mode 并在 13/15 inch 屏幕上完成适配。

## 3. 分支管理 (Git Flow)
*   `main`: 稳定的发布分支。
*   `develop`: 主开发分支。
*   `feature/*`: 新特性分支，完成后需经过 Code Review 合入 develop。
*   `hotfix/*`: 紧急修复分支。

## 4. 提交规范 (Commit Messages)
采用 Conventional Commits 格式：
*   `feat`: 新功能
*   `fix`: 修补 bug
*   `docs`: 文档变更
*   `refactor`: 代码重构
*   `perf`: 性能优化
