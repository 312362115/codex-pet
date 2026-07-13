# Codex 原生宠物 v2 实施计划

关联方案：[Codex 原生宠物 v2 适配方案](../specs/2026-07-13-native-pet-v2.md)。

## 阶段

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | 适配 v2 校验器、标准行构建器与 Swift fallback | completed |
| Phase 2 | 迁移 Lingxi OL，完成 16 方向生成、盲测、连续性和最终视觉 QA | completed |
| Phase 3 | 迁移招财猫，完成同等 v2 QA | completed |
| Phase 4 | 更新文档，运行状态测试、构建、临时安装和最终 diff 自检 | completed |

## 验证命令

```bash
./scripts/test-status-logic.sh
./scripts/build-app.sh
CODEX_HOME=/private/tmp/codex-pet-v2-home ./scripts/install-codex-native-pet.sh
```

每只宠物还必须保留对应 `hatch-pet` run 的 v2 validation、chroma despill、方向语义、盲测共识、连续性和最终视觉 QA 证据，只有全部通过后才复制最终 `spritesheet.webp` 到仓库。

## 完成证据

- 两只宠物的 `hatch-pet` v2 图集校验、方向盲测和最终视觉 QA 通过。
- `./scripts/test-status-logic.sh` 通过。
- `./scripts/build-app.sh` 通过。
- `CODEX_HOME=/private/tmp/codex-pet-install-smoke-20260713 ./scripts/install-codex-native-pet.sh` 通过源码包与安装后包校验。
- Lingxi OL 资产重建前后中性帧与 rows 9-10 像素哈希保持一致。
