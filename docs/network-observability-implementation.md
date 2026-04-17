# 网络可观测与智能诊断实现文档

## 1. 目标

为 `vm-net` 增加一组围绕“网络可观测与问题定位”的能力，使应用从“实时网速展示工具”升级为“常驻菜单栏的网络助手”。

本次规划包含以下 5 个功能点：

- `进程级流量排行`
- `异常应用提醒`
- `网络活动时间线`
- `长期趋势统计`
- `AI 诊断解读`

这 5 项能力应形成一条完整链路：

- `实时网速` 告诉用户网络正在变化
- `进程排行` 告诉用户是谁在占网
- `异常提醒` 告诉用户何时出现异常
- `活动时间线` 告诉用户刚刚发生了什么
- `长期趋势` 告诉用户问题是否持续存在
- `AI 解读` 帮助用户理解诊断事实并给出下一步建议

## 2. 本次实现功能

本次文档只保留实际要实现的功能点，避免无关边界描述干扰。

### 2.1 网络活动页

新增一个 `网络活动` 页面，承载以下能力：

- 实时摘要
- 进程级流量排行
- 异常应用提醒入口
- 网络活动时间线
- 长期趋势视图

### 2.2 进程级流量排行

实现按应用聚合的流量列表，支持：

- 当前下载排行
- 当前上传排行
- 最近 1 分钟累计流量排行
- 活跃连接数展示
- 远端域名摘要展示

### 2.3 异常应用提醒

实现基于规则的异常识别与提醒，支持：

- 高下载占用提醒
- 高上传占用提醒
- 后台持续活跃提醒
- 异常重试提醒

### 2.4 网络活动时间线

实现关键事件记录与回看，支持：

- 网络路径变化
- 接口切换
- 带宽突增事件
- 异常应用事件
- 测速完成事件
- 诊断完成事件
- AI 解读完成事件

### 2.5 长期趋势统计

实现本地历史聚合与趋势查询，支持：

- 最近 1 小时趋势
- 最近 24 小时趋势
- 最近 7 天趋势
- 上下行趋势图
- 异常次数统计
- 活跃进程数统计

### 2.6 AI 诊断解读

实现基于已有诊断数据的 AI 解读，支持：

- 对本次诊断结果做总结
- 结合最近一次测速结果
- 结合当前异常应用摘要
- 结合最近时间线事件
- 结构化输出结论、原因、依据和建议

## 3. 产品定位

`vm-net` 的定位应明确为：

- 一个常驻菜单栏的 `macOS 网络可观测与诊断工具`
- 强调 `观察、归因、提醒、复盘、解释`

### 3.1 目标用户

主要面向以下用户：

- 普通用户：想知道“为什么网络变慢了”
- 重度互联网用户：想知道“谁在占网”
- 开发者与技术用户：想快速定位“当前异常发生在哪一层”

### 3.2 第一原则

第一版应优先做到：

- 低打扰常驻运行
- 结果可解释
- 诊断链路稳定
- 数据采集边界清晰
- 不引入与产品主线冲突的复杂能力

## 4. 功能总览

### 4.1 进程级流量排行

用于回答：

- 当前是谁在上传
- 当前是谁在下载
- 哪些应用持续活跃
- 哪些应用可能在后台异常重试

### 4.2 异常应用提醒

用于回答：

- 哪个应用突然占满带宽
- 哪个应用在后台持续高上传
- 哪个应用短时间内连接失败明显增多

### 4.3 网络活动时间线

用于回答：

- 网络是什么时候断开的
- 什么时间切到了另一种网络接口
- 哪次测速或诊断发生在异常前后
- 哪个应用在异常窗口内最活跃

### 4.4 长期趋势统计

用于回答：

- 最近 24 小时网络是否稳定
- 某段时间是否总有上传高峰
- 异常是否集中出现在某些时间段
- 问题是偶发还是持续发生

### 4.5 AI 诊断解读

用于回答：

- 当前诊断结果意味着什么
- 哪个应用或哪类活动可能是诱因
- 下一步最值得执行什么排查动作

## 5. 设计原则

### 5.1 确定性数据优先

AI 只负责解释已有事实，不参与底层采集与探测。

### 5.2 低侵入常驻

后台采集必须控制 CPU、内存和唤醒频率，避免为了监控而影响系统体验。

### 5.3 隐私优先

