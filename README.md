# Codex Pet Companion

一个独立的 macOS 桌面宠物 companion。它不修改 `Codex.app`，而是通过原生 AppKit 悬浮窗显示高清宠物帧，并根据 Codex 本地活动状态做轻量联动。

<p align="center">
  <img src="assets/reference/generated/base-shirt-skirt-hires.png" alt="Codex Pet Companion 主图" width="320">
</p>

## 桌宠形象

当前桌宠名为 `Lingxi OL`，是一位年轻职场风格的桌面 companion。形象采用白衬衣、黑色包臀裙、眼镜和深色长袜的搭配，整体偏真人感而不是像素或强动画风格。她会在桌面上保持低干扰存在，根据 Codex 的本地活动状态显示工作中、等待输入或离线，并通过偶尔的小动作、转身和鼠标悬停反馈营造轻量陪伴感。

## 功能

- 独立 macOS App，不 patch Codex 安装包。
- 桌面显示尺寸为 `576x624`。
- 使用 `assets/lingxi-ol-hires/` 中的高清透明 PNG 帧。
- 根据 Codex 本地状态显示 `Codex 工作中`、`等待输入`、`Codex 离线`。
- 平时静止，小动作约 4-8 秒一次，转身等大动作约 55-95 秒一次；鼠标悬停会立即触发同源转身动作。
- 运行帧包含离线生成的透明通道感知补间，短动作 24 帧、转身 25 帧，播放时长保持稳定。
- 拖动时暂停动画，使用 AppKit 原生窗口拖动。
- 右键菜单支持打开 Codex 和退出宠物。

## 推荐安装

普通用户优先下载 GitHub Release，不需要源码编译：

[https://github.com/312362115/codex-pet/releases/latest](https://github.com/312362115/codex-pet/releases/latest)

下载 `CodexPetCompanion-macos-arm64.zip`，解压后执行：

```bash
./install-release.sh
```

开发者从源码安装：

```bash
./scripts/install.sh
```

完整说明见 [INSTALL.md](INSTALL.md)。

## 目录

- `Sources/`：Swift/AppKit 源码。
- `Tests/`：轻量策略测试。
- `docs/`：开发历史、架构、决策和验证记录。
- `memory/`：项目级记忆，供后续 Codex 会话快速恢复上下文。
- `INSTALL.md`：安装、验证和排障说明。
- `assets/lingxi-ol-hires/`：当前桌宠实际使用的高清帧。
- `assets/lingxi-ol/`：旧版标准 spritesheet 备份，当前不作为主展示资源。
- `assets/reference/generated/`：后续 3D 多视角和动作设计的生成参考图。
- `scripts/install.sh`：一键测试、构建、签名、安装并重启桌宠。
- `scripts/package-release.sh`：生成可上传到 GitHub Release 的预编译安装包。
- `scripts/build-app.sh`：构建 `.app`。
- `scripts/test-status-logic.sh`：运行策略测试。
- `scripts/build-hires-assets.py`：从生成行图重建高清帧的资产脚本。
- `scripts/build-shirt-skirt-assets.py`：从衬衣包臀裙参考图重建当前运行帧。

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

## 生成 Release 包

```bash
./scripts/package-release.sh --version 2026.5.1
```

输出在 `dist/`，可直接上传到 GitHub Release。

## 资源说明

当前运行版主用 `assets/lingxi-ol-hires/`，README 顶部展示的主图来自 `assets/reference/generated/base-shirt-skirt-hires.png`。静止、工作、等待等主态由这张高清主图生成，短动作来自 `assets/reference/generated/action-strip-shirt-skirt-consistent.png`，转身来自 `assets/reference/generated/turntable-strip-shirt-skirt-consistent.png`。裁切时禁止放大，也不再对整个人物做缩放动画；运行帧限制最大人物高度并在 App 内按比例绘制，避免从小图切大图导致模糊和身体比例变形。短动作和转身动作会在生成阶段插入 premultiplied-alpha 补间帧，运行时只播放 PNG 序列，不引入模型依赖。

## 注意

这个项目只读取 Codex 本地状态文件的修改时间和进程状态，不读取对话内容。
