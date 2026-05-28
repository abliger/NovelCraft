# NovelCraft

一款基于 SwiftUI 与 SwiftData 的小说创作辅助应用，专为 macOS 与 iOS 打造。

NovelCraft 帮助作者从灵感捕捉、大纲规划、角色设定到章节撰写与导出，提供一站式创作体验。界面简洁、数据持久化本地存储，让创作回归纯粹。

---

## 功能概览

| 模块 | 功能说明 |
|------|---------|
| **小说项目管理** | 创建多个小说项目，设置标题、作者、目标字数与简介，实时追踪写作进度。 |
| **卷 / 章节 / 场景** | 树形结构组织小说内容，支持拖拽排序、状态标记（草稿 / 修订中 / 已完成 / 已归档）。 |
| **Markdown 编辑器** | 内置 Markdown 编辑与实时预览，支持查找替换，让排版与写作同步进行。 |
| **专注模式** | 全屏沉浸式写作界面，集成计时器与实时字数/阅读时间统计浮层。 |
| **角色管理** | 为每个项目维护角色档案，记录外貌、性格、背景故事与人物关系。 |
| **世界观设定** | 分类管理世界观设定条目，构建完整的故事背景资料库。 |
| **大纲视图** | 树形大纲节点，支持自由拖拽与坐标定位，辅助梳理故事脉络。 |
| **便签** | 彩色便签与置顶功能，快速记录临时灵感。 |
| **多格式导出** | 支持导出为 Markdown、纯文本、PDF 与 EPUB 四种格式。 |
| **主题设置** | 跟随系统 / 浅色 / 深色三种主题模式，自定义编辑器字体与行距。 |

---

## 系统要求

- **macOS** 14.0 或更高版本
- **iOS** 17.0 或更高版本

---

## 技术栈

- **语言**: Swift 5.9
- **UI 框架**: SwiftUI
- **数据持久化**: SwiftData（`@Model`、`@Query`、`modelContainer`）
- **包管理器**: Swift Package Manager
- **外部依赖**:
  - [ZIPFoundation](https://github.com/weichsel/ZIPFoundation.git) `0.9.19+`（EPUB 打包依赖）

---

## 构建与运行

### 命令行

```bash
# 克隆项目后进入目录
cd NovelCraft

# 构建
swift build

# 运行测试
swift test

# 清理构建产物
swift package clean
```

### macOS 启动脚本

项目根目录提供了 `run.sh`，可一键构建并打包为 `.app` 后启动：

```bash
./run.sh
```

脚本会自动：
1. 调用 `swift build`
2. 将可执行文件复制到 `NovelCraft.app/Contents/MacOS/`
3. 生成 `Info.plist`
4. 使用 `open NovelCraft.app` 启动应用

> 注意：脚本默认从 `.build/arm64-apple-macosx/debug/NovelCraft` 复制二进制文件。若使用 Release 构建或其他架构路径，请手动调整。

---

## 项目结构

```
NovelCraft/
├── Package.swift                   # SPM 包配置
├── run.sh                          # macOS 构建启动脚本
├── Sources/NovelCraft/
│   ├── NovelCraftApp.swift         # 应用入口，注册 SwiftData ModelContainer
│   ├── Models/                     # SwiftData 数据模型
│   │   ├── Project.swift           # 小说项目
│   │   ├── Volume.swift            # 卷
│   │   ├── Chapter.swift           # 章节（含状态枚举）
│   │   ├── StoryScene.swift        # 场景（视角角色、地点、时间）
│   │   ├── Character.swift         # 角色
│   │   ├── WorldSetting.swift      # 世界观设定
│   │   ├── OutlineNode.swift       # 大纲节点
│   │   └── Note.swift              # 便签
│   ├── Views/                      # SwiftUI 视图
│   │   ├── ContentView.swift       # 主界面（侧边栏 + 详情区）
│   │   ├── ProjectListView.swift   # 项目列表
│   │   ├── ChapterTreeView.swift   # 卷/章节树形侧边栏
│   │   ├── EditorView.swift        # Markdown 编辑器
│   │   ├── FocusModeView.swift     # 专注模式
│   │   ├── ExportView.swift        # 导出面板
│   │   ├── CharacterListView.swift # 角色管理
│   │   ├── WorldSettingListView.swift
│   │   ├── OutlineView.swift       # 大纲视图
│   │   ├── NoteListView.swift      # 便签列表
│   │   └── SettingsView.swift      # 应用设置
│   └── Utils/
│       ├── ExportEngine.swift      # 导出逻辑（Markdown/TXT/PDF/EPUB）
│       └── ThemeManager.swift      # 主题管理
└── Tests/NovelCraftTests/
    └── NovelCraftTests.swift       # XCTest 单元测试
```

---

## 测试

项目使用 XCTest 框架，运行以下命令执行测试：

```bash
swift test
```

当前测试覆盖：
- Project 默认属性验证
- ChapterStatus 枚举与原始值映射
- ExportEngine Markdown 与纯文本导出

---

## 数据与安全

- **本地存储**: 所有小说数据由 SwiftData 自动管理，默认使用系统 SQLite 存储位置，无需额外配置服务器或数据库。
- **隐私**: 应用数据完全存储在本地设备，不上传至任何云端服务。

---

## 已知限制

- Markdown 解析当前基于正则表达式实现，对复杂嵌套语法的支持有限。
- EPUB 导出依赖系统 `/usr/bin/zip` 命令，在沙盒环境或自定义运行环境中需确认该路径可用。

---

## 许可协议

本项目采用 **双许可（Dual Licensing）** 模式：

### 开源许可 — AGPL-3.0

本项目开源版本依据 **GNU Affero General Public License v3**（AGPL-3.0）或后续版本发布。

- 个人用户、非营利组织和教育用途可免费使用开源版本。
- 若您**修改**软件并以网络服务形式向公众提供（如 SaaS），必须公开您的修改源代码。
- 若您**分发**软件（无论是否修改），必须以 AGPL-3.0 向接收者提供完整源代码。

详见 [LICENSE](LICENSE) 文件。

### 商业许可

如果您希望以下述方式使用 NovelCraft，则需要购买商业许可：

- 闭源修改软件，且无需向第三方公开源代码；
- 将软件或衍生作品嵌入商业闭源产品中分发；
- 以商业 SaaS 形式提供服务，且不希望受 AGPL-3.0 开源义务的约束；
- 需要官方技术支持、定制开发或优先更新服务。

商业许可授予您在特定条件下闭源使用、修改和分发软件的权利，不受 AGPL-3.0 约束。详见 [LICENSE-COMMERCIAL.md](LICENSE-COMMERCIAL.md) 文件。

### 如何选择

| 使用场景 | 所需许可 |
|---------|---------|
| 个人写作、学习、研究 | AGPL-3.0（免费） |
| 非营利组织内部使用 | AGPL-3.0（免费） |
| 修改后闭源用于商业产品 | 商业许可 |
| 作为 SaaS 对外提供服务 | AGPL-3.0 或商业许可 |
| 需要官方技术支持 | 商业许可 |

> 如有商业许可意向，请联系：**3330181534@qq.com**
