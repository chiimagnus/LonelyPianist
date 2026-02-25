# PianoKey UI：侧边栏双栏整合（NavigationSplitView）

## Goal

- 将「菜单栏面板」与「Control Panel 窗口」的主要功能整合到一个主窗口中，采用 macOS 原生侧边栏双栏样式（`NavigationSplitView`）。
- App 启动后不自动弹出主窗口；仅在 `MenuBarExtra` 中提供入口打开。
- App 不显示在 Dock（只显示在菜单栏）。

## Non-goals

- 不重做现有业务逻辑（权限/MIDI/映射/录制回放）。
- 不引入新的持久化结构或迁移。

## UI 信息架构

- Sidebar：
  - Runtime：连接状态 + 监听控制 + Recorder Transport + Recent Events
  - Mappings：现有映射配置页面
  - Recorder：现有 Recorder 页面（Library/Transport/Piano Roll）

## 验收标准

- 启动后 Dock 无图标，菜单栏可见，主窗口不自动出现。
- 菜单栏面板点击 `Open PianoKey / Open Mappings / Open Recorder` 能打开同一个主窗口并切换到对应页面。
- Runtime/Mappings/Recorder 三个页面均可正常操作（权限流程、MIDI 监听、映射编辑、Rec/Play/Stop）。

## 验证

- `xcodebuild -project PianoKey.xcodeproj -scheme PianoKey -configuration Debug build`
- 手测：权限流程、Start Listening、映射规则（Single Key/Chord/Melody）、Recorder（Rec/Stop/Play/Stop）与重启后数据保留。

