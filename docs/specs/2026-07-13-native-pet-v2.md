# Codex 原生宠物 v2 适配方案

## 背景与目标

迁移前，仓库维护的 `Lingxi OL` 与招财猫原生宠物包是 8×9 v1 图集。最新版原生宠物契约要求 8×11、`spriteVersionNumber: 2`、标准动画行未用槽透明，以及两行共 16 个顺时针环视方向。

本次目标是让仓库生成、校验、打包和安装的两个原生宠物包符合 v2 契约，同时保持独立桌宠现有高清 PNG / SpriteKit rig 主路径不变。

## 验收标准

- 两个 `pet.json` 都包含与目录一致的 `id`、`spriteVersionNumber: 2` 和 `spritesheetPath`。
- 两个 `spritesheet.webp` 都是 `1536×2288`、8 列×11 行、单格 `192×208`。
- 标准行顺序固定为 `idle`、`running-right`、`running-left`、`waving`、`jumping`、`failed`、`waiting`、`running`、`review`；未用槽透明，`idle[6]` 保存中性帧。
- 除允许作为失败定格反馈的 `failed` 外，标准动作行必须包含至少两帧不同内容；`running-right` / `running-left` 方向相反，`jumping` 首尾落地且中段明确离地，不允许跨姿态 alpha 混合产生双影。
- rows 9–10 包含经 `hatch-pet` 方向语义、连续性、盲测和视觉 QA 通过的 16 个方向。
- `--rebuild-assets` 只重建标准动画行，并从当前已批准 v2 图集保留中性帧和方向行；缺少已批准 v2 图集时明确失败，不静默降级为 v1。
- 独立桌宠 fallback 按最新版行号和每行实际帧数读取，短动画不会播放透明空槽。
- 状态测试、原生宠物校验、App 构建和安装到临时 `CODEX_HOME` 的回归通过。

## 核心决策

### 最终图集是方向素材的仓库真相源

仓库只保留最终 `assets/<pet-id>/spritesheet.webp`，不提交 imagegen prompt、生成条带、提取帧或临时 QA 目录。构建器重建 rows 0–8 时，从现有 v2 图集中复制 `idle[6]` 与 rows 9–10。这样既保留可复现的标准动画，又不会在普通资产重建中丢失已经过视觉 QA 的方向素材。

### 校验器按版本识别契约

校验器保留 v1 读取能力，便于迁移和诊断旧安装；当 `spriteVersionNumber` 为 2 时严格检查 v2 尺寸、行帧数、透明空槽、中性帧和 16 个方向。仓库源码包最终必须全部为 v2。

### 独立桌宠不消费方向行

rows 9–10 由 Codex 原生宠物 renderer 使用。当前独立桌宠仍优先读取高清 PNG 与 rig；spritesheet 仅作 fallback，因此只需修正标准行映射和 frame count，不新增另一套指针方向渲染逻辑。

## 影响范围

- `Sources/CodexPetCompanion/main.swift`：标准行顺序和 fallback 帧数。
- `scripts/build-shirt-skirt-assets.py`、`scripts/build-maneki-neko-assets.py`：v2 标准行组装、方向行保留和 v2 manifest。
- `scripts/validate-codex-native-pet.py`：v1/v2 契约校验。
- `assets/lingxi-ol/`、`assets/maneki-neko/`：最终 v2 包。
- README、架构文档、安装说明和回归用例：同步 8×11 / v2 事实。

## 风险与边界

- 方向素材必须走 `hatch-pet` 完整 QA；不得用镜像、程序插值或单格拼补替代失败的完整方向行。
- 真人角色图像生成可能触发误判审核；CLI/API fallback 仍需要用户明确授权，不能静默切换。
- 迁移完成前构建器不能生成合格 v2 包，因此先落基础设施，再把通过 QA 的最终图集接入并运行整体回归。
