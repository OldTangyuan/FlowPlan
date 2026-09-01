# FlowPlan 🗒️

一个手机端 TODO（待办事项）管理应用，未来将接入 AI 辅助管理任务。

> [!WARNING]
> 当前为 **v0.1 基础框架版**：TODO 增删改查 + 本地持久化 + 面向 AI 接入的分层架构。

## ✨ 功能（v0.1）

- ✅ 新增 / 编辑 / 删除任务
- ✅ 完成 / 未完成切换
- ✅ 优先级（高 / 中 / 低）
- ✅ 筛选（全部 / 未完成 / 已完成）
- ✅ 统计（已完成 x / 共 y）
- ✅ 本地持久化（SQLite，关闭 App 数据不丢）
- 🔮 AI 管理 TODO（架构已预留，v0.2 实现）

## 🏗️ 技术栈

| 技术                     | 用途        |
| ------------------------ | ----------- |
| Flutter 3.44 / Dart 3.12 | 跨平台框架  |
| Riverpod 3               | 状态管理    |
| sqflite (SQLite)         | 本地数据库  |
| Material 3               | UI 设计语言 |

## 📁 项目结构

```
lib/
├── main.dart                    # 程序入口
├── app.dart                     # 根组件（主题/路由）
├── core/                        # 全局共享
│   ├── constants/               # 常量
│   └── theme/                   # 主题
└── features/                    # 功能模块（feature-first）
    └── todo/
        ├── domain/              # 领域层：模型 + 抽象接口（最稳定）
        ├── data/                # 数据层：SQLite 实现
        ├── application/         # 应用层：业务逻辑（Riverpod）
        └── presentation/        # 表现层：UI 页面
```

## 🚀 快速开始

```bash
# 1. 检查环境
flutter doctor

# 2. 运行测试
flutter test          # 30 个测试

# 3. 静态分析
flutter analyze       # 零警告

# 4. 运行（Android 模拟器/真机）
flutter run
```

## 🗺️ 版本规划

| 版本 | 内容                            | 状态      |
| ---- | ------------------------------- | --------- |
| v0.1 | 基础 TODO + 本地存储 + 分层架构 | ✅ 完成   |
| v0.2 | AI 对话：自然语言添加任务       | 🔜 规划中 |
| v0.3 | AI 排期 + 日历视图 + 通知提醒   | 📋 规划中 |
| v0.4 | 云端同步                        | 📋 规划中 |

## 📄 License

MIT
