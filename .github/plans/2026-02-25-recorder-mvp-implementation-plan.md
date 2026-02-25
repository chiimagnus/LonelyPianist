# PianoKey Recorder（录制+播放）MVP 实施计划

> 执行方式：建议使用 `executing-plans` 按批次实现与验收。

**Goal（目标）:** 在现有 PianoKey UI 中新增 Recorder 功能，支持录制 MIDI 音符、固定钢琴音色回放、持久化保存、重启恢复，以及多 takes 切换。

**Non-goals（非目标）:** 不做多乐器、不做 Piano Roll 编辑、不做多轨、不导入外部 `.mid`、回放不触发映射引擎（不发送键盘注入/快捷指令）。

**Approach（方案）:**
1. 在现有 `MIDIEvent` 输入链路上增加录制分支，按 noteOn/noteOff 组装“音符片段（开始+时长）”。
2. 用 SwiftData 新增录制数据实体（Take + NoteEvent），通过独立 Repository 管理 CRUD。
3. 用 `AVAudioEngine + AVAudioUnitSampler` 实现内置钢琴回放（固定音色），播放状态与录制状态互斥。
4. UI 采用“现有 Control Panel 融合式”布局：Mapping/Recorder 两个主区；Recorder 内部为 Sidebar + Toolbar + Piano Roll + Statusbar。
5. 菜单栏增加 Recorder 快控（Rec/Play/Stop/Open），保证与当前菜单栏工作流一致。

**Acceptance（验收）:**
1. 用户可在 Recorder 页面录制一段 MIDI，停止后生成 take 并显示在 Library。
2. 选择任意 take 点击 Play 可听到钢琴声音，Stop 可立即停止。
3. 关闭应用后重启，已保存 takes 仍可见且可播放。
4. 回放过程中不会触发文本输入/组合键/快捷指令（仅发声）。
5. 菜单栏快控可直接控制 Rec/Play/Stop，并可打开 Recorder 页面。

---

## P1（最高优先级）：数据模型与核心服务

### Task 1: 定义录制领域模型与状态类型

**Files:**
- Create: `PianoKey/Models/Recording/RecordedNote.swift`
- Create: `PianoKey/Models/Recording/RecordingTake.swift`
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`（仅先添加类型占位，不接业务）

**Step 1: 实现功能**
- 新增 `RecordedNote`（`id/note/velocity/channel/startOffsetSec/durationSec`）。
- 新增 `RecordingTake`（`id/name/createdAt/updatedAt/durationSec/notes`）。
- 在 ViewModel 增加 `RecorderMode` 枚举（`idle/recording/playing`）占位，后续任务再接行为。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 编译通过。

### Task 2: 新增 SwiftData 实体（Take + Note）

**Files:**
- Create: `PianoKey/Models/Storage/RecordingTakeEntity.swift`
- Create: `PianoKey/Models/Storage/RecordedNoteEntity.swift`

**Step 1: 实现功能**
- 定义 `@Model`：`RecordingTakeEntity`、`RecordedNoteEntity`。
- 关系：`RecordingTakeEntity` 1:N `RecordedNoteEntity`。
- 字段覆盖 MVP 所需（名称、时间、时长、音高、力度、通道、起始偏移、时值）。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: SwiftData 模型通过编译。

### Task 3: 新增录制仓储协议与 SwiftData 实现

**Files:**
- Create: `PianoKey/Services/Protocols/RecordingTakeRepositoryProtocol.swift`
- Create: `PianoKey/Services/Storage/SwiftDataRecordingTakeRepository.swift`

**Step 1: 实现功能**
- 协议定义：`fetchTakes/saveTake/deleteTake/renameTake`。
- 实现 JSON/实体互转（若领域模型直接映射实体可省编码层）。
- 查询按 `updatedAt DESC`，保证 Library 最新优先。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: Repository 层编译通过，无未实现协议方法。

### Task 4: 录制服务（实时收集 noteOn/noteOff）

**Files:**
- Create: `PianoKey/Services/Protocols/RecordingServiceProtocol.swift`
- Create: `PianoKey/Services/Recording/DefaultRecordingService.swift`
- Create: `PianoKey/Services/Protocols/ClockProtocol.swift`（可注入时间源）

**Step 1: 实现功能**
- `startRecording(at:)`、`append(event:)`、`stopRecording(at:) -> RecordingTake`。
- 内部维护未闭合 noteOn（按 `note+channel` 索引），在 stop 时自动补齐末尾 noteOff。
- 仅处理 `noteOn/noteOff`，忽略其他未来扩展事件。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 录制服务可编译，接口可被 ViewModel 调用。

### Task 5: 播放服务（固定钢琴音色）

**Files:**
- Create: `PianoKey/Services/Protocols/MIDIPlaybackServiceProtocol.swift`
- Create: `PianoKey/Services/Playback/AVSamplerMIDIPlaybackService.swift`

**Step 1: 实现功能**
- 用 `AVAudioEngine + AVAudioUnitSampler` 初始化固定钢琴音色。
- 提供 `play(take:)`、`stop()`、`isPlaying`、`onPlaybackFinished`。
- 基于 `RecordedNote.startOffsetSec/durationSec` 调度 noteOn/noteOff。
- 取消播放时清理所有挂起调度，避免“粘音”。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 回放服务编译通过。

**Step 3: 手测（局部）**
Run App: `open PianoKey.xcodeproj` 后运行 Debug。
Expected: 可在临时按钮或调试入口触发一段固定音符并听到钢琴声。

### Task 6: 应用入口注入 Recorder 依赖

**Files:**
- Modify: `PianoKey/PianoKeyApp.swift`
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`（构造参数）

