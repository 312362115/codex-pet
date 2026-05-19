# Codex Pet Companion

一个独立的 macOS 桌面宠物 companion。它不修改 `Codex.app`，而是通过原生 AppKit 悬浮窗显示高清宠物帧，并根据 Codex 本地活动状态做轻量联动。

## 功能

- 独立 macOS App，不 patch Codex 安装包。
- 桌面显示尺寸为 `576x624`。
- 使用 `assets/lingxi-ol-hires/` 中的高清透明 PNG 帧。
- 根据 Codex 本地状态显示 `Codex 工作中`、`等待输入`、`Codex 离线`。
- 平时静止，低频随机播放短动作。
- 拖动时暂停动画，使用 AppKit 原生窗口拖动。
- 右键菜单支持打开 Codex 和退出宠物。

## 目录

- `Sources/`：Swift/AppKit 源码。
- `Tests/`：轻量策略测试。
- `assets/lingxi-ol-hires/`：当前桌宠实际使用的高清帧。
- `assets/lingxi-ol/`：Codex 标准宠物包备份。
- `assets/reference/generated/`：后续 3D 多视角和动作设计的生成参考图。
- `scripts/build-app.sh`：构建 `.app`。
- `scripts/test-status-logic.sh`：运行策略测试。
- `scripts/build-hires-assets.py`：从生成行图重建高清帧的资产脚本。

## 构建

```bash
./scripts/test-status-logic.sh
./scripts/build-app.sh
codesign --force --deep --sign - build/CodexPetCompanion.app
open build/CodexPetCompanion.app
```

## 安装到本机 Codex 目录

```bash
mkdir -p "$HOME/.codex/pet-companion"
ditto build/CodexPetCompanion.app "$HOME/.codex/pet-companion/CodexPetCompanion.app"
open "$HOME/.codex/pet-companion/CodexPetCompanion.app"
```

## 资源说明

当前运行版使用 `assets/lingxi-ol-hires/`。`assets/reference/generated/` 中保留了新的 3D 多视角、清凉 OL 服装和自然动作参考图，后续可以继续切成转身、侧身、背身动作帧并接入 companion。

## 注意

这个项目只读取 Codex 本地状态文件的修改时间和进程状态，不读取对话内容。
