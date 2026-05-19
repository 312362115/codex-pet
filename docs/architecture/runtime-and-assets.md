# 运行时与素材架构

## 模块概览

| 模块 | 文件 | 职责 |
|------|------|------|
| AppKit 入口 | `Sources/CodexPetCompanion/main.swift` | 创建透明悬浮窗、绘制宠物、处理拖动、右键菜单、定时动作、状态轮询和 Codex 元数据只读查询。 |
| 状态与策略 | `Sources/PetCompanion/CodexActivityStatus.swift` | 定义 Codex 粗状态、工作阶段、宠物展示状态、动画枚举、状态分类、帧数、动作时长和动作套组策略。 |
| 策略测试 | `Tests/PetCompanionStatusTestRunner.swift` | 验证状态分类、展示状态映射、动画映射、帧数和动作套组。 |
| 运行帧生成 | `scripts/build-shirt-skirt-assets.py` | 从参考图生成 `assets/lingxi-ol-hires/` 运行时 PNG 帧。 |
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
  -> PetFrameProvider
  -> 高清 PNG 帧或 spritesheet fallback
```

`PetView` 使用 `context.interpolationQuality = .high` 绘制帧，并通过 aspect-fit 保持原始帧比例，避免窗口尺寸和素材尺寸不一致时产生拉伸。

动作播放使用固定总时长和动态帧间隔。运行时按实际帧数自动计算单帧间隔，避免补帧后动作整体变慢。

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
| 微动作 | 根据展示状态选择 `breathing`、`hair-sway`、`weight-shift`、`shoulder-relax`、`tiny-hand-adjust`，由独立 timer 低干扰插入。 |
| 小动作 | `reviewFocused` 偏审阅动作，`toolRunning` 偏工具运行动作，`waitingAttentive` 偏回应用户动作，`longWorkTired` 偏舒展恢复动作。 |
| 中/大动作 | 按展示状态低频选择 `glance-left/right`、`focus-shift`、`fix-posture`、`posture-reset`、`stretch`、`look-around` 等动作。 |
| 交互动作 | hover 按展示状态轮换短反馈：等待态看光标/挥手，思考态收紧专注/扶眼镜，工具态敲键盘/切换焦点，完成态微笑/点头；右键触发 `context-menu-attend`；drag 释放触发 `drag-release-settle`。 |
| 调试动作 | `turning` 只保留为调试/素材检查，不进入默认调度。 |

所有动作都不连续 loop，播完回到当前展示状态的停留姿态。

调度器拆分为三类 timer 和一类事件触发：

| 调度器 | 运行节奏 | 冲突策略 |
|--------|----------|----------|
| 微动作调度 | working `14-30s`，waiting `18-36s` | 微动作是最低干扰 ambient；hover 时暂停。 |
| 小动作调度 | working `32-68s`，waiting `35-75s` | 小动作可短暂排队，状态变化或交互时丢弃。 |
| 大动作调度 | working `220-360s`，waiting `200-340s` | 只在空窗执行，忙碌、hover、状态刚切换时丢弃。 |
| 交互调度 | hover、右键、drag、状态变化事件驱动 | hover 不抢正在播放的可见动作；右键和拖动仍是高优先级。 |

当前高频动作帧数：

| 动作 | 帧数 | 说明 |
|------|------|------|
| `blink` / `slow-blink` / `eye-shift-left/right` | 5-8 | 旧表情 clip 资产保留，但不进入默认独立调度。 |
| `focus-tighten` / `small-smile` / `hover-smile` / `context-menu-attend` | 12 | 旧表情/交互 clip 资产保留；后续应改为动作立绘自带表情。 |
| `breathing` | 12 | 低干扰呼吸微动作。 |
| `hair-sway` | 12 | 头发/整体轮廓轻摆。 |
| `weight-shift` | 16 | waiting 重心变化。 |
| `shoulder-relax` | 16 | 肩部放松微动作。 |
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
| `cursor-look` | 16 | hover 时短暂看向用户。 |
| `look-around` | 32 | 等待态低频环顾，不展示背面。 |
| `stretch` | 32 | 长时间稳定后的低频伸展。 |
| `step-aside` | 32 | 等待态极低频半步横移。 |
| `posture-reset` | 32 | 长时间无主动作后的站姿重置。 |
| `wake-up` | 20 | Codex 从离线/等待恢复的轻反馈。 |
| `turning` | 25 | 8 张转身关键帧之间插入缓动补间，并回到正面。 |

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
    blink/
    slow-blink/
    eye-shift-left/
    eye-shift-right/
    focus-tighten/
    relax-face/
    small-smile/
    tired-soften/
    curious-look/
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
    jumping/
    review/
    glance-left/
    glance-right/
    cursor-look/
    hover-smile/
    context-menu-attend/
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
  reference/generated/
    base-shirt-skirt-hires.png
    action-strip-shirt-skirt-consistent.png
    turntable-strip-shirt-skirt-consistent.png
```

`assets/lingxi-ol/` 是 Codex 标准宠物包备份。当前独立桌宠优先使用 `assets/lingxi-ol-hires/`，只有高清帧缺失时才 fallback 到 spritesheet。

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