默认仅在本地保存聚合结果，不上传原始长期数据。

### 5.4 渐进式落地

优先做：

- 本地可观测
- 聚合视图
- 异常识别

后续再考虑更复杂的关联和解释能力。

## 6. 范围

### 6.1 本次实现包含

- 新增网络活动页
- 新增进程级流量排行
- 新增异常提醒规则与通知
- 新增活动时间线
- 新增长期趋势统计与历史汇总
- 新增 AI 解读层
- 新增本地持久化存储

## 7. 总体架构

### 7.1 推荐结构

```text
NetworkMonitor
    ->
ThroughputStore
    ->
ObservationAggregator
    ->
ProcessTrafficStore
    ->
AlertStore
    ->
NetworkTimelineStore
    ->
NetworkTrendStore
    ->
AIDiagnosisStore
```

同时保留现有链路：

```text
MLabSpeedTestService -> SpeedTestStore
NetworkDiagnosisService -> NetworkDiagnosisStore
```

### 7.2 新增模块建议

建议新增以下模块：

- `Models/ProcessTrafficSnapshot.swift`
- `Models/ProcessTrafficProcessRecord.swift`
- `Models/ProcessTrafficPhase.swift`
- `Models/NetworkActivityEvent.swift`
- `Models/NetworkActivityEventKind.swift`
- `Models/NetworkTrendBucket.swift`
- `Models/NetworkAnomaly.swift`
- `Models/AIDiagnosisContext.swift`
- `Services/ProcessTrafficCollector.swift`
- `Services/ProcessTrafficHelperBridge.swift`
- `Services/ObservationAggregator.swift`
- `Services/NetworkEventDetector.swift`
- `Services/AnomalyDetectionService.swift`
- `Services/TrendPersistenceService.swift`
- `Stores/ProcessTrafficStore.swift`
- `Stores/AlertStore.swift`
- `Stores/NetworkTimelineStore.swift`
- `Stores/NetworkTrendStore.swift`
- `Stores/AIDiagnosisStore.swift`
- `Support/NotificationCenterHelper.swift`
- `Support/KeychainHelper.swift`

### 7.3 角色说明

#### ProcessTrafficCollector

职责：

- 获取进程级网络活动快照
- 屏蔽底层采集实现差异
- 对外输出统一结构

#### ProcessTrafficHelperBridge

职责：

- 管理外部 helper 生命周期
- 读取 helper 输出
- 做协议解析与错误恢复

实现方式：

- 第一版使用独立 helper 进程
- helper 推荐使用 `Rust`
- 主应用通过 `JSON lines` 或标准输出协议读取

#### ObservationAggregator

职责：

- 聚合总网速、进程排行、测速、诊断、时间点事件
- 作为时间线与趋势存储的统一入口

#### NetworkEventDetector

职责：

- 识别网络切换、断网恢复、异常峰值、诊断完成、测速完成等事件

#### AnomalyDetectionService

职责：

- 基于规则检测异常应用与异常网络状态
- 生成可展示与可通知的异常事件

#### TrendPersistenceService

职责：

- 将分钟级、小时级聚合指标落盘
- 提供趋势查询接口

#### AIDiagnosisStore

职责：

- 管理 AI 解读请求状态
- 构建 AI 上下文
- 展示结构化结论

## 8. 数据采集策略

### 8.1 总带宽采集

继续复用现有：

- [vm-net/Services/NetworkMonitor.swift](/Users/chen/cwork/vm-net/vm-net/Services/NetworkMonitor.swift)

该模块继续负责：

- 总上传速率
- 总下载速率
- 短期历史曲线
- 当前接口名称

### 8.2 进程级采集

本能力应明确为：

- `进程级流量归因`
- `连接活跃度估算`
- `异常连接聚类`

建议实现方式：

- 使用独立 helper 进程采集
- helper 周期性输出每个进程的聚合快照
- Swift 主应用只负责展示、存储和联动

### 8.2.1 获取方式

进程流量不从现有总网速采样链路中推导，而是通过独立的数据源获取。

实现原则：

- `NetworkMonitor` 继续只负责总带宽
- 进程级流量由独立 helper 单独采集
- 主应用只消费 helper 输出的聚合结果

建议链路如下：

