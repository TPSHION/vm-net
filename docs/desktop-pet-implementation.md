# 桌面宠物系统实现文档

## 1. 目标

为 `vm-net` 增加一个可选的 `桌面宠物系统`，使宠物成为独立存在的桌面角色，而不是悬浮胶囊旁边的附属挂件。

本次方案的核心目标是：

- 宠物可以在整个屏幕范围内自由活动
- 悬浮胶囊作为宠物的“家”，而不是宠物的固定锚点
- 宠物和悬浮胶囊不必绑定移动，但保持弱关联
- 为后续“多宠物资源”和“按付费解锁能力”预留稳定架构
- 保持 Mac App Store 可接受的实现边界，避免高风险底层事件方案

## 2. 产品定义

### 2.1 功能形态

桌面宠物应定义为：

- 一个独立的桌面角色
- 拥有自己的位置、状态、行为和动画
- 在屏幕内随机巡游、驻留、回家、互动
- 不依赖悬浮胶囊的位置来决定每一帧的位置

悬浮胶囊应定义为：

- 宠物的 `home anchor`
- 一个“家”的位置参考点
- 宠物部分行为的目标点

### 2.2 默认行为

- 默认关闭
- 启用后，宠物在当前屏幕自由活动
- 宠物空闲时会做轻量随机巡游
- 宠物可在适当时机回到胶囊附近停靠
- 拖动悬浮胶囊时，只更新宠物的“家”位置
- 宠物不会强制跟随胶囊一起移动

### 2.3 第一版定位

第一版建议是：

- 单宠物
- 单屏活动
- 单实例
- 屏幕内自由巡游
- 基础鼠标互动
- 基础回家行为

暂不追求复杂剧情、对话或多角色生态。

## 3. 设计原则

### 3.1 宠物是独立角色

宠物应拥有自己的世界坐标和行为状态，而不是继续作为胶囊附件存在。

### 3.2 胶囊是“家”而不是“父节点”

胶囊不再直接决定宠物位置，只作为回家、休息、环绕停留等行为的目标点。

### 3.3 展示与行为解耦

宠物动画、行为决策、互动命中、资源能力应拆层设计，不要把逻辑堆在单个视图里。

### 3.4 能力与资源解耦

不同宠物资源不应直接写死在控制器逻辑中。宠物资源和宠物能力要分离，方便后续做付费解锁。

### 3.5 稳定优先于“全局捕获”

第一版全屏互动基于应用自己的透明全屏 overlay，不依赖高风险的系统级事件拦截。

## 4. 范围

### 4.1 本次实现包含

- 独立桌面宠物世界模型
- 宠物全屏自由活动能力
- 悬浮胶囊作为 home anchor
- 基础巡游、停留、回家行为
- 基础鼠标互动
- 基于可切换渲染后端的角色动画系统
- 宠物能力模型
- 后续多宠物切换和付费解锁的架构预留

### 4.2 本次实现不包含

- 多宠物同时活动
- 跨屏漫游
- 宠物语音
- 宠物对话系统
- 系统级全局事件抓取
- 复杂成就或养成系统

## 5. 核心形态

### 5.1 新方案

推荐形态为：

- `全屏透明互动层 + 独立宠物 actor + home anchor`

宠物显示在透明全屏 overlay 上，在 overlay 内自由活动。

### 5.2 与旧方案的区别

旧方案是：

- 宠物贴在悬浮胶囊旁边
- 宠物跟随胶囊移动
- 宠物交互区域受限于小窗口

新方案是：

- 宠物在屏幕内独立活动
- 胶囊只提供“家”的位置
- 宠物与胶囊可以分离
- 宠物行为由状态机和行为系统驱动

## 6. 技术选型

### 6.1 展示容器

推荐使用：

- 每个屏幕一个透明无边框窗口
- 作为宠物世界的 overlay

建议配置：

