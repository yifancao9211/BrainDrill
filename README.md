# BrainDrill

BrainDrill 是一个运行在 macOS 上的认知训练工具，面向日常训练场景，提供统一的训练库、控制台、分析、素材工作台和设置体验。当前版本已经覆盖阅读理解、逻辑推理、注意控制、抑制控制、工作记忆与处理速度等模块。

## 当前能力

- 原生 `SwiftUI` macOS App
- 左侧工作台导航：`控制台`、`训练库`、`分析`、`素材`、`设置`
- 阅读理解、逻辑推理、视觉注意、抑制控制、工作记忆、处理速度等多类训练模块
- 训练计时、错误统计、连续训练、模块反馈与认知画像
- 历史记录、趋势摘要、能力类别概览
- 本地持久化保存训练记录、用户设置与素材工作台数据

## 本地启动

1. 确保已安装完整 Xcode。
2. 如需把命令行工具切到 Xcode，可执行：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

3. 安装 `xcodegen`：

```bash
brew install xcodegen
```

4. 生成工程并运行测试：

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project BrainDrill.xcodeproj \
  -scheme BrainDrill \
  -destination 'platform=macOS'
```

## 信息架构

- `控制台`：今日推荐、连续训练、短板提醒和最近表现
- `训练库`：按能力类别浏览全部训练模块
- `分析`：总览、历史和趋势摘要
- `素材`：抓取、清洗、审核和入库阅读材料
- `设置`：训练参数、AI 配置和本地数据

## 项目结构

- `Sources/App`: App 入口、根壳层、路由、全局状态
- `Sources/Core`: 训练模型、引擎、持久化、统计
- `Sources/Features`: 工作台页面与各训练模块
- `Sources/Shared`: 主题 token、共享视觉组件、展示 profile
- `Tests/BrainDrillTests`: 核心逻辑与本地存储测试

## 后续扩展方向

- 反应力训练
- 数字记忆训练
- 更多趋势图和阶段目标
- iCloud 或服务端同步
