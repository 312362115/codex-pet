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
- 状态到动画的映射。
- 各动画帧数。
- 动作总时长和按帧数自适应的单帧间隔。
- 静止、小动作、大动作策略。

关键帧数预期：

- `running`：24 帧。
- `waving`：24 帧。
- `turning`：25 帧。

对应时长预期：

- 短动作：`2.4s`。
- 转身动作：`3.24s`。

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

## 用例 3：Release 打包

执行命令：

```bash
./scripts/package-release.sh --version 2026.5.1
```

预期结果：

- `dist/CodexPetCompanion-macos-arm64-2026.5.1.zip` 存在。
- `dist/CodexPetCompanion-macos-arm64.zip` 存在。
- `dist/SHA256SUMS.txt` 存在。
- 两个 zip 的 SHA256 相同。

## 用例 4：Release zip 元数据检查

执行命令：

```bash
unzip -l dist/CodexPetCompanion-macos-arm64.zip | rg '__MACOSX|\.DS_Store|\._'
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
- assets 包含两个 zip 和 `SHA256SUMS.txt`。
