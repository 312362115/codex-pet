# 运行素材清理决策

## 背景

本轮视觉检查发现 `assets/lingxi-ol-hires/` 中存在多批历史素材：

- 旧脸部覆盖 clip 会在角色脸部叠出明显线条，尤其是眨眼、视线移动和 hover 笑脸。
- `running-left/right`、`jumping` 等旧目录已经不被当前运行时加载。
- `assets/reference/generated/` 中保留了多张探索期图片，容易被误认为当前资产来源。
- 部分重复帧看起来像冗余，但实际用于停帧和动作节奏，不适合按图片 hash 直接去重。

## 决策

运行素材只保留当前加载器和默认调度会使用的动作目录。旧脸部覆盖目录从运行资产中删除，但相关 `PetAnimation` 枚举和策略描述暂时保留，作为兼容层和后续高质量脸部素材接入点。

当前清理范围：

- 删除旧脸部覆盖目录：`blink`、`slow-blink`、`eye-shift-left`、`eye-shift-right`、`focus-tighten`、`relax-face`、`small-smile`、`tired-soften`、`curious-look`、`hover-smile`、`context-menu-attend`。后续恢复眯眼时必须使用动作一体的全帧素材；当前招财猫的 `slow-blink` 按这个约束重新生成，不恢复旧覆盖层。
- 删除旧调试/旧运行目录：`jumping`、`running-left`、`running-right`。
- 删除历史参考图，仅保留当前重建所需的 3 张源图。
- 删除 `.DS_Store` 等 Finder 元数据。

`scripts/build-shirt-skirt-assets.py` 维护 `RUNTIME_STATES` 清单，生成前会删除不在清单内的旧状态目录，防止废弃素材回流。

## 影响

- 默认 hover、右键和 ambient 路径不再请求已清理的脸部覆盖 clip。
- 运行帧目录体积下降，发布包不再包含红线覆盖素材。
- 后续如果要恢复眨眼、视线移动和笑脸，应重新生成干净的脸部/眼镜/头发拆层或直接烘焙进动作关键帧，而不是复用本轮删除的旧素材。
