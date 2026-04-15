# AI 诊断功能实现文档

## 1. 目标

为 `vm-net` 增加一个可选的 `AI 诊断` 能力，在保留现有确定性诊断链路的前提下，为用户提供：

- 对当前网络诊断结果的自然语言总结
- 对可能问题原因的推断
- 对后续排查步骤的建议
- 对测速结果和诊断结果的联合解读
- 用户自行配置模型提供商、模型名称和 API Key

本功能的核心定位是：

- `NetworkDiagnosisService` 负责采集事实
- `AI 诊断` 负责解释事实

不允许 AI 直接替代已有的路径、DNS、HTTPS、测速等检测逻辑。

## 2. 产品定义

### 2.1 功能形态

`AI 诊断` 不是单独的一套“网络探测器”，而是建立在已有诊断结果之上的“智能解读层”。

建议在现有 `网络诊断` 页面中增加一个新的区块：

- `AI 解读本次结果`

用户流程如下：

1. 用户先执行一次普通网络诊断
2. 诊断完成后，页面显示 `AI 解读本次结果` 按钮
3. 用户手动触发 AI 诊断
4. 应用将本次诊断快照与可选测速结果发送给用户配置的模型提供商
5. 页面展示结构化解读结果

### 2.2 默认行为

- 默认关闭，不主动请求任何模型服务
- 未配置模型提供商时，不显示可执行的 AI 解读按钮
- 不自动在每次诊断结束后发起请求
- 只有用户点击后，才会发送诊断数据

### 2.3 展示内容

AI 解读结果建议展示为 4 个固定区域：

- `诊断结论`
- `可能原因`
- `依据说明`
- `建议操作`

同时增加一个轻量提示：

- `AI 结论基于本次诊断数据推断，仅供排查参考`

## 3. 设计原则

### 3.1 确定性数据优先

AI 只解释已有数据，不参与底层探测，不决定底层测量结果。

### 3.2 用户手动触发

AI 请求必须由用户主动发起，不能默认自动上传数据。

### 3.3 提供商可配置

应用不绑定单一模型厂商，用户自己配置提供商信息。

### 3.4 安全优先

- API Key 不存入 `UserDefaults`
- API Key 必须使用 Keychain 存储
- 页面中默认不明文展示完整 Key

### 3.5 结构化输出优先

模型输出必须尽量约束为结构化 JSON，而不是直接渲染一大段自由文本。

## 4. 范围

### 4.1 本次实现包含

- 新增 AI 诊断设置区
- 支持用户配置模型提供商
- 支持保存 `Base URL / Model / API Key`
- 支持连接测试
- 支持对“本次网络诊断结果”进行 AI 解读
- 支持可选附带最近一次测速结果
- 支持结构化展示 AI 返回内容

### 4.2 本次实现不包含

- AI 自动连续追问
- 聊天式多轮诊断
- 自动上传长期监控历史
- 自动收集系统日志
- 支持所有模型厂商原生协议

## 5. 提供商方案

### 5.1 V1 推荐方案

第一版优先支持 `OpenAI-compatible` 协议。

这样可以兼容多类提供商：

- OpenAI
- OpenRouter
- DeepSeek 兼容接口
- 硅基流动兼容接口
- 本地 Ollama 兼容接口
- LM Studio 兼容接口

### 5.2 后续可扩展方案

后续可按需增加原生适配器：

- Anthropic
- Gemini
- Azure OpenAI

建议架构上预留 `Provider Adapter`，但第一版只落地 `OpenAICompatibleClient`。

## 6. 配置项定义

建议在现有 `AppPreferences` 基础上增加以下字段：

- `aiDiagnosisEnabled: Bool = false`
- `aiDiagnosisProviderName: String`
- `aiDiagnosisBaseURL: String`
- `aiDiagnosisModel: String`
- `aiDiagnosisIncludeLatestSpeedTest: Bool = true`
- `aiDiagnosisRequestTimeout: Double = 30`

说明：

