# vm-net

[English](README.md) | [简体中文](README.zh-CN.md)

`vm-net` 是一个面向 macOS 的菜单栏网络工具，重点放在常驻可观测性和快速排障上。它把实时网速监控、可拖拽悬浮胶囊、进程级网络活动分析、内置测速、网络诊断，以及可选的桌面宠物叠层整合到了同一个应用里。

## 功能亮点

- 基于统一数据链路的实时上下行速率监控
- 菜单栏双行网速展示
- 可拖拽的悬浮胶囊，支持位置、颜色和透明度持久化
- `网络活动` 页面支持进程流量排行、异常提醒、事件时间线和快速进程操作
- 基于 Measurement Lab（M-Lab / NDT7）的测速流程
- 内置网络诊断流程，覆盖路径、DNS 和 HTTPS 检查，并保留最近诊断历史
- 可选 `桌面宠物` 叠层，包含漫游行为、Rive 动画渲染和基于 StoreKit 的解锁流程
- 内置英文与简体中文双语界面

## 当前范围

当前仓库已经落地的应用页面包括：

- `设置`：展示模式、启动行为、悬浮胶囊、多语言和活动提醒等配置
- `网络活动`：进程流量、异常提醒、时间线和实时摘要
- `测速`：延迟、下载、上传和最近测速结果
- `网络诊断`：预设目标诊断与历史记录
- `桌面宠物`：依附悬浮胶囊的可选宠物叠层

[`docs/ai-diagnosis-implementation.md`](docs/ai-diagnosis-implementation.md) 当前属于后续功能的设计文档，还没有在现有代码里完整落地。

## 运行要求

- macOS `13.5` 及以上
- 建议使用 Xcode `16.3` 或以上版本
- 进行测速和网络诊断时需要联网

## 构建与运行

### 方式 1：使用 Xcode

1. 打开 [`vm-net.xcodeproj`](vm-net.xcodeproj)。
2. 选择 `vm-net` scheme。
3. 在 macOS 目标上直接运行。

### 方式 2：使用脚本

```bash
./script/build_and_run.sh
```

首次构建会通过 Swift Package Manager 拉取 `RiveRuntime` 依赖。

## 项目结构

```text
vm-net/
  App/           应用生命周期、偏好设置、窗口管理
  MenuBar/       菜单栏 UI 与状态项控制器
  FloatingBall/  悬浮胶囊窗口与内容
  DesktopPet/    桌宠世界、渲染桥接与行为引擎
  Models/        数据模型与快照
  Services/      监控、诊断、测速与进程服务
  Stores/        长生命周期状态仓库
  Views/         SwiftUI 页面
  Support/       格式化、国际化与通用辅助
docs/            实现说明与设计文档
site/            静态隐私政策页面
img/             品牌与截图资源
```

## 隐私与数据说明

- 应用整体以本地存储偏好设置和最近结果为主。
- 测速功能会访问外部的 Measurement Lab 服务。
- 网络诊断会访问当前选定的诊断目标。
- 桌面宠物的购买与恢复购买依赖 Apple StoreKit。

当前隐私页面位于 [`site/privacy-policy.html`](site/privacy-policy.html)。

## 相关文档

- [网速展示形态设计](docs/throughput-display-implementation.md)
- [桌面宠物实现文档](docs/desktop-pet-implementation.md)
- [网络可观测实现文档](docs/network-observability-implementation.md)
- [AI 诊断设计文档](docs/ai-diagnosis-implementation.md)

## 许可证

项目采用 [MIT License](LICENSE)。