```text
ProcessTrafficHelper
    ->
ProcessTrafficHelperBridge
    ->
ProcessTrafficStore
    ->
NetworkActivityPage / AlertStore / NetworkTimelineStore
```

### 8.2.2 helper 形态

建议新增一个独立可执行文件：

- `ProcessTrafficHelper`

建议实现语言：

- `Rust`

选择独立 helper 的原因：

- 采集逻辑和 SwiftUI 主应用解耦
- 便于高频轮询与异常恢复
- helper 崩溃不会直接拖垮主 UI
- 后续替换采集实现时不会影响上层展示结构

### 8.2.3 数据来源

第一版建议直接读取系统可用的进程网络活动数据，并将其转换为应用内统一结构。

推荐方式：

- helper 周期性调用系统网络活动数据源
- 将每次采样转换为“按进程聚合”的快照
- 计算上传、下载、连接数和域名摘要

第一版目标不是精确计量，而是稳定产出：

- 当前 Top 进程排行
- 当前上传 / 下载速率估算
- 活跃连接数
- 远端域名摘要
- 失败计数增量

### 8.2.4 主应用接入方式

Swift 侧不直接参与底层采集，只负责管理 helper 与消费结果。

建议职责拆分：

- `ProcessTrafficHelperBridge`
  - 启动 helper
  - 读取标准输出
  - 解析 `JSON lines`
  - 处理退出、重启和错误恢复
- `ProcessTrafficStore`
  - 保存当前快照
  - 维护 1 分钟窗口累计值
  - 提供排序和筛选结果
  - 为提醒、时间线和趋势提供统一数据源

### 8.2.5 通信协议

建议 helper 与主应用之间使用：

- `stdout JSON lines`

即 helper 每次采样输出一行 JSON，主应用按行读取。

建议原因：

- 实现简单
- 调试方便
- 崩溃恢复清晰
- 适合持续流式输出

### 8.2.6 采样频率

建议第一版采样频率：

- `1 秒一次`

该频率可以兼顾：

- 排行响应速度
- 异常提醒及时性
- CPU 和 I/O 开销可控

### 8.2.7 结果精度定义

本功能第一版的精度目标应明确为：

- 用于排行
- 用于提醒
- 用于趋势与诊断辅助

不以计费级、抓包级或请求级精度为目标。

建议 helper 输出字段：

```json
{
  "sampleTime": "2026-04-17T12:00:00Z",
  "processes": [
    {
      "pid": 123,
      "processName": "Google Chrome",
      "bundleIdentifier": "com.google.Chrome",
      "downloadBytesPerSecond": 5242880,
      "uploadBytesPerSecond": 262144,
      "activeConnectionCount": 18,
      "remoteHostsTop": ["youtube.com", "googlevideo.com"],
      "failureCountDelta": 0
    }
  ]
}
```

### 8.3 事件采集

事件应来自以下几类：

- 网络接口切换
- 路径状态变化
- 诊断开始 / 完成 / 失败
- 测速开始 / 完成 / 失败
- 异常应用触发
- 总带宽突增或断崖下降

### 8.4 趋势采集

趋势建议按聚合桶保存：

- `1 分钟桶`
- `1 小时桶`
- `1 天桶`

每个桶保存的不是原始每秒数据，而是汇总值。

## 9. 进程级流量排行

### 9.1 功能目标

该功能用于回答：

- 当前 Top 下载应用是谁
- 当前 Top 上传应用是谁
- 过去 1 分钟谁最活跃
- 哪些应用可能在后台持续占用带宽

### 9.2 UI 方案

建议新增一个页面：

- `网络活动`

页面结构建议如下：

- 顶部摘要区
  - 当前总下载
  - 当前总上传
  - 活跃进程数
  - 当前异常数
- 排行列表
  - 应用图标
  - 应用名
  - 实时下载
  - 实时上传
  - 最近 1 分钟累计流量
  - 活跃连接数
  - 状态标签
- 详情抽屉
  - 最近远端域名
  - 最近异常计数
  - 趋势小图

### 9.3 排序模式

建议支持：

- 按当前下载排序
- 按当前上传排序
- 按 1 分钟累计流量排序
- 按异常次数排序

### 9.4 标签建议

建议为应用打上以下标签：

- `高下载`
- `高上传`
- `后台活跃`
- `异常重试`
- `短时突发`

### 9.5 数据模型

建议新增：