- `aiDiagnosisEnabled`：是否启用 AI 功能
- `aiDiagnosisProviderName`：提供商名称，仅用于界面展示
- `aiDiagnosisBaseURL`：接口根地址
- `aiDiagnosisModel`：模型名称
- `aiDiagnosisIncludeLatestSpeedTest`：是否附带最近一次测速结果
- `aiDiagnosisRequestTimeout`：请求超时秒数

不建议写入 `AppPreferences` 的字段：

- `apiKey`

`apiKey` 应单独存入 Keychain。

## 7. 存储方案

### 7.1 UserDefaults / AppPreferences

适合存：

- 是否启用
- 提供商名称
- Base URL
- 模型名称
- 是否附带测速结果
- 请求超时

### 7.2 Keychain

适合存：

- API Key

建议新增：

- `Support/KeychainHelper.swift`

或：

- `Services/CredentialStore.swift`

职责：

- 保存 API Key
- 读取 API Key
- 删除 API Key

## 8. 架构方案

### 8.1 推荐结构

```text
NetworkDiagnosisService
    ->
NetworkDiagnosisStore
    ->
AIDiagnosisPayloadBuilder
    ->
AIDiagnosisStore
    ->
AIClient
    ->
OpenAICompatibleClient
    ->
NetworkDiagnosisPageView
```

### 8.2 类型建议

建议新增以下文件：

- `Models/AIDiagnosisPayload.swift`
- `Models/AIDiagnosisResponse.swift`
- `Models/AIDiagnosisResult.swift`
- `Models/AIDiagnosisPhase.swift`
- `Services/AIClient.swift`
- `Services/OpenAICompatibleClient.swift`
- `Stores/AIDiagnosisStore.swift`
- `Support/AIDiagnosisPromptBuilder.swift`
- `Support/KeychainHelper.swift`

### 8.3 角色说明

#### AIDiagnosisStore

职责：

- 管理 AI 诊断状态
- 发起请求
- 保存本次 AI 解读结果
- 管理错误与加载状态

建议状态：

- `idle`
- `requesting`
- `completed`
- `failed`

#### AIClient

职责：

- 抽象模型提供商调用协议

建议接口：

- `analyzeDiagnosis(payload: AIDiagnosisPayload) async throws -> AIDiagnosisResponse`

#### OpenAICompatibleClient

职责：

- 实现基于 `chat/completions` 或兼容响应格式的模型请求
- 拼接请求体
- 解码响应

#### AIDiagnosisPromptBuilder

职责：

- 将诊断结果转换为稳定提示词
- 强约束模型以 JSON 返回固定结构

## 9. 数据来源

AI 诊断的输入数据建议仅来自以下两类：

### 9.1 必选

- 当前 `NetworkDiagnosisResult`
- 当前 `NetworkDiagnosisSnapshot`
- 本次检查项明细

### 9.2 可选

- 最近一次 `SpeedTestResult`

不建议第一版直接上传：

- 长时间原始网速监控历史
- 系统日志
- 用户桌面或系统敏感信息

## 10. 请求与返回设计

### 10.1 输入结构

建议构造统一的 `AIDiagnosisPayload`：

```json
{
  "targetHost": "www.cloudflare.com",
  "diagnosisHeadline": "网络连接正常",
  "diagnosisSummary": "路径、DNS 和 HTTPS 检查均成功",
  "checks": [
    {
      "kind": "path",
      "status": "success",
      "summary": "网络路径可用"
    }
  ],
  "latestSpeedTest": {
    "pingMs": 12,
    "downloadMbps": 152.3,
    "uploadMbps": 41.6
  }
}
```

### 10.2 输出结构

建议强制模型返回：

```json
{
  "summary": "当前网络整体正常，但 DNS 响应略慢。",
  "severity": "low",
  "probableCauses": [
    "当前 DNS 解析路径较慢",
    "目标站点响应链路正常"
  ],
  "evidence": [
    "路径检查成功",
    "HTTPS 连接成功",
    "DNS 延迟高于 HTTPS 建连延迟"
  ],
  "nextSteps": [
    "尝试切换 DNS 服务后重新诊断",
    "如需确认带宽，可继续执行测速"
  ],
  "needMoreData": false
}
```

