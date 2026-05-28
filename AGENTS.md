<!-- From: /Users/fengsixue/own/swift/AGENTS.md -->
# Agent Guide for NovelCraft

> 本文件面向 AI 编码助手。它记录了 NovelCraft 项目的当前状态以及编码助手应遵循的约定。

## 项目概述

**NovelCraft** 是一款基于 SwiftUI 和 SwiftData 的小说创作辅助应用，面向 macOS（最低 macOS 14）与 iOS（最低 iOS 17）。项目使用 Swift Package Manager 管理依赖，核心功能包括小说项目管理、卷/章节/场景的树形组织、角色与世界观设定、大纲卡片、Markdown 编辑器、专注模式写作、以及多格式导出（Markdown / 纯文本 / PDF / EPUB）。

项目中的所有 UI 文本、模型默认值、注释以及用户可见字符串均使用**中文**。

## 技术栈

- **语言**: Swift 5.9
- **UI 框架**: SwiftUI
- **数据持久化**: SwiftData（`@Model`、`@Query`、`modelContainer`）
- **包管理器**: Swift Package Manager（`Package.swift`）
- **外部依赖**:
  - [ZIPFoundation](https://github.com/weichsel/ZIPFoundation.git) `0.9.19+`（用于 EPUB 打包时创建 ZIP 文件；注意：当前代码中 EPUB 生成实际使用系统 `/usr/bin/zip` 命令，ZIPFoundation 已声明但未在核心导出逻辑中直接调用）
- **最低系统版本**: macOS 14.0, iOS 17.0
- **Bundle ID**: `com.novelcraft.NovelCraft`
- **版本**: 1.0.0

## 项目结构

```
NovelCraft/
├── Package.swift              # SPM 包配置
├── Package.resolved           # 锁定依赖版本
├── run.sh                     # macOS 构建并打包为 .app 后启动的脚本
├── .gitignore
├── Sources/
│   └── NovelCraft/
│       ├── NovelCraftApp.swift          # App 入口，注册 SwiftData ModelContainer
│       ├── Models/                      # 8 个 SwiftData @Model 实体
│       │   ├── Project.swift            # 小说项目（标题、作者、目标字数等）
│       │   ├── Volume.swift             # 卷
│       │   ├── Chapter.swift            # 章节（含状态枚举：草稿/修订中/已完成/已归档）
│       │   ├── StoryScene.swift         # 场景（视角角色、地点、时间）
│       │   ├── Character.swift          # 角色（外貌、性格、背景、关系等）
│       │   ├── WorldSetting.swift       # 世界观设定（分类、标题、内容）
│       │   ├── OutlineNode.swift        # 大纲节点（支持树形 parent/children 及 x/y 坐标）
│       │   └── Note.swift               # 便签（颜色、置顶）
│       ├── Views/                       # 全部 SwiftUI 视图
│       │   ├── ContentView.swift        # 主界面：侧边栏 Tab + 详情区
│       │   ├── ProjectListView.swift    # 项目列表（卡片网格、搜索、新建）
│       │   ├── ChapterTreeView.swift    # 卷/章节树形侧边栏（增删改、排序、状态切换）
│       │   ├── EditorView.swift         # Markdown 编辑器 + 预览 + 查找替换
│       │   ├── FocusModeView.swift      # 全屏专注写作模式（计时器、统计浮层）
│       │   ├── ExportView.swift         # 导出选项面板（范围、格式、元数据）
│       │   ├── CharacterListView.swift  # 角色列表与编辑表单
│       │   ├── WorldSettingListView.swift # 世界观设定列表与编辑
│       │   ├── OutlineView.swift        # 大纲视图
│       │   ├── NoteListView.swift       # 便签列表
│       │   └── SettingsView.swift       # 设置（主题、字体、行距、自动保存等）
│       └── Utils/
│           ├── ExportEngine.swift       # 导出逻辑（Markdown/TXT/PDF/EPUB）
│           └── ThemeManager.swift       # 主题管理（跟随系统/浅色/深色）
└── Tests/
    └── NovelCraftTests/
        └── NovelCraftTests.swift        # XCTest 测试
```

## 构建与运行

### 命令行

```bash
cd NovelCraft

# 构建
swift build

# 运行测试
swift test

# 清理
swift package clean
```

### 使用启动脚本（macOS）

项目根目录下的 `run.sh` 会：
1. 调用 `swift build`
2. 将生成的可执行文件复制到 `NovelCraft.app/Contents/MacOS/`
3. 若不存在则生成 `Info.plist`
4. 使用 `open NovelCraft.app` 启动

```bash
cd NovelCraft
./run.sh
```

> 注意：`run.sh` 默认从 `.build/arm64-apple-macosx/debug/NovelCraft` 复制二进制文件。若使用 Release 构建或不同架构路径，需手动调整脚本。

## 代码风格与开发约定

### 语言与命名
- **界面语言**：所有用户可见字符串、模型默认值、枚举 rawValue 均为中文。例如：
  - `ChapterStatus.draft.rawValue == "草稿"`
  - `Project` 默认标题为 `"未命名小说"`
  - `Volume` 默认标题为 `"新卷"`
- **代码注释**：少量注释使用中文，可继续沿用中文注释。
- **类型命名**：遵循 Swift 标准 UpperCamelCase；属性与方法使用 lowerCamelCase。

### SwiftData 模型约定
- 所有模型类均标记为 `@Model final class`。
- 主键使用 `@Attribute(.unique) var id: UUID`，在 `init` 中通过 `UUID()` 自动生成。
- 关系删除规则：
  - 父级对子级通常使用 `.cascade`（如 `Project` → `Volume` / `Character` / `Note` 等）。
  - 反向关系（`inverse:`）用于维护对象图一致性。
- 时间戳字段：`createdAt`、`updatedAt` 在初始化时设置为 `Date()`，并在修改时更新。
- 计算属性（如 `wordCount`、`progressPercentage`）不持久化，仅用于 UI 展示。

### 视图层约定
- 视图大量使用 `@Environment(\.modelContext)` 进行数据的增删改查。
- 列表/树形数据通过 `@Query` 或父对象的关系属性获取，并手动按 `order` 排序。
- `try? modelContext.save()` 被广泛用于保存变更；当前代码未对保存失败做详细错误处理，新增功能可沿用此模式或视情况加强错误提示。
- 状态枚举的 UI 显示直接依赖 `rawValue`，修改枚举值会影响界面文本。

### 导出引擎（ExportEngine）
- 支持四种格式：`markdown`、`plainText`、`pdf`、`epub`。
- PDF 生成通过条件编译区分 macOS（AppKit / `CGContext`）与 iOS（UIKit / `UIGraphicsBeginPDFContextToData`）。
- EPUB 生成在临时目录组装标准 EPUB 文件结构（mimetype、META-INF/container.xml、OEBPS/content.opf、chapter.xhtml），然后调用系统 `/usr/bin/zip` 打包。
- Markdown → HTML 转换使用正则表达式手动处理，非完整 Markdown 解析器。

## 测试策略

- **框架**: XCTest
- **测试目标**: `NovelCraftTests`
- **现有测试覆盖**:
  - `testProjectCreation` — 验证 Project 默认属性
  - `testChapterStatus` — 验证 ChapterStatus 枚举与 rawValue 映射
  - `testExportEngineMarkdown` — 验证 Markdown 导出文件生成与内容包含
  - `testExportEnginePlainText` — 验证纯文本导出及 Markdown 标记去除
- **运行方式**: `swift test`
- **建议**: 新增模型逻辑或导出格式时，应在 `NovelCraftTests.swift` 中补充对应 XCTestCase；视图层测试目前未覆盖，可后续引入 Xcode UI 测试或 ViewInspector 等方案。

## 依赖管理

依赖通过 `Package.swift` 声明。如需新增外部库：
1. 在 `dependencies` 数组中添加 `.package(url:from:)`。
2. 在对应 `target` 的 `dependencies` 中引用产品名。
3. 运行 `swift package resolve`。

> 当前仅依赖 `ZIPFoundation`，若后续需要更完善的 Markdown 解析或 PDF 生成，可考虑引入专用库并更新导出逻辑。

## 部署说明

- **目标平台**: macOS 14+（主要）、iOS 17+
- **产物形式**: Swift Package Manager 可执行文件，可通过 `run.sh` 快速包装为 `.app`。
- **Info.plist**: 由 `run.sh` 动态生成，包含本地化语言 `zh-CN`、最低系统版本 `14.0`、应用分类 `public.app-category.productivity`。
- **数据存储**: 应用数据由 SwiftData 自动管理，默认使用系统提供的 SQLite 存储位置，无需额外配置服务器或数据库。

## 安全与注意事项

- **文件系统**: `ExportEngine` 在 `FileManager.default.temporaryDirectory` 中创建临时文件，EPUB 生成还会创建临时目录并在完成后删除。确保临时目录可写。
- **外部进程**: EPUB 导出调用 `/usr/bin/zip`，在沙盒环境或自定义运行环境中需确认该路径存在。
- **数据丢失风险**: 多处使用 `try? modelContext.save()` 静默忽略保存错误；关键操作（如批量删除）可考虑增加显式错误提示。
- **Markdown 解析**: 当前为正则表达式实现的简易解析，对复杂嵌套语法支持有限，后续若增强预览/导出需评估引入成熟 Markdown 解析库。

---

*Last updated: 2026-05-28*
