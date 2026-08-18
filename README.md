# Codex Pet Companion

一个独立的 macOS 桌面宠物 companion。它不修改 `Codex.app`，而是通过原生 AppKit 悬浮窗显示高清宠物帧，并根据 Codex 本地活动状态做轻量联动。

<p align="center">
  <img src="assets/reference/generated/base-shirt-skirt-hires.png" alt="Codex Pet Companion 主图" width="320">
</p>

## 桌宠形象

当前默认桌宠名为 `Lingxi OL`，是一位年轻职场风格的桌面 companion。形象采用白衬衣、黑色包臀裙、眼镜和深色长袜的搭配，整体偏真人感而不是像素或强动画风格。她会在桌面上保持低干扰存在，根据 Codex 的本地活动状态显示工作中、等待输入或离线，并通过偶尔的小动作、转身和鼠标悬停反馈营造轻量陪伴感。

右键菜单支持在不同宠物之间切换。当前内置 `Lingxi OL` 和 `招财猫`：招财猫是白色招财猫形象，带红色项圈、金铃铛、金币和抬起的招手爪。每个宠物有独立行为配置，切换到招财猫时会同步切换到精简动作集，只保留招手、眯眼、摆尾、左右看、环顾、点头和基础状态反馈。`Lingxi OL` 和 `招财猫` 都可以安装为 Codex 原生宠物包，使用标准 `spritesheet.webp` 和 `pet.json`。

## Codex 工作台皮肤

`assets/dream-skin/` 保存独立于桌宠 App 和 Codex 原生宠物包的工作台主题，兼容 Codex Dream Skin 的本地简化主题格式。每套主题都包含 `2560x1440` 纯背景、主题配置和通过 Safe CSS 白名单约束的界面样式。

| 目录 | 主题 | 外观 |
|---|---|---|
| `assets/dream-skin/maneki-neko/` | `招财猫 · 招福工坊` | 奶油金、朱砂红、琥珀金和玉绿的浅色主题。 |
| `assets/dream-skin/lingxi-ol/` | `Lingxi OL · 清透日程` | 暖象牙、灰绿色和香槟金的浅色清透主题。 |

生成可导入的普通 ZIP：

```bash
THEME_SLUG="lingxi-ol" # 或 maneki-neko
mkdir -p dist
ditto -c -k --norsrc --keepParent \
  "assets/dream-skin/$THEME_SLUG" \
  "dist/$THEME_SLUG-dream-skin.zip"
```

在 Codex Dream Skin 菜单栏 App 中选择“导入主题 ZIP…”，导入后从“已保存主题”显式选择需要的主题。Dream Skin 通过本机回环 CDP 应用主题，不修改官方 `Codex.app` / `ChatGPT.app` 或 `app.asar`。

Agent 自动化安装、验证和恢复流程见 [`docs/architecture/dream-skin-theme-installation.md`](docs/architecture/dream-skin-theme-installation.md)。

## 功能

- 独立 macOS App，不 patch Codex 安装包。
- 桌面显示尺寸为 `576x624`。
- 使用 `assets/lingxi-ol-hires/` 中的高清透明 PNG 帧。
- 根据 Codex 本地状态显示 `Codex 工作中`、`等待输入`、`Codex 离线`。
- 平时低干扰待命，按状态插入呼吸、看向用户、扶眼镜、点头、整理姿态等短动作；完整转身只保留为调试/素材检查动作。
- 运行帧包含离线生成的透明通道感知补间，短动作 16-24 帧，转身检查动作 25 帧，播放时长保持稳定。
- 待机/等待态的呼吸、头部轻摆、重心变化、肩部放松、轻微看向用户、拖动落位和唤醒反馈使用轻量 SpriteKit rig；大动作继续播放高清 PNG clip。
- 拖动时暂停动画，使用 AppKit 原生窗口拖动。
- 右键菜单支持选择宠物、打开 Codex 和退出宠物。

## 推荐安装

普通用户优先下载 GitHub Release，不需要源码编译：

