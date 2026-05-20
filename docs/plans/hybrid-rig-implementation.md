# 混合 SpriteKit Rig 实施计划

## 目标

在不重写 AppKit 桌宠的前提下，引入轻量 SpriteKit 2D rig。大动作继续使用现有高清 PNG clip，待机和微动作由透明 `SKView` 承载，提升长期停留时的生命感。

关联方案：[混合 2D 骨骼动画方案](../specs/2026-05-20-hybrid-rig-animation.md)。

## 验收标准

- `breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp` 可映射为 `spriteKitRigMotion`；`cursorLook` 和 `hairSway` 只做 head/body 轻微代理动作，不叠加脸部或头发覆盖层。
- `blink`、`slowBlink`、`eyeShiftLeft/right` 等旧脸部覆盖动作只保留兼容枚举，运行素材目录已清理，默认不调度。
- `waving`、`turning`、`tapKeyboard`、`stretch` 等大动作继续走 PNG `frameClip`。
- `assets/lingxi-ol-rig/` 被打进 `CodexPetCompanion.app/Contents/Resources/`。
- `scripts/validate-rig-assets.py` 校验 rig manifest、body/head 部件图、透明像素和高风险脸部/头发覆盖层禁入规则，并被 `test-status-logic.sh` / `build-app.sh` 调用。
- rig 资产缺失时不影响 App 启动，自动回退到 PNG 帧。
- `./scripts/test-status-logic.sh` 和 `./scripts/build-app.sh` 通过。

## 阶段

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | 新增动作渲染模式策略、SpriteKit rig runtime、PoC 拆层资产和 bundle 复制 | done |
| Phase 2a | 使用现有 body/head rig 扩展非脸部微动作：`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp` | done |
| Phase 2b | 重新生成表情和动作一体的高质量全帧素材；不再拆独立五官/眼睑覆盖层 | pending |
| Phase 3 | 增加 rig 资产自动化检查、fallback 安装验证文档和构建守护 | done |
| Phase 4 | 视觉验收后决定是否扩展肩膀/手部微动作或评估专业 runtime | pending |

## 当前会话记录

### 2026-05-20

