# 网速多展示形态实现文档

## 1. 目标

为 `vm-net` 增加多种网速状态展示方式，在不重复采样、不增加监控链路复杂度的前提下，支持以下能力：

- 默认使用状态栏展示网速
- 可选启用悬浮球展示
- 悬浮球使用小胶囊样式
- 悬浮球同时显示上传和下载速度
- 主配置窗口统一管理展示方式和相关设置

## 2. 产品定义

### 2.1 默认行为

- 应用首次启动后，默认启用状态栏展示
- 悬浮球默认关闭
- 主窗口打开时，状态栏仍持续显示网速
- 主窗口关闭后，应用不退出，状态栏继续显示网速
- 用户可通过状态栏菜单再次打开主窗口

### 2.2 悬浮球定义

悬浮球采用“小胶囊”而不是纯圆形样式，原因如下：

- 小胶囊更适合同时展示上传和下载两组数据
- 文本布局更稳定，不需要压缩到难以阅读
- 更符合 macOS 桌面工具的轻量信息面板风格

默认展示内容：

- 第一行：上传速度
- 第二行：下载速度

示例：

```text
↑ 128K/s
↓ 3.4M/s
```

## 3. 设计原则

### 3.1 单一数据源

状态栏和悬浮球必须共用同一份网速数据，不允许各自创建一套 `NetworkMonitor`。

### 3.2 展示层与监控层解耦

网速采样只负责产出数据，状态栏和悬浮球只负责渲染。

### 3.3 配置驱动

所有展示方式都由主窗口中的配置项控制，而不是写死在入口逻辑中。

### 3.4 默认稳定优先

第一版优先保证：

- 默认状态栏方案不受影响
- 悬浮球可稳定打开、关闭、拖动和持久化位置
- 登录项启动时不主动弹出主窗口

## 4. 范围

### 4.1 本次实现包含

- 状态栏展示继续保留
- 新增悬浮球展示能力
- 主窗口新增展示方式配置
- 悬浮球位置记忆
- 应用启动时根据配置恢复展示方式

### 4.2 本次实现不包含

- 悬浮球复杂动画
- 悬浮球展开态
- 悬浮球吸边
- 悬浮球点击后复杂快捷操作
- 多种皮肤主题

## 5. 用户场景

### 5.1 只使用状态栏

用户保持默认配置，仅通过状态栏查看网速。

### 5.2 同时使用状态栏和悬浮球

用户希望在桌面上直观看到上传和下载速率，同时保留状态栏入口。

### 5.3 只使用悬浮球

用户关闭状态栏，仅保留悬浮球作为桌面展示入口。

## 6. 配置项定义

建议在现有 `AppPreferences` 基础上增加以下配置：

- `showInStatusBar: Bool = true`
- `showInFloatingBall: Bool = false`
- `displayMode: ThroughputDisplayMode = .smoothed`
- `floatingBallOriginX: Double?`
- `floatingBallOriginY: Double?`
- `floatingBallScreenIdentifier: String?`

说明：

- `showInStatusBar`：是否显示状态栏网速
- `showInFloatingBall`：是否显示悬浮球
- `displayMode`：平滑显示或实时显示
- `floatingBallOriginX/Y`：悬浮球位置
- `floatingBallScreenIdentifier`：记录所在屏幕，便于多显示器恢复位置

## 7. 架构方案

### 7.1 推荐结构

```text
NetworkMonitor
    ->
ThroughputStore / PresentationStore
    ->
StatusItemController
    ->
FloatingBallController
    ->
ConfigurationWindow
```

### 7.2 角色说明

#### NetworkMonitor

职责：

- 负责系统网速采样
- 产出统一的 `NetworkMonitorSnapshot`

约束：

- 全局只保留一个实例

#### ThroughputStore

职责：

- 作为应用内共享状态中心
- 缓存最新网速快照
- 对外发布当前用于展示的数据
- 根据配置决定使用平滑值或实时值

建议：

- 使用 `@MainActor` + `ObservableObject`
- 作为 `AppDelegate` 持有的长生命周期对象

#### StatusItemController

职责：

- 渲染状态栏文本
- 负责状态栏菜单动作
- 不直接持有监控逻辑，只订阅共享数据

#### FloatingBallController

职责：

- 负责创建和控制悬浮球窗口
- 负责显示、隐藏、拖动、恢复位置
- 订阅共享数据并刷新小胶囊内容

#### ConfigurationWindow

职责：

- 承载展示方式配置
- 控制状态栏/悬浮球是否启用
- 展示核心说明，不承载监控逻辑

## 8. 悬浮球实现方案

### 8.1 技术选型

推荐使用 `NSPanel`，不建议直接用普通 SwiftUI `Window` 作为悬浮球容器。

原因：

- `NSPanel` 更适合桌面浮层
- 更容易实现置顶、透明、无标题栏
- 更容易控制不抢主窗口焦点
- 更适合跨桌面空间显示

### 8.2 窗口行为

建议配置：

- 无标题栏
- 透明背景
- 常驻最前
- 支持拖动
- 不因关闭主窗口而消失
- 可加入所有桌面空间

建议能力：

- `level = .floating`
- `isFloatingPanel = true`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `backgroundColor = .clear`
- `isOpaque = false`
- `hidesOnDeactivate = false`

