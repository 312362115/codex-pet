#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets" / "maneki-neko-hires"


EXPECTED_STATE_FRAME_COUNTS = {
    "breathing": 12,
    "cursor-look": 16,
    "drag-release-settle": 12,
    "failed": 10,
    "glance-left": 16,
    "glance-right": 16,
    "hair-sway": 12,
    "idle": 10,
    "look-around": 32,
    "nod": 16,
    "slow-blink": 8,
    "waiting": 10,
    "wake-up": 20,
    "waving": 24,
}


REGIONS = {
    "raised_paw": (350, 150, 500, 315),
    "waving_paw": (350, 200, 550, 440),
    "tail": (380, 350, 510, 535),
    "head": (150, 175, 440, 385),
    "left_eye": (215, 240, 300, 310),
    "slow_blink_eye": (225, 285, 275, 340),
}


def alpha_centroid(path: Path, region: tuple[int, int, int, int]) -> tuple[float, float]:
    image = Image.open(path).convert("RGBA").crop(region)
    alpha = image.getchannel("A")
    sx = 0.0
    sy = 0.0
    total = 0.0
    for y in range(image.height):
        for x in range(image.width):
            value = alpha.getpixel((x, y))
            if value <= 48:
                continue
            sx += x * value
            sy += y * value
            total += value

    if total <= 0:
        raise SystemExit(f"No visible pixels in region {region} for {path}")
    return (region[0] + sx / total, region[1] + sy / total)


def movement_range(state: str, region_name: str) -> tuple[float, float]:
    frames = sorted((ASSET_ROOT / state).glob("*.png"))
    if not frames:
        raise SystemExit(f"Missing frames for {state}")

    points = movement_points(state, region_name)
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return (max(xs) - min(xs), max(ys) - min(ys))


def movement_points(state: str, region_name: str) -> list[tuple[float, float]]:
    frames = sorted((ASSET_ROOT / state).glob("*.png"))
    if not frames:
        raise SystemExit(f"Missing frames for {state}")

    return [alpha_centroid(path, REGIONS[region_name]) for path in frames]


def dark_centroid(path: Path, region: tuple[int, int, int, int]) -> tuple[float, float]:
    image = Image.open(path).convert("RGBA").crop(region)
    sx = 0.0
    sy = 0.0
    total = 0.0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if alpha <= 48:
                continue

            luminance = red * 0.299 + green * 0.587 + blue * 0.114
            if luminance >= 95:
                continue

            weight = alpha * (95 - luminance)
            sx += x * weight
            sy += y * weight
            total += weight

    if total <= 0:
        raise SystemExit(f"No dark visible pixels in region {region} for {path}")
    return (region[0] + sx / total, region[1] + sy / total)


def dark_movement_range(state: str, region_name: str) -> tuple[float, float]:
    frames = sorted((ASSET_ROOT / state).glob("*.png"))
    if not frames:
        raise SystemExit(f"Missing frames for {state}")

    points = [dark_centroid(path, REGIONS[region_name]) for path in frames]
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return (max(xs) - min(xs), max(ys) - min(ys))


def dark_pixel_count(path: Path, region: tuple[int, int, int, int]) -> int:
    image = Image.open(path).convert("RGBA").crop(region)
    count = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if alpha <= 48:
                continue

            luminance = red * 0.299 + green * 0.587 + blue * 0.114
            if luminance < 95:
                count += 1
    return count


def expect_at_least(label: str, actual: float, minimum: float) -> None:
    if actual < minimum:
        raise SystemExit(f"FAIL {label}: expected >= {minimum:.1f}px, got {actual:.1f}px")


def expect_at_most(label: str, actual: float, maximum: float) -> None:
    if actual > maximum:
        raise SystemExit(f"FAIL {label}: expected <= {maximum:.1f}px, got {actual:.1f}px")


def expect_beckoning_paw(points: list[tuple[float, float]]) -> None:
    high = min(points, key=lambda point: point[1])
    low = max(points, key=lambda point: point[1])
    if low[1] < high[1] + 20:
        raise SystemExit(
            f"FAIL waving raised paw path: expected a clear downward beckon, "
            f"got high=({high[0]:.1f},{high[1]:.1f}) low=({low[0]:.1f},{low[1]:.1f})"
        )


def expect_paw_below_head(points: list[tuple[float, float]]) -> None:
    low = max(points, key=lambda point: point[1])
    if low[1] < 330:
        raise SystemExit(
            f"FAIL waving raised paw low point: expected lower paw below head, "
            f"got low=({low[0]:.1f},{low[1]:.1f})"
        )


def expect_slow_blink_closes_eyes() -> None:
    frames = sorted((ASSET_ROOT / "slow-blink").glob("*.png"))
    if len(frames) != EXPECTED_STATE_FRAME_COUNTS["slow-blink"]:
        raise SystemExit("FAIL slow-blink frame count before eye closure check")

    counts = [dark_pixel_count(path, REGIONS["slow_blink_eye"]) for path in frames]
    if max(counts) < min(counts) * 2:
        raise SystemExit(
            f"FAIL slow-blink eye closure: expected open-to-squint dark pixel change, got counts={counts}"
        )


def expect_pruned_state_dirs() -> None:
    existing = {path.name for path in ASSET_ROOT.iterdir() if path.is_dir()}
    expected = set(EXPECTED_STATE_FRAME_COUNTS)
    if existing != expected:
        extra = sorted(existing - expected)
        missing = sorted(expected - existing)
        raise SystemExit(f"FAIL pruned action dirs: extra={extra} missing={missing}")

    for state, expected_count in EXPECTED_STATE_FRAME_COUNTS.items():
        count = len(list((ASSET_ROOT / state).glob("*.png")))
        if count != expected_count:
            raise SystemExit(f"FAIL {state} frame count: expected {expected_count}, got {count}")


def main() -> None:
    expect_pruned_state_dirs()

    paw_points = movement_points("waving", "waving_paw")
    paw_x, paw_y = movement_range("waving", "waving_paw")
    tail_x, tail_y = movement_range("hair-sway", "tail")
    glance_left_x, _ = movement_range("glance-left", "head")
    glance_right_x, _ = movement_range("glance-right", "head")
    look_x, _ = movement_range("look-around", "head")
    gaze_left_x, _ = dark_movement_range("glance-left", "left_eye")
    gaze_right_x, _ = dark_movement_range("glance-right", "left_eye")
    gaze_around_x, _ = dark_movement_range("look-around", "left_eye")

    expect_at_least("waving raised paw vertical motion", paw_y, 20)
    expect_at_least("waving raised paw horizontal motion", paw_x, 1)
    expect_beckoning_paw(paw_points)
    expect_paw_below_head(paw_points)
    expect_at_least("tail horizontal sway", tail_x, 14)
    expect_at_least("tail vertical sway", tail_y, 5)
    expect_at_most("glance-left head slide", glance_left_x, 12)
    expect_at_most("glance-right head slide", glance_right_x, 12)
    expect_at_most("look-around head slide", look_x, 14)
    expect_at_least("glance-left gaze motion", gaze_left_x, 1)
    expect_at_least("glance-right gaze motion", gaze_right_x, 1)
    expect_at_least("look-around gaze motion", gaze_around_x, 3)
    expect_slow_blink_closes_eyes()

    print("PASS maneki neko assets")


if __name__ == "__main__":
    main()