```text
ProcessTrafficSnapshot
    - sampleTime
    - totalDownloadBytesPerSecond
    - totalUploadBytesPerSecond
    - activeProcessCount
    - processes: [ProcessTrafficProcessRecord]

ProcessTrafficProcessRecord
    - pid
    - processName
    - bundleIdentifier
    - iconHint
    - downloadBytesPerSecond
    - uploadBytesPerSecond
    - oneMinuteDownloadBytes
    - oneMinuteUploadBytes
    - activeConnectionCount
    - remoteHostsTop
    - failureCountDelta
    - isForegroundApp
    - tags
```

### 9.6 第一版交付项

第一版提供：

- Top 10 进程排行
- 当前上下行速率
- 最近 1 分钟累计流量
- 活跃连接数
- 域名 Top N

## 10. 异常应用提醒

### 10.1 功能目标

用于主动提醒用户：

- 某应用突然占用大量下载带宽
- 某应用持续高上传
- 某应用后台长时间活跃
- 某应用连接失败明显增多

### 10.2 提醒形态

建议支持两种形态：

- 应用内提醒卡片
- macOS 本地通知

默认策略：

- 应用内提醒默认开启
- 系统通知默认开启，但允许用户关闭

### 10.3 规则建议

建议第一版规则如下：

- `高下载占用`
  - 单进程连续 10 秒位于下载 Top 1
  - 且下载速率高于设定阈值
- `高上传占用`
  - 单进程连续 10 秒位于上传 Top 1
  - 且上传速率高于设定阈值
- `后台长活跃`
  - 非前台应用连续 60 秒有明显流量
- `异常重试`
  - 短时间内失败计数增量超过阈值

### 10.4 配置项建议

建议在设置页新增：

- `启用异常应用提醒`
- `启用系统通知`
- `下载提醒阈值`
- `上传提醒阈值`
- `后台活跃提醒阈值`
- `异常重试提醒阈值`
- `提醒冷却时间`

### 10.5 数据模型

建议新增：

```text
NetworkAnomaly
    - id
    - occurredAt
    - processName
    - bundleIdentifier
    - kind
    - severity
    - headline
    - summary
    - metricValue
    - cooldownKey
```

### 10.6 去重与冷却

为了避免骚扰，建议：

- 同一应用同一异常类型进入冷却窗口
- 默认冷却时间 `10 分钟`
- 异常消失后重新计时

## 11. 网络活动时间线

### 11.1 功能目标

时间线用于帮助用户回答：

- 网络是何时变差的
- 变差前后发生了什么
- 哪个应用在异常窗口中最活跃
- 诊断和测速的结果与异常是否有关联

### 11.2 事件类型

建议支持以下事件：

- `网络路径可用`
- `网络路径不可用`
- `接口切换`
- `总下载突增`
- `总上传突增`
- `异常应用触发`
- `测速完成`
- `诊断完成`
- `AI 解读完成`

### 11.3 UI 方案

建议在 `网络活动` 页内加入下半区时间线，或后续拆成独立 `活动记录` 页。

单条时间线卡片建议包含：

- 时间
- 事件标题
- 事件摘要
- 相关应用
- 相关指标
- 快捷动作

快捷动作建议：

- `查看该应用`
- `运行网络诊断`
- `查看测速结果`
- `查看 AI 解读`

### 11.4 事件结构

建议新增：

```text
NetworkActivityEvent
    - id
    - occurredAt
    - kind
    - title
    - summary
    - relatedProcessName
    - relatedBundleIdentifier
    - relatedSpeedTestID
    - relatedDiagnosisID
    - metadata
```

### 11.5 自动生成规则

建议由 `NetworkEventDetector` 统一生成事件，而不是由各个页面各自记录。

这样可以保证：

- 事件风格统一
- 时间排序一致
- AI 解读能直接读取上下文

## 12. 长期趋势统计

### 12.1 功能目标

长期趋势用于帮助用户回答：

- 最近一周网络是否稳定
- 哪些时段更容易出现高流量
- 上传高峰是否重复出现
- 异常应用是否每天都在后台活跃

### 12.2 存储策略

建议使用本地持久化数据库，优先推荐：

- `SQLite`

原因：

- 趋势查询天然是时间窗口查询
- 需要聚合和裁剪
- 后续需要和时间线、异常、诊断结果做关联

### 12.3 建议存储内容

