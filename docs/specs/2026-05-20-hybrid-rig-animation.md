# 混合 2D 骨骼动画方案

## 背景与目标

当前桌宠使用 AppKit 透明悬浮窗播放高清 PNG 帧。这个方案稳定、轻量，也适合 `turning`、`waving`、`tap-keyboard` 这类已经离线生成好的动作 clip；但待机和微动作仍然依赖整帧序列，角色长时间停留时容易显得“活性不足”，而继续增加整帧 PNG 会带来资产数量、补间质量和动作切换成本。

本方案目标是采用 SpriteKit 混合渲染：

- **大动作继续使用现有 PNG clip**，保留当前稳定的素材和调度体系。
- **待机和微动作新增轻量 SpriteKit 2D rig 层**，用局部部件动画增强呼吸、眨眼、头发摆动、看向鼠标等生命感。
- **保持可降级**，rig 资产缺失或加载失败时仍回退到现有 PNG 帧。

## 需求对焦结论

- **目标**：提升真人感桌宠在待机、等待用户和轻交互场景下的流畅度和陪伴感。
- **验收标准**：不破坏现有 PNG 动作；待机状态可通过 rig 呈现呼吸、重心变化、肩部放松和轻微鼠标注视；大动作播放前后能自然切回 rig 或现有停留帧。
- **不做**：第一阶段不做完整 3D，不引入 Spine/Live2D runtime，不用 2D rig 承担完整转身、走路、跳跃等大姿态动作。
- **待定**：拆图质量和 rig anchor 需要通过视觉 PoC 验证；若真人质感变形明显，rig 只保留眼睛、头发和极轻身体呼吸。

## 当前基础

| 模块 | 当前能力 | 可复用点 |
|------|----------|----------|
| `PetView` | 绘制透明 PNG 帧、状态文案、拖动和鼠标事件 | 可作为混合渲染入口，负责在 PNG clip 与 rig 层之间切换。 |
| `PetFrameProvider` | 从 `assets/lingxi-ol-hires/` 加载高清帧，缺失时 fallback 到 spritesheet | 继续服务大动作和降级路径。 |
| `PetAnimation` | 定义动作枚举 | 可增加渲染模式映射，不需要重命名现有动作。 |
| `PetAmbientActionPolicy` | 定义展示状态、微动作、小动作、大动作和交互动作 | 可直接决定哪些动作走 rig，哪些动作走 PNG clip。 |
| `PetActionTimeline` | 处理动作冲突、排队、丢弃和优先级 | 混合渲染不改变调度语义，只改变动作执行方式。 |

## 核心决策

### 1. 先做 SpriteKit 轻量 rig，不直接接 Godot/Spine/Live2D

第一阶段使用 Apple 原生 SpriteKit：在现有 `PetView` 的宠物绘制区域嵌入透明 `SKView`，由 `PetRigScene` 管理 `SKSpriteNode` 部件和 `SKAction` 动作。原因是当前应用已经是原生 AppKit，SpriteKit 能直接嵌入 `NSView`，比完整游戏引擎更轻，也比手写 `CALayer` 动画更适合持续维护动作。

暂不接 Godot，因为那更接近重写成一个独立游戏应用；暂不接 Spine/Live2D/Rive，因为它们会引入额外工具链、runtime、授权和打包复杂度。评估触发条件是：动作数量继续增长，`SKAction` 的维护成本超过收益，或者需要专业 rig 工具链支持更复杂的曲线、蒙皮和动画编辑。

### 2. 只让 rig 负责小幅局部动作

`Lingxi OL` 是偏真人感角色，2D 骨骼对大角度身体透视、裙装、头发和手臂遮挡的容错低。第一阶段 rig 只负责视觉穿帮风险较小的动作：

- 呼吸：胸肩和身体整体极小幅上下/缩放。
- 眨眼：眼睛 layer 切换或垂直缩放。
- 头发摆动：前发、后发 layer 小幅旋转。
- 看向鼠标：头部轻微旋转，body 轻微反向补偿；眼睛拆层完成后再补眼神移动。
- 肩膀/手部微调：手臂 layer 小幅旋转或位移。

完整转身、走动、跳跃、伸展、敲键盘、挥手等仍由 PNG clip 承担。

### 3. 保持现有调度模型

不新增一套独立动作调度器。现有动作请求仍从 `PetAmbientActionPolicy` 和 `PetActionTimeline` 进入，最终由渲染层判断执行方式：

