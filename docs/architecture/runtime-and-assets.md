# 运行时与素材架构

## 模块概览

| 模块 | 文件 | 职责 |
|------|------|------|
| AppKit 入口 | `Sources/CodexPetCompanion/main.swift` | 创建透明悬浮窗、绘制宠物、处理拖动、右键菜单、定时动作和状态轮询。 |
| 状态与策略 | `Sources/PetCompanion/CodexActivityStatus.swift` | 定义 Codex 状态、动画枚举、状态分类、帧数、动作时长和动作套组策略。 |
| 策略测试 | `Tests/PetCompanionStatusTestRunner.swift` | 验证状态分类、动画映射、帧数和动作套组。 |
| 运行帧生成 | `scripts/build-shirt-skirt-assets.py` | 从参考图生成 `assets/lingxi-ol-hires/` 运行时 PNG 帧。 |
| 源码安装 | `scripts/install.sh` | 测试、构建、签名、安装并重启本机桌宠。 |
| Release 打包 | `scripts/package-release.sh` | 生成 GitHub Release 预编译 zip 和 checksum。 |

## 运行时流程

```text
CodexActivityReader
  -> CodexActivityClassifier
  -> AppDelegate.handleStatus
  -> PetAmbientActionPolicy
  -> PetView.play / PetView.settle
  -> PetFrameProvider
  -> 高清 PNG 帧或 spritesheet fallback
```

`PetView` 使用 `context.interpolationQuality = .high` 绘制帧，并通过 aspect-fit 保持原始帧比例，避免窗口尺寸和素材尺寸不一致时产生拉伸。

动作播放使用固定总时长和动态帧间隔。运行时按实际帧数自动计算单帧间隔，避免补帧后动作整体变慢。

## 状态读取

当前只做轻量本地联动：

- 进程存在：`com.openai.codex` 或应用名 `Codex`。
- 最近活动：读取 `.codex` 下几个状态文件的修改时间。
- 不读取、不解析、不保存任何对话内容。

默认阈值：

- `activeThreshold = 8s`：最近活动视为工作中。
- `waitingThreshold = 90s`：目前工作态之外统一落到等待态，保留阈值用于后续扩展。

## 动作策略

当前动作被分为基础姿态、表情动作、小动作、中/大动作、交互动作和调试动作，并通过统一时间线处理冲突：

| 类型 | 策略 |
|------|------|
| 静止态 | `working -> review`，`waiting -> waiting`，`offline -> failed`。 |
| 表情动作 | `blink`、`slow-blink`、`eye-shift-left/right`、`focus-tighten`、`small-smile` 等，由独立 timer 调度。 |
| 微动作 | `breathing`、`hair-sway`、`weight-shift`、`shoulder-relax`、`tiny-hand-adjust`，由独立 timer 低干扰插入。 |
| 小动作 | 工作态轮换 `adjust-glasses`、`thinking`、`nod`、`tap-keyboard`、`check-notes`、`stretch-wrist`；等待态轮换 `waving`、`small-smile`、`slow-blink`。 |
| 中/大动作 | 工作态轮换 `glance-left/right`、`focus-shift`、`fix-posture`、`posture-reset`、`stretch`；等待态低频加入 `adjust-outfit`、`look-around`、`step-aside`。 |
| 交互动作 | hover 触发 `curious-look -> cursor-look -> hover-smile`；右键触发 `context-menu-attend`；drag 释放触发 `drag-release-settle`。 |
| 调试动作 | `turning` 只保留为调试/素材检查，不进入默认调度。 |

所有动作都不连续 loop，播完回到当前状态的静止态。

调度器拆分为四类 timer 和一类事件触发：

| 调度器 | 运行节奏 | 冲突策略 |
|--------|----------|----------|
| 表情调度 | working `4-9s`，waiting `3-8s`，offline `45-90s` | runtime 暂不做图层 overlay，主动作播放时表情延后。 |
| 微动作调度 | working `6-14s`，waiting `7-16s` | 微动作是最低干扰 ambient；主动作到点时可被更明显动作打断。 |
| 小动作调度 | working `12-30s`，waiting `10-25s` | 小动作可短暂排队，状态变化或交互时丢弃。 |
| 大动作调度 | working `120-210s`，waiting `90-180s` | 只在空窗执行，忙碌、hover、状态刚切换时丢弃。 |
| 交互调度 | hover、右键、drag、状态变化事件驱动 | 可打断 ambient，拖动优先级最高。 |

当前高频动作帧数：

| 动作 | 帧数 | 说明 |
|------|------|------|
| `blink` | 5 | 极短表情 clip。 |
| `slow-blink` | 8 | 等待态慢眨眼。 |
| `eye-shift-left/right` | 8 | 眼神短暂扫动。 |
| `focus-tighten` | 12 | 进入工作态的专注表情过渡。 |
| `small-smile` | 12 | 轻交互或等待态正反馈。 |
| `hover-smile` | 12 | hover 专用轻微微笑。 |
| `context-menu-attend` | 12 | 右键菜单打开时的关注反馈。 |
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
  CodexPetCompanion-macos-arm64.zip
  SHA256SUMS.txt
```

稳定文件名 `CodexPetCompanion-macos-arm64.zip` 用于 GitHub latest asset 下载，带版本号文件用于明确归档。
