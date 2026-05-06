# ZhiYu 开发者工具箱 (Developer Tools)

本目录包含用于加速 ZhiYu 开发与测试的辅助脚本与工具。

## 目录结构原则

- **长期存在**：对于需要长期维护的工具和脚本，直接放置在 `Tools/` 根目录下。
- **临时使用**：对于一次性或实验性的脚本，放置在 `Tools/Temp/` 目录下，并注意及时清理。
- **文档同步**：每当新增或移动脚本时，必须同步更新本 `README.md`。

## 1. 数据库种子工具 (`seed_data.py`)

用于快速初始化或重建模拟器环境下的测试数据。

### 核心功能
- **动态定位**：自动探测当前运行中的 iOS 模拟器路径，无需手动修改代码。
- **数据重建**：一键注入 10+ 个包含复杂双向链接、Markdown 语法的示例页面。
- **环境清理**：支持仅清空数据库而不插入数据。

### 使用方法
```bash
# 重建数据（清空并插入种子页面）
python3 Tools/seed_data.py

# 仅清空数据
python3 Tools/seed_data.py --clean

# 手动指定数据库路径（适用于真机调试或非标准路径）
python3 Tools/seed_data.py --path /path/to/your/km.sqlite3
```

---

## 2. 模拟服务器 (`MockServer`)

用于在本地模拟远程 API 接口，如插件市场、AI 代理等。

### 核心功能
- **静态资源托管**：托管 `community.json` 等配置文件。
- **API 路由模拟**：默认将 `/api/community` 映射至本地 JSON。

### 使用方法
```bash
# 启动服务器（默认监听 http://localhost:8080）
python3 Tools/MockServer/server.py
```

### 验证接口
启动后访问：[http://localhost:8080/api/community](http://localhost:8080/api/community)

---

## 3. 本地化同步工具 (`update_localization.py`)

用于自动合并分表词条到主表。

### 核心功能
- **自动合并**：将 `Sources/Localization/` 目录下所有 `.xcstrings` 文件的内容同步到 `Localizable.xcstrings`。
- **环境兼容**：解决部分构建环境下无法识别多本地化文件的问题。

### 使用方法
```bash
python3 Tools/update_localization.py
```

---

## 4. 注意事项
- **Python 环境**：建议使用 Python 3.8+。
- **权限说明**：在 macOS 上操作模拟器容器路径可能需要全盘访问权限（通常 Terminal 会自动请求）。
- **同步建议**：建议在修改数据库架构（Schema）后，同步更新 `seed_data.py` 中的 `INSERT` 语句。
