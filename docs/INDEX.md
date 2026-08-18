# Codex Pet Companion 文档索引

这个目录保存桌宠开发过程中沉淀下来的项目知识。`memory/` 负责快速恢复上下文，`docs/` 负责长期维护的历史、决策、架构和验证记录。

## 历史记录

- [2026-05-19 桌宠开发会话迁移记录](history/2026-05-19-pet-development-session.md)：从 Codex 内置宠物尝试，到独立 macOS App、高清素材、动作策略和 Release 发布的完整演进。

## 架构说明

- [运行时与素材架构](architecture/runtime-and-assets.md)：AppKit 悬浮窗、Codex 状态读取、动画策略、高清帧加载、素材生成和发布包结构。
- [动作体系设计与实现](architecture/action-system-design.md)：梳理表情、姿态、微动作、主动作、动作组合、场景语义、调度规则、插帧算法、动作 clip 资产和当前落地状态。
- [Codex Dream Skin 主题安装 Agent Runbook](architecture/dream-skin-theme-installation.md)：说明主题与引擎的依赖边界、打包、首次安装、导入、切换授权、实机验证和完整恢复流程。

## 技术方案

- [混合 2D 骨骼动画方案](specs/2026-05-20-hybrid-rig-animation.md)：在保留现有 PNG 大动作的基础上，新增轻量 2D rig 层承载待机和微动作的方案。

## 开发计划

- [动作体系实现计划](plans/action-system-implementation.md)：跟踪完整动作体系的阶段、验收标准、实现约束和会话进度。
- [Codex 状态机联动实现计划](plans/codex-state-machine-implementation.md)：跟踪 Codex 元数据阶段、宠物展示状态和动作流转改造。
- [混合 SpriteKit Rig 实施计划](plans/hybrid-rig-implementation.md)：跟踪 SpriteKit 2D rig 的实现阶段、验收标准和会话进度。

## Backlog

- [Backlog 索引](backlog/INDEX.md)：记录暂不进入当前实现范围、但后续有价值的需求。

## 决策记录

- [改用独立桌宠应用](decisions/2026-05-19-standalone-companion.md)：放弃 patch `Codex.app`，改为独立 companion app 的原因和后续约束。
- [Release 预编译安装包](decisions/2026-05-19-release-packaging.md)：为什么普通用户优先下载 GitHub Release，而不是从源码编译。
- [动作立绘自带表情方案](decisions/2026-05-19-baked-action-expression.md)：记录不做独立脸部 overlay，改为每个动作 clip 自带合适表情的方向。
- [运行素材清理决策](decisions/2026-05-20-runtime-asset-pruning.md)：记录旧脸部覆盖素材、旧调试目录和历史参考图的清理范围与后续约束。

## 验证记录

- [运行时与 Release 验证](tests/runtime-and-release.md)：当前可复用的测试、打包、zip 检查和安装验证命令。