[https://github.com/312362115/codex-pet/releases/latest](https://github.com/312362115/codex-pet/releases/latest)

下载带版本号的 `CodexPetCompanion-macos-arm64-<version>.zip`，解压后执行：

```bash
./install-release.sh
```

开发者从源码安装：

```bash
./scripts/install.sh
```

源码安装会同时安装桌宠 App、`Lingxi OL` 原生宠物包和 `招财猫` 原生宠物包；原始素材仍保存在本仓库的 `assets/lingxi-ol/` 和 `assets/maneki-neko/`。

完整说明见 [INSTALL.md](INSTALL.md)。

## 目录

- `Sources/`：Swift/AppKit 源码。
- `Tests/`：轻量策略测试。
- `docs/`：开发历史、架构、决策和验证记录。
- `memory/`：项目级记忆，供后续 Codex 会话快速恢复上下文。
- `INSTALL.md`：安装、验证和排障说明。
- `assets/lingxi-ol-hires/`：当前桌宠实际使用的高清帧。
- `assets/lingxi-ol-rig/`：当前 SpriteKit rig PoC 资产，只包含安全的身体/头部拆层，用于呼吸、头部轻摆、重心变化、肩部放松、轻微看向用户、拖动落位和唤醒反馈。
- `assets/lingxi-ol/`：由当前高清帧派生的 Codex 原生 v2 宠物包，包含 `pet.json` 和 8x11 `spritesheet.webp`。
- `assets/maneki-neko-hires/`：招财猫实际使用的高清透明 PNG 帧。
- `assets/maneki-neko/`：招财猫标准 spritesheet 备份和 `pet.json`。
- `assets/dream-skin/maneki-neko/`：招财猫 Codex 工作台主题，包含背景、主题配置和 Safe CSS。
- `assets/dream-skin/lingxi-ol/`：Lingxi OL Codex 工作台主题，包含背景、主题配置和 Safe CSS。
- `assets/reference/generated/`：当前运行帧重建所需的高清源图。
- `scripts/install.sh`：一键测试、构建、签名、安装并重启桌宠，同时安装 Codex 原生宠物包。
- `scripts/install-codex-native-pet.sh`：把 `Lingxi OL` 和 `招财猫` 安装为 Codex 原生宠物包到 `~/.codex/pets/`。
- `scripts/package-release.sh`：生成可上传到 GitHub Release 的预编译安装包。
- `scripts/build-app.sh`：构建 `.app`。
- `scripts/test-status-logic.sh`：运行策略测试。
- `scripts/validate-rig-assets.py`：校验 rig manifest、部件图、透明像素和高风险脸部/头发覆盖层禁入规则。
- `scripts/validate-maneki-neko-assets.py`：校验招财猫招手、摆尾和左右看动作幅度。
- `scripts/validate-codex-native-pet.py`：按 `spriteVersionNumber` 校验 Codex 原生宠物包的清单、图集尺寸、透明空槽和每格可见内容。
- `scripts/build-hires-assets.py`：旧版临时行图重建脚本，不作为当前运行素材主入口。
- `scripts/build-shirt-skirt-assets.py`：从衬衣包臀裙参考图重建当前运行帧。
- `scripts/build-maneki-neko-assets.py`：可复现生成招财猫高清帧和标准 spritesheet。

## 构建

```bash
./scripts/test-status-logic.sh
./scripts/build-app.sh
codesign --force --deep --sign - build/CodexPetCompanion.app
open build/CodexPetCompanion.app
```

## 安装到本机 Codex 目录

```bash
./scripts/install.sh
```

这会安装 `CodexPetCompanion.app` 到 `~/.codex/pet-companion/`，并把仓库里的 `assets/lingxi-ol/` 和 `assets/maneki-neko/` 复制到 `~/.codex/pets/`。

## 安装 Codex 原生宠物

```bash
./scripts/install-codex-native-pet.sh --rebuild-assets
```

安装后包路径为 `~/.codex/pets/lingxi-ol/` 和 `~/.codex/pets/maneki-neko/`，都包含 `spriteVersionNumber: 2` 的 `pet.json` 和标准 `1536x2288` 的 8x11 `spritesheet.webp`。

## 生成 Release 包

```bash
./scripts/package-release.sh --version 2026.5.1
```

输出在 `dist/`，可直接上传到 GitHub Release。

## 资源说明

当前运行版主用 `assets/lingxi-ol-hires/`，README 顶部展示的主图来自 `assets/reference/generated/base-shirt-skirt-hires.png`。基础待机由这张高清主图生成，短动作来自 `assets/reference/generated/action-strip-shirt-skirt-consistent.png`，转身检查动作来自 `assets/reference/generated/turntable-strip-shirt-skirt-consistent.png`；`failed`、`review`、`waiting`、`nod` 和 `wake-up` 等语义状态会额外使用 `assets/reference/generated/expression-keyframes-v1.png` 中的整帧表情关键帧。裁切时禁止放大，也不再对整个人物做缩放动画；运行帧限制最大人物高度并在 App 内按比例绘制，避免从小图切大图导致模糊和身体比例变形。短动作和转身动作会在生成阶段插入 premultiplied-alpha 补间帧，运行时只播放 PNG 序列，不引入模型依赖。

旧脸部覆盖素材已经从 Lingxi 运行目录清理：`blink`、`eye-shift-*`、`focus-tighten`、`small-smile`、`hover-smile`、`context-menu-attend` 等目录不再打包。运行默认动作通过动作自身帧或 rig 姿态携带表情意图，不再叠加独立脸部、五官或眼睑覆盖层。`scripts/validate-rig-assets.py` 会阻止 `eyes`、`face`、`lid`、`hair`、`glasses` 等高风险覆盖层进入当前 rig 包。重复的静止帧用于动作停顿和节奏控制，不按单帧去重。

招财猫运行版主用 `assets/maneki-neko-hires/`，标准 `assets/maneki-neko/spritesheet.webp` 作为兼容备份。素材由 `scripts/build-maneki-neko-assets.py` 机械生成，只保留 `idle`、`waiting`、`failed`、`waving`、`slow-blink`、`cursor-look`、`glance-left/right`、`look-around`、`hair-sway`、`breathing`、`nod`、`drag-release-settle` 和 `wake-up`。`slow-blink` 是招财猫自己的全帧眯眼动作，不恢复旧的脸部覆盖层。调度层通过 `PetBehaviorProfile.manekiNeko` 避免调用人形桌宠的敲键盘、扶眼镜、拉伸、横移等动作。

## 注意

这个项目只读取 Codex 本地状态文件的修改时间和进程状态，不读取对话内容。