**Step 1: 实现功能**
- `Schema` 增加录制实体。
- 创建 `SwiftDataRecordingTakeRepository`、`DefaultRecordingService`、`AVSamplerMIDIPlaybackService`。
- 注入到 `PianoKeyViewModel`。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: App 正常启动，ModelContainer 初始化成功。

---

## P2：ViewModel 状态机与业务编排

### Task 7: 扩展 ViewModel 的 Recorder 状态

**Files:**
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`

**Step 1: 实现功能**
- 新增状态：`recorderMode`、`takes`、`selectedTakeID`、`playheadSec`、`recorderStatusMessage`。
- 新增派生属性：`selectedTake`、`canRecord/canPlay/canStop`。
- 在 `bootstrap()` 中加载 takes。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 现有功能不回归，新增状态可被 UI 绑定。

### Task 8: 把 MIDI 输入分流到录制服务

**Files:**
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`

**Step 1: 实现功能**
- 在 `handleMIDIEvent(_:)` 内，当 `recorderMode == .recording` 时调用 `recordingService.append(event:)`。
- 保持当前映射行为不变（录制与映射可并行；回放另行隔离）。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 录制分流逻辑接入后编译通过。

### Task 9: 实现 Transport 动作（Rec/Play/Stop）

**Files:**
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`

**Step 1: 实现功能**
- 新增方法：`startRecordingTake()`、`playSelectedTake()`、`stopTransport()`。
- 互斥规则：
  - 录制开始前若在播放，先 stop。
  - 播放开始前若在录制，先 stop 并落盘。
  - stop 对两种模式都生效。
- 回放结束回调后自动切回 `.idle`。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 状态切换完整，无死状态。

### Task 10: Take 管理动作（保存/重命名/删除/切换）

**Files:**
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`

**Step 1: 实现功能**
- 新增 `renameTake/deleteTake/selectTake`。
- 录制 stop 后创建新 take（默认名 `Take yyyy-MM-dd HH:mm:ss`）并保存。
- 切换 take 时若正在播放，自动 stop。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: CRUD 路径可编译且状态一致。

---

## P3：UI 融合（方案 2）

### Task 11: 在 Control Panel 增加 Mapping/Recorder 主入口

