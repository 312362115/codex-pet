# 运行时与素材架构

## 模块概览

| 模块 | 文件 | 职责 |
|------|------|------|
| AppKit 入口 | `Sources/CodexPetCompanion/main.swift` | 创建透明悬浮窗、绘制宠物、处理拖动、右键菜单、定时动作、状态轮询和 Codex 元数据只读查询。 |
| 状态与策略 | `Sources/PetCompanion/CodexActivityStatus.swift` | 定义 Codex 粗状态、工作阶段、宠物展示状态、动画枚举、状态分类、帧数、动作时长和动作套组策略。 |
| 策略测试 | `Tests/PetCompanionStatusTestRunner.swift` | 验证状态分类、展示状态映射、动画映射、帧数和动作套组。 |
| 运行帧生成 | `scripts/build-shirt-skirt-assets.py` | 从参考图生成 `assets/lingxi-ol-hires/` 运行时 PNG 帧。 |
| Rig 资产生成 | `scripts/build-rig-assets.py` | 从当前待机帧机械生成 `assets/lingxi-ol-rig/` PoC 拆层资产。 |
| Rig 资产验证 | `scripts/validate-rig-assets.py` | 校验 rig manifest、body/head 部件图、透明像素和高风险覆盖层禁入规则。 |
| 源码安装 | `scripts/install.sh` | 测试、构建、签名、安装并重启本机桌宠。 |
| Release 打包 | `scripts/package-release.sh` | 生成 GitHub Release 预编译 zip 和 checksum。 |

## 运行时流程

```text
CodexActivityReader
  -> CodexMetadataReader
  -> CodexWorkPhaseClassifier
  -> PetPresentationState
  -> AppDelegate.handlePresentationState
  -> PetAmbientActionPolicy
  -> PetView.play / PetView.settle
  -> PetRenderModePolicy
  -> 高清 PNG 帧 / SpriteKit rig / spritesheet fallback
```

`PetView` 使用 `context.interpolationQuality = .high` 绘制 PNG 帧，并通过 aspect-fit 保持原始帧比例，避免窗口尺寸和素材尺寸不一致时产生拉伸。等待/待命状态下，如果 `assets/lingxi-ol-rig/rig.json` 和部件 PNG 可用，`PetView` 会在宠物绘制区域显示透明 `SKView`，由 `PetRigScene` 播放 `breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle` 和 `wakeUp`。脸部、眼镜和手部相关动作暂时仍走 PNG 帧，避免机械拆层素材产生重复覆盖、脸部线条或手臂穿帮。

默认窗口位置由 `PetWindowPlacementPolicy` 计算，启动时落在当前主屏可见区域左下角，并保留 24px 边距；多屏或菜单栏/Dock 改变可见区域时使用 `visibleFrame.minX/minY`，不再默认放到右下角。

PNG 动作播放使用固定总时长和动态帧间隔。运行时按实际帧数自动计算单帧间隔，避免补帧后动作整体变慢。SpriteKit rig 动作使用同一套 `PetAnimationTimingPolicy` 总时长，但不启动 PNG frame timer，而是通过一次性 timer 推进动作 suite。当前测试已锁定 rig、交互、短动作、大动作和旧表情兼容动作的总时长，避免后续补帧或切换渲染方式时把动作整体拖慢。

## 状态读取

当前只做轻量本地联动，并且只读取 Codex 元数据：

- 进程存在：`com.openai.codex` 或应用名 `Codex`。
- 最近活动：读取 `.codex` 下几个状态文件的修改时间。
- `state_5.sqlite`：只读 `threads`、`thread_goals`、`agent_jobs`、`agent_job_items` 的状态、时间戳和计数字段。
- `logs_2.sqlite`：只统计最近错误级别、工具相关 `target` 和时间戳，不读取 `feedback_log_body`。
- 不读取、不解析、不保存 rollout/session JSONL 正文、用户消息、模型回复或代码内容。

默认阈值：

- `activeThreshold = 8s`：最近活动视为工作中。
- `waitingThreshold = 90s`：最近有线程活动但短时间没有更新时视为等待用户。
- `longWorkingThreshold = 50m`：连续活跃超过阈值时进入长时间工作展示状态。

为了避免状态抖动，runtime 对展示状态额外做防抖：

- 非错误/离线状态切换必须先满足当前状态最小停留时间。
- 候选状态需要持续命中一小段时间后才生效。
- `blockedConcerned` 和 `offlineRest` 保持即时切换，避免错误和离线反馈被延迟。

Codex 元数据先被分类为 `CodexWorkPhase`，再映射为可长期停留的 `PetPresentationState`：

| CodexWorkPhase | PetPresentationState | 展示文案 | 停留姿态 |
|----------------|----------------------|----------|----------|
| `offline` | `offlineRest` | `Codex 离线` | `failed` |
| `idle` | `idleRelaxed` | `Codex 待命` | `waiting` |
| `thinking` | `reviewFocused` | `正在思考` | `review` |
| `runningTool` | `toolRunning` | `运行工具中` | `tap-keyboard` |
| `waitingUser` | `waitingAttentive` | `等待你确认` | `waiting` |
| `blocked` | `blockedConcerned` | `遇到错误` | `failed` |
| `completed` | `completedCalm` | `这轮完成` | `nod` |
| `longWorking` | `longWorkTired` | `连续工作中` | `stretch-wrist` |

