#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
HIRES_ROOT = ROOT / "assets" / "maneki-neko-hires"
PET_ROOT = ROOT / "assets" / "maneki-neko"
DISPLAY_SIZE = (576, 624)
CELL_SIZE = (192, 208)
V2_GRID_SIZE = (8, 11)
STANDARD_ROWS = 9
SCALE = 3
CONTENT_SCALE = 0.82
CONTENT_BASELINE_Y = 600
CONTENT_CROP_BOX = (112, 48, 504, 568)

STATE_FRAME_COUNTS = {
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

SPRITESHEET_ROWS = [
    ("idle", 6),
    ("running-right", 8),
    ("running-left", 8),
    ("waving", 4),
    ("jumping", 5),
    ("failed", 8),
    ("waiting", 6),
    ("running", 6),
    ("review", 6),
]


def s(value: float) -> int:
    return round(value * SCALE)


def box(values: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(s(value) for value in values)


def point(values: tuple[float, float]) -> tuple[int, int]:
    return (s(values[0]), s(values[1]))


def normalize_hidden_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (0, 0, 0, 0) if alpha == 0 else (red, green, blue, alpha)
    return rgba


def scale_content_to_canvas(
    image: Image.Image,
    factor: float,
    baseline_y: int,
    crop_box: tuple[int, int, int, int],
) -> Image.Image:
    rgba = image.convert("RGBA")
    source = rgba.crop(crop_box)
    resized = source.resize(
        (
            max(1, round(source.width * factor)),
            max(1, round(source.height * factor)),
        ),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    x = (rgba.width - resized.width) // 2
    y = min(rgba.height - resized.height, max(0, baseline_y - resized.height))
    canvas.alpha_composite(resized, (x, y))
    return normalize_hidden_rgb(canvas)


def draw_polygon(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int],
    width: int,
) -> None:
    scaled = [point(item) for item in points]
    draw.polygon(scaled, fill=fill)
    draw.line([*scaled, scaled[0]], fill=outline, width=s(width), joint="curve")


def draw_round_line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    fill: tuple[int, int, int, int],
    width: int,
) -> None:
    scaled = [point(item) for item in points]
    draw.line(scaled, fill=fill, width=s(width), joint="curve")
    radius = width / 2
    for x, y in points:
        draw.ellipse(box((x - radius, y - radius, x + radius, y + radius)), fill=fill)


def phase(index: int, count: int, offset: float = 0.0) -> float:
    return math.sin((index / max(1, count)) * math.tau + offset)


def triangle_points(center_x: float, top_y: float, direction: int) -> list[tuple[float, float]]:
    return [
        (center_x, top_y),
        (center_x - 44 * direction, top_y + 84),
        (center_x + 28 * direction, top_y + 72),
    ]


def cat_params(variant: str, index: int, count: int) -> dict[str, float | str | bool]:
    wave = phase(index, count)
    bounce = phase(index, count, math.pi / 5)
    params: dict[str, float | str | bool] = {
        "body_x": 0,
        "body_y": 0,
        "body_tilt": 0,
        "head_x": 0,
        "head_y": 0,
        "paw_x": 0,
        "paw_y": 0,
        "paw_wave": 0,
        "paw_fold": 0,
        "coin_y": 0,
        "tail_x": 0,
        "tail_y": 0,
        "gaze_x": 0,
        "eye": "open",
        "eye_open": 1.0,
        "mood": "happy",
        "bell_y": 0,
        "left_foot_x": 0,
        "left_foot_y": 0,
        "right_foot_x": 0,
        "right_foot_y": 0,
        "left_arm_x": 0,
        "left_arm_y": 0,
        "right_arm_pose": "raised",
    }

    if variant == "idle":
        params["body_y"] = 2 * bounce
        params["head_y"] = 1.5 * bounce
        params["paw_y"] = 2 * bounce
        params["eye"] = "blink" if index in {4, 5} else "open"
    elif variant == "waiting":
        params["body_y"] = 1.5 * bounce
        params["paw_x"] = 10 * wave
        params["paw_y"] = -10 * abs(wave)
        params["tail_x"] = 18 * wave
        params["tail_y"] = 7 * wave
        params["gaze_x"] = 2 * wave
    elif variant == "waving":
        params["paw_fold"] = (1 - math.cos(index / max(1, count) * math.tau)) / 2
        params["tail_x"] = 22 * wave
        params["tail_y"] = 8 * wave
        params["head_x"] = 2 * wave
        params["body_y"] = 2 * bounce
    elif variant == "running":
        params["body_y"] = 3 * bounce
        params["paw_x"] = 14 * wave
        params["coin_y"] = 4 * abs(wave)
        params["eye"] = "focused"
        params["gaze_x"] = 3
    elif variant in {"running-right", "running-left"}:
        direction = 1 if variant == "running-right" else -1
        stride = phase(index, count)
        params["body_tilt"] = -7 * direction
        params["body_y"] = -5 * abs(stride)
        params["head_x"] = 10 * direction
        params["head_y"] = -3
        params["gaze_x"] = 13 * direction
        params["paw_x"] = 14 * direction * stride
        params["paw_y"] = -8 * abs(stride)
        params["left_arm_x"] = 12 * direction * stride
        params["left_arm_y"] = -7 * abs(stride)
        params["left_foot_x"] = 15 * direction * stride
        params["left_foot_y"] = -8 * max(0.0, stride)
        params["right_foot_x"] = -15 * direction * stride
        params["right_foot_y"] = 8 * min(0.0, stride)
        params["tail_x"] = -44 * direction + 10 * stride
        params["tail_y"] = -8 * abs(stride)
        params["coin_y"] = 5 * abs(stride)
        params["eye"] = "focused"
        params["right_arm_pose"] = "rest"
    elif variant == "review":
        params["head_x"] = -3
        params["head_y"] = 2 * bounce
        params["paw_y"] = 6
        params["eye"] = "focused"
        params["gaze_x"] = -3
    elif variant == "failed":
        params["body_y"] = 6
        params["head_y"] = 5
        params["paw_y"] = 30
        params["eye"] = "sad"
        params["mood"] = "sad"
        params["right_arm_pose"] = "rest"
    elif variant == "glance-left":
        look = abs(wave)
        params["head_x"] = -5 * look
        params["tail_x"] = 14 * abs(wave)
        params["gaze_x"] = -11 * look
        params["paw_x"] = -3
        params["right_arm_pose"] = "rest"
    elif variant == "glance-right":
        look = abs(wave)
        params["head_x"] = 5 * look
        params["tail_x"] = -14 * abs(wave)
        params["gaze_x"] = 11 * look
        params["paw_x"] = 6
        params["right_arm_pose"] = "rest"
    elif variant == "thinking":
        params["head_x"] = -4
        params["paw_y"] = 12
        params["eye"] = "focused"
        params["gaze_x"] = -5
        params["coin_y"] = 2 * wave
    elif variant == "nod":
        params["head_y"] = 7 * abs(wave)
        params["bell_y"] = 2 * abs(wave)
    elif variant == "slow-blink":
        progress = index / max(1, count - 1)
        openness = 0.12 + 0.88 * abs(math.cos(progress * math.pi))
        params["eye"] = "soft-blink"
        params["eye_open"] = openness
        params["body_y"] = 1.2 * bounce
        params["tail_x"] = 8 * wave
        params["tail_y"] = 3 * wave
    elif variant == "stretch":
        params["body_y"] = -5 * abs(wave)
        params["head_y"] = -8 * abs(wave)
        params["paw_y"] = -22
        params["paw_x"] = 8 * wave
    elif variant == "step-aside":
        params["body_x"] = 10 * wave
        params["tail_x"] = -18 * wave
        params["tail_y"] = 6 * wave
        params["head_x"] = 4 * wave
    elif variant == "posture-reset":
        params["body_y"] = 6 * math.sin(index / max(1, count - 1) * math.pi)
        params["head_y"] = 3 * math.sin(index / max(1, count - 1) * math.pi)
    elif variant == "wake-up":
        progress = index / max(1, count - 1)
        params["body_y"] = 14 * (1 - progress)
        params["head_y"] = 8 * (1 - progress)
        params["eye"] = "blink" if index < 3 else "open"
    elif variant == "jumping":
        lift = math.sin(index / max(1, count - 1) * math.pi)
        params["head_y"] = -8 * lift
        params["paw_y"] = -16 * lift
        params["left_foot_y"] = -10 * lift
        params["right_foot_y"] = -10 * lift
        params["tail_y"] = -10 * lift
    elif variant == "look-around":
        turn = math.sin(index / max(1, count - 1) * math.tau)
        params["gaze_x"] = 11 * turn
        params["head_x"] = 4 * turn
        params["tail_x"] = -30 * turn
        params["tail_y"] = 10 * turn
        params["right_arm_pose"] = "rest"
    elif variant == "drag-release-settle":
        params["body_y"] = 7 * math.sin(index / max(1, count - 1) * math.pi)
        params["head_y"] = 4 * math.sin(index / max(1, count - 1) * math.pi)
    elif variant == "breathing":
        params["body_y"] = 2 * bounce
        params["bell_y"] = 1.5 * bounce
    elif variant == "hair-sway":
        params["head_x"] = 5 * wave
        params["tail_x"] = -52 * wave
        params["tail_y"] = 16 * wave
    elif variant == "weight-shift":
        params["body_x"] = 6 * wave
        params["head_x"] = 3 * wave
    elif variant == "shoulder-relax":
        params["body_y"] = 5 * abs(wave)
        params["head_y"] = 2 * abs(wave)
    elif variant == "turning":
        params["head_x"] = 12 * math.sin(index / max(1, count - 1) * math.tau)
        params["body_x"] = 8 * math.sin(index / max(1, count - 1) * math.tau)
        params["tail_x"] = -20 * math.sin(index / max(1, count - 1) * math.tau)
        params["tail_y"] = 8 * math.sin(index / max(1, count - 1) * math.tau)
        params["gaze_x"] = 8 * math.sin(index / max(1, count - 1) * math.tau)
        params["right_arm_pose"] = "rest"

    return params


def draw_cat(variant: str, index: int, count: int, size: tuple[int, int] = DISPLAY_SIZE) -> Image.Image:
    image = Image.new("RGBA", (size[0] * SCALE, size[1] * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    params = cat_params(variant, index, count)

    ox = (size[0] - DISPLAY_SIZE[0]) / 2 + float(params["body_x"])
    oy = (size[1] - DISPLAY_SIZE[1]) / 2 + float(params["body_y"])
    hx = ox + float(params["head_x"])
    hy = oy + float(params["head_y"])
    paw_x = float(params["paw_x"])
    paw_y = float(params["paw_y"])
    paw_wave = float(params["paw_wave"])
    paw_fold = float(params["paw_fold"])
    coin_y = float(params["coin_y"])
    tail_x = float(params["tail_x"])
    tail_y = float(params["tail_y"])
    gaze_x = float(params["gaze_x"])
    bell_y = float(params["bell_y"])
    left_foot_x = float(params["left_foot_x"])
    left_foot_y = float(params["left_foot_y"])
    right_foot_x = float(params["right_foot_x"])
    right_foot_y = float(params["right_foot_y"])
    left_arm_x = float(params["left_arm_x"])
    left_arm_y = float(params["left_arm_y"])
    right_arm_pose = str(params["right_arm_pose"])

    ink = (63, 48, 43, 255)
    white = (255, 251, 239, 255)
    warm = (249, 235, 208, 255)
    patch = (232, 151, 62, 255)
    red = (214, 42, 45, 255)
    gold = (246, 181, 50, 255)
    gold_dark = (173, 111, 21, 255)
    pink = (248, 171, 169, 255)
    blue = (94, 166, 220, 255)

    def b(rect: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
        return box((rect[0] + ox, rect[1] + oy, rect[2] + ox, rect[3] + oy))

    def hb(rect: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
        return box((rect[0] + hx, rect[1] + hy, rect[2] + hx, rect[3] + hy))

    def draw_right_arm() -> None:
        if right_arm_pose == "rest":
            arm_points = [
                (354 + ox + paw_x * 0.08, 356 + oy + paw_y * 0.08),
                (360 + ox + paw_x * 0.08, 402 + oy + paw_y * 0.08),
            ]
            draw_round_line(draw, arm_points, ink, 34)
            draw_round_line(draw, arm_points, white, 25)
            draw.ellipse(
                box((334 + ox + paw_x * 0.08, 392 + oy + paw_y * 0.08, 384 + ox + paw_x * 0.08, 440 + oy + paw_y * 0.08)),
                fill=white,
                outline=ink,
                width=s(4),
            )
            return

        shoulder = (360 + ox + paw_x * 0.08, 356 + oy + paw_y * 0.08)
        fold = max(0.0, min(1.0, paw_fold))
        elbow = (392 + ox + paw_x * 0.08, 318 + oy + paw_y * 0.08)
        paw_center = (
            410 + ox + paw_x * 0.08 + 4 * paw_wave,
            235 + oy + paw_y * 0.08 + 110 * fold,
        )
        arm_points = [shoulder, elbow, paw_center]
        draw_round_line(draw, arm_points, ink, 39)
        draw_round_line(draw, arm_points, white, 28)
        draw.ellipse(
            box((paw_center[0] - 29, paw_center[1] - 30, paw_center[0] + 29, paw_center[1] + 30)),
            fill=white,
            outline=ink,
            width=s(4),
        )
        for claw_x in [-13, 0, 13]:
            draw.line(
                [
                    point((paw_center[0] + claw_x, paw_center[1] - 15)),
                    point((paw_center[0] + claw_x - 4, paw_center[1] - 1)),
                ],
                fill=ink,
                width=s(2),
            )

    def draw_tail() -> None:
        swing = max(-1.0, min(1.0, tail_x / 52))
        angle = 0.32 * swing
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        base = (374 + ox, 418 + oy)

        def tail_point(dx: float, dy: float) -> tuple[float, float]:
            return (
                base[0] + dx * cos_a - dy * sin_a,
                base[1] + dx * sin_a + dy * cos_a,
            )

        points = [
            base,
            tail_point(28, -4),
            tail_point(54, -16),
            tail_point(76, -38),
            tail_point(88, -68),
            tail_point(82, -102),
        ]
        draw_round_line(draw, points, ink, 30)
        draw_round_line(draw, points, white, 21)

    draw_tail()
    draw.ellipse(b((197, 282, 379, 526)), fill=white, outline=ink, width=s(4))
    draw.ellipse(
        b((222 + left_foot_x, 484 + left_foot_y, 284 + left_foot_x, 552 + left_foot_y)),
        fill=white,
        outline=ink,
        width=s(4),
    )
    draw.ellipse(
        b((304 + right_foot_x, 484 + right_foot_y, 366 + right_foot_x, 552 + right_foot_y)),
        fill=white,
        outline=ink,
        width=s(4),
    )

    draw.rounded_rectangle(
        b((224, 381 + coin_y, 352, 493 + coin_y)),
        radius=s(28),
        fill=gold,
        outline=gold_dark,
        width=s(4),
    )
    draw.ellipse(b((244, 404 + coin_y, 332, 472 + coin_y)), outline=(255, 226, 126, 255), width=s(5))

    left_arm_points = [
        (224 + ox, 350 + oy),
        (252 + ox + left_arm_x, 414 + oy + left_arm_y),
    ]
    draw_round_line(draw, left_arm_points, ink, 36)
    draw_round_line(draw, left_arm_points, white, 27)
    draw.ellipse(
        b((234 + left_arm_x, 398 + left_arm_y, 282 + left_arm_x, 446 + left_arm_y)),
        fill=white,
        outline=ink,
        width=s(4),
    )

    draw_polygon(draw, [(216 + hx, 168 + hy), (231 + hx, 64 + hy), (297 + hx, 158 + hy)], white, ink, 4)
    draw_polygon(draw, [(360 + hx, 168 + hy), (347 + hx, 64 + hy), (281 + hx, 158 + hy)], white, ink, 4)
    draw_polygon(draw, triangle_points(231 + hx, 100 + hy, 1), pink, pink, 1)
    draw_polygon(draw, triangle_points(347 + hx, 100 + hy, -1), pink, pink, 1)
    draw.ellipse(hb((170, 124, 406, 342)), fill=white, outline=ink, width=s(5))
    draw.pieslice(hb((181, 119, 301, 244)), 205, 45, fill=patch)
    draw.arc(hb((181, 119, 301, 244)), 205, 45, fill=ink, width=s(3))
    draw.ellipse(hb((300, 124, 385, 203)), fill=(48, 45, 47, 255))
    draw.ellipse(hb((315, 134, 356, 173)), fill=gold)

    draw.rounded_rectangle(hb((218, 291, 358, 324)), radius=s(14), fill=red, outline=ink, width=s(4))
    draw.ellipse(box((270 + hx, 311 + hy + bell_y, 306 + hx, 347 + hy + bell_y)), fill=gold, outline=ink, width=s(3))
    draw.line(
        [point((288 + hx, 329 + hy + bell_y)), point((288 + hx, 340 + hy + bell_y))],
        fill=gold_dark,
        width=s(2),
    )

    eye = str(params["eye"])
    eye_open = float(params["eye_open"])
    if eye == "blink":
        draw.line([point((228 + hx, 222 + hy)), point((260 + hx, 222 + hy))], fill=ink, width=s(4))
        draw.line([point((318 + hx, 222 + hy)), point((350 + hx, 222 + hy))], fill=ink, width=s(4))
    elif eye == "sad":
        draw.line([point((229 + hx, 212 + hy)), point((260 + hx, 226 + hy))], fill=ink, width=s(4))
        draw.line([point((350 + hx, 212 + hy)), point((319 + hx, 226 + hy))], fill=ink, width=s(4))
    elif eye == "focused":
        draw.ellipse(hb((226 + gaze_x, 206, 260 + gaze_x, 240)), fill=ink)
        draw.ellipse(hb((318 + gaze_x, 206, 352 + gaze_x, 240)), fill=ink)
        draw.rectangle(hb((222 + gaze_x, 203, 264 + gaze_x, 212)), fill=white)
        draw.rectangle(hb((314 + gaze_x, 203, 356 + gaze_x, 212)), fill=white)
    elif eye == "soft-blink":
        if eye_open <= 0.2:
            draw.arc(hb((223 + gaze_x, 204, 263 + gaze_x, 238)), 20, 160, fill=ink, width=s(4))
            draw.arc(hb((315 + gaze_x, 204, 355 + gaze_x, 238)), 20, 160, fill=ink, width=s(4))
        else:
            eye_height = 36 * eye_open
            left_eye_box = (
                226 + gaze_x,
                222 - eye_height / 2,
                260 + gaze_x,
                222 + eye_height / 2,
            )
            right_eye_box = (
                318 + gaze_x,
                222 - eye_height / 2,
                352 + gaze_x,
                222 + eye_height / 2,
            )
            draw.ellipse(hb(left_eye_box), fill=ink)
            draw.ellipse(hb(right_eye_box), fill=ink)
            if eye_open > 0.55:
                draw.ellipse(hb((237 + gaze_x, 212, 247 + gaze_x, 222)), fill=white)
                draw.ellipse(hb((329 + gaze_x, 212, 339 + gaze_x, 222)), fill=white)
    else:
        draw.ellipse(hb((226 + gaze_x, 204, 260 + gaze_x, 240)), fill=ink)
        draw.ellipse(hb((318 + gaze_x, 204, 352 + gaze_x, 240)), fill=ink)
        draw.ellipse(hb((237 + gaze_x, 212, 247 + gaze_x, 222)), fill=white)
        draw.ellipse(hb((329 + gaze_x, 212, 339 + gaze_x, 222)), fill=white)

    draw.polygon([point((288 + hx, 244 + hy)), point((275 + hx, 258 + hy)), point((301 + hx, 258 + hy))], fill=pink)
    if params["mood"] == "sad":
        draw.arc(hb((270, 267, 306, 301)), 200, 340, fill=ink, width=s(3))
        draw.ellipse(hb((350, 239, 366, 262)), fill=blue, outline=ink, width=s(1))
    else:
        draw.arc(hb((268, 254, 288, 280)), 0, 95, fill=ink, width=s(3))
        draw.arc(hb((288, 254, 308, 280)), 85, 180, fill=ink, width=s(3))

    for whisker_y in [249, 264, 279]:
        draw.line([point((219 + hx, whisker_y + hy)), point((154 + hx, whisker_y - 11 + hy))], fill=ink, width=s(2))
        draw.line([point((357 + hx, whisker_y + hy)), point((422 + hx, whisker_y - 11 + hy))], fill=ink, width=s(2))

    draw_right_arm()

    body_tilt = float(params["body_tilt"])
    if body_tilt:
        image = image.rotate(body_tilt, resample=Image.Resampling.BICUBIC)

    image = image.resize(size, Image.Resampling.LANCZOS)
    image = image.filter(ImageFilter.UnsharpMask(radius=0.35, percent=18, threshold=6))
    if size == DISPLAY_SIZE:
        image = scale_content_to_canvas(image, CONTENT_SCALE, CONTENT_BASELINE_Y, CONTENT_CROP_BOX)
    return normalize_hidden_rgb(image)


def variant_for_state(state: str) -> str:
    return {
        "breathing": "breathing",
        "cursor-look": "glance-right",
        "drag-release-settle": "drag-release-settle",
        "failed": "failed",
        "glance-left": "glance-left",
        "glance-right": "glance-right",
        "hair-sway": "hair-sway",
        "idle": "idle",
        "look-around": "look-around",
        "nod": "nod",
        "slow-blink": "slow-blink",
        "waiting": "waiting",
        "wake-up": "wake-up",
        "waving": "waving",
    }[state]


def write_state(state: str, count: int) -> None:
    state_dir = HIRES_ROOT / state
    state_dir.mkdir(parents=True, exist_ok=True)
    for stale in state_dir.glob("*.png"):
        stale.unlink()
    variant = variant_for_state(state)
    for index in range(count):
        draw_cat(variant, index, count).save(state_dir / f"{index:02d}.png")


def fit_to_cell(
    frame: Image.Image,
    *,
    scale_multiplier: float = 1.0,
    bottom_lift: int = 0,
) -> Image.Image:
    frame = frame.convert("RGBA")
    bbox = frame.getbbox()
    cropped = frame.crop(bbox) if bbox else frame
    scale = min(
        (CELL_SIZE[0] - 10) / cropped.width,
        (CELL_SIZE[1] - 10) / cropped.height,
        1.0,
    )
    scale *= scale_multiplier
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    cell = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
    cell.alpha_composite(
        resized,
        (
            (CELL_SIZE[0] - resized.width) // 2,
            CELL_SIZE[1] - resized.height - 5 - bottom_lift,
        ),
    )
    return normalize_hidden_rgb(cell)


def spritesheet_variant(row: str) -> str:
    return {
        "idle": "idle",
        "running-right": "running-right",
        "running-left": "running-left",
        "waving": "waving",
        "jumping": "jumping",
        "failed": "failed",
        "waiting": "waiting",
        "review": "review",
        "running": "running",
    }[row]


def load_approved_v2_atlas() -> Image.Image:
    spritesheet_path = PET_ROOT / "spritesheet.webp"
    if not spritesheet_path.is_file():
        raise FileNotFoundError(
            "Missing approved Maneki Neko v2 spritesheet. Complete the hatch-pet v2 QA run before rebuilding assets."
        )
    image = Image.open(spritesheet_path).convert("RGBA")
    expected_size = (CELL_SIZE[0] * V2_GRID_SIZE[0], CELL_SIZE[1] * V2_GRID_SIZE[1])
    if image.size != expected_size:
        raise ValueError(
            f"Approved Maneki Neko spritesheet must be {expected_size}, got {image.size}. "
            "Complete the hatch-pet v2 migration before rebuilding assets."
        )
    required_cells = [(0, 6), *[(row, column) for row in (9, 10) for column in range(8)]]
    for row, column in required_cells:
        cell = image.crop(
            (
                column * CELL_SIZE[0],
                row * CELL_SIZE[1],
                (column + 1) * CELL_SIZE[0],
                (row + 1) * CELL_SIZE[1],
            )
        )
        if cell.getchannel("A").getbbox() is None:
            raise ValueError(
                f"Approved Maneki Neko v2 spritesheet is missing required cell row={row} column={column}."
            )
    return image


def write_spritesheet() -> None:
    approved_v2 = load_approved_v2_atlas()
    PET_ROOT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new(
        "RGBA",
        (CELL_SIZE[0] * V2_GRID_SIZE[0], CELL_SIZE[1] * V2_GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for row_index, (row, frame_count) in enumerate(SPRITESHEET_ROWS):
        variant = spritesheet_variant(row)
        for column in range(frame_count):
            if row == "jumping":
                progress = column / max(1, frame_count - 1)
                jump_lift = round(28 * math.sin(progress * math.pi))
                frame = fit_to_cell(
                    draw_cat(variant, column, frame_count),
                    scale_multiplier=0.86,
                    bottom_lift=jump_lift,
                )
            else:
                frame = fit_to_cell(draw_cat(variant, column, frame_count))
            sheet.alpha_composite(frame, (column * CELL_SIZE[0], row_index * CELL_SIZE[1]))

    neutral = approved_v2.crop((6 * CELL_SIZE[0], 0, 7 * CELL_SIZE[0], CELL_SIZE[1]))
    sheet.alpha_composite(neutral, (6 * CELL_SIZE[0], 0))
    look_rows = approved_v2.crop(
        (0, STANDARD_ROWS * CELL_SIZE[1], sheet.width, V2_GRID_SIZE[1] * CELL_SIZE[1])
    )
    sheet.alpha_composite(look_rows, (0, STANDARD_ROWS * CELL_SIZE[1]))
    normalize_hidden_rgb(sheet).save(PET_ROOT / "spritesheet.webp", lossless=True, quality=100, method=6)
    (PET_ROOT / "pet.json").write_text(
        json.dumps(
            {
                "id": "maneki-neko",
                "displayName": "招财猫",
                "description": "A compact lucky white Maneki Neko desktop pet with a raised paw, red collar, gold bell, and coin.",
                "spriteVersionNumber": 2,
                "spritesheetPath": "spritesheet.webp",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    HIRES_ROOT.mkdir(parents=True, exist_ok=True)
    for child in HIRES_ROOT.iterdir():
        if child.is_dir() and child.name not in STATE_FRAME_COUNTS:
            shutil.rmtree(child)

    for state, count in STATE_FRAME_COUNTS.items():
        write_state(state, count)

    (HIRES_ROOT / "manifest.txt").write_text(
        "\n".join(
            [
                "source=scripts/build-maneki-neko-assets.py",
                "display_size=576x624",
                "style=deterministic vector-like maneki neko",
                f"content_scale={CONTENT_SCALE}",
                f"content_baseline_y={CONTENT_BASELINE_Y}",
                f"content_crop_box={CONTENT_CROP_BOX}",
                *[
                    f"{state} {len(list((HIRES_ROOT / state).glob('*.png')))}"
                    for state in sorted(STATE_FRAME_COUNTS)
                ],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    write_spritesheet()
    print(f"Wrote Maneki Neko runtime frames to {HIRES_ROOT}")
    print(f"Wrote Maneki Neko spritesheet to {PET_ROOT / 'spritesheet.webp'}")


if __name__ == "__main__":
    main()
