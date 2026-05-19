# Codex Pet Companion 文档索引

这个目录保存桌宠开发过程中沉淀下来的项目知识。`memory/` 负责快速恢复上下文，`docs/` 负责长期维护的历史、决策、架构和验证记录。

## 历史记录

- [2026-05-19 桌宠开发会话迁移记录](history/2026-05-19-pet-development-session.md)：从 Codex 内置宠物尝试，到独立 macOS App、高清素材、动作策略和 Release 发布的完整演进。

## 架构说明

- [运行时与素材架构](architecture/runtime-and-assets.md)：AppKit 悬浮窗、Codex 状态读取、动画策略、高清帧加载、素材生成和发布包结构。
- [动作体系设计与实现](architecture/action-system-design.md)：梳理表情、姿态、微动作、主动作、动作组合、场景语义、调度规则、插帧算法、动作 clip 资产和当前落地状态。

## 开发计划

- [动作体系实现计划](plans/action-system-implementation.md)：跟踪完整动作体系的阶段、验收标准、实现约束和会话进度。

## 决策记录

- [改用独立桌宠应用](decisions/2026-05-19-standalone-companion.md)：放弃 patch `Codex.app`，改为独立 companion app 的原因和后续约束。
- [Release 预编译安装包](decisions/2026-05-19-release-packaging.md)：为什么普通用户优先下载 GitHub Release，而不是从源码编译。

## 验证记录

- [运行时与 Release 验证](tests/runtime-and-release.md)：当前可复用的测试、打包、zip 检查和安装验证命令。
