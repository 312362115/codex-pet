# Codex Pet Companion 安装指南

## 推荐方式：下载 Release 安装

普通用户不需要克隆源码，也不需要本地编译 Swift。到 GitHub Releases 下载对应平台的预编译包即可：

[https://github.com/312362115/codex-pet/releases/latest](https://github.com/312362115/codex-pet/releases/latest)

当前支持的 Release 包：

- `CodexPetCompanion-macos-arm64-<version>.zip`：Apple Silicon Mac。

下载后解压，进入解压目录执行：

```bash
./install-release.sh
```

这条命令会自动完成：

- 安装预编译的 `CodexPetCompanion.app` 到 `~/.codex/pet-companion/CodexPetCompanion.app`。
- 停止旧桌宠进程并启动新版本。

自定义安装目录：

```bash
CODEX_PET_INSTALL_DIR="$HOME/.codex/pet-companion-dev" ./install-release.sh
```

安装但不自动重启桌宠：

```bash
./install-release.sh --no-restart
```

## 给 Codex 的一键指令

如果让 Codex 代为安装，可以直接给它这句：

```text
下载 https://github.com/312362115/codex-pet/releases/latest 中带版本号的 CodexPetCompanion-macos-arm64-<version>.zip，解压后执行 install-release.sh，完成后确认 CodexPetCompanion 进程已启动。
```

## 维护者：生成 Release 包

在仓库根目录执行：

```bash
./scripts/package-release.sh --version 2026.5.1
```

输出文件：

- `dist/CodexPetCompanion-macos-arm64-2026.5.1.zip`
- `dist/SHA256SUMS.txt`

上传到 GitHub Release 时，只上传带版本号的 zip 和 `SHA256SUMS.txt`。不再上传稳定文件名 zip，避免 Release 页面出现两个内容相同的 arm64 包。

## 开发者：从源码安装

只有需要改源码、改素材或本地验证时，才需要从源码安装：

```bash
mkdir -p ~/workspace
git clone git@github.com:312362115/codex-pet.git ~/workspace/codex-pet
cd ~/workspace/codex-pet
./scripts/install.sh
```

源码安装会自动完成：

- 运行状态逻辑测试。
- 构建 `CodexPetCompanion.app`。
- 使用本机 ad-hoc 签名。
- 安装到 `~/.codex/pet-companion/CodexPetCompanion.app`。
- 停止旧桌宠进程并启动新版本。

源码安装常用选项：

```bash
./scripts/install.sh --skip-tests
./scripts/install.sh --no-restart
./scripts/install.sh --rebuild-assets
CODEX_PET_INSTALL_DIR="$HOME/.codex/pet-companion-dev" ./scripts/install.sh
```

## 验证

安装后确认进程：

```bash
ps -axo pid,command | rg 'CodexPetCompanion|codex-pet-companion'
```

确认安装包资源：

```bash
sed -n '1,40p' "$HOME/.codex/pet-companion/CodexPetCompanion.app/Contents/Resources/lingxi-ol-hires/manifest.txt"
```

## 手动启动和退出

启动：

```bash
open "$HOME/.codex/pet-companion/CodexPetCompanion.app"
```

退出：

```bash
pkill -f 'CodexPetCompanion.app/Contents/MacOS/CodexPetCompanion'
```

也可以在桌宠上右键，选择“退出宠物”。

## 排障

- 如果 Release 安装后没有变化，通常是旧进程仍在运行；重新执行 `./install-release.sh` 会自动杀掉旧进程并启动新版本。
- 如果 macOS 拦截启动，在“系统设置 → 隐私与安全性”中允许打开，或让维护者重新生成并上传签名后的 Release 包。
- 如果修改过素材但桌面没有变化，使用源码安装路径执行 `./scripts/install.sh --rebuild-assets`。
- 如果只想看源码构建产物，不安装到 Codex 目录，执行 `./scripts/build-app.sh`，产物在 `build/CodexPetCompanion.app`。
