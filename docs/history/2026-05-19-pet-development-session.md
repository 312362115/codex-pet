# 2026-05-19 桌宠开发会话迁移记录

本文把当前 Codex 桌宠开发相关会话记忆迁移到仓库中。它不是 Codex 桌面应用的原始完整聊天数据库导出，而是基于当前会话上下文、仓库提交历史和本地文件状态整理出的项目记录。

## 起点

最初目标是在 Codex 桌面上展示一个定制桌宠，并且希望宠物能和 Codex 任务状态联动，而不是只做纯装饰形象。

早期尝试过基于 `hatch-pet` 工作流生成 Codex 兼容宠物资源，并探索把宠物尺寸从标准单元格 `192x208` 放大到桌面显示约三倍。这个方向遇到两个实际问题：

- Codex 原生宠物的显示尺寸和运行逻辑受 Codex 应用内部约束，单纯改资源无法稳定改变桌面显示大小。
- patch `Codex.app` 安装包后出现过应用疯狂退出重启、崩溃和恢复困难的问题，维护风险过高。

因此项目方向改为：不再 patch `Codex.app`，而是单独做一个原生 macOS 桌宠 companion。

## 独立应用方案

独立应用落地为 Swift/AppKit 项目，仓库路径为：

```text
/Users/renlongyu/workspace/codex-pet
```

安装路径为：

```text
~/.codex/pet-companion/CodexPetCompanion.app
```

核心行为：

- 使用无边框透明 AppKit 悬浮窗显示宠物。
- 桌面显示尺寸固定为 `576x624`，即标准 `192x208` 的三倍。
- 不修改 `Codex.app`，避免 Codex 升级、签名校验或 Electron 崩溃带来的风险。
- 通过本地进程和状态文件修改时间推断 Codex 状态，不读取对话内容。
- 右键菜单提供“打开 Codex”和“退出宠物”。
- 支持拖动，拖动期间暂停动画，避免拖拽卡顿。

## 视觉需求演进

用户最初想要一个女性角色，后续逐步收敛为年轻职场 OL 风格。关键视觉要求经过多轮调整：

- 形象要更接近真人感，不要过度动画化。
- 需要眼镜、黑丝、较高颜值和较好的身材比例。
- 初版外套偏黑、偏严肃保守，后来改为更年轻、轻量的职场穿搭。
- 最终运行版以白衬衣、黑色包臀裙、眼镜和黑丝为主，不再保留外套。
- 素材要保持一致性，侧面、背面和正面不能出现衣服颜色明显不一致。
- 脸部、腿部、鞋子和身材比例都经过多轮反馈，最终优先保证桌面展示时不变形、不拉伸、不从小图放大。

视觉资产的安全边界是：保持本地桌宠和职场穿搭表达，避免露骨内容；后续生成新素材时应继续使用这个边界。

## 素材质量问题和修复

开发过程中出现过这些素材问题：

- 生成小图后再裁大图导致模糊。
- 绿色背景抠图残留，桌面展示出现绿色毛边。
- 放大显示后锯齿、毛刺比预期明显。
- 素材看起来比例正常，但实际展示时出现拉伸、头身比夸张、腿部比例异常。
- 动作帧之间差异太大，导致突然转身、突然后退或快速切回正面时生硬。

最终处理策略：

- 运行帧统一使用 `assets/lingxi-ol-hires/` 的高清透明 PNG。
- 静止、工作、等待等主态来自 `assets/reference/generated/base-shirt-skirt-hires.png`。
- 短动作来自 `assets/reference/generated/action-strip-shirt-skirt-consistent.png`。
- 转身来自 `assets/reference/generated/turntable-strip-shirt-skirt-consistent.png`。
- `scripts/build-shirt-skirt-assets.py` 负责从参考图重建运行帧。
- 裁切后禁止放大，`MAX_UPSCALE=1.0`。
- `MAX_BODY_HEIGHT=540`，运行时通过 aspect-fit 绘制，避免强行填满窗口导致比例变形。
- 抠图后清理透明像素和绿色边缘残留。

