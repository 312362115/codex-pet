# 动作体系实现计划

## 目标

把桌宠从“几个随机动画轮换”升级为完整动作体系：有动作目录、动作层级、表情/小动作/大动作/交互调度、时间冲突规则、可回归测试和运行资产。

## 验收标准

- 默认调度不再播放完整 `turning`。
- 至少覆盖这些层级：基础姿态、表情动作、微动作、小动作、中动作、大动作、交互动作、调试动作。
- 工作态能低频播放专注动作：扶眼镜、思考、点头、查看笔记。
- 等待态能低频播放陪伴动作：眨眼、慢眨眼、呼吸、重心变化、挥手、左右短瞥、轻微环顾、伸展和半步横移。
- hover/drag/status change 的优先级高于 ambient，不发生旧动作延迟播放。
- 所有新增动作有帧数、时长、目录映射和策略测试。
- 运行时资产可由脚本重建，manifest 记录新增动作。

## 范围

本轮完成“clip-based 动作调度体系”和默认动作池。脸部表情不再作为独立 overlay 或独立高频调度层推进，后续按 [动作立绘自带表情方案](../decisions/2026-05-19-baked-action-expression.md) 把表情直接画进每个动作 clip。

## 阶段

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | 停用默认完整转身，新增 `glance-left/right` | done |
| Phase 2 | 建立动作元数据、层级、优先级和时间线冲突决策 | done |
| Phase 3 | 补齐微动作、小动作、中动作、大动作和交互 clip 资产；脸部表情随动作立绘补齐 | partial |
| Phase 4 | runtime 接入微动作/小动作/大动作/交互多调度器，停用独立表情调度 | done |
| Phase 5 | 文档、验证和交付自检 | done |

## 当前实现约束

- 不引入 runtime ML 插帧。
- 不把正式资产做成 GIF。
- 继续使用 PNG 帧目录，按需补 manifest。
- 不继续用固定坐标在整帧 PNG 上硬画脸部表情；也不新增独立 `ExpressionRenderer`。
- `swift test` 受当前命令行工具链缺少 `Testing` 模块影响，主要回归命令使用 `scripts/test-status-logic.sh`。

## 会话记录

### 2026-05-19

- 已完成：`glance-left/right` 短瞥动作、默认调度移除完整转身、资产生成和验证。
- 已完成：动作 catalog、统一 timeline 冲突决策、微动作/小动作/中动作/大动作/交互 clip 资产、runtime 多调度器接入。
- 已调整：脸部表情不做独立 overlay，改为动作立绘自带表情；独立表情调度已停用。
- 已完成：微动作调度器、右键关注动作、hover 专用微笑、`stretch` / `step-aside` / `posture-reset` 等低频大动作接入。
- 已完成：重建运行帧 772 张；`scripts/test-status-logic.sh` 通过；`scripts/build-app.sh` 通过；`scripts/install.sh --rebuild-assets` 完成安装并重启桌宠。
- 已知环境问题：`swift test` 在当前命令行工具链缺少 Swift `Testing` 模块时失败，状态逻辑回归使用 `scripts/test-status-logic.sh` 覆盖。