**Files:**
- Modify: `PianoKey/Views/Main/ControlPanelView.swift`
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`（新增 `MainPanelTab`）

**Step 1: 实现功能**
- 采用 `TabView` 或 `Picker(.segmented)` 增加 `Mappings` 与 `Recorder` 切换。
- 默认保持当前 `Mappings` 页面行为不变。

**Step 2: 验证**
Run App: `open PianoKey.xcodeproj` 后运行 Debug。
Expected: Control Panel 可在两个主入口切换，现有映射编辑区正常。

### Task 12: 新增 Recorder 页面骨架（Apple 风格）

**Files:**
- Create: `PianoKey/Views/Main/Recorder/RecorderPanelView.swift`
- Create: `PianoKey/Views/Main/Recorder/RecorderLibraryView.swift`
- Create: `PianoKey/Views/Main/Recorder/RecorderTransportBarView.swift`
- Create: `PianoKey/Views/Main/Recorder/RecorderStatusBarView.swift`

**Step 1: 实现功能**
- 左侧 `Library`：展示 takes、选择与基础操作菜单。
- 顶部 `Transport`：Rec/Play/Stop + 时间文本。
- 底部 `Status`：notes 数量、时长、保存状态。

**Step 2: 验证**
Run App: 运行 Debug。
Expected: 版式稳定，窗口缩放下布局不崩。

### Task 13: 新增只读 Piano Roll 视图

**Files:**
- Create: `PianoKey/Views/Main/Recorder/PianoRollView.swift`
- Modify: `PianoKey/Views/Main/Recorder/RecorderPanelView.swift`

**Step 1: 实现功能**
- 按音高（Y）与时间（X）绘制短横线（`Canvas` 或 `Path`）。
- 支持当前 take 的基础缩放（至少固定比例 + 滚动）。
- 不提供拖拽编辑。

**Step 2: 验证**
Run App: 录一段包含高低音变化的片段。
Expected: Piano Roll 能看到对应横线分布，随 take 切换更新。

### Task 14: 菜单栏快控融合

**Files:**
- Modify: `PianoKey/Views/MenuBar/MenuBarPanelView.swift`
- Modify: `PianoKey/PianoKeyApp.swift`（必要时增加窗口 id 或打开逻辑）
- Modify: `PianoKey/ViewModels/PianoKeyViewModel.swift`

**Step 1: 实现功能**
- 在现有菜单栏面板中增加 `Rec / Play / Stop` 按钮。
- 保留 `Open Control Panel`，并可直接切换到 Recorder 主入口（通过 ViewModel 状态）。

**Step 2: 验证**
Run App: 从菜单栏直接录制、停止、播放。
Expected: 与 Control Panel 的状态一致，不出现“双状态不同步”。

---

## P4：测试、回归与文档同步

### Task 15: 新增 Recorder 逻辑测试（建议）

**Files:**
- Create: `PianoKeyTests/Recording/DefaultRecordingServiceTests.swift`
- Create: `PianoKeyTests/ViewModels/PianoKeyViewModelRecorderStateTests.swift`
- Modify: `PianoKey.xcodeproj/project.pbxproj`（加入 test target 与文件引用）

**Step 1: 实现功能**
- 为新 Service Protocol 提供 test doubles（成功/失败路径）。
- 覆盖：
  - noteOn/noteOff 配对与 stop 自动补齐。
  - 状态机互斥（recording/playing）。
  - 回放不触发映射动作（通过 mock 验证 execute 未被调用）。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -destination 'platform=macOS' test`
Expected: 新增测试通过。

### Task 16: 全量回归与文档更新

**Files:**
- Modify: `README.md`
- Modify: `.github/docs/business-logic.md`
- Modify: `AGENTS.md`（仅当协作流程或术语边界需要同步时）

**Step 1: 实现功能**
- README：补充 Recorder 功能、操作步骤、限制说明（固定钢琴、无 MIDI 导入、无编辑）。
- business-logic：更新能力清单、用户流程、术语与产出。
- AGENTS：若新增协作规范/术语，按约定同步；否则保持不动并在 PR 标注“无需更新”。

**Step 2: 验证**
Run: `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
Expected: 构建通过且文档与实现一致。

**Step 3: 手测清单（必须）**
1. 权限流程：未授权可请求，授权后状态自动刷新。
2. MIDI 流程：Start Listening 后 Sources 与 MIDI Events 更新。
3. 录制流程：Rec->Stop 生成 take，Library 可切换。
4. 播放流程：Play 有钢琴声，Stop 立即停。
5. 持久化流程：重启后 takes 仍在且可播放。
6. 兼容流程：回放时不触发文本注入/组合键/快捷指令。

---

## 风险与缓解

1. **内置钢琴音色路径兼容性**：不同 macOS 版本 sound bank 路径可能不同。
- 缓解：实现主路径 + 兜底路径；失败时禁用播放并提示。

2. **播放调度精度与粘音**：`Task.sleep` 抖动可能导致尾音异常。
- 缓解：集中管理所有调度任务；stop 时统一 noteOff + cancel。

3. **录制与映射并发状态复杂**：可能出现状态错乱。
- 缓解：ViewModel 统一状态机 + 单入口 transport API，禁止 UI 直接改模式。

## 提交建议（可选）

- `feat: task1 - add recording domain models`
- `feat: task2 - add swiftdata entities for takes`
- `feat: task3 - implement recording repository`
- `feat: task4 - add recording and playback services`
- `feat: task5 - integrate recorder state into viewmodel`
- `feat: task6 - add recorder panel and piano roll ui`
- `test: task7 - add recorder service and state tests`
- `docs: task8 - update readme and business logic for recorder`

## 下一步

1. 直接进入执行：使用 `executing-plans` 按 P1 -> P4 分批实现。
2. 先 review：你先确认这个计划的任务顺序与文件命名，再开始动手。
