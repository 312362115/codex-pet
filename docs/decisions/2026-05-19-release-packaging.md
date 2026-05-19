# 决策：普通用户使用 Release 预编译包安装

日期：2026-05-19

## 背景

仓库最初只有源码安装脚本，用户需要克隆仓库、安装 Swift 构建环境、执行测试和构建，再复制 `.app` 到本机目录。

这对开发者可接受，但对普通用户不合适。

## 决策

仓库保留源码安装能力，但文档和交付方式以 GitHub Release 预编译包为主：

- 普通用户下载 `CodexPetCompanion-macos-arm64.zip`。
- 解压后执行包内的 `install-release.sh`。
- 不需要克隆源码，不需要本地编译 Swift。
- 维护者使用 `scripts/package-release.sh` 生成 zip 和 checksum。

## 发布资产

每次 Release 建议上传：

- `CodexPetCompanion-macos-arm64-<version>.zip`
- `CodexPetCompanion-macos-arm64.zip`
- `SHA256SUMS.txt`

稳定文件名 `CodexPetCompanion-macos-arm64.zip` 方便 Codex 或脚本始终下载 latest asset；带版本号文件方便归档和人工核对。

## 打包细节

`package-release.sh` 会：

1. 运行 `scripts/test-status-logic.sh`。
2. 构建 `build/CodexPetCompanion.app`。
3. 使用 ad-hoc 签名并执行 `codesign --verify --deep --strict`。
4. 生成包内 `install-release.sh`。
5. 使用 `ditto -c -k --norsrc --keepParent` 打包，避免 `__MACOSX` 和 `._*` 元数据进入 Release zip。
6. 写入 `SHA256SUMS.txt`。

## 后续约束

- 公开 Release 前必须跑一次 `package-release.sh`。
- zip 需要检查不包含 macOS 元数据：

```bash
unzip -l dist/CodexPetCompanion-macos-arm64.zip | rg '__MACOSX|\.DS_Store|\._'
```

该命令无输出才符合预期。
