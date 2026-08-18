# Codex Dream Skin 主题安装 Agent Runbook

## 目标与边界

本文供执行本仓库任务的 Agent 使用，说明如何把 `assets/dream-skin/<theme-id>/` 安装为 Codex 工作台主题。

这套主题与以下两类资产相互独立：

- `CodexPetCompanion.app`：独立 macOS 桌宠应用。
- `assets/lingxi-ol/` 与 `assets/maneki-neko/`：Codex 原生宠物包，加载到 `~/.codex/pets/`。

工作台主题由本仓库提供视觉资产，由 Codex Dream Skin 运行时负责校验、CDP 启动、渲染注入、切换和恢复。Agent 不需要长期保留 Dream Skin 的源码仓库，但本机必须先安装其运行时引擎。

当前支持的工作台主题：

| Theme slug | 显示名 | 外观 |
|---|---|---|
| `maneki-neko` | `招财猫 · 招福工坊` | 浅色红金主题。 |
| `lingxi-ol` | `Lingxi OL · 清透日程` | 浅色灰绿主题。 |

每个主题包包含且只包含：

```text
assets/dream-skin/<theme-id>/
  background.png
  theme.css
  theme.json
```

不要修改、解包、重签或替换官方 `ChatGPT.app`、`Codex.app` 或 `app.asar`。

## 依赖模型

| 层 | 位置 | 职责 |
|---|---|---|
| 主题源码 | `assets/dream-skin/<theme-id>/` | 背景、主题元数据和 Safe CSS。 |
| 可导入包 | `dist/<theme-id>-dream-skin.zip` | Dream Skin 的本地简化 ZIP 格式。 |
| Dream Skin 引擎 | `~/.codex/codex-dream-skin-studio/` | ZIP 校验、主题库、CDP 注入、验证和恢复。 |
| Dream Skin 源码 | 独立 checkout 或官方安装包 | 只用于首次安装或升级引擎，不是主题运行时的源码依赖。 |

禁止把 Dream Skin 的部分脚本单独复制进本仓库。它的注入器、选择器、Safe CSS 策略、进程身份校验和恢复逻辑必须作为同一版本运行。

## Agent 权限门禁

以下动作必须区分：

- 生成 ZIP、静态校验、导入到“已保存主题”：不改变当前 Codex 外观。
- 切换主题：可能退出并重启正在运行的 Codex，执行前必须得到用户明确授权。
- 恢复官方外观：会停止注入器、恢复配置并可能重启 Codex，执行前必须得到用户明确授权。
- 首次安装 Dream Skin 引擎：会写入 `~/.codex/` 和 `~/Library/Application Support/`，执行前必须得到用户明确授权。

不要为规避当前 Codex 进程而编写临时 `launchctl`、`nohup` 或循环重启任务。需要退出应用时，优先让用户手动关闭，或在获得明确授权后直接运行 Dream Skin 官方脚本。

## 1. 从当前仓库生成主题 ZIP

在仓库根目录执行：

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
THEME_SLUG="lingxi-ol" # 或 maneki-neko
THEME_SOURCE="$REPO_ROOT/assets/dream-skin/$THEME_SLUG"
THEME_ZIP="$REPO_ROOT/dist/$THEME_SLUG-dream-skin.zip"

test -f "$THEME_SOURCE/background.png"
test -f "$THEME_SOURCE/theme.json"
test -f "$THEME_SOURCE/theme.css"

mkdir -p "$REPO_ROOT/dist"
ditto -c -k --norsrc --keepParent "$THEME_SOURCE" "$THEME_ZIP"
unzip -l "$THEME_ZIP"
```

ZIP 根目录可以直接放三个文件，也可以像当前命令一样只包含一层主题目录。不得包含额外图片、嵌套目录、符号链接、其他压缩包或 `.DS_Store`。

## 2. 检查 Dream Skin 引擎

```bash
ENGINE_ROOT="$HOME/.codex/codex-dream-skin-studio"

test -x "$ENGINE_ROOT/scripts/import-theme-zip-macos.sh"
test -x "$ENGINE_ROOT/scripts/switch-theme-macos.sh"
test -x "$ENGINE_ROOT/scripts/verify-dream-skin-macos.sh"
test -x "$ENGINE_ROOT/scripts/restore-dream-skin-macos.sh"
```

全部存在时，不再依赖 Dream Skin 源码仓库，直接进入“导入主题”。

### 引擎未安装

优先让用户安装 Codex Dream Skin 的发行版。若任务作用域中已有完整 Dream Skin 源码 checkout，可在用户授权并完全退出 Codex 后执行：

```bash
cd /absolute/path/to/Codex-Dream-Skin
./macos/scripts/install-dream-skin-macos.sh --no-launch --no-launchers
```

安装脚本会验证官方 App 的 bundle identity、签名、Team ID、CPU 架构和内置 Node.js。验证失败时停止，不要改用系统 Node、手工复制引擎文件或降低校验要求。

## 3. 导入主题

导入只写入 Dream Skin 的“已保存主题”库，不切换当前外观：

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
ENGINE_ROOT="$HOME/.codex/codex-dream-skin-studio"
THEME_SLUG="lingxi-ol" # 或 maneki-neko
THEME_ZIP="$REPO_ROOT/dist/$THEME_SLUG-dream-skin.zip"

IMPORT_RESULT="$(
  "$ENGINE_ROOT/scripts/import-theme-zip-macos.sh" \
    --file "$THEME_ZIP"
)"
printf '%s\n' "$IMPORT_RESULT"

THEME_ID="$(
  printf '%s' "$IMPORT_RESULT" \
    | /usr/bin/plutil -extract id raw -o - -
)"
test -n "$THEME_ID"
```

