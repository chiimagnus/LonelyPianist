# PianoKey — 用钢琴弹出代码

一个把 MIDI 键盘变成 macOS 输入设备的菜单栏应用。

## 已实现功能

### MVP
- [x] 连接 MIDI 键盘并监听琴键输入（CoreMIDI，自动监听所有 Source）
- [x] 琴键 -> 字符的单键映射
- [x] 发送键盘输入到其他应用（CGEvent）
- [x] 在控制面板显示映射、运行状态、输入预览、最近事件

### 扩展
- [x] 和弦 -> 组合键（如 `cmd+c`）
- [x] 旋律 -> 文本 / 组合键 / Shortcuts
- [x] 力度分层（阈值以上可输出另一组字符）
- [x] 自定义映射配置（新增/删除/切换/编辑，SwiftData 持久化）

## UI 形态

- 菜单栏入口（`MenuBarExtra`）
- 控制面板浮窗（规则编辑 + 运行状态）
- 简洁分区：Runtime / Profiles / Single Key Map / Rules / Recent Events

## 技术栈

- Swift + SwiftUI
- CoreMIDI
- CGEvent
- SwiftData
- Observation (`@Observable`)
- 无第三方依赖

## 架构

- MVVM：`ViewModels / Views / Models / Services`
- 面向协议：服务层全部通过协议注入
- 映射引擎独立：单键 / 和弦 / 旋律 / 力度逻辑统一在 `DefaultMappingEngine`

## 快速开始

1. 打开 `PianoKey.xcodeproj`
2. 运行 `PianoKey` target
3. 首次启动后在菜单栏打开应用
4. 若要发送按键，需在系统里授予辅助功能权限

命令行构建：

```bash
xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build
```

## 使用说明

1. 菜单栏面板点击 `Start Listening`
2. 打开 `Control Panel`
3. 在 `Profiles` 里切换或创建配置
4. 在 `Rules` 里编辑：
   - `Single Key`: 音符、普通输出、高力度输出、阈值
   - `Chord`: 音符序列 + 动作类型 + 动作值
   - `Melody`: 音符序列 + 时间窗口 + 动作类型 + 动作值
5. 动作值示例：
   - `text`: `hello `
   - `keyCombo`: `cmd+shift+k`
   - `shortcut`: `Open Notion`

## 无实体琴测试

可用 GarageBand 测试 MIDI 输入：

1. 打开 GarageBand
2. `窗口 -> 显示音乐打字键盘`
3. 运行 PianoKey 并开始监听
4. 用 GarageBand 键盘触发 MIDI 事件

## 已知限制

- 需要授予辅助功能权限后，键盘注入才会生效。
- `shortcut` 动作依赖系统中已存在同名快捷指令。
- 在受限输入场景（安全输入/部分沙盒上下文）下，按键注入可能被系统拦截。
