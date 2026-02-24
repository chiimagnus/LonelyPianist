# PianoKey 全量功能实现计划

> 执行方式：使用 `executing-plans` 按批次实现与验收。

**Goal（目标）:** 实现一个可用的 macOS 菜单栏 PianoKey 应用，支持 MIDI 输入监听、单键映射、和弦快捷键、旋律触发、力度分层、自定义映射配置持久化与切换，并以简洁苹果风 UI 展示运行状态与编辑能力。

**Non-goals（非目标）:**
- 不实现练琴/教学能力
- 不做云同步或多人共享配置
- 不在本轮完成 Mac App Store 上架流程与审核材料

**Approach（方案）:**
- 按 `.github/docs/开发规范.md` 落地 MVVM + Protocol-Oriented 架构：`Models / Services / ViewModels / Views`
- MIDI 与键盘事件模拟分别抽象为协议服务，ViewModel 只依赖协议
- 映射配置用 SwiftData 持久化，领域模型与存储实体分离，避免 UI 直接依赖存储层
- 使用 `@Observable` 管理状态，避免 `ObservableObject`
- UI 采用菜单栏主入口 + 浮动控制面板，强调简洁、状态可见、配置可编辑

**Acceptance（验收）:**
- `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build` 成功
- 启动后可在 UI 中看到 MIDI 连接状态与最近事件
- 单键映射可输出字符到任意输入框（在已授予辅助功能权限的前提下）
- 和弦映射可触发组合键；旋律映射可触发文本/组合键/Shortcuts
- 力度阈值可影响单键映射输出
- 可创建/切换/编辑/删除映射配置，重启后数据保留

---

## P1（最高优先级）：核心架构与 MVP 闭环

### Task 1: 建立 MVVM+Protocol 项目骨架与领域模型

**Files:**
- Create: `PianoKey/Models/MIDI/MIDIEvent.swift`
- Create: `PianoKey/Models/MIDI/MIDINote.swift`
- Create: `PianoKey/Models/Mapping/MappingAction.swift`
- Create: `PianoKey/Models/Mapping/MappingProfile.swift`
- Create: `PianoKey/Models/Mapping/MappingRule.swift`
- Create: `PianoKey/Services/Protocols/MIDIInputServiceProtocol.swift`
- Create: `PianoKey/Services/Protocols/KeyboardEventServiceProtocol.swift`
- Create: `PianoKey/Services/Protocols/MappingProfileRepositoryProtocol.swift`
- Create: `PianoKey/Services/Protocols/MappingEngineProtocol.swift`
- Create: `PianoKey/Services/Protocols/PermissionServiceProtocol.swift`
- Create: `PianoKey/Services/Protocols/ShortcutServiceProtocol.swift`

**Step 1: 实现基础数据结构与协议抽象**
- 定义 MIDI 事件、音名转换、映射动作、配置模型、规则模型
- 定义服务协议，明确输入输出与依赖边界

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 2: 实现 CoreMIDI 输入服务

**Files:**
- Create: `PianoKey/Services/MIDI/CoreMIDIInputService.swift`

**Step 1: 实现 MIDI Client/Port 初始化与 Source 连接**
- 监听所有可用 MIDI Source
- 将 `noteOn/noteOff` 转换为领域 `MIDIEvent`

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 3: 实现键盘事件与权限服务

**Files:**
- Create: `PianoKey/Services/Input/KeyboardEventService.swift`
- Create: `PianoKey/Services/System/AccessibilityPermissionService.swift`
- Create: `PianoKey/Utilities/KeyComboParser.swift`

**Step 1: 实现文本输入/组合键发送与权限检测/请求**
- 文本输入通过 `CGEvent` unicode 注入
- 组合键通过 keyCode + flags 注入
- 权限服务封装辅助功能检测与请求

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 4: 实现映射引擎（单键 + 和弦 + 旋律 + 力度）

**Files:**
- Create: `PianoKey/Services/Mapping/DefaultMappingEngine.swift`
- Create: `PianoKey/Utilities/MIDINoteParser.swift`

**Step 1: 实现规则匹配与运行时状态机**
- 单键按力度阈值输出
- 和弦按按下集合触发并防抖
- 旋律按时间窗口匹配

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 5: 实现 SwiftData 配置仓储与默认模板

**Files:**
- Create: `PianoKey/Models/Storage/MappingProfileEntity.swift`
- Create: `PianoKey/Services/Storage/SwiftDataMappingProfileRepository.swift`
- Create: `PianoKey/Utilities/DefaultProfileFactory.swift`

**Step 1: 落地配置持久化与首启种子数据**
- 支持 profile 的增删改查与激活状态
- 默认内置模板包含单键/和弦/旋律规则

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 6: 实现主 ViewModel（业务编排）

**Files:**
- Create: `PianoKey/ViewModels/PianoKeyViewModel.swift`

**Step 1: 组装服务并管理应用状态**
- 管理监听状态、配置状态、日志、实时预览
- 接收 MIDI 事件并调度映射引擎与输出服务

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

## P2：菜单栏 + 苹果风控制面板 + 配置编辑

### Task 7: 菜单栏入口与浮动窗口场景

**Files:**
- Modify: `PianoKey/PianoKeyApp.swift`
- Create: `PianoKey/Views/MenuBar/MenuBarPanelView.swift`

**Step 1: 实现 MenuBarExtra + 控制面板窗口打开入口**
- 菜单栏显示连接状态
- 提供开始/停止监听、打开控制面板

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 8: 主控制面板与简洁苹果风 UI

**Files:**
- Modify: `PianoKey/ContentView.swift`
- Create: `PianoKey/Views/Main/ControlPanelView.swift`
- Create: `PianoKey/Views/Main/Sections/StatusSectionView.swift`
- Create: `PianoKey/Views/Main/Sections/KeyboardMapSectionView.swift`
- Create: `PianoKey/Views/Main/Sections/RecentEventSectionView.swift`

**Step 1: 实现状态区/映射可视化/实时预览/最近事件**
- 采用卡片式分区、留白与系统色
- 避免冗余控件，保证层级清晰

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 9: 配置编辑界面（单键/和弦/旋律/力度）

**Files:**
- Create: `PianoKey/Views/Main/Sections/ProfileSectionView.swift`
- Create: `PianoKey/Views/Main/Sections/RulesEditorSectionView.swift`

**Step 1: 实现可编辑规则 UI 与 Profile 切换/增删**
- 单键映射表编辑
- 和弦规则编辑（音符列表 + 动作）
- 旋律规则编辑（序列 + 动作 + 时间窗口）
- 力度阈值开关与阈值调节

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

## P3：体验收尾与回归

### Task 10: 运行日志与错误可观测性

**Files:**
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`
- Modify: `PianoKey/Services/*`（相关实现文件）

**Step 1: 加入 `os.Logger`、错误提示与降级行为**
- 服务层记录关键事件与错误
- UI 显示用户可理解的提示文本

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

### Task 11: 全量回归与 README 同步

**Files:**
- Modify: `README.md`

**Step 1: 对齐实现状态与使用说明**
- 增加权限要求、使用步骤、功能已实现清单

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过

---

## 不确定项（执行前已确认）

- 功能范围：按 README 全量功能实现（含扩展项）
- 规则能力：采用“混合”策略（内置模板 + 可编辑）
- 设计风格：苹果风简洁 UI，避免冗余

## 执行建议

- 直接进入执行：从 P1 的 Task 1-4 作为第一批
- 每批完成后汇报：改动文件、验证命令结果、下一批计划