- `borderless`
- `nonactivatingPanel`
- `backgroundColor = .clear`
- `isOpaque = false`
- `level = .floating`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`

### 6.2 渲染与动画方案

推荐使用“统一宠物系统 + 多渲染后端”的方案。

第一版默认后端：

- `Rive`

后续可并行支持：

- `SceneKit`
- `RealityKit`
- 其他轻量帧动画后端

原则是：

- 宠物世界模型统一
- 行为系统统一
- 资源定义统一
- 不同渲染方案只作为表现层后端存在

这样可以做到：

- 现阶段用 `Rive` 快速落地 roaming pet
- 后续增加更逼真的 `3D` 宠物
- 不需要推翻现有桌宠系统

### 6.3 Rive 的定位

`Rive` 作为第一版默认后端，适合：

- 高质感 2D / 2.5D 角色
- 状态机驱动
- 资源快速迭代
- 多宠物能力验证

### 6.4 3D 后端的定位

后续如果需要更逼真的宠物，可增加 `SceneKit` 或其他 3D 渲染后端。

3D 后端应理解为：

- 与 `Rive` 并行存在
- 复用同一套行为系统
- 只替换渲染层和动画适配层

### 6.5 输入事件方案

第一版建议：

- 不依赖 `CGEventTap`
- 不做系统级全局拦截
- 使用 overlay 自身事件与命中测试完成互动

这样更适合当前 `Mac App Store` 分发方向。

## 7. 架构方案

### 7.1 推荐结构

```text
ThroughputStore
    ->
FloatingBallController
    -> provides home anchor

PetWorldController
    ->
PetOverlayController (per screen)
    ->
PetActorController
    ->
PetRenderer
    ->