```text
PetPresentationState
  -> PetAmbientActionPolicy
  -> PetActionTimeline
  -> PetAnimation
  -> PetRenderMode(frameClip | spriteKitRigMotion)
  -> PetView / PetRigView(SKView) / PetRigScene(SKScene)
```

这样状态防抖、hover 优先级、drag 抑制、小动作排队等既有行为不需要重新设计。

## 技术方案

### 素材结构

新增 rig 资产目录：

```text
assets/
  lingxi-ol-rig/
    rig.json
    parts/
      body.png
      head.png
```

`rig.json` 保存部件元数据：

```json
{
  "canvas": { "width": 576, "height": 624 },
  "parts": [
    {
      "id": "body",
      "image": "parts/body.png",
      "parent": null,
      "position": { "x": 288, "y": 330 },
      "anchor": { "x": 0.5, "y": 0.35 },
      "zIndex": 10
    },
    {
      "id": "head",
      "image": "parts/head.png",
      "parent": "body",
      "position": { "x": 0, "y": 150 },
      "anchor": { "x": 0.5, "y": 0.72 },
      "zIndex": 30
    }
  ]
}
```

坐标以运行窗口内的 576x624 宠物画布为基准，避免和当前 `PetView` 的状态文案区域混淆。部件图必须是透明 PNG，边缘需要清理隐藏 RGB 残留，保持和现有高清帧一致的透明质量。

### Runtime 模块

| 模块 | 类型 | 职责 |
|------|------|------|
| `PetRigManifest` | struct | 解析 `rig.json`，描述 canvas、part、parent、anchor、position、zIndex。 |
| `PetRigProvider` | class | 从 bundle 或安装目录加载 rig manifest 和部件图片。 |
| `PetRigView` | `SKView` | 嵌在 `PetView` 的宠物区域，透明显示 SpriteKit scene。 |
| `PetRigScene` | `SKScene` | 构建 `SKSpriteNode` 部件层级，播放 `SKAction` 动作，负责 settle/reset。 |
| `PetRenderModePolicy` | struct | 将 `PetAnimation` 映射为 `frameClip` 或 `spriteKitRigMotion`。 |
| `PetView` | 现有视图 | 持有 `PetFrameProvider` 和可选 `PetRigView`，负责绘制/隐藏 PNG 与 rig。 |

rig 作为 `PetView` 内部的透明 SpriteKit 子视图，而不是拆成独立窗口。这样拖动、透明背景、鼠标 tracking、右键菜单和状态文案都继续由 `PetView` 管理。

### 动作分流

第一阶段动作映射：

| 动作 | 渲染方式 | 说明 |
|------|----------|------|
| `breathing` | `spriteKitRigMotion` | 可常驻循环，低幅度。 |
| `weightShift` | `spriteKitRigMotion` | 使用 body/head 整体轻移和轻旋转，不触碰脸部覆盖素材。 |
| `shoulderRelax` | `spriteKitRigMotion` | 使用 body/head 局部下沉和回弹，避免真人手臂拆层穿帮。 |
| `hairSway` | `spriteKitRigMotion` | 当前用 head/body 代理头部轻摆，不启用独立头发覆盖层；干净头发拆层完成后再替换为真实 hair part。 |
| `blink` / `slowBlink` | `frameClip` 兼容枚举 | 不再拆独立眼睑/五官，也不默认调度；后续如需恢复，必须重新生成表情和动作一体的全帧动作素材。 |
| `eyeShiftLeft` / `eyeShiftRight` | `frameClip` 兼容枚举 | 眼睛/眼镜没有干净拆层前不保留运行素材，默认不调度。 |
| `cursorLook` | `spriteKitRigMotion` | 只使用 head/body 轻微转向，不叠加脸部覆盖素材；rig 不可用时回退 PNG。 |
| `tinyHandAdjust` | `frameClip` | 手臂/手部没有干净拆层前继续使用 PNG。 |
| `dragReleaseSettle` | `spriteKitRigMotion` | 拖动结束后用 body rig 做轻微压缩回弹。 |
| `wakeUp` | `spriteKitRigMotion` | Codex 恢复或 hover 唤醒时用 body/head rig 做轻微抬头。 |
| `waving` / `turning` / `stretch` / `tapKeyboard` / `checkNotes` | `frameClip` | 大姿态动作继续用现有 PNG。 |
| 其它未声明动作 | `frameClip` | 默认保守回退。 |

### 播放状态机

混合渲染层内部使用三种状态：

