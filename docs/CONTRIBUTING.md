# Knowledge Management 开发者贡献指南 (Contributing Guidelines)

## 1. 工程价值观
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
