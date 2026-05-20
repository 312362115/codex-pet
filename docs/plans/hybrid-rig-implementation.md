# 混合 SpriteKit Rig 实施计划

## 目标

在不重写 AppKit 桌宠的前提下，引入轻量 SpriteKit 2D rig。大动作继续使用现有高清 PNG clip，待机和微动作由透明 `SKView` 承载，提升长期停留时的生命感。

关联方案：[混合 2D 骨骼动画方案](../specs/2026-05-20-hybrid-rig-animation.md)。

## 验收标准

- `breathing` 可映射为 `spriteKitRigMotion`。
- `hairSway`、`cursorLook` 在干净拆层素材完成前继续映射为 `frameClip`。
- `blink`、`slowBlink`、`eyeShiftLeft/right` 等旧脸部覆盖动作只保留兼容枚举，运行素材目录已清理，默认不调度。
- `waving`、`turning`、`tapKeyboard`、`stretch` 等大动作继续走 PNG `frameClip`。
- `assets/lingxi-ol-rig/` 被打进 `CodexPetCompanion.app/Contents/Resources/`。
- rig 资产缺失时不影响 App 启动，自动回退到 PNG 帧。
- `./scripts/test-status-logic.sh` 和 `./scripts/build-app.sh` 通过。

## 阶段

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | 新增动作渲染模式策略、SpriteKit rig runtime、PoC 拆层资产和 bundle 复制 | in-progress |
| Phase 2 | 重新生成高质量脸部、头发和眼镜拆层素材，再打开 blink / eyeShift / cursorLook | pending |
| Phase 3 | 增加 rig fallback 自动化检查和安装验证文档 | pending |
| Phase 4 | 视觉验收后决定是否扩展肩膀/手部微动作或评估专业 runtime | pending |

## 当前会话记录

### 2026-05-20

- 已完成：`PetRenderMode` / `PetRenderModePolicy`，策略测试覆盖 rig 与 PNG 分流。
- 已完成：`PetRigProvider`、`PetRigView`、`PetRigScene` 最小实现，等待/待命状态可显示 SpriteKit rig。
- 已完成：`scripts/build-rig-assets.py` 生成 `assets/lingxi-ol-rig/` PoC 资产。
- 已完成：`scripts/build-app.sh` 增加 SpriteKit 链接和 rig 资源复制；`install.sh` / `package-release.sh --rebuild-assets` 同步生成 rig 资产。
- 已调整：脸部/眼睛/眼镜/头发机械拆层会出现重复覆盖和线条，当前已回退为 PNG，只保留 `breathing` 使用 SpriteKit rig。
- 已清理：旧脸部覆盖运行素材、`jumping` 调试目录、`running-left/right` 旧目录和历史参考图不再保留；生成脚本会主动删除不在运行清单内的旧目录。
- 下一步：重新生成或手工修正干净的脸部、头发和眼镜拆层，再单独打开 `blink` / `eyeShift` / `cursorLook`。