- 已完成：`PetRenderMode` / `PetRenderModePolicy`，策略测试覆盖 rig 与 PNG 分流。
- 已完成：`PetRigProvider`、`PetRigView`、`PetRigScene` 最小实现，等待/待命状态可显示 SpriteKit rig。
- 已完成：`scripts/build-rig-assets.py` 生成 `assets/lingxi-ol-rig/` PoC 资产。
- 已完成：`scripts/build-app.sh` 增加 SpriteKit 链接和 rig 资源复制；`install.sh` / `package-release.sh --rebuild-assets` 同步生成 rig 资产。
- 已调整：脸部/眼睛/眼镜/头发机械拆层会出现重复覆盖和线条，当前不打包独立覆盖层，只保留 `breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp` 使用 SpriteKit rig；`cursorLook` / `hairSway` 只转 head/body，不使用脸部或头发覆盖素材。
- 已清理：旧脸部覆盖运行素材、`jumping` 调试目录、`running-left/right` 旧目录和历史参考图不再保留；生成脚本会主动删除不在运行清单内的旧目录。
- 已完成 Phase 2a：`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle` 和 `wakeUp` 走 SpriteKit rig，使用 body/head 层做头部轻摆、轻移、轻旋转、肩部下沉、拖动回弹和轻微看向用户，不触碰脸部覆盖素材。
- 已完成骨骼层级：`rig.json` 的 `head.parent` 指向 `body`，运行时按 parent 挂载节点；body 变换会带动 head，再叠加 head 局部动作。
- 已完成表情安全策略：默认动作通过 `PetActionDescriptor.expressions` 携带 baked expression intent；独立脸部覆盖动作保持 `defaultEligible=false`，不进入默认调度；状态测试覆盖所有默认动作都有非空表情意图。
- 已完成定时回归：`PetAnimationTimingPolicy` 统一管理 PNG 和 rig 动作总时长；测试覆盖旧表情兼容动作、rig 微动作、交互动作、短动作和大动作的固定时长与关键帧间隔。
- 已接入调度：`waitingAttentive` 微动作池加入 `weightShift` 和 `shoulderRelax`，等待用户时会低频触发更多 rig 微动作。
- 已调整：桌宠默认启动位置从右下角改为当前屏幕可见区域左下角，保留 24px 边距；多屏偏移由 `PetWindowPlacementPolicy` 统一计算并覆盖测试。
- 已完成 Phase 3：新增 `scripts/validate-rig-assets.py`，校验 rig manifest、body/head 部件、透明像素和高风险脸部/头发覆盖层禁入规则；`test-status-logic.sh` 与 `build-app.sh` 已接入该验证。
- 已修正：撤销独立眼睑 rig 尝试；当前运行包只允许 `body/head`，表情继续和动作帧一体，不走单独覆盖层。
- 已完成整套动作表情复核：`failed`、`review`、`waiting`、`idle` 当前都直接复用同一基础表情，语义区分不足；`adjust-glasses`、`tap-keyboard`、`thinking`、`check-notes` 等工作动作已有姿态变化，但表情仍偏接近；`wake-up` 中段存在补间导致的脸部轻微虚影。
- 已完成第一版表情一体关键帧接入：新增 `assets/reference/generated/expression-keyframes-v1.png`，用于 `failed`、`review`、`waiting`、`nod` 和 `wake-up` 等语义状态；动态挥手/伸展等跨源补间会产生重影，第一版暂不接入这些动作。
- 已修正动作调度过保守的问题：首轮小动作从 24-40 秒缩短为 8-14 秒，首轮大动作从 140-220 秒缩短为 24-38 秒；等待/待机小动作池扩展为多动作轮转，避免实际运行只在少数动作里循环。
- 下一步：如需进一步提升动态动作表情，需要重新生成同一动作内部连续关键帧，而不是把不同源图交叉补间。

## 表情一体化重生成候选

| 优先级 | 候选源帧 | 覆盖动作 | 表情目标 | 说明 |
|--------|----------|----------|----------|------|
| P0 | `failed_concerned` | `failed`、`blockedConcerned` 停留态 | 轻微担忧、低能量、嘴角收住 | 当前 `failed` 与 idle 完全同脸，离线/失败状态读不出来。 |
| P0 | `review_focused` | `review`、`focus-shift`、`tap-keyboard`、`check-notes` | 专注、眼神收紧、轻微严肃 | 工作/评审态需要和等待态拉开，不靠单独眼睛覆盖。 |
| P0 | `waiting_expectant` | `waiting`、`cursor-look`、`waving` 入口帧 | 期待、友好、轻微好奇 | 等待用户输入时应更像“等你确认”，但不能加问号、气泡或浮动符号。 |
| P1 | `completed_soft_smile` | `nod`、`completedCalm` 停留态 | 轻松、克制微笑 | 完成态现在主要靠点头位移，情绪反馈偏弱。 |
| P1 | `tired_soft` | `stretch`、`stretch-wrist`、`longWorkTired` 停留态 | 疲惫但不沮丧 | 长时间工作需要和普通 stretch 区分。 |
| P1 | `wake_up_clear` | `wake-up` 中段关键帧 | 清醒抬头、脸部清晰 | 替换当前由整帧位移补间造成的轻微虚影。 |

生成约束：

- 必须是整个人物完整帧，表情、头部、手势和身体姿态一体生成。
- 背景继续使用可移除的纯色 chroma key；不得有文字、符号、红线、网格、阴影、气泡或独立装饰。
- 不新增 `blink`、`eye`、`face`、`lid`、`mouth`、`smile` 等局部 part；`scripts/validate-rig-assets.py` 继续阻止这些覆盖层进入 rig。
- 新素材先保存为版本化参考图，视觉 QA 通过后再接入 `scripts/build-shirt-skirt-assets.py` 的源帧映射。
