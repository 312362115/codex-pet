# 动作立绘自带表情方案

## 背景

动作体系已经有动作 catalog、调度器和 `PetExpression` 语义标签，但脸部视觉表达仍不完整。之前评估过两条路线：

- 在整帧 PNG 上按固定坐标绘制脸部表情。
- 做独立脸部 overlay，由 runtime 把眼睛、眉毛、嘴巴合成到动作帧上。

第一条会产生明显贴图感和坐标脆弱性，不进入主线。第二条更灵活，但现在会把素材结构、渲染顺序、mask、anchor 和动作兼容性一次性复杂化。

当前采用更直接的方案：**表情跟动作立绘一起烘焙，每个动作 clip 自带适合该动作语义的表情**。

## 决策

短期不做独立脸部 overlay，也不单独调度脸部表情层。`PetExpression` 保留为动作语义标签，用来说明一个动作应该呈现什么情绪，而不是代表 runtime 上的独立图层。

动作资产的最小单位仍是完整 PNG clip：

```text
action clip = 身体姿态 + 手臂/头发/衣服变化 + 适合该动作的脸部表情
```

## 动作与表情匹配

| 动作场景 | 推荐表情 | 说明 |
|----------|----------|------|
| `review`、`adjust-glasses`、`tap-keyboard` | `focused` | 工作态保持专注，不需要夸张笑脸。 |
| `thinking`、`check-notes` | `thinking` | 视线偏移、嘴部收敛，表达思考。 |
| `nod`、`focus-shift` | `focused` 或 `curious` | 确认/注意力转移，轻微变化即可。 |
| `waving`、`cursor-look`、`wake-up` | `curious` 或 `happy` | 用户交互反馈，表情可以更明确。 |
| `weight-shift`、`shoulder-relax`、`stretch` | `neutral` 或 `tired` | 等待或舒展，不做强情绪。 |
| `failed` | `error` | 离线或不可用，低干扰。 |

## Runtime 调整

- 停用独立 expression timer，不再高频单独播放 `blink`、`eye-shift`、`small-smile`。
- 默认 ambient 只调度微动作、小动作、大动作和交互动作。
- `expressions` 字段继续保留在 `PetActionDescriptor`，作为动作资产生成和验收时的语义约束。
- 旧的 expression clip 描述保留但不进入默认调度，仅用于枚举和策略兼容；对应运行素材目录已清理，避免红线覆盖素材回流。

## TODO

- 为每个默认动作明确首选表情，优先覆盖高频动作：`review`、`waiting`、`adjust-glasses`、`thinking`、`waving`、`cursor-look`。
- 重新生成动作立绘时，把对应表情直接画进每个动作关键帧和补间帧。
- 生成动作 contact sheet，按“动作是否能读出情绪”做人工验收。
- 增加轻量资产检查：默认调度动作必须有表达语义，不再要求存在独立脸部 overlay。
- 长期如果动作数量和表情组合爆炸，再重新评估局部分层；在当前阶段不提前引入。

## 暂不做

- 不在整帧 PNG 上硬编码坐标画脸部 patch。
- 不做独立 `ExpressionRenderer`。
- 不单独调度脸部 overlay。
- 不为所有动作乘以所有表情生成组合资产，只给每个动作配最合适的一种或少数几种表情。
