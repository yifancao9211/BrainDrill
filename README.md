# BrainDrill

BrainDrill 是一个运行在 macOS 上的专注训练应用。当前版本聚焦“舒尔特方格训练”，提供完整的训练、记录、统计和设置闭环，并为后续反应力、记忆力等模块预留结构。

## 当前能力

- 原生 `SwiftUI` macOS App
- 三档舒尔特难度：`3x3`、`4x4`、`5x5`
- 训练计时、错误统计、个人最佳提示
- 历史记录、近期趋势、统计面板
- 本地持久化保存训练记录和用户设置

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

## 项目结构

- `Sources/App`: App 入口、路由、全局状态
- `Sources/Core`: 训练模型、持久化、统计
- `Sources/Features`: 训练、历史、统计、设置页面
- `Tests/BrainDrillTests`: 核心逻辑与本地存储测试

## 后续扩展方向

- 反应力训练
- 数字记忆训练
- 更多趋势图和阶段目标
- iCloud 或服务端同步