| 状态 | 说明 | 进入方式 |
|------|------|----------|
| `rigIdle` | rig 可见，播放待机呼吸、头部轻摆等 body/head 动作 | 展示状态 settle，且 rig 可用。 |
| `spriteKitRigMotion` | rig 可见，播放一次局部动作 | 动作映射为 `spriteKitRigMotion`。 |
| `frameClip` | rig 隐藏，PNG clip 播放 | 动作映射为 `frameClip`，或 rig 不可用。 |

切换规则：

1. 展示状态 settle 时，优先让 rig 回到对应姿态；如果 rig 不可用，继续显示现有 PNG 停留帧。
2. `spriteKitRigMotion` 动作播放时，不启动现有 PNG frame timer；动作完成后回到 `rigIdle` 或继续下一个 suite step。
3. `frameClip` 动作播放前隐藏 rig，播放完后再恢复 rig；如果当前展示状态没有 rig 姿态，回到现有 PNG 停留帧。
4. drag 开始时暂停 rig 和 PNG 动作；drag 结束后按当前展示状态 settle。
5. hover 离开时取消未完成的鼠标注视动作，回到当前展示状态。

表情策略：

1. 默认动作不叠加整脸覆盖层，也不拆独立五官/眼睑/嘴型；表情必须通过动作自身的 baked expression intent 或后续重新生成的全帧动作表达。
2. `PetActionDescriptor.expressions` 保存每个动作的表情意图，测试要求默认可调度动作都必须有非空表情意图。
3. `blink` / `slowBlink`、`eyeShiftLeft/right`、`hoverSmile`、`smallSmile` 等旧脸部覆盖动作只保留兼容枚举和时长策略，保持 `defaultEligible=false`，直到有动作一体的高质量全帧素材。

定时策略：

1. 所有 PNG clip 和 SpriteKit rig 动作共用 `PetAnimationTimingPolicy`。
2. PNG clip 根据实际帧数计算单帧间隔，rig 动作用同一总时长驱动一次性 suite timer。
3. 状态测试锁定旧表情兼容动作、rig 微动作、交互动作、短动作和大动作的总时长，防止补帧后整体节奏变慢。

### 降级策略

- `rig.json` 不存在：完全使用现有 PNG 渲染。
- 某个 part 图片缺失：禁用 rig，记录启动错误到控制台，不阻塞桌宠启动。
- 某个 rig 动作未实现：该动作走 `frameClip`。
- `PetRigView` 初始化失败：`PetView` 不崩溃，沿用 `PetFrameProvider`。

## 分阶段落地

| 阶段 | 内容 | 产物 | 验收 |
|------|------|------|------|
| Phase 1 | 最小 rig PoC | `lingxi-ol-rig` 最小拆层、`PetRigProvider`、`PetRigView` | 待机呼吸和 body/head 微动作可见；PNG fallback 正常。 |
| Phase 2 | 接入动作分流 | `PetRenderModePolicy`、`PetView.play` 分流 | `breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp` 走 rig；表情、手部和大动作仍走 PNG 或兼容路径。 |
| Phase 3 | 交互增强 | hover 鼠标方向、drag 暂停、状态切换 settle | hover 看向鼠标自然，拖动不抖动。 |
| Phase 4 | 素材质量优化 | 优化拆层、anchor、透明边缘和动作曲线 | 真人感不明显穿帮，长时间待机更自然。 |
| Phase 5 | 验证与文档 | 更新架构、测试说明和安装验证 | `scripts/test-status-logic.sh`、构建、安装验证通过。 |

## 代码改动范围

| 文件/目录 | 改动 | 原因 |
|-----------|------|------|
| `Sources/CodexPetCompanion/main.swift` | 新增 rig 加载、视图持有、动作分流和状态切换 | 当前渲染、事件和调度入口都集中在这里，先保持改动集中。 |
| `Sources/PetCompanion/CodexActivityStatus.swift` | 新增 `PetRenderMode` / `PetRenderModePolicy` | 保持调度层不关心 SpriteKit 细节，只暴露动作渲染模式。 |
| `Tests/PetCompanionStatusTestRunner.swift` | 增加动作分流策略测试 | 防止高风险大动作误走 rig。 |
| `assets/lingxi-ol-rig/` | 新增 rig manifest 和拆层 PNG | 提供运行时局部动画素材。 |
| `scripts/build-rig-assets.py` | 从当前待机帧机械生成 PoC rig 资产 | 让 PoC 资产可复现，后续可调 anchor 和拆层区域。 |
| `scripts/validate-rig-assets.py` | 校验 rig manifest、部件图和高风险覆盖层禁入规则 | 防止脸部红线/贴片素材回流到运行包。 |
| `scripts/build-app.sh` | 链接 SpriteKit，复制 `assets/lingxi-ol-rig` 到 app bundle | 保证源码安装和 Release 包包含 rig 资产。 |
| `docs/architecture/runtime-and-assets.md` | 同步运行时架构说明 | 文档反映混合渲染后的真实结构。 |
| `docs/tests/runtime-and-release.md` | 增加 rig fallback / 安装验证用例 | 后续回归可执行。 |