RivePetRenderer / SceneKitPetRenderer / OtherRenderer
```

### 7.2 类型建议

建议新增或重构以下模块：

- `DesktopPet/PetWorldController.swift`
- `DesktopPet/PetOverlayController.swift`
- `DesktopPet/PetActorController.swift`
- `DesktopPet/PetBehaviorEngine.swift`
- `DesktopPet/PetRenderer.swift`
- `DesktopPet/RivePetRenderer.swift`
- `DesktopPet/PetAnimationAdapter.swift`
- `DesktopPet/PetDefinition.swift`
- `DesktopPet/PetAbility.swift`
- `DesktopPet/PetCapabilityGate.swift`
- `DesktopPet/PetHomeAnchor.swift`

### 7.3 角色说明

#### PetWorldController

职责：

- 管理宠物系统整体生命周期
- 跟踪当前屏幕和 overlay
- 跟踪 home anchor
- 管理当前装备宠物

#### PetOverlayController

职责：

- 创建全屏透明 overlay
- 只在宠物区域接鼠标事件
- 其余区域点击穿透

#### PetActorController

职责：

- 管理单个宠物实例
- 维护位置、速度、朝向、当前行为
- 执行移动和过渡

#### PetBehaviorEngine

职责：

- 负责宠物行为决策
- 例如：
  - `idle`
  - `wander`
  - `goHome`
  - `restAtHome`
  - `play`
  - `interact`
  - `excited`

#### PetRenderer

职责：

- 统一定义宠物表现层接口
- 承载位置更新、缩放、朝向、行为状态注入
- 屏蔽具体渲染实现差异

建议接口关注：

- `setPosition(_:)`
- `setFacing(_:)`
- `setScale(_:)`
- `applyBehaviorState(_:)`
- `beginInteraction(at:)`
- `updateInteraction(at:)`
- `endInteraction(at:)`

#### RivePetRenderer

职责：

- 负责 `Rive` 资源加载
- 负责 `RiveView` 宿主与生命周期
- 将统一行为状态映射到 Rive 状态机输入

#### PetAnimationAdapter

职责：

- 将统一行为状态映射到具体资源输入
- 允许不同资源在命名和状态机结构上存在差异
- 作为 `PetRenderer` 和资源定义之间的桥接层

#### PetCapabilityGate

职责：

- 根据用户解锁状态决定宠物可用能力
- 为付费能力开关提供统一入口

## 8. 宠物世界模型

### 8.1 宠物坐标

宠物应保存自己的绝对世界坐标，而不是相对胶囊偏移。

建议字段：

- `position`
- `velocity`
- `facing`
- `currentScreenID`

### 8.2 家的位置

home anchor 来自悬浮胶囊。

建议字段：

- `homeCenter`
- `homeRadius`
- `homePreferredSide`

### 8.3 行为状态

建议统一行为状态：

- `idle`
- `wander`
- `goHome`
- `restAtHome`
- `play`
- `interact`
- `excited`

### 8.4 过渡原则

状态切换不要每帧硬切，应通过：

- 时间片
- 冷却时间
- 距离阈值
- 动画完成回调

来做稳定过渡。

## 9. 悬浮胶囊与宠物的关系

### 9.1 胶囊作为 Home Anchor

胶囊只负责提供宠物“家”的坐标。

### 9.2 胶囊移动逻辑

当胶囊被拖动时：

- 更新 `home anchor`
- 不强制瞬移宠物
- 宠物在下一个行为窗口内决定是否回家

### 9.3 胶囊隐藏逻辑

如果悬浮胶囊被关闭：

- 宠物可根据产品策略选择：
  - 自动隐藏
  - 或继续停留但丢失 home 行为

建议第一版保持简单：

- 胶囊关闭时，宠物同步隐藏

## 10. 行为系统建议

### 10.1 基础行为循环

推荐行为循环：

1. `idle`
2. `wander`
3. `pause`
4. `play`
5. `goHome`
6. `restAtHome`

说明：

- 第一版就必须包含 `wander`
- 不能只停留在胶囊附近做装饰动画
- 用户打开桌宠后，应能直接看到宠物在屏幕内独立活动

### 10.2 巡游规则

建议：

- 只在当前屏幕安全区域内生成目标点
- 每次移动距离有限
- 避免过快、过频繁的方向切换

### 10.3 回家规则

触发条件可包括：

- 长时间未回家
- 用户拖动了胶囊
- 用户有互动后空闲一段时间
- 当前能力要求家附近待机

### 10.4 网速联动

后续可选支持：

- 空闲：`idle`
- 高速：`busy / excited`
- 短时间峰值：`playful reaction`

但建议不要让网速状态直接决定宠物位移。

## 11. 互动方案

### 11.1 互动原则

互动应建立在“宠物区域命中”上，而不是整屏抢占事件。

### 11.2 第一版互动

建议支持：

- 点击宠物
- 拖动宠物资源中的可交互部件
- 鼠标悬停轻反应
- 松手后恢复自主行为

### 11.3 全屏互动

“全屏互动”在产品上应理解为：

- 宠物能在全屏范围活动
- 互动时可在全屏范围内继续拖拽和释放

而不是：

- 整个屏幕永久被宠物窗口吃掉事件

### 11.4 事件实现建议

推荐：

- overlay 默认只在宠物命中区域吃事件
- 进入一次互动会话后，允许在当前屏幕范围继续接管 drag / up
- 结束后立即释放

## 12. 资源与能力模型

### 12.1 PetDefinition

建议定义：

- `id`
- `displayName`
- `renderBackend`
- `assetPath`
- `animationProfile`
- `defaultScale`
- `defaultBehaviorProfile`
- `supportedAbilities`

说明：

- `renderBackend` 用于区分 `rive`、`scenekit` 等后端
- `assetPath` 指向对应资源文件
- `animationProfile` 用于描述该资源如何映射统一行为状态

### 12.2 PetAbility

建议支持能力枚举：

- `roaming`
- `interactiveBall`
- `homeReturn`
- `throughputReactive`
- `multiScreen`
- `advancedInteraction`

### 12.3 付费解锁模型

建议将“宠物资源”和“能力解锁”拆开：

- 某个宠物是否已解锁
- 某项能力是否已解锁
- 当前装备宠物是什么

这样后续可以做到：

- 免费宠物 + 免费能力
- 付费宠物皮肤
- 高级能力单独解锁
- 宠物与能力自由组合

## 13. 配置项定义

建议在 `AppPreferences` 中新增：

- `showDesktopPet: Bool`
- `equippedPetID: String`
- `desktopPetBehaviorMode`
- `desktopPetScale`
- `desktopPetFollowThroughputState`
- `desktopPetUnlockedPetIDs`
- `desktopPetUnlockedAbilityIDs`

说明：

- `showDesktopPet`：总开关
- `equippedPetID`：当前装备宠物
- `desktopPetBehaviorMode`：行为模式，例如安静、活跃、自动
- `desktopPetScale`：整体缩放
- `desktopPetFollowThroughputState`：是否根据网速变化动作
- `desktopPetUnlockedPetIDs`：已解锁资源
- `desktopPetUnlockedAbilityIDs`：已解锁能力

## 14. UI 方案

### 14.1 设置页入口

建议保留独立的“桌宠配置页面”。

### 14.2 桌宠配置页面建议

建议包含：

- 当前宠物预览
- 当前装备宠物
- 宠物开关
- 行为模式
- 是否响应网速
- 已解锁能力列表
- 未解锁能力提示

### 14.3 资源切换展示

建议用“可预览卡片列表”而不是简单下拉框。

因为后续宠物会越来越多，需要让用户直观看到：

- 宠物外观
- 已解锁/未解锁状态
- 能力差异

## 15. Rive 资源规范

### 15.0 多后端共存原则

桌宠系统不应与 `Rive` 强绑定。

应遵循：

- 行为系统统一
- 宠物定义统一
- 渲染后端可替换
- 不同宠物可使用不同表现后端

建议支持的后端示例：

- `rive`
- `scenekit`
- `realitykit`

推荐策略：

- 第一版默认使用 `Rive`
- 后续更逼真的宠物可接入 `3D` 后端
- 两者共存，不互相替代

### 15.1 通用约束

建议每个宠物资源都满足：

- 透明背景
- 主 `Artboard`
- 默认 `State Machine`
- 稳定命名的输入

### 15.2 推荐输入

建议统一抽象这些输入：

- `isIdle`
- `isMoving`
- `isExcited`
- `goHome`
- `interactNow`

具体资源内部命名可以不同，但由 `PetAnimationAdapter` 做映射。

### 15.3 资源组织建议

```text
vm-net/Resources/DesktopPet/
  blobby-cat/
    pet.riv
    manifest.json
  pet-name-2/
    pet.riv
    manifest.json