字段说明：

- `summary`：一句话结论
- `severity`：严重程度，可选 `low / medium / high`
- `probableCauses`：可能原因
- `evidence`：依据
- `nextSteps`：建议操作
- `needMoreData`：是否建议用户继续采集更多信息

## 11. UI 方案

### 11.1 设置页

建议在主配置页新增 `AI 诊断` 分组，配置项如下：

- `启用 AI 诊断`
- `提供商名称`
- `接口地址`
- `模型名称`
- `API Key`
- `连接测试`
- `附带最近一次测速结果`

### 11.2 诊断页

建议在现有 `NetworkDiagnosisPageView` 中新增一个区块：

- `AI 解读`

状态分为：

- 未配置：提示先配置模型提供商
- 可执行：显示 `AI 解读本次结果`
- 请求中：显示加载状态
- 已完成：显示结构化解读结果
- 失败：显示错误提示和重试按钮

### 11.3 结果展示

推荐结构：

- 顶部一行结论
- 下方 3 个分组：
  - 可能原因
  - 依据说明
  - 建议操作

不建议第一版使用聊天气泡式布局。

## 12. Prompt 设计

### 12.1 核心要求

Prompt 应明确要求模型：

- 只依据给定数据推断
- 不编造未出现的系统信息
- 返回 JSON
- 结论保持简洁
- 建议面向普通用户可执行

### 12.2 建议约束

可在系统提示中加入：

- 你是网络诊断助手
- 只能依据输入数据判断
- 如果证据不足，应明确说明不确定
- 不要输出 Markdown
- 仅返回 JSON

## 13. 安全与隐私

### 13.1 数据发送原则

- 不自动发送
- 必须用户主动点击
- 发送前在界面中说明会将诊断数据发送到用户配置的模型提供商

### 13.2 凭证安全

- API Key 存 Keychain
- 设置页输入框使用安全输入
- 不在日志中输出完整凭证

### 13.3 模型结论性质

AI 结果应始终标注为：

- 推断结果
- 仅供参考

避免让用户误以为是系统级确定判断。

## 14. 失败处理

建议处理以下失败场景：

- 未配置 Base URL
- 未配置模型名称
- 未配置 API Key
- 接口不可达
- 认证失败
- 返回数据不是合法 JSON
- 模型超时

UI 侧建议统一给出：

- 简短错误描述
- `重试`
- `前往设置`

## 15. 分阶段实施建议

### 15.1 Phase 1

- 新增 AI 设置区
- 新增 Keychain 存储 API Key
- 新增 `OpenAICompatibleClient`
- 支持对本次诊断结果进行 AI 解读

### 15.2 Phase 2

- 支持附带最近一次测速结果
- 支持连接测试
- 优化错误提示与空状态

### 15.3 Phase 3

- 支持诊断结果历史中的 AI 复读
- 支持更多提供商适配器
- 支持复制 AI 诊断摘要

## 16. 验收标准

完成功能后应满足：

- 用户可在设置页配置模型提供商
- API Key 不保存在 `UserDefaults`
- 未配置时无法触发 AI 诊断
- 已配置时可成功请求模型
- AI 返回结果能稳定渲染为结构化内容
- 诊断页不会因为 AI 区块导致布局错乱
- 失败和超时场景有明确提示

## 17. 推荐落地结论

当前项目最适合的第一版方案是：

- 只支持 `OpenAI-compatible`
- 只做“本次诊断结果”的 AI 解读
- 可选附带最近一次测速结果
- 用户手动触发
- 设置页配置提供商
- API Key 存 Keychain
- 结果使用结构化卡片展示

这个方案对当前 `vm-net` 的代码结构侵入较小，也最容易先做稳。
