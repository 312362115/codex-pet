# 运行时与素材架构

## 模块概览

| 模块 | 文件 | 职责 |
|------|------|------|
| AppKit 入口 | `Sources/CodexPetCompanion/main.swift` | 创建透明悬浮窗、绘制宠物、处理拖动、右键菜单、定时动作和状态轮询。 |
| 状态与策略 | `Sources/PetCompanion/CodexActivityStatus.swift` | 定义 Codex 状态、动画枚举、状态分类、帧数和动作套组策略。 |
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

## 状态读取

当前只做轻量本地联动：

- 进程存在：`com.openai.codex` 或应用名 `Codex`。
- 最近活动：读取 `.codex` 下几个状态文件的修改时间。
- 不读取、不解析、不保存任何对话内容。

默认阈值：

- `activeThreshold = 8s`：最近活动视为工作中。
- `waitingThreshold = 90s`：目前工作态之外统一落到等待态，保留阈值用于后续扩展。

## 动作策略

当前动作被分为静止态、小动作和大动作：

| 类型 | 策略 |
|------|------|
| 静止态 | `working -> review`，`waiting -> waiting`，`offline -> failed`。 |
| 小动作 | 工作态轮换 `running`、`waving`、`running`；等待态轮换 `waving`、`running`。 |
| 大动作 | 工作态和等待态都只播放 `turning`。 |
| 鼠标悬停 | 立即触发 `turning`，并暂停常规大动作计时。 |

所有动作都不连续 loop，播完回到当前状态的静止态。

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
    waving/
    jumping/
    review/
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