建议保存以下维度：

- 每分钟总上传平均值 / 峰值
- 每分钟总下载平均值 / 峰值
- 每分钟活跃进程数
- 每分钟异常次数
- 每分钟 Top 进程摘要
- 每小时汇总值

### 12.4 查询视图

建议提供：

- 最近 1 小时
- 最近 24 小时
- 最近 7 天

图表建议：

- 上下行趋势图
- 异常次数柱状图
- 活跃进程热力分布

### 12.5 数据模型

建议新增：

```text
NetworkTrendBucket
    - bucketStart
    - bucketGranularity
    - avgDownloadBytesPerSecond
    - peakDownloadBytesPerSecond
    - avgUploadBytesPerSecond
    - peakUploadBytesPerSecond
    - activeProcessCountAvg
    - anomalyCount
    - topProcessesSummary
```

### 12.6 数据保留策略

建议：

- 1 分钟桶保留 `7 天`
- 1 小时桶保留 `90 天`
- 1 天桶保留 `365 天`

并在后台定期清理旧数据。

## 13. AI 诊断解读

### 13.1 功能目标

AI 解读用于解释以下信息的组合结果：

- 当前网络诊断结果
- 最近一次测速结果
- 当前异常应用
- 最近时间线事件
- 最近一段时间的趋势摘要

### 13.2 角色定位

AI 只负责：

- 总结
- 解释
- 推断可能原因
- 推荐下一步动作

### 13.3 第一版输入范围

建议第一版输入仅包含：

- `NetworkDiagnosisResult`
- 最近一次 `SpeedTestResult`
- 最近 `N` 条时间线关键事件
- 当前 Top 进程排行摘要
- 最近 1 小时趋势摘要

### 13.4 AI 上下文建议

建议构造：

```json
{
  "diagnosis": {
    "headline": "网络路径可用，但 DNS 略慢",
    "summary": "路径和 HTTPS 均成功，DNS 延迟较高"
  },
  "speedTest": {
    "downloadMbps": 82.3,
    "uploadMbps": 15.1,
    "latencyMs": 18
  },
  "topProcesses": [
    {
      "processName": "Google Chrome",
      "downloadMbps": 32.1,
      "uploadMbps": 0.8
    }
  ],
  "recentEvents": [
    {
      "kind": "anomalyHighUpload",
      "summary": "WeChat 在后台持续高上传 90 秒"
    }
  ],
  "trendSummary": {
    "lastHourAnomalyCount": 3,
    "peakUploadMbps": 12.4
  }
}
```

### 13.5 输出结构建议

建议强制模型输出：

```json
{
  "summary": "当前网络整体可用，但后台应用上传较活跃，可能影响交互体验。",
  "severity": "medium",
  "probableCauses": [
    "后台应用持续上传占用带宽",
    "DNS 解析延迟略高"
  ],
  "evidence": [
    "最近 1 小时出现多次高上传异常",
    "最新诊断中 DNS 延迟高于正常水平"
  ],
  "nextSteps": [
    "检查异常应用的同步或备份任务",
    "在带宽空闲时再次测速确认是否恢复"
  ],
  "needMoreData": false
}
```

### 13.6 设置页配置项

建议增加：

- `启用 AI 诊断`
- `提供商名称`
- `Base URL`
- `模型名称`
- `API Key`
- `是否附带最近测速结果`
- `是否附带活动时间线摘要`
- `请求超时`

`API Key` 应存入 `Keychain`。

## 14. UI 落地建议

### 14.1 设置页

在现有 [vm-net/Views/ConfigurationView.swift](/Users/chen/cwork/vm-net/vm-net/Views/ConfigurationView.swift) 中建议新增两个分组：

- `网络活动`
- `AI 诊断`

`网络活动` 分组包含：

- 启用进程排行
- 启用异常提醒
- 提醒阈值
- 历史保留时长

`AI 诊断` 分组包含：

- 启用 AI
- 提供商配置
- 附带数据范围

### 14.2 页面结构

建议在现有页面结构上新增：

- `网络活动页`

页面内部可分为 3 个区域：

- 实时摘要
- 进程排行
- 活动时间线

长期趋势可放在：

- `网络活动页` 下半区切换
- 或独立二级页面

### 14.3 功能入口

本功能建议提供两个入口：