必须使用导入器返回的 `id`。当主题 ID 已存在或发生内容冲突时，导入器可能分配带后缀的新 ID；不要从源码中的 `theme.json` 猜测最终目录名。

导入器会完成：

- ZIP 路径、条目数、展开大小和压缩安全检查。
- `theme.json`、唯一背景图和 `theme.css` 文件合同检查。
- Safe CSS 白名单校验。
- 背景尺寸、格式和 payload 校验。
- 主题库原子发布与重复内容处理。

任一校验失败时停止。不要绕过导入器，把文件直接覆盖到活动主题目录。

## 4. 应用主题

应用前告知用户：若当前 Codex 没有可验证的 Dream Skin CDP 会话，切换脚本会退出并重启 Codex。只有取得明确授权后才执行：

```bash
ENGINE_ROOT="$HOME/.codex/codex-dream-skin-studio"
"$ENGINE_ROOT/scripts/switch-theme-macos.sh" --id "$THEME_ID"
```

切换脚本负责：

1. 从主题库读取并重新校验指定主题。
2. 原子发布活动主题副本。
3. CDP 会话可用时热更新。
4. CDP 会话不可用时，以 `127.0.0.1` 回环调试端口重启 Codex。
5. 只有真实渲染器确认主题 ID 和 payload revision 后才报告成功。

不要直接调用 `injector.mjs --watch` 代替切换脚本。

## 5. 验证实际渲染

主题应用成功后运行：

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
ENGINE_ROOT="$HOME/.codex/codex-dream-skin-studio"
THEME_SLUG="lingxi-ol" # 与导入时一致
QA_SCREENSHOT="$REPO_ROOT/build/qa/$THEME_SLUG-dream-skin.png"

mkdir -p "$(dirname "$QA_SCREENSHOT")"
"$ENGINE_ROOT/scripts/verify-dream-skin-macos.sh" \
  --screenshot "$QA_SCREENSHOT"
```

Agent 必须检查截图，确认：

- 原生侧栏、标题、项目控件和 composer 可见且可交互。
- 背景连续，没有把截图、文字或伪造 UI 烘焙进背景。
- 页面没有水平溢出。
- 主题主体没有遮挡主操作区。
- 文字、焦点描边和主要控件对比度可读。
- 任务页的背景强度低于首页。

同时检查 Dream Skin 状态：

```bash
STATE_PATH="$HOME/Library/Application Support/CodexDreamSkinStudio/state.json"
/usr/bin/plutil -extract session raw -o - "$STATE_PATH"
/usr/bin/plutil -extract appliedThemeId raw -o - "$STATE_PATH"
```

只有 `session` 为 `active`、`appliedThemeId` 等于导入器返回的 `THEME_ID`，且实机验证通过，才能声明安装完成。

## 6. 恢复官方外观

“暂停皮肤”只移除当前可见样式，不恢复官方外观配置，也不保证关闭 CDP 暴露窗口。用户要求“去掉皮肤”“恢复原状”时，应在获得重启授权后执行完整恢复：

```bash
ENGINE_ROOT="$HOME/.codex/codex-dream-skin-studio"
"$ENGINE_ROOT/scripts/restore-dream-skin-macos.sh" \
  --restore-base-theme \
  --restart-codex
```

恢复成功的证据是：

- 命令输出包含恢复完成信息。
- Dream Skin `state.json` 已移除。
- 注入器进程已停止。
- Codex 以不带 Dream Skin CDP 启动参数的官方方式重新打开。

恢复不会删除本仓库的主题源码和 ZIP，也不会删除“已保存主题”库中的候选主题。

## 常见失败与处理

### Codex 正在运行，首次安装被拒绝

安装器为了避免与 Codex 自己保存 `config.toml` 发生竞态，会要求先退出应用。不要绕过检查；让用户手动关闭，或取得明确重启授权后执行官方安装流程。

### `skin connection cannot be verified`

这通常表示状态文件仍在，但当前 Codex 不是原先的可验证 CDP 会话。不要声称暂停或恢复成功；在用户授权后运行完整恢复命令。

### 导入成功但固定主题 ID 不存在

读取导入命令返回 JSON 中的 `id`。主题目录发生冲突时，实际 ID 可能带 `-2`、`-3` 等后缀。

### ZIP 或 Safe CSS 校验失败

修复 `assets/dream-skin/<theme-id>/` 中的源文件并重新打包。禁止修改 Dream Skin 验证器、增加旁路或直接写活动主题目录。

### Agent 在重启后失去当前执行上下文

不要创建自定义常驻 launchd 或循环重启任务。将官方命令和预期验证结果交给用户在终端执行，或在能够可靠恢复任务上下文的产品流程中继续。

## 最终交付清单

- [ ] `background.png`、`theme.json`、`theme.css` 恰好三份主题文件。
- [ ] `dist/<theme-id>-dream-skin.zip` 已重新生成。
- [ ] Dream Skin 导入器返回 `status: imported`。
- [ ] 使用返回的真实 `id` 切换主题。
- [ ] 切换/恢复前已取得必要的重启授权。
- [ ] 实机验证和截图通过。
- [ ] 未修改官方 App、`app.asar`、签名或系统权限。
- [ ] 最终回答说明安装状态、验证结果和恢复方式。
