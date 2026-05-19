---
type: project
updated: 2026-05-19
source: migrated-from-current-codex-pet-development-session
---

# Codex Pet Companion 项目上下文

## 项目定位

`codex-pet` 是独立 macOS 桌宠 companion，不 patch `Codex.app`。它通过 AppKit 透明悬浮窗显示高清角色帧，并用轻量本地状态推断展示 Codex 工作中、等待输入或离线。

## 当前仓库

- 本地路径：`/Users/renlongyu/workspace/codex-pet`
- 远端：`git@github.com:312362115/codex-pet.git`
- 最新 Release：`v2026.5.1`
- Release URL：`https://github.com/312362115/codex-pet/releases/tag/v2026.5.1`

## 核心决策

- 不再 patch `Codex.app`。早期 patch 方向导致 Codex 退出重启和崩溃风险，独立 companion 更稳。
- 普通用户通过 GitHub Release 预编译 zip 安装，不要求从源码编译。
- 源码安装只用于开发者改代码、改素材或本地验证。
- 当前只正式支持 macOS arm64。

## 视觉和素材约束

- 当前形象是年轻职场 OL 风格：白衬衣、黑色包臀裙、眼镜、黑丝，保持本地桌宠和职场穿搭边界，避免露骨内容。
- 运行帧目录：`assets/lingxi-ol-hires/`。
- 主参考图：`assets/reference/generated/base-shirt-skirt-hires.png`。
- 短动作参考：`assets/reference/generated/action-strip-shirt-skirt-consistent.png`。
- 转身参考：`assets/reference/generated/turntable-strip-shirt-skirt-consistent.png`。
- 生成运行帧使用 `scripts/build-shirt-skirt-assets.py`。
- 禁止从小图放大，`MAX_UPSCALE=1.0`；显示尺寸 `576x624`；最大人物高度 `540`。

## 动作策略

- 所有动作播完即回到静止态，不持续 loop。
- 小动作：初始 `2-4s`，后续 `4-8s`。
- 大动作：初始 `35-55s`，后续 `55-95s`。
- 鼠标悬停立即触发转身。
- 工作态静止为 `review`，小动作轮换 `running`、`waving`、`running`。
- 等待态静止为 `waiting`，小动作轮换 `waving`、`running`。
- 离线态静止为 `failed`，不播放额外动作。

## 验证和发布

常用验证：

```bash
./scripts/test-status-logic.sh
./scripts/package-release.sh --version 2026.5.1
unzip -l dist/CodexPetCompanion-macos-arm64.zip | rg '__MACOSX|\.DS_Store|\._'
CODEX_PET_INSTALL_DIR=/private/tmp/codex-pet-release-test ./dist/CodexPetCompanion-macos-arm64/install-release.sh --no-restart
```

Release 上传资产：

- `CodexPetCompanion-macos-arm64-<version>.zip`
- `CodexPetCompanion-macos-arm64.zip`
- `SHA256SUMS.txt`
