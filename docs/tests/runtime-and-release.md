# 运行时与 Release 验证

## 用例 1：状态和动作策略测试

前置条件：在仓库根目录。

执行命令：

```bash
./scripts/test-status-logic.sh
```

预期结果：

```text
PASS status logic
```

覆盖范围：

- Codex 离线、工作中、等待输入分类。
- Codex 元数据阶段分类：`offline`、`idle`、`thinking`、`runningTool`、`waitingUser`、`blocked`、`completed`、`longWorking`。
- `CodexWorkPhase -> PetPresentationState` 映射。
- `PetPresentationTransitionPolicy` 的最小停留时间、候选状态确认和错误即时切换。
- 状态到动画的映射。
- 各动画帧数。
- 动作总时长和按帧数自适应的单帧间隔。
- 展示状态、微动作、小动作、中/大动作、交互和调试动作策略；独立表情动作不进入默认调度。
- 动作 catalog 的层级分类。
- 统一 timeline 的冲突决策：小动作排队、可见动作打断微动作、大动作丢弃、hover 节流、drag 抑制、过期状态动作丢弃。

展示状态停留姿态预期：

- `offlineRest`：`failed`。
- `idleRelaxed`：`waiting`。
- `reviewFocused`：`review`。
- `toolRunning`：`tap-keyboard`。
- `waitingAttentive`：`waiting`。
- `blockedConcerned`：`failed`。
- `completedCalm`：`nod`。
- `longWorkTired`：`stretch-wrist`。

关键帧数预期：

- 旧表情兼容枚举：`blink` 5 帧，`slow-blink` 和 `eye-shift-left/right` 8 帧；这些只是策略兼容断言，不再对应运行素材目录。
- 旧脸部覆盖动作：`focus-tighten`、`relax-face`、`small-smile`、`tired-soften`、`curious-look`、`hover-smile`、`context-menu-attend` 保留兼容策略，不进入默认调度，也不打包运行素材。
- 微动作：`breathing`、`hair-sway` 为 12 帧；`weight-shift`、`shoulder-relax`、`tiny-hand-adjust` 为 16 帧。
- `running`：24 帧。
- `waving`：24 帧。
- `adjust-glasses`：24 帧。
- `thinking`：24 帧。
- `tap-keyboard`：24 帧。
- `check-notes`：24 帧。
- `stretch-wrist`：24 帧。
- `focus-shift`：24 帧。
- `fix-posture`：24 帧。
- `adjust-outfit`：24 帧。
- `nod`：16 帧。
- `glance-left`：16 帧。
- `glance-right`：16 帧。
- `cursor-look`：16 帧。
- `look-around`：32 帧。
- `stretch`：32 帧。
- `step-aside`：32 帧。
- `posture-reset`：32 帧。
- `wake-up`：20 帧。
- `turning`：25 帧。

对应时长预期：

- 旧表情兼容策略：`blink` 为 `0.25s`，`slow-blink` 为 `0.7s`，`eye-shift-left/right` 为 `0.8s`；这些动作不进入默认调度。
- 微动作：`1.2-1.6s`。
- 短动作：`2.4s`。
- 短瞥动作：`1.6s`。
- `look-around`：`3.2s`。
- `stretch`、`step-aside`：`3.6s`。
- 转身动作：`3.24s`。

补充说明：当前机器的 `swift test` 会在测试 target 导入 Swift `Testing` 模块时报 `no such module 'Testing'`。在工具链修复前，状态策略回归以 `./scripts/test-status-logic.sh` 为准；该脚本直接编译并运行同一套核心状态和动作策略断言。

## 用例 2：源码安装

前置条件：在 macOS，Swift 编译环境可用。

执行命令：

```bash
./scripts/install.sh
```

预期结果：

- 状态测试通过。
- `build/CodexPetCompanion.app` 构建成功。
- ad-hoc 签名和 `codesign --verify --deep --strict` 通过。
- App 安装到 `~/.codex/pet-companion/CodexPetCompanion.app`。
- 旧桌宠进程被停止，新版本启动。

## 用例 2.1：SpriteKit rig 资源打包

前置条件：在仓库根目录。

执行命令：

```bash
./scripts/build-rig-assets.py
./scripts/build-app.sh
find build/CodexPetCompanion.app/Contents/Resources/lingxi-ol-rig -maxdepth 2 -type f | sort
```

预期结果：

- 输出包含 `rig.json`。
- 输出包含 `parts/body.png` 和 `parts/head.png`。
- 输出不包含 `parts/eyes-blink.png` 等脸部覆盖层；脸部 rig 在干净拆层素材完成前不打包。
- `./scripts/build-app.sh` 通过，说明 SpriteKit 链接和资源复制没有破坏构建。

## 用例 2.2：运行素材清理检查

前置条件：在仓库根目录，已经运行 `./scripts/build-shirt-skirt-assets.py`。

执行命令：

```bash
find assets/lingxi-ol-hires -maxdepth 1 -type d | sort
find assets/reference/generated -maxdepth 1 -type f | sort
```

预期结果：

- `assets/lingxi-ol-hires/` 不包含 `blink`、`slow-blink`、`eye-shift-left`、`eye-shift-right`、`focus-tighten`、`relax-face`、`small-smile`、`tired-soften`、`curious-look`、`hover-smile`、`context-menu-attend`、`jumping`、`running-left`、`running-right`。
- `assets/reference/generated/` 只包含 `README.md`、`base-shirt-skirt-hires.png`、`action-strip-shirt-skirt-consistent.png`、`turntable-strip-shirt-skirt-consistent.png`。
- 运行帧中的重复静止帧允许存在，它们用于停帧 timing，不按单帧去重。

## 用例 3：Release 打包

执行命令：

```bash
./scripts/package-release.sh --version 2026.5.1
```

预期结果：

- `dist/CodexPetCompanion-macos-arm64-2026.5.1.zip` 存在。
- `dist/SHA256SUMS.txt` 存在。
- `SHA256SUMS.txt` 只包含带版本号的 zip。

## 用例 4：Release zip 元数据检查

执行命令：

```bash
unzip -l dist/CodexPetCompanion-macos-arm64-2026.5.1.zip | rg '__MACOSX|\.DS_Store|\._'
```

预期结果：无输出，命令退出码为 `1`。

原因：Release zip 不应包含 macOS 资源叉和 Finder 元数据。

## 用例 5：Release 包安装脚本不依赖源码

执行命令：

```bash
CODEX_PET_INSTALL_DIR=/private/tmp/codex-pet-release-test \
  ./dist/CodexPetCompanion-macos-arm64/install-release.sh --no-restart
```

预期结果：

- `/private/tmp/codex-pet-release-test/CodexPetCompanion.app` 存在。
- 输出包含 `Installed. Restart skipped.` 和 `Done`。
- 不触发源码编译。

## 用例 6：GitHub Release 核对

执行命令：

```bash
gh release view v2026.5.1 --json url,tagName,name,assets,isDraft,isPrerelease,publishedAt,targetCommitish
```

预期结果：

- `isDraft=false`。
- `isPrerelease=false`。
- `targetCommitish=main`。
- assets 包含带版本号的 zip 和 `SHA256SUMS.txt`。