## 动作策略

当前动作被分为展示状态、微动作、小动作、中/大动作、交互动作和调试动作，并通过统一时间线处理冲突。展示状态是一等公民，动作结束后回到当前 `PetPresentationState` 的停留姿态，而不是统一回到 `working/waiting/offline` 的单一基础图。

| 类型 | 策略 |
|------|------|
| 展示状态 | `offlineRest`、`idleRelaxed`、`reviewFocused`、`toolRunning`、`waitingAttentive`、`blockedConcerned`、`completedCalm`、`longWorkTired` 都可作为最终展示状态；终态会停在动作 clip 的可读帧，不统一停在第 0 帧。 |
| 表情 | 运行默认动作通过 `PetActionDescriptor.expressions` 携带 baked expression intent；独立脸部覆盖动作不进入默认调度，避免旧红线/贴片素材叠到脸上。 |
| 微动作 | 根据展示状态选择 `breathing`、`weight-shift`、`shoulder-relax`、`hair-sway`、`tiny-hand-adjust`，由独立 timer 低干扰插入；等待态优先可触发 body/head rig 微动作，`hair-sway` 当前是 head/body 代理轻摆。 |
| 小动作 | `reviewFocused` 偏审阅动作，`toolRunning` 偏工具运行动作，`waitingAttentive` 偏回应用户动作，`longWorkTired` 偏舒展恢复动作。 |
| 中/大动作 | 按展示状态低频选择 `glance-left/right`、`focus-shift`、`fix-posture`、`posture-reset`、`stretch`、`look-around` 等动作。 |
| 交互动作 | hover 按展示状态轮换短反馈：等待态用 head/body rig 看光标或播放挥手，思考态扶眼镜/思考，工具态敲键盘/切换焦点，完成态点头/肩部放松；右键在离线态显示 `failed`，其它状态显示 `cursor-look`；drag 释放触发 body rig `drag-release-settle`。 |
| 调试动作 | `turning` 只保留为调试/素材检查，不进入默认调度。 |

所有动作都不连续 loop，播完回到当前展示状态的停留姿态。

调度器拆分为三类 timer 和一类事件触发：

| 调度器 | 运行节奏 | 冲突策略 |
|--------|----------|----------|
| 微动作调度 | working `14-30s`，waiting `18-36s` | 微动作是最低干扰 ambient；hover 时暂停。 |
| 小动作调度 | working `32-68s`，waiting `35-75s` | 小动作可短暂排队，状态变化或交互时丢弃。 |
| 大动作调度 | working `220-360s`，waiting `200-340s` | 只在空窗执行，忙碌、hover、状态刚切换时丢弃。 |
| 交互调度 | hover、右键、drag、状态变化事件驱动 | hover 不抢正在播放的可见动作；右键和拖动仍是高优先级。 |

当前运行资产帧数：

| 动作 | 帧数 | 说明 |
|------|------|------|
| `breathing` | 12 | 低干扰呼吸微动作，优先走 SpriteKit rig。 |
| `hair-sway` | 12 | 当前优先走 SpriteKit head/body 代理轻摆；真实 hair part 等干净头发拆层后再接入。 |
| `weight-shift` | 16 | waiting 重心变化，优先走 SpriteKit rig。 |
| `shoulder-relax` | 16 | 肩部放松微动作，优先走 SpriteKit rig。 |
| `tiny-hand-adjust` | 16 | 手部小幅调整。 |
| `running` | 24 | 主姿态到动作姿态再回到主姿态的透明通道感知补间。 |
| `waving` | 24 | 主姿态到挥手姿态再回到主姿态的透明通道感知补间。 |
| `adjust-glasses` | 24 | 工作态扶眼镜动作。 |
| `thinking` | 24 | 工作态思考动作。 |
| `tap-keyboard` | 24 | 工作态轻敲/处理动作。 |
| `check-notes` | 24 | 工作态查看/思考动作。 |
| `stretch-wrist` | 24 | 长时间工作后的手腕舒展。 |
| `focus-shift` | 24 | 工作态注意力短暂转向用户再回落。 |
| `fix-posture` | 24 | 轻微整理站姿。 |
| `adjust-outfit` | 24 | 等待态低频整理衣服。 |
| `nod` | 16 | 工作态确认动作。 |
| `glance-left` | 16 | 正面姿态到 3/4 侧向姿态再回到正面，作为低频注意力转移动作。 |
| `glance-right` | 16 | 与 `glance-left` 对称，替代默认完整转身。 |
| `cursor-look` | 16 | hover/右键时短暂看向用户；等待/待命 rig 可用时优先走 SpriteKit head/body，PNG 目录保留为 fallback。 |
| `look-around` | 32 | 等待态低频环顾，不展示背面。 |
| `stretch` | 32 | 长时间稳定后的低频伸展。 |
| `step-aside` | 32 | 等待态极低频半步横移。 |
| `posture-reset` | 32 | 长时间无主动作后的站姿重置。 |
| `drag-release-settle` | 12 | 拖动结束后优先走 SpriteKit body 回弹，PNG 目录保留为 fallback。 |
| `wake-up` | 20 | Codex 从离线/等待恢复的轻反馈；等待/待命 rig 可用时优先走 SpriteKit body/head。 |
| `turning` | 25 | 8 张转身关键帧之间插入缓动补间，并回到正面。 |