- 主入口：配置窗口中的 `网络活动`
- 快捷入口：状态栏菜单中的 `打开网络活动`

#### 配置窗口主入口

建议在现有 [vm-net/Views/ConfigurationView.swift](/Users/chen/cwork/vm-net/vm-net/Views/ConfigurationView.swift) 页面体系中新增一个与 `测速`、`网络诊断` 同级的页面：

- `activity`

建议将页面枚举扩展为：

```text
settings
activity
speedTest
diagnosis
desktopPet
```

设置首页中增加一个明确入口：

- `网络活动`

点击后进入网络活动页，承载以下内容：

- 进程级流量排行
- 异常应用提醒摘要
- 网络活动时间线
- 长期趋势统计

#### 状态栏菜单快捷入口

建议在 [vm-net/Support/AppControlMenuFactory.swift](/Users/chen/cwork/vm-net/vm-net/Support/AppControlMenuFactory.swift) 中新增一项：

- `打开网络活动`

该入口用于：

- 快速查看当前谁在占网
- 快速进入时间线和趋势页
- 作为常驻后台使用时的高频访问入口

#### 页面职责划分

建议职责划分如下：

- `设置页`
  - 管理开关、阈值、历史保留时长和 AI 配置
- `网络活动页`
  - 承载实时看板、排行、时间线和趋势
- `状态栏菜单`
  - 提供快速打开入口

### 14.4 状态栏菜单增强

建议扩展当前 [vm-net/Support/AppControlMenuFactory.swift](/Users/chen/cwork/vm-net/vm-net/Support/AppControlMenuFactory.swift)：

- 打开网络活动页
- 运行网络诊断
- 立即测速
- 暂停提醒

## 15. 存储与持久化

### 15.1 建议持久化内容

建议持久化：

- 时间线事件
- 趋势桶
- 异常记录
- 最近进程排行摘要
- AI 解读结果摘要

### 15.2 持久化层建议

建议新增一个轻量数据库层，封装：

- 写入趋势桶
- 写入时间线事件
- 查询时间窗口
- 数据清理任务

## 16. 权限与隐私

### 16.1 采集原则

- 默认只做本地处理
- 默认只保留聚合结果
- AI 发送必须由用户主动触发

### 16.2 用户说明

在设置页和 AI 区域应明确说明：

- 进程排行是聚合观察
- AI 解读仅基于本次提供的数据推断
- 用户可关闭历史保留和通知

### 16.3 凭证安全

- API Key 存 Keychain
- 不在日志中打印完整凭证
- 不在 `UserDefaults` 中保存 API Key

## 17. 分阶段实施建议

### 17.1 Phase 1

- 新增 `网络活动页`
- 新增 `ProcessTrafficStore`
- 接入 helper 采集 Top 进程快照
- 展示基础进程排行
- 新增异常规则和本地提醒

### 17.2 Phase 2

- 新增时间线事件系统
- 新增趋势持久化
- 提供最近 24 小时和 7 天图表
- 状态栏菜单增加活动入口

### 17.3 Phase 3

- 新增 AI 诊断设置区
- 新增 `AIDiagnosisStore`
- 将诊断结果、测速结果、异常摘要、趋势摘要组合给 AI
- 结构化展示 AI 结论

### 17.4 Phase 4

- 优化规则权重
- 增加更多时间窗口
- 支持导出趋势摘要
- 支持从时间线快速回看诊断与测速结果

## 18. 验收标准

完成功能后应满足：

- 用户可以看到当前进程级流量 Top 排行
- 用户可以收到异常应用提醒，并可关闭提醒
- 用户可以在时间线中看到关键网络事件
- 用户可以查看最近 24 小时与 7 天的趋势统计
- 用户可以基于本次诊断结果请求 AI 解读
- AI 解读只基于用户明确允许的数据范围
- 应用在后台常驻时不会出现明显性能退化

## 19. 推荐落地结论

当前项目最适合的路线是：

- 将 `vm-net` 明确收敛为“网络可观测与定位”工具
- 第一阶段优先做 `进程级流量排行 + 异常提醒`
- 第二阶段补上 `时间线 + 长期趋势`
- 第三阶段加入 `AI 诊断解读`

这样可以保证：

- 产品边界清晰
- 与现有实时网速、测速、诊断能力强关联
- 每一阶段都能独立交付用户价值
- 迭代节奏清晰