```

每个资源目录建议包含：

- 资源元信息
- 默认尺寸
- 推荐行为参数
- 支持能力清单

## 16. 多屏与空间处理

### 16.1 第一版建议

第一版只让宠物活动在当前主屏或胶囊所在屏幕。

### 16.2 后续扩展

后续可支持：

- 多屏独立 overlay
- 宠物跨屏移动
- 不同屏幕的 home 行为

### 16.3 Spaces 处理

建议与胶囊保持一致：

- `canJoinAllSpaces`
- `fullScreenAuxiliary`

## 17. 性能与风险

### 17.1 风险点

需要重点注意：

- 透明全屏 overlay 的长期稳定性
- 命中测试是否误挡桌面点击
- 行为系统更新频率过高导致不必要重绘
- 宠物资源差异过大导致统一适配困难

### 17.2 控制原则

- 只在启用宠物时初始化 overlay
- 默认只保留一个宠物实例
- 行为系统低频 tick，渲染交给动画引擎
- 非命中区域必须点击穿透

## 18. 分阶段实施建议

### 18.1 Phase 1：自由活动 MVP

- 引入 `PetWorldController`
- 引入 `PetOverlayController`
- 宠物脱离胶囊附件模式
- 胶囊仅作为 home anchor
- 单宠物单屏 roaming
- 行为状态至少包含 `idle / wander / goHome / restAtHome`
- 宠物在屏幕安全区域内持续自由活动
- 非宠物区域点击穿透
- 用户能够直观看到“会自己活动的宠物”

### 18.2 Phase 2：行为系统与互动

- 加入 `PetBehaviorEngine`
- 支持巡游、停留、回家
- 加入基础鼠标互动
- 加入互动会话中的 drag / up 处理

### 18.3 Phase 3：资源与能力系统

- 引入 `PetDefinition`
- 引入 `PetAbility`
- 引入 `PetCapabilityGate`
- 支持多宠物切换
- 支持能力解锁

### 18.4 Phase 4：高级扩展

- 多屏活动
- 更复杂互动
- 付费能力升级
- 更丰富状态联动

## 19. 验收标准

完成功能后应满足：

- 宠物可以在屏幕范围内独立活动
- 第一版启用后即可看到宠物自由巡游，而不是固定停留在胶囊旁边
- 宠物不再依赖悬浮胶囊跟随移动
- 胶囊移动后，宠物能正确更新 home anchor
- 非宠物区域不会挡住用户点击
- 基础互动稳定，不会长期捕获鼠标
- 设置页可以清晰预览和配置当前宠物
- 架构上可继续扩展到多宠物和付费能力

## 20. 推荐落地结论

当前项目最适合的新方案是：

- 将桌宠从“胶囊伴生挂件”升级为“独立桌面宠物系统”
- 使用 `全屏透明 overlay + 宠物 actor + home anchor`
- 第一版默认使用 `Rive` 后端，但架构上支持多渲染后端共存
- 胶囊只提供 home 位置，不再作为宠物父节点
- 第一版就交付可自由巡游的 roaming pet
- 通过 `PetDefinition + PetAbility + PetCapabilityGate` 为后续付费解锁预留统一模型

这套方案更适合长期演进，也更适合你后面做“不同宠物、不同能力、不同付费层级”的产品路线。