`blink`、`slow-blink`、`eye-shift-left/right`、`focus-tighten`、`relax-face`、`small-smile`、`tired-soften`、`curious-look`、`hover-smile`、`context-menu-attend` 是旧脸部覆盖方案留下的兼容枚举，不再作为运行素材目录保存，也不进入默认调度。旧目录里的红线覆盖和坐标绘制痕迹会破坏脸部观感，已从 `assets/lingxi-ol-hires/` 清理。状态测试会校验这些动作 `defaultEligible=false`，同时校验所有默认可调度动作都带有非空表情意图。需要不同表情时，使用 `assets/reference/generated/expression-keyframes-v1.png` 这类整帧关键源图重新派生动作帧，不拆五官覆盖层。

## 素材目录

```text
assets/
  lingxi-ol/
    pet.json
    spritesheet.webp
  lingxi-ol-hires/
    idle/
    running/
    waiting/
    failed/
    breathing/
    hair-sway/
    weight-shift/
    shoulder-relax/
    tiny-hand-adjust/
    adjust-glasses/
    thinking/
    nod/
    tap-keyboard/
    check-notes/
    stretch-wrist/
    waving/
    review/
    glance-left/
    glance-right/
    cursor-look/
    focus-shift/
    fix-posture/
    adjust-outfit/
    look-around/
    stretch/
    step-aside/
    posture-reset/
    drag-release-settle/
    wake-up/
    turning/
    manifest.txt
  lingxi-ol-rig/
    rig.json
    parts/
      body.png
      head.png
  reference/generated/
    base-shirt-skirt-hires.png
    action-strip-shirt-skirt-consistent.png
    turntable-strip-shirt-skirt-consistent.png
```

`assets/lingxi-ol/` 是 Codex 标准宠物包备份。当前独立桌宠优先使用 `assets/lingxi-ol-hires/`，只有高清帧缺失时才 fallback 到 spritesheet。

`assets/reference/generated/` 只保留当前运行帧重建所需的 3 张源图。历史探索图、旧 turntable 草稿和旧动作探索图已清理，避免把废弃素材误当作当前来源。

`assets/lingxi-ol-rig/` 是第一版 SpriteKit rig PoC 资产。它从 `waiting/00.png` 机械拆层生成，用于验证透明 `SKView`、动作分流、rig/PNG 切换和打包路径。当前只保留 `body` 和 `head` 两层，用于安全验证呼吸、头部轻摆、重心变化、肩部放松、拖动回弹、唤醒和轻微看向用户；`head` 作为 `body` 的子节点挂载，body 变换会带动 head，再叠加 head 局部动作。它不是最终高质量拆层资产。脸部、头发、眼镜和手部等局部分层需要重新生成或手工修正后再接入。

`scripts/validate-rig-assets.py` 被 `scripts/test-status-logic.sh` 和 `scripts/build-app.sh` 调用。它会拒绝非 `body/head` 的当前 rig 部件、错误父子关系、缺失图片、尺寸不匹配、透明像素隐藏 RGB 污染，以及 `eye`、`face`、`lid`、`hair`、`glasses` 等高风险覆盖层文件名或 part id，防止红线/贴片素材回流到运行包。

## 素材生成约束

`scripts/build-shirt-skirt-assets.py` 的关键参数：

```text
DISPLAY_SIZE = 576x624
MAX_BODY_HEIGHT = 540
MAX_UPSCALE = 1.0
```

这些限制用于解决早期出现过的模糊、毛边和比例变形问题：

- 禁止把小素材放大。
- 抠图后清理绿色背景残留。
- 透明像素写成 `(0,0,0,0)`，减少隐藏色污染。
- 保留人物比例，由运行时 aspect-fit 再绘制到窗口内。
- 相邻关键帧使用 premultiplied-alpha 补间，避免透明边缘在普通 RGBA 混合下变灰或泛色。
- 生成脚本只保留 `RUNTIME_STATES` 清单中的目录，运行前会删除不在清单内的旧状态目录，防止废弃脸部覆盖素材回流。

## 发布包结构

`scripts/package-release.sh` 输出：

```text
dist/
  CodexPetCompanion-macos-arm64/
    CodexPetCompanion.app
    install-release.sh
    README.txt
  CodexPetCompanion-macos-arm64-<version>.zip
  SHA256SUMS.txt
```

Release 只上传带版本号的 zip，避免同一版本出现两个内容相同的 arm64 包。