### 8.3 视图形态

小胶囊内容推荐为两行布局：

```text
↑ 128K/s
↓ 3.4M/s
```

视觉要求：

- 圆角胶囊背景
- 半透明或材质背景
- 等宽数字字体
- 左侧箭头，右侧速率
- 文字层级清晰但不过度装饰

### 8.4 交互建议

第一版建议保留最少交互：

- 拖动：移动位置
- 单击：打开主窗口
- 右键：显示和状态栏一致的菜单

## 9. 启动流程

### 9.1 普通启动

流程：

1. 初始化共享监控数据层
2. 根据配置决定是否创建状态栏
3. 根据配置决定是否创建悬浮球
4. 打开主窗口

### 9.2 登录项启动

流程：

1. 初始化共享监控数据层
2. 根据配置恢复状态栏
3. 根据配置恢复悬浮球
4. 不主动打开主窗口

说明：

- 该行为与当前登录项启动策略保持一致
- 用户登录后应直接看到状态栏或悬浮球，而不是被主窗口打断

## 10. 状态栏与悬浮球的组合逻辑

### 10.1 组合规则

- `showInStatusBar = true`，显示状态栏
- `showInFloatingBall = true`，显示悬浮球
- 两者可同时开启

### 10.2 边界处理

如果用户关闭了两种展示方式，建议处理为以下两种策略之一：

#### 策略 A：禁止全部关闭

- 至少保留一种展示方式
- 当用户尝试关闭最后一个展示方式时，提示必须保留至少一种

#### 策略 B：允许全部关闭，但保留应用入口

- 应用继续运行
- 只能通过 Dock 或登录项方式再次进入

推荐采用策略 A，避免用户误操作后“看不到应用”。

## 11. 数据流

### 11.1 发布流程

`NetworkMonitor` 采样后，将快照写入共享 Store。

共享 Store 负责：

- 保存最新快照
- 计算当前展示用速率
- 将更新广播给状态栏和悬浮球

### 11.2 展示选择

当前展示速率仍沿用现有逻辑：

- 平滑模式：使用 `displayedThroughput`
- 实时模式：使用 `instantaneousThroughput`

状态栏和悬浮球必须使用相同的展示模式，避免两个界面显示口径不一致。

## 12. 持久化方案

### 12.1 持久化内容

- 状态栏是否启用
- 悬浮球是否启用
- 展示模式
- 悬浮球位置
- 悬浮球所在屏幕

### 12.2 存储方式

建议继续使用 `UserDefaults`。

原因：

- 当前项目配置量很小
- 不需要额外持久化层
- 与现有 `AppPreferences` 一致

## 13. 风险与注意事项

### 13.1 重复监控风险

如果状态栏和悬浮球各自持有 `NetworkMonitor`，会导致：

- 重复采样
- 数据不同步
- 资源浪费

必须避免。

### 13.2 悬浮球位置恢复风险

如果只保存绝对坐标，可能出现：

- 外接显示器拔掉后恢复到不可见区域

需要在启动时做屏幕边界修正。

### 13.3 可见性风险

如果允许同时关闭状态栏和悬浮球，用户可能找不到应用入口。

建议至少强制保留一种展示方式。

### 13.4 Mac App Store 约束

当前方案基于公开系统 API：

- `SMAppService`
- `NSPanel`
- `UserDefaults`

符合 Mac App Store 发布方向，不依赖私有接口。

## 14. 实施步骤

### 第一阶段：架构重构

- 提取共享 `ThroughputStore`
- 让 `StatusItemController` 改为订阅 Store
- 保持现有状态栏功能不变

### 第二阶段：悬浮球基础版

- 新增 `FloatingBallController`
- 新增小胶囊 SwiftUI 视图
- 支持显示上传和下载速度
- 支持显示/隐藏

### 第三阶段：配置接入

- 主窗口增加“状态栏显示”开关
- 主窗口增加“悬浮球显示”开关
- 接入持久化

### 第四阶段：体验完善

- 支持拖动位置记忆
- 多显示器边界修正
- 登录项启动时恢复悬浮球但不弹主窗口

## 15. 建议新增文件

建议新增或调整的文件如下：

- `vm-net/App/ThroughputStore.swift`
- `vm-net/App/FloatingBallPreferences.swift` 或合并进 `AppPreferences.swift`
- `vm-net/FloatingBall/FloatingBallController.swift`
- `vm-net/FloatingBall/FloatingBallPanel.swift`
- `vm-net/FloatingBall/FloatingBallView.swift`

建议调整：

- `vm-net/MenuBar/StatusItemController.swift`
- `vm-net/App/AppDelegate.swift`
- `vm-net/Views/ConfigurationView.swift`

## 16. 验收标准

满足以下条件即可视为完成第一版：

- 默认启动后只显示状态栏
- 主窗口可开启或关闭悬浮球
- 悬浮球为小胶囊样式
- 悬浮球同时显示上传和下载速度
- 状态栏与悬浮球显示同一份网速数据
- 关闭主窗口后，状态栏和悬浮球继续工作
- 可通过状态栏菜单重新打开主窗口
- 登录项启动时不主动弹出主窗口

