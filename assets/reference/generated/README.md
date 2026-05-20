# Generated References

这些图片是当前运行帧重建所需的源图，不是 App runtime 直接加载的帧。历史探索图已清理，避免把废弃素材误当成当前资产来源。

- `base-shirt-skirt-hires.png`：当前运行帧的高清主姿态源图，用于缩小裁切，避免小格放大导致毛刺。
- `action-strip-shirt-skirt-consistent.png`：当前运行版正面小动作源图，4 个全身姿态来自同一套角色。
- `turntable-strip-shirt-skirt-consistent.png`：当前运行版转身源图，8 个全身视角来自同一套角色。
- `expression-keyframes-v1.png`：表情和动作一体的关键源帧，当前用于 `failed`、`review`、`waiting`、`nod` 和 `wake-up` 等语义状态；不拆分五官覆盖层。
