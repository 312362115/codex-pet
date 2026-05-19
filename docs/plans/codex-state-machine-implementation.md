# Codex 状态机联动实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将桌宠动作体系从三态静止图 + 插播动作，升级为 Codex 元数据驱动的可停留展示状态机。

**Architecture:** `CodexWorkPhase` 表达 Codex 元数据阶段，`PetPresentationState` 表达宠物可长期停留的展示状态。Runtime 只读 Codex 本地元数据，先映射到 phase，再映射到 presentation state；`PetPresentationTransitionPolicy` 负责状态防抖和最小停留时间；动作调度按 presentation state 选择停留姿态、过渡动作和状态内动作。

**Tech Stack:** Swift 6、AppKit、Foundation、macOS `/usr/bin/sqlite3` 只读查询、现有 PNG clip 资产。

---

## 文件职责

- `Sources/PetCompanion/CodexActivityStatus.swift`：新增 phase/state 状态机、元数据 snapshot、分类器、presentation state 防抖策略和动作策略。
- `Sources/CodexPetCompanion/main.swift`：新增 Codex 元数据只读查询，runtime 从 `CodexActivityStatus` 切到 `PetPresentationState`。
- `Tests/PetCompanionStatusTestRunner.swift`：覆盖 phase 推断、phase 到展示状态映射、展示状态动作池和 timeline stale state 丢弃。
- `Tests/PetCompanionTests/CodexActivityStatusTests.swift`：同步 Swift Testing 测试，保持未来 `swift test` 恢复后仍可回归。
- `docs/architecture/action-system-design.md`：补充新的状态机和动作落点规则。
- `docs/architecture/runtime-and-assets.md`：更新运行时流程、隐私边界、状态读取说明。
- `docs/tests/runtime-and-release.md`：补充状态机验证命令。

## 任务

### Task 1: 纯策略状态机

- [x] Step 1: 定义 `CodexWorkPhase` 和 `PetPresentationState`。
- [x] Step 2: 定义 `CodexMetadataSnapshot` 和 `CodexWorkPhaseClassifier`。
- [x] Step 3: 把 `PetAmbientActionPolicy` 扩展为按 `PetPresentationState` 返回停留姿态和动作池。
- [x] Step 4: 更新策略测试，先只验证纯策略逻辑。

### Task 2: Runtime 接入展示状态

- [x] Step 1: 把 `PetView.settle(status:)` 改为 `settle(presentationState:)`。
- [x] Step 2: `AppDelegate` 使用 `currentPresentationState` 管理调度。
- [x] Step 3: 状态切换动作改为 `previousPresentationState -> nextPresentationState`。
- [x] Step 4: hover、drag、context menu 继续通过 interaction 优先级打断 ambient。

### Task 3: Codex 元数据只读联动

- [x] Step 1: 新增 runtime 内部 `CodexMetadataReader`，只读 `state_5.sqlite` 和 `logs_2.sqlite` 元字段。
- [x] Step 2: 使用 `/usr/bin/sqlite3 -readonly` 查询 thread/job/goal/log status 和 timestamp。
- [x] Step 3: 不读取 session JSONL、不读取用户消息、不读取模型回复、不读取日志正文。
- [x] Step 4: 元数据读取失败时 fallback 到现有 mtime 状态判断，不影响桌宠启动。

### Task 4: 文档、验证、发布

- [x] Step 1: 更新架构文档和验证文档。
- [x] Step 2: 运行 `./scripts/test-status-logic.sh`。
- [x] Step 3: 运行 `./scripts/build-app.sh`。
- [x] Step 4: 本地安装并重启桌宠。
- [x] Step 5: 提交、推送、打 tag、创建 GitHub Release。
