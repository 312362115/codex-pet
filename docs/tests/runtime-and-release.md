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
PASS rig assets
PASS maneki neko assets
PASS Codex native pet
```

覆盖范围：

- Codex 离线、工作中、等待输入分类。
- Codex 元数据阶段分类：`offline`、`idle`、`thinking`、`runningTool`、`waitingUser`、`blocked`、`completed`、`longWorking`。
- `CodexWorkPhase -> PetPresentationState` 映射。
- `PetPresentationTransitionPolicy` 的最小停留时间、候选状态确认和错误即时切换。
- 状态到动画的映射。
- 各动画帧数。
- 动作总时长和按帧数自适应的单帧间隔。
- 展示状态、微动作、小动作、中/大动作、交互和调试动作策略；旧独立表情动作不进入默认 catalog 调度，招财猫 profile 可显式调度全帧 `slow-blink`。
- 宠物 catalog：默认宠物、右键菜单顺序、招财猫条目和未知选择回落。
- 调度节奏：初始微动作在 10-16 秒内出现，初始小动作在 24-36 秒内出现，初始大动作在 75-110 秒内出现；等待/待机状态的小动作和大动作池必须覆盖多种可见素材目录，但循环节奏要保留安静间隔，避免实际运行变成连续切动作。
- 表情安全策略：旧脸部覆盖动作 `defaultEligible=false`；所有默认可调度动作都有非空 baked expression intent。
- 动作 catalog 的层级分类。
- 默认窗口位置策略：启动落在当前屏幕可见区域左下角，并保留 24px 边距。
- Codex 原生宠物包：`assets/lingxi-ol/` 和 `assets/maneki-neko/` 的 `pet.json` 与 8x11 v2 `spritesheet.webp` 结构可加载，透明空槽、中性帧、标准状态和 16 个方向有效；除允许作为失败定格反馈的 `failed` 外，标准动作行不能整行静止，`jumping` 中段必须相对首尾明确离地。
- rig 渲染模式策略：`breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp` 走 SpriteKit rig；旧脸部兼容枚举不走 rig。
- rig 资产策略：manifest 只能引用当前允许的 `body/head` 部件；`body` 必须是 root，`head` 必须 parent 到 `body`；拒绝脸部、眼睛、头发、眼镜等高风险覆盖层；透明像素隐藏 RGB 必须归零。
- 招财猫资产策略：只允许精简状态目录；`waving` 的抬爪必须有可见上下招手，`hair-sway` 必须作为摆尾动作有可见左右/上下位移，`glance-left/right` 和 `look-around` 必须限制头部大幅滑动并保留轻微看向。
- 统一 timeline / runtime 调度冲突决策：小动作排队、可见动作打断微动作、hover 打断 ambient 小/大动作但不打断 active interaction、大动作丢弃、hover 节流、drag 抑制、过期状态动作丢弃；启动补挂 ambient timer 时不能与状态切换 interaction 重叠。

展示状态停留姿态预期：

- `offlineRest`：`failed`。
- `idleRelaxed`：`idle`。
- `reviewFocused`：`review`。
- `toolRunning`：`tap-keyboard`。
- `waitingAttentive`：`waiting`。
- `blockedConcerned`：`failed`。
- `completedCalm`：`nod`。
- `longWorkTired`：`stretch-wrist`。

关键帧数预期：

- 旧表情兼容枚举：`blink` 5 帧，`eye-shift-left/right` 8 帧；这些只是策略兼容断言，不再对应运行素材目录。`slow-blink` 8 帧仍保持兼容枚举，但招财猫会生成同名全帧眯眼素材。
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

- 旧表情兼容策略：`blink` 为 `0.25s`，`slow-blink` 为 `0.7s`，`eye-shift-left/right` 为 `0.8s`；`slow-blink` 不进入默认 catalog 调度，只由招财猫 profile 显式调度全帧动作。
- rig 微动作：`breathing` / `hair-sway` 为 `1.2s`，`weight-shift` / `shoulder-relax` / `cursor-look` 为 `1.6s`。
- rig 交互动作：`drag-release-settle` 为 `1.0s`，`wake-up` 为 `2.0s`。
- 短动作：`2.4s`。
- 短瞥动作：`1.6s`。
- `look-around`：`3.2s`。
- `stretch`、`step-aside`：`3.6s`。
- 转身动作：`3.24s`。

补充说明：当前机器的 `swift test` 会在测试 target 导入 Swift `Testing` 模块时报 `no such module 'Testing'`。在工具链修复前，状态策略回归以 `./scripts/test-status-logic.sh` 为准；该脚本直接编译并运行同一套核心状态和动作策略断言。

招财猫行为 profile 预期：

- `PetCatalog` 中 `maneki-neko` 使用 `PetBehaviorProfile.manekiNeko`。
- 工作/思考/等待等停留姿态回到 `waiting`，不调用人形桌宠的工作姿态。
- 等待态微动作池为 `hair-sway`、`breathing`、`slow-blink`，其中 `hair-sway` 在招财猫素材中承担摆尾动作，`slow-blink` 是全帧眯眼动作。
- 等待态小动作池重复包含 `waving`，让招手比人形桌宠更高频。
- 等待态大动作池只包含 `look-around`、`glance-left`、`glance-right`。
- 初始调度间隔：微动作 `2-4s`，小动作 `3-6s`，大动作 `8-14s`。

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
- `Lingxi OL` 和招财猫 Codex 原生宠物包安装到 `~/.codex/pets/`。
- 旧桌宠进程被停止，新版本启动。

## 用例 2.1：SpriteKit rig 资源打包

前置条件：在仓库根目录。

执行命令：

```bash
./scripts/validate-rig-assets.py
./scripts/build-rig-assets.py
./scripts/build-app.sh
find build/CodexPetCompanion.app/Contents/Resources/lingxi-ol-rig -maxdepth 2 -type f | sort
```

预期结果：

- `./scripts/validate-rig-assets.py` 输出 `PASS rig assets`。
- 输出包含 `rig.json`。
- 输出包含 `parts/body.png` 和 `parts/head.png`。
- 输出不包含 `parts/eyes-blink.png` 等脸部覆盖层；表情不做独立 rig，后续只接受动作一体的全帧素材。
- `./scripts/build-app.sh` 通过，说明 rig 资产验证、SpriteKit 链接和资源复制没有破坏构建。
- `./scripts/test-status-logic.sh` 覆盖 `breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp` 走 SpriteKit rig，且 `waitingAttentive` 微动作池包含 `breathing`、`weightShift`、`shoulderRelax`、`hairSway`；脸部兼容枚举继续走 PNG / 兼容路径。

## 用例 2.2：运行素材清理检查

前置条件：在仓库根目录，已经运行 `./scripts/build-shirt-skirt-assets.py` 和 `./scripts/build-maneki-neko-assets.py`。

执行命令：

```bash
find assets/lingxi-ol-hires -maxdepth 1 -type d | sort
find assets/reference/generated -maxdepth 1 -type f | sort
find assets/maneki-neko-hires -maxdepth 1 -type d | sort
find assets/maneki-neko-hires -maxdepth 2 -type f | wc -l
./scripts/validate-maneki-neko-assets.py
```

预期结果：

- `assets/lingxi-ol-hires/` 不包含 `blink`、`slow-blink`、`eye-shift-left`、`eye-shift-right`、`focus-tighten`、`relax-face`、`small-smile`、`tired-soften`、`curious-look`、`hover-smile`、`context-menu-attend`、`jumping`、`running-left`、`running-right`。
- `assets/reference/generated/` 只包含 `README.md`、`base-shirt-skirt-hires.png`、`action-strip-shirt-skirt-consistent.png`、`turntable-strip-shirt-skirt-consistent.png`。
- 如果启用表情一体化关键帧，`assets/reference/generated/` 还应包含版本化的 `expression-keyframes-v1.png`；它是整帧源图，不是五官覆盖层。
- 运行帧中的重复静止帧允许存在，它们用于停帧 timing，不按单帧去重。
- `assets/maneki-neko-hires/` 只包含 `breathing`、`cursor-look`、`drag-release-settle`、`failed`、`glance-left`、`glance-right`、`hair-sway`、`idle`、`look-around`、`nod`、`slow-blink`、`waiting`、`wake-up`、`waving` 这 14 个状态目录。
- `assets/maneki-neko-hires` 文件数为 215：214 张 PNG 帧加 `manifest.txt`。
- `./scripts/validate-maneki-neko-assets.py` 输出 `PASS maneki neko assets`。

## 用例 2.3：多宠物资源打包

前置条件：在仓库根目录。

执行命令：

```bash
./scripts/build-app.sh
find build/CodexPetCompanion.app/Contents/Resources -maxdepth 2 -type d | sort
find build/CodexPetCompanion.app/Contents/Resources/maneki-neko-hires -maxdepth 2 -type f | wc -l
ls -lh assets/maneki-neko/spritesheet.webp build/CodexPetCompanion.app/Contents/Resources/maneki-neko/spritesheet.webp
```

预期结果：

- `./scripts/build-app.sh` 通过，并输出 `build/CodexPetCompanion.app`。
- `Resources` 中包含 `lingxi-ol-hires`、`lingxi-ol`、`lingxi-ol-rig`、`maneki-neko-hires` 和 `maneki-neko`。
- build 内 `maneki-neko-hires` 文件数为 215。
- build 内 `maneki-neko/spritesheet.webp` 存在，和源码资源同名可读。

## 用例 2.4：Codex 原生宠物包

前置条件：在仓库根目录，已经运行 `./scripts/build-shirt-skirt-assets.py` 和 `./scripts/build-maneki-neko-assets.py`。

执行命令：

```bash
./scripts/validate-codex-native-pet.py assets/lingxi-ol
./scripts/validate-codex-native-pet.py assets/maneki-neko
./scripts/install-codex-native-pet.sh --rebuild-assets
./scripts/validate-codex-native-pet.py "$HOME/.codex/pets/lingxi-ol"
./scripts/validate-codex-native-pet.py "$HOME/.codex/pets/maneki-neko"
```

预期结果：

- 源码和安装后的原生包都输出 `PASS Codex native pet`。
- `~/.codex/pets/lingxi-ol/pet.json` 存在，Codex 读取到的原生宠物 ID 为目录派生的 `custom:lingxi-ol`。
- `~/.codex/pets/maneki-neko/pet.json` 存在，`id` 为 `maneki-neko`。
- 两个 `pet.json` 都包含 `spriteVersionNumber: 2`，且 `id` 与目录名一致。
- 两个 `spritesheet.webp` 尺寸都为 `1536x2288`，对应 8 列 x 11 行、单格 `192x208`。
- 标准动画行未用槽完全透明，`idle[6]` 是中性帧，rows 9-10 的 16 个方向格均有可见内容。
- 原生包只包含 `pet.json` 和 `spritesheet.webp`，不包含高清动作目录。

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
- 如果设置 `CODEX_HOME=/private/tmp/codex-home-test`，`/private/tmp/codex-home-test/pets/lingxi-ol/` 和 `/private/tmp/codex-home-test/pets/maneki-neko/` 下的 `pet.json` 和 `spritesheet.webp` 都存在。
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