## 当前落地状态

截至 2026-05-20，Phase 2a 已进入最小可运行实现：

- 已新增 `PetRenderModePolicy`，并用 `scripts/test-status-logic.sh` 覆盖微动作走 SpriteKit、大动作走 PNG 的策略。
- 已新增 `PetRigProvider`、`PetRigView`、`PetRigScene`，在等待/待命展示状态下启用透明 SpriteKit rig。
- 已新增 `scripts/build-rig-assets.py`，从 `assets/lingxi-ol-hires/waiting/00.png` 生成 `assets/lingxi-ol-rig/` PoC 拆层资产。
- 已新增 `scripts/validate-rig-assets.py`，并接入 `test-status-logic.sh` 与 `build-app.sh`，构建前会校验 rig 只包含当前允许的 body/head 部件。
- 已更新 `scripts/build-app.sh` 链接 SpriteKit 并把 rig 资产打进 app bundle。
- 当前 rig 支持 `breathing`、`hairSway`、`weightShift`、`shoulderRelax`、`cursorLook`、`dragReleaseSettle`、`wakeUp`。这些动作只使用已验证的 body/head 拆层，不触碰整脸或独立五官覆盖素材。`head` 已作为 `body` 的子节点挂载。表情、眼镜和手部相关动作仍回退 PNG 或兼容路径，因为机械拆层会产生脸部覆盖线、边缘重复叠图或手臂穿帮。后续必须重新生成表情动作一体的全帧素材后再打开。

## 验证计划

自动化验证：

```bash
./scripts/test-status-logic.sh
./scripts/build-app.sh
codesign --verify --deep --strict build/CodexPetCompanion.app
```

本机安装验证：

```bash
./scripts/install.sh
```

视觉验收：

- 待机 60 秒，确认呼吸和眨眼低干扰且不变形。
- 鼠标 hover 进入/离开，确认头眼轻微响应，退出后回到当前状态。
- 触发工作、等待、离线状态，确认状态文案和停留姿态没有倒退。
- 播放 `waving`、`tap-keyboard`、`turning` 调试动作，确认 rig 隐藏和恢复没有闪烁。
- 删除或改名 `assets/lingxi-ol-rig/rig.json` 后重新构建，确认仍可使用 PNG fallback 启动。

## 风险与边界

| 风险 | 影响 | 应对 |
|------|------|------|
| 真人形象拆层后出现贴纸感 | 观感低于现有 PNG | rig 只保留眼睛、头发、极轻呼吸；大动作继续 PNG。 |
| anchor 和父子层级调试成本高 | 初期迭代慢 | 先只做 5-8 个部件，不做复杂蒙皮。 |
| rig 与 PNG 切换闪烁 | 动作衔接差 | 切换前后统一使用当前展示状态的 settle 姿态，必要时加短淡入淡出。 |
| 资产打包遗漏 | 安装版缺图 | `build-app.sh` 和 Release 验证增加 rig 目录检查。 |
| 手写动画曲线膨胀 | 维护困难 | 超过 8-10 个 rig 动作后再评估 Spine/Live2D。 |

## 暂不做

- 不做完整 3D 骨骼人物。
- 不引入 Spine、Live2D、Rive runtime。
- 不把所有现有 PNG 动作重做成 rig。
- 不让 2D rig 处理完整转身、走路、跳跃、大幅挥手。
- 不读取 Codex 对话内容，也不改变当前本地状态读取边界。

## 后续决策点

Phase 1 PoC 后需要根据视觉结果做一次判断：

| 判断项 | 通过标准 | 后续动作 |
|--------|----------|----------|
| 真人质感 | 待机和 hover 不出现明显拉伸、错层、贴纸感 | 继续 Phase 2。 |
| 性能 | 待机 CPU/GPU 占用不明显高于当前 PNG 方案 | 保留 rig 常驻。 |
| 衔接 | PNG 大动作结束后回 rig 不闪烁 | 扩展更多 rig 微动作。 |
| 维护成本 | 新增一个 rig 动作不需要改多处核心调度 | 继续原生方案；否则评估专业 runtime。 |