## 动作策略演进

动作系统经历了几次方向调整：

1. 初期持续循环动画导致桌宠一直动，看起来烦躁且拖动卡。
2. 改成完全静止后又缺乏活人感。
3. 后续要求“偶尔动一动”，小动作更频繁，大动作间隔更长。
4. 用户希望鼠标指针放上去能立刻动起来。
5. 动作不能完全随机，否则会出现莫名其妙快速转身、立刻转回正面等不自然表现。

当前策略：

- 所有动画都不是持续 loop，一段动作播放完就回到静止状态。
- 小动作初始延迟 `2-4s`，后续间隔 `4-8s`。
- 大动作初始延迟 `35-55s`，后续间隔 `55-95s`。
- 鼠标悬停会立即触发转身动作。
- 工作态小动作套组为 `running -> waving -> running` 的轮换。
- 等待态小动作套组为 `waving -> running` 的轮换。
- 大动作只使用 `turning`，并和小动作分开调度。
- 离线态保持静止失败态，不额外播放动作。

这个策略的目标不是做复杂 AI 行为，而是让桌宠有“活人感”但不干扰工作。

## Codex 状态联动

当前状态联动是轻量实现：

- 检查 Codex 是否在运行：进程 bundle identifier 为 `com.openai.codex` 或应用名为 `Codex`。
- 检查 `.codex` 下状态文件的最近修改时间：
  - `logs_2.sqlite-wal`
  - `state_5.sqlite-wal`
  - `.codex-global-state.json`
  - `session_index.jsonl`
- 最近 `8s` 内有活动视为 `working`。
- Codex 运行但没有近期活动视为 `waiting`。
- Codex 未运行视为 `offline`。

状态展示：

- `working`：状态条显示 `Codex 工作中`，静止态使用 `review`。
- `waiting`：状态条显示 `等待输入`，静止态使用 `waiting`。
- `offline`：状态条显示 `Codex 离线`，静止态使用 `failed`。

当前实现不读取对话文本，也不解析任务内容。后续如要支持 Claude 或其他工具，应抽象状态读取层，而不是把新工具逻辑混在 AppKit UI 层。

## 发布与安装

仓库远端：

```text
git@github.com:312362115/codex-pet.git
```

已发布版本：

```text
v2026.5.1
https://github.com/312362115/codex-pet/releases/tag/v2026.5.1
```

Release 资产：

- `CodexPetCompanion-macos-arm64-2026.5.1.zip`
- `SHA256SUMS.txt`

普通用户应该优先下载 Release 预编译包，解压后执行：

```bash
./install-release.sh
```

开发者从源码安装：

```bash
./scripts/install.sh
```

维护者打包：

```bash
./scripts/package-release.sh --version 2026.5.1
```

## 已验证内容

当前已跑通过的验证：

- `./scripts/test-status-logic.sh`：状态分类、动画映射、动作策略测试，输出 `PASS status logic`。
- `./scripts/package-release.sh --version 2026.5.1`：构建、签名、生成 Release zip 和 checksum。
- `unzip -l dist/CodexPetCompanion-macos-arm64-2026.5.1.zip | rg '__MACOSX|\.DS_Store|\._'`：确认 zip 不含 macOS 元数据。
- `CODEX_PET_INSTALL_DIR=/private/tmp/codex-pet-release-test ./dist/CodexPetCompanion-macos-arm64/install-release.sh --no-restart`：确认 Release 包内安装脚本不依赖源码编译。

## 后续注意事项

- 不要再通过 patch `Codex.app` 实现桌宠，风险和维护成本都太高。
- 新素材要从足够大的高清图生成，禁止从小格放大。
- 保持正面、侧面、背面衣服和脸部一致，否则动作会显得割裂。
- 动作调度要以套组为单位，不要完全随机拼接。
- 拖动期间必须暂停动画。
- Release zip 使用 `ditto --norsrc`，避免上传 `__MACOSX` 和 `._*` 文件。
- 普通用户安装文档应以 GitHub Release 为主，源码安装只作为开发者路径。
