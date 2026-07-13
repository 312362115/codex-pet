#!/opt/homebrew/bin/python3
from __future__ import annotations

import json
import shutil
from pathlib import Path
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT / "assets" / "reference" / "generated"
OUTPUT_ROOT = ROOT / "assets" / "lingxi-ol-hires"
PET_ROOT = ROOT / "assets" / "lingxi-ol"
DISPLAY_SIZE = (576, 624)
CELL_SIZE = (192, 208)
V2_GRID_SIZE = (8, 11)
STANDARD_ROWS = 9
MAX_BODY_HEIGHT = 540
MAX_UPSCALE = 1.0
MAX_NORMALIZED_UPSCALE = 1.08
ACTION_FRAME_COUNT = 24
ACTION_START_HOLD_FRAMES = 3
ACTION_TARGET_HOLD_FRAMES = 5
ACTION_TRANSITION_FRAMES = 8
GLANCE_FRAME_COUNT = 16
GLANCE_START_HOLD_FRAMES = 2
GLANCE_TARGET_HOLD_FRAMES = 4
GLANCE_TRANSITION_FRAMES = 5
MICRO_SHORT_FRAME_COUNT = 12
MICRO_FRAME_COUNT = 16
TURN_FRAME_COUNT = 25
TURN_SEGMENT_FRAMES = 3
SHORT_FEEDBACK_FRAME_COUNT = 12
NOD_FRAME_COUNT = 16
LOOK_AROUND_FRAME_COUNT = 32
LARGE_ACTION_FRAME_COUNT = 32
WAKE_UP_FRAME_COUNT = 20
ACTION_STRIP_SOURCE = REFERENCE_ROOT / "action-strip-shirt-skirt-consistent.png"
TURNTABLE_STRIP_SOURCE = REFERENCE_ROOT / "turntable-strip-shirt-skirt-consistent.png"
PRIMARY_SOURCE = REFERENCE_ROOT / "base-shirt-skirt-hires.png"
EXPRESSION_STRIP_SOURCE = REFERENCE_ROOT / "expression-keyframes-v1.png"
RUNTIME_STATES = {
    "adjust-glasses",
    "adjust-outfit",
    "breathing",
    "check-notes",
    "cursor-look",
    "drag-release-settle",
    "failed",
    "fix-posture",
    "focus-shift",
    "glance-left",
    "glance-right",
    "hair-sway",
    "idle",
    "look-around",
    "nod",
    "posture-reset",
    "review",
    "running",
    "shoulder-relax",
    "step-aside",
    "stretch",
    "stretch-wrist",
    "tap-keyboard",
    "thinking",
    "tiny-hand-adjust",
    "turning",
    "waiting",
    "wake-up",
    "waving",
    "weight-shift",
}
NATIVE_ROWS = [
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

def is_chroma_green(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    dominance = green - max(red, blue)
    spread = green - min(red, blue)
    return green > 64 and dominance > 14 and spread > 28


def image_data(image: Image.Image):
    if hasattr(image, "get_flattened_data"):
        return image.get_flattened_data()
    return image.getdata()


def transparent_chroma(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    mask_values = []
    for red, green, blue, alpha in image_data(rgba):
        if is_chroma_green((red, green, blue, alpha)):
            mask_values.append(0)
        else:
            mask_values.append(255)

    mask = Image.new("L", rgba.size)
    mask.putdata(mask_values)
    # 真人立绘的脸、脚踝和小腿很窄，不能用腐蚀型 mask，否则会削尖轮廓。
    mask = mask.filter(ImageFilter.GaussianBlur(radius=0.35))

    pixels = []
    for (red, green, blue, alpha), mask_alpha in zip(image_data(rgba), image_data(mask)):
        if mask_alpha < 32:
            pixels.append((0, 0, 0, 0))
            continue

        if green > max(red, blue) + 3:
            green = max(red, blue)
        pixels.append((red, green, blue, min(alpha, mask_alpha)))
    rgba.putdata(pixels)
    return rgba


def clean_edge_residue(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in image_data(rgba):
        greenish = green > 42 and green > max(red, blue) + 2 and green - min(red, blue) > 8
        if alpha == 0 or (greenish and alpha < 96):
            pixels.append((0, 0, 0, 0))
        elif greenish:
            neutral_green = max(red, blue)
            pixels.append((red, neutral_green, blue, alpha))
        else:
            pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return rgba


def normalize_hidden_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in image_data(rgba):
        if alpha == 0:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return rgba


def remove_alpha_islands(image: Image.Image, min_area_ratio: float = 0.02) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha_values = list(image_data(rgba.getchannel("A")))
    seen = bytearray(width * height)
    components: list[list[int]] = []

    for start_index, alpha in enumerate(alpha_values):
        if seen[start_index] or alpha <= 8:
            continue

        stack = [start_index]
        seen[start_index] = 1
        component: list[int] = []
        while stack:
            index = stack.pop()
            component.append(index)
            x = index % width
            y = index // width
            for next_y in range(max(0, y - 1), min(height, y + 2)):
                row_start = next_y * width
                for next_x in range(max(0, x - 1), min(width, x + 2)):
                    next_index = row_start + next_x
                    if seen[next_index] or alpha_values[next_index] <= 8:
                        continue
                    seen[next_index] = 1
                    stack.append(next_index)

        components.append(component)

    if len(components) <= 1:
        return rgba

    largest_area = max(len(component) for component in components)
    minimum_area = max(24, round(largest_area * min_area_ratio))
    removed_indexes = [
        index
        for component in components
        if len(component) < minimum_area
        for index in component
    ]
    if not removed_indexes:
        return rgba

    pixels = list(image_data(rgba))
    for index in removed_indexes:
        pixels[index] = (0, 0, 0, 0)
    rgba.putdata(pixels)
    return rgba


def trim_and_fit(
    frame: Image.Image,
    target_body_height: int | None = None,
    target_baseline_y: int | None = None,
) -> Image.Image:
    bbox = frame.getbbox()
    if bbox is None:
        cropped = frame
        crop_left = 0
        crop_top = 0
    else:
        left, top, right, bottom = bbox
        width = right - left
        height = bottom - top
        pad_x = max(10, round(width * 0.08))
        pad_y = max(10, round(height * 0.06))
        crop_left = max(0, left - pad_x)
        crop_top = max(0, top - pad_y)
        cropped = frame.crop((
            crop_left,
            crop_top,
            min(frame.width, right + pad_x),
            min(frame.height, bottom + pad_y),
        ))

    canvas_width, canvas_height = DISPLAY_SIZE
    if bbox is None or target_body_height is None:
        scale = min(canvas_width / cropped.width, MAX_BODY_HEIGHT / cropped.height, MAX_UPSCALE)
    else:
        left, top, right, bottom = bbox
        body_height = bottom - top
        scale = min(
            target_body_height / body_height,
            canvas_width / cropped.width,
            MAX_BODY_HEIGHT / body_height,
            MAX_NORMALIZED_UPSCALE,
        )
    scaled = cropped.resize((
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    ), Image.Resampling.LANCZOS)
    scaled = scaled.filter(ImageFilter.UnsharpMask(radius=0.45, percent=28, threshold=8))

    canvas = Image.new("RGBA", DISPLAY_SIZE, (0, 0, 0, 0))
    if bbox is None or target_body_height is None:
        x = (canvas_width - scaled.width) // 2
        y = canvas_height - scaled.height
    else:
        left, top, right, bottom = bbox
        body_left = round((left - crop_left) * scale)
        body_right = round((right - crop_left) * scale)
        body_bottom = round((bottom - crop_top) * scale)
        x = round(canvas_width / 2 - (body_left + body_right) / 2)
        y = (target_baseline_y if target_baseline_y is not None else canvas_height) - body_bottom
        x = max(0, min(x, canvas_width - scaled.width))
        y = max(0, min(y, canvas_height - scaled.height))
    canvas.alpha_composite(scaled, (x, y))
    return clean_edge_residue(canvas)


def smoothstep(progress: float) -> float:
    return progress * progress * (3.0 - 2.0 * progress)


def tween_frame(start: Image.Image, end: Image.Image, progress: float) -> Image.Image:
    start_rgba = start.convert("RGBA")
    end_rgba = end.convert("RGBA")
    if start_rgba.size != end_rgba.size:
        raise ValueError(f"Cannot tween frames with different sizes: {start_rgba.size} vs {end_rgba.size}")

    weight = smoothstep(progress)
    inverse = 1.0 - weight
    pixels = []
    for (sr, sg, sb, sa), (er, eg, eb, ea) in zip(image_data(start_rgba), image_data(end_rgba)):
        start_alpha = sa / 255.0
        end_alpha = ea / 255.0
        alpha = start_alpha * inverse + end_alpha * weight
        if alpha <= 0.0001:
            pixels.append((0, 0, 0, 0))
            continue

        red = (sr * start_alpha * inverse + er * end_alpha * weight) / alpha
        green = (sg * start_alpha * inverse + eg * end_alpha * weight) / alpha
        blue = (sb * start_alpha * inverse + eb * end_alpha * weight) / alpha
        pixels.append((
            max(0, min(255, round(red))),
            max(0, min(255, round(green))),
            max(0, min(255, round(blue))),
            max(0, min(255, round(alpha * 255))),
        ))

    tweened = Image.new("RGBA", start_rgba.size)
    tweened.putdata(pixels)
    return clean_edge_residue(tweened)


def shifted_frame(frame: Image.Image, offset_x: int, offset_y: int) -> Image.Image:
    shifted = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    shifted.alpha_composite(frame.convert("RGBA"), (offset_x, offset_y))
    return clean_edge_residue(shifted)


def transition_frames(start: Image.Image, end: Image.Image, frame_count: int) -> list[Image.Image]:
    return [
        tween_frame(start, end, index / frame_count)
        for index in range(1, frame_count + 1)
    ]


def brief_action_sequence(primary_frame: Image.Image, action_frame: Image.Image) -> list[Image.Image]:
    frames = [
        *[primary_frame.copy() for _ in range(ACTION_START_HOLD_FRAMES)],
        *transition_frames(primary_frame, action_frame, ACTION_TRANSITION_FRAMES),
        *[action_frame.copy() for _ in range(ACTION_TARGET_HOLD_FRAMES)],
        *transition_frames(action_frame, primary_frame, ACTION_TRANSITION_FRAMES),
    ]
    if len(frames) != ACTION_FRAME_COUNT:
        raise AssertionError(f"Expected {ACTION_FRAME_COUNT} action frames, got {len(frames)}")
    return frames


def glance_sequence(primary_frame: Image.Image, glance_frame: Image.Image) -> list[Image.Image]:
    frames = [
        *[primary_frame.copy() for _ in range(GLANCE_START_HOLD_FRAMES)],
        *transition_frames(primary_frame, glance_frame, GLANCE_TRANSITION_FRAMES),
        *[glance_frame.copy() for _ in range(GLANCE_TARGET_HOLD_FRAMES)],
        *transition_frames(glance_frame, primary_frame, GLANCE_TRANSITION_FRAMES),
    ]
    if len(frames) != GLANCE_FRAME_COUNT:
        raise AssertionError(f"Expected {GLANCE_FRAME_COUNT} glance frames, got {len(frames)}")
    return frames


def offset_sequence(primary_frame: Image.Image, offsets: list[tuple[int, int]], expected_count: int, name: str) -> list[Image.Image]:
    frames = [
        shifted_frame(primary_frame, offset_x, offset_y)
        for offset_x, offset_y in offsets
    ]
    if len(frames) != expected_count:
        raise AssertionError(f"Expected {expected_count} {name} frames, got {len(frames)}")
    return frames


def micro_action_sequence(primary_frame: Image.Image, target_frame: Image.Image) -> list[Image.Image]:
    frames = [
        primary_frame.copy(),
        *transition_frames(primary_frame, target_frame, 5),
        *[target_frame.copy() for _ in range(4)],
        *transition_frames(target_frame, primary_frame, 6),
    ]
    if len(frames) != MICRO_FRAME_COUNT:
        raise AssertionError(f"Expected {MICRO_FRAME_COUNT} micro frames, got {len(frames)}")
    return frames


def large_action_sequence(primary_frame: Image.Image, target_frame: Image.Image) -> list[Image.Image]:
    frames = [
        *[primary_frame.copy() for _ in range(2)],
        *transition_frames(primary_frame, target_frame, 10),
        *[target_frame.copy() for _ in range(8)],
        *transition_frames(target_frame, primary_frame, 12),
    ]
    if len(frames) != LARGE_ACTION_FRAME_COUNT:
        raise AssertionError(f"Expected {LARGE_ACTION_FRAME_COUNT} large-action frames, got {len(frames)}")
    return frames


def posture_reset_sequence(primary_frame: Image.Image) -> list[Image.Image]:
    lowered = shifted_frame(primary_frame, 0, 7)
    raised = shifted_frame(primary_frame, 0, -5)
    frames = [
        *[primary_frame.copy() for _ in range(2)],
        *transition_frames(primary_frame, lowered, 6),
        *[lowered.copy() for _ in range(4)],
        *transition_frames(lowered, raised, 6),
        *[raised.copy() for _ in range(2)],
        *transition_frames(raised, primary_frame, 12),
    ]
    if len(frames) != LARGE_ACTION_FRAME_COUNT:
        raise AssertionError(f"Expected {LARGE_ACTION_FRAME_COUNT} posture-reset frames, got {len(frames)}")
    return frames


def nod_sequence(primary_frame: Image.Image) -> list[Image.Image]:
    down = shifted_frame(primary_frame, 0, 7)
    frames = [
        primary_frame.copy(),
        *transition_frames(primary_frame, down, 5),
        *[down.copy() for _ in range(4)],
        *transition_frames(down, primary_frame, 6),
    ]
    if len(frames) != NOD_FRAME_COUNT:
        raise AssertionError(f"Expected {NOD_FRAME_COUNT} nod frames, got {len(frames)}")
    return frames


def look_around_sequence(primary_frame: Image.Image, left_frame: Image.Image, right_frame: Image.Image) -> list[Image.Image]:
    frames = [
        *[primary_frame.copy() for _ in range(2)],
        *transition_frames(primary_frame, left_frame, 5),
        *[left_frame.copy() for _ in range(3)],
        *transition_frames(left_frame, primary_frame, 4),
        *[primary_frame.copy() for _ in range(2)],
        *transition_frames(primary_frame, right_frame, 5),
        *[right_frame.copy() for _ in range(3)],
        *transition_frames(right_frame, primary_frame, 8),
    ]
    if len(frames) != LOOK_AROUND_FRAME_COUNT:
        raise AssertionError(f"Expected {LOOK_AROUND_FRAME_COUNT} look-around frames, got {len(frames)}")
    return frames


def wake_up_sequence(primary_frame: Image.Image) -> list[Image.Image]:
    offsets = [(0, 10), (0, 10), (0, 8), (0, 7), (0, 6), (0, 4), (0, 3), (0, 2), (0, 1), (0, 0)]
    frames = [
        *[shifted_frame(primary_frame, offset_x, offset_y) for offset_x, offset_y in offsets],
        *[primary_frame.copy() for _ in range(10)],
    ]
    if len(frames) != WAKE_UP_FRAME_COUNT:
        raise AssertionError(f"Expected {WAKE_UP_FRAME_COUNT} wake-up frames, got {len(frames)}")
    return frames


def turntable_sequence(turn_frames: list[Image.Image]) -> list[Image.Image]:
    if len(turn_frames) < 2:
        return turn_frames

    frames = [turn_frames[0].copy()]
    for index, frame in enumerate(turn_frames):
        next_frame = turn_frames[(index + 1) % len(turn_frames)]
        frames.extend(transition_frames(frame, next_frame, TURN_SEGMENT_FRAMES))

    if len(frames) != TURN_FRAME_COUNT:
        raise AssertionError(f"Expected {TURN_FRAME_COUNT} turn frames, got {len(frames)}")
    return frames


def split_grid(
    path: Path,
    columns: int,
    rows: int,
    target_body_height: int | None = None,
    target_baseline_y: int | None = None,
) -> list[Image.Image]:
    source = Image.open(path).convert("RGBA")
    frames: list[Image.Image] = []
    for row in range(rows):
        for column in range(columns):
            left = round(column * source.width / columns)
            right = round((column + 1) * source.width / columns)
            top = round(row * source.height / rows)
            bottom = round((row + 1) * source.height / rows)
            frame = source.crop((left, top, right, bottom))
            # AI 横条偶尔会把相邻格的边缘残片切进来，先移除游离小块再算人物尺寸。
            cleaned = remove_alpha_islands(transparent_chroma(frame))
            frames.append(trim_and_fit(
                cleaned,
                target_body_height=target_body_height,
                target_baseline_y=target_baseline_y,
            ))
    return frames


def load_single_frame(path: Path) -> Image.Image:
    return trim_and_fit(transparent_chroma(Image.open(path).convert("RGBA")))


def write_state(state: str, frames: list[Image.Image]) -> None:
    state_dir = OUTPUT_ROOT / state
    state_dir.mkdir(parents=True, exist_ok=True)
    for old in state_dir.glob("*.png"):
        old.unlink()
    for index, frame in enumerate(frames):
        frame.save(state_dir / f"{index:02d}.png")


def fit_native_sequence(frames: list[Image.Image]) -> list[Image.Image]:
    """用整行共享几何生成原生帧，保留跳跃、呼吸和行进的相对位移。"""
    cleaned = [clean_edge_residue(frame.convert("RGBA")) for frame in frames]
    bboxes = [frame.getbbox() for frame in cleaned]
    visible = [bbox for bbox in bboxes if bbox is not None]
    if not visible:
        raise ValueError("Native sequence must contain visible frames")

    left = min(bbox[0] for bbox in visible)
    top = min(bbox[1] for bbox in visible)
    right = max(bbox[2] for bbox in visible)
    bottom = max(bbox[3] for bbox in visible)
    union_bbox = (left, top, right, bottom)
    union_width = right - left
    union_height = bottom - top
    scale = min(
        (CELL_SIZE[0] - 10) / union_width,
        (CELL_SIZE[1] - 10) / union_height,
        1.0,
    )
    target_size = (
        max(1, round(union_width * scale)),
        max(1, round(union_height * scale)),
    )
    target_position = (
        (CELL_SIZE[0] - target_size[0]) // 2,
        CELL_SIZE[1] - target_size[1] - 5,
    )

    cells = []
    for frame in cleaned:
        resized = frame.crop(union_bbox).resize(target_size, Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
        cell.alpha_composite(resized, target_position)
        cells.append(normalize_hidden_rgb(cell))
    return cells


def shifted_keyframes(
    keyframes: list[Image.Image],
    offsets: list[tuple[int, int]],
) -> list[Image.Image]:
    if len(keyframes) != len(offsets):
        raise ValueError("Native keyframes and offsets must have identical lengths")
    return [
        shifted_frame(frame, offset_x, offset_y)
        for frame, (offset_x, offset_y) in zip(keyframes, offsets)
    ]


def build_native_sequences(
    primary_frame: Image.Image,
    action_frames: list[Image.Image],
    turn_frames: list[Image.Image],
    expression_frames: list[Image.Image],
) -> dict[str, list[Image.Image]]:
    failed_frame = expression_frames[0]
    review_frame = expression_frames[1]
    wave_expression_frame = expression_frames[2]
    waiting_frame = expression_frames[3]
    running_frame = action_frames[2]
    wave_frame = action_frames[3]
    right_profile = turn_frames[6]
    right_three_quarter = turn_frames[7]
    left_profile = turn_frames[2]
    left_three_quarter = turn_frames[1]

    native_source_sequences = {
        "idle": [
            shifted_frame(primary_frame, 0, offset_y)
            for offset_y in (0, -3, -6, -6, -3, 0)
        ],
        "running-right": shifted_keyframes(
            [right_profile, right_three_quarter] * 4,
            [(0, 0), (5, -6), (10, -2), (5, -8), (0, 0), (-5, -6), (-10, -2), (-5, -8)],
        ),
        "running-left": shifted_keyframes(
            [left_profile, left_three_quarter] * 4,
            [(0, 0), (-5, -6), (-10, -2), (-5, -8), (0, 0), (5, -6), (10, -2), (5, -8)],
        ),
        "waving": [
            wave_frame.copy(),
            wave_expression_frame.copy(),
            shifted_frame(wave_frame, -2, -3),
            wave_expression_frame.copy(),
        ],
        "jumping": [
            shifted_frame(primary_frame, 0, offset_y)
            for offset_y in (0, -18, -36, -18, 0)
        ],
        "failed": [
            shifted_frame(failed_frame, 0, offset_y)
            for offset_y in (0, 3, 7, 10, 10, 7, 3, 0)
        ],
        "waiting": [
            shifted_frame(waiting_frame, offset_x, offset_y)
            for offset_x, offset_y in ((0, 0), (2, -2), (4, -4), (2, -2), (0, 0), (-2, -1))
        ],
        "running": [
            shifted_frame(running_frame, offset_x, offset_y)
            for offset_x, offset_y in ((0, 0), (3, -5), (6, -2), (3, -7), (0, 0), (-3, -4))
        ],
        "review": [
            shifted_frame(review_frame, 0, offset_y)
            for offset_y in (0, 2, 5, 5, 2, 0)
        ],
    }

    expected_counts = dict(NATIVE_ROWS)
    for state, frames in native_source_sequences.items():
        expected = expected_counts[state]
        if len(frames) != expected:
            raise AssertionError(f"Expected {expected} native {state} frames, got {len(frames)}")
    return {
        state: fit_native_sequence(frames)
        for state, frames in native_source_sequences.items()
    }


def load_approved_v2_atlas() -> Image.Image:
    spritesheet_path = PET_ROOT / "spritesheet.webp"
    if not spritesheet_path.is_file():
        raise FileNotFoundError(
            "Missing approved Lingxi OL v2 spritesheet. Complete the hatch-pet v2 QA run before rebuilding assets."
        )
    image = Image.open(spritesheet_path).convert("RGBA")
    expected_size = (CELL_SIZE[0] * V2_GRID_SIZE[0], CELL_SIZE[1] * V2_GRID_SIZE[1])
    if image.size != expected_size:
        raise ValueError(
            f"Approved Lingxi OL spritesheet must be {expected_size}, got {image.size}. "
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
                f"Approved Lingxi OL v2 spritesheet is missing required cell row={row} column={column}."
            )
    return image


def write_native_pet_package(native_sequences: dict[str, list[Image.Image]]) -> None:
    approved_v2 = load_approved_v2_atlas()
    PET_ROOT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new(
        "RGBA",
        (CELL_SIZE[0] * V2_GRID_SIZE[0], CELL_SIZE[1] * V2_GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for row_index, (state, frame_count) in enumerate(NATIVE_ROWS):
        frames = native_sequences[state]
        if len(frames) != frame_count:
            raise AssertionError(f"Expected {frame_count} native {state} frames, got {len(frames)}")
        for column_index, frame in enumerate(frames):
            sheet.alpha_composite(frame, (column_index * CELL_SIZE[0], row_index * CELL_SIZE[1]))

    neutral = approved_v2.crop((6 * CELL_SIZE[0], 0, 7 * CELL_SIZE[0], CELL_SIZE[1]))
    sheet.alpha_composite(neutral, (6 * CELL_SIZE[0], 0))
    look_rows = approved_v2.crop(
        (0, STANDARD_ROWS * CELL_SIZE[1], sheet.width, V2_GRID_SIZE[1] * CELL_SIZE[1])
    )
    sheet.alpha_composite(look_rows, (0, STANDARD_ROWS * CELL_SIZE[1]))

    normalize_hidden_rgb(sheet).save(PET_ROOT / "spritesheet.webp", lossless=True, quality=100, method=6, exact=True)
    (PET_ROOT / "pet.json").write_text(
        json.dumps(
            {
                "id": "lingxi-ol",
                "displayName": "Lingxi OL",
                "description": "A polished office-style Codex companion with glasses, a white shirt, black skirt, and calm work-focused gestures.",
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
    primary_frame = load_single_frame(PRIMARY_SOURCE)
    primary_bbox = primary_frame.getbbox()
    if primary_bbox is None:
        raise ValueError(f"Primary source produced an empty frame: {PRIMARY_SOURCE}")
    target_body_height = primary_bbox[3] - primary_bbox[1]
    target_baseline_y = primary_bbox[3]

    action_frames = split_grid(
        ACTION_STRIP_SOURCE,
        columns=4,
        rows=1,
        target_body_height=target_body_height,
        target_baseline_y=target_baseline_y,
    )
    turn_frames = split_grid(
        TURNTABLE_STRIP_SOURCE,
        columns=8,
        rows=1,
        target_body_height=target_body_height,
        target_baseline_y=target_baseline_y,
    )
    expression_frames = split_grid(
        EXPRESSION_STRIP_SOURCE,
        columns=6,
        rows=1,
        target_body_height=target_body_height,
        target_baseline_y=target_baseline_y,
    )
    (
        failed_concerned_frame,
        review_focused_frame,
        _wave_expression_frame,
        completed_soft_smile_frame,
        tired_soft_frame,
        wake_up_clear_frame,
    ) = expression_frames
    waiting_expectant_frame = completed_soft_smile_frame
    native_sequences = build_native_sequences(
        primary_frame,
        action_frames,
        turn_frames,
        expression_frames,
    )

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    for state_dir in OUTPUT_ROOT.iterdir():
        if state_dir.is_dir() and state_dir.name not in RUNTIME_STATES:
            shutil.rmtree(state_dir)

    write_state("idle", [primary_frame.copy() for _ in range(10)])
    write_state("waiting", [waiting_expectant_frame.copy() for _ in range(10)])
    write_state("review", [review_focused_frame.copy() for _ in range(10)])
    write_state("failed", [failed_concerned_frame.copy() for _ in range(10)])

    write_state("running", brief_action_sequence(primary_frame, action_frames[2]))
    write_state("waving", brief_action_sequence(primary_frame, action_frames[3]))
    write_state("thinking", brief_action_sequence(primary_frame, action_frames[1]))
    write_state("adjust-glasses", brief_action_sequence(primary_frame, action_frames[2]))
    write_state("tap-keyboard", brief_action_sequence(primary_frame, action_frames[2]))
    write_state("check-notes", brief_action_sequence(primary_frame, action_frames[1]))
    write_state("stretch-wrist", brief_action_sequence(primary_frame, action_frames[3]))
    write_state("nod", nod_sequence(completed_soft_smile_frame))
    write_state("glance-left", glance_sequence(primary_frame, turn_frames[1]))
    write_state("glance-right", glance_sequence(primary_frame, turn_frames[-1]))
    write_state("cursor-look", glance_sequence(primary_frame, turn_frames[-1]))
    write_state("focus-shift", brief_action_sequence(primary_frame, turn_frames[-1]))
    write_state("fix-posture", brief_action_sequence(primary_frame, shifted_frame(primary_frame, 0, -6)))
    write_state("adjust-outfit", brief_action_sequence(primary_frame, action_frames[1]))
    write_state("look-around", look_around_sequence(primary_frame, turn_frames[1], turn_frames[-1]))
    write_state("stretch", large_action_sequence(primary_frame, shifted_frame(action_frames[3], 0, -8)))
    write_state("step-aside", offset_sequence(
        primary_frame,
        [(0, 0), (-2, 0), (-5, 0), (-8, 0), (-12, 0), (-16, 0), (-20, 0), (-20, 0),
         (-18, 0), (-15, 0), (-12, 0), (-8, 0), (-4, 0), (0, 0), (3, 0), (5, 0),
         (6, 0), (5, 0), (3, 0), (0, 0), (-2, 0), (-4, 0), (-5, 0), (-4, 0),
         (-2, 0), (0, 0), (1, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)],
        LARGE_ACTION_FRAME_COUNT,
        "step-aside",
    ))
    write_state("posture-reset", posture_reset_sequence(primary_frame))
    write_state("breathing", offset_sequence(
        primary_frame,
        [(0, 0), (0, -1), (0, -2), (0, -2), (0, -1), (0, 0), (0, 1), (0, 2), (0, 2), (0, 1), (0, 0), (0, 0)],
        MICRO_SHORT_FRAME_COUNT,
        "breathing",
    ))
    write_state("hair-sway", offset_sequence(
        primary_frame,
        [(0, 0), (1, 0), (2, 0), (1, 0), (0, 0), (-1, 0), (-2, 0), (-1, 0), (0, 0), (1, 0), (0, 0), (0, 0)],
        MICRO_SHORT_FRAME_COUNT,
        "hair-sway",
    ))
    write_state("weight-shift", offset_sequence(
        primary_frame,
        [(0, 0), (2, 0), (4, 0), (6, 0), (6, 0), (4, 0), (2, 0), (0, 0),
         (-2, 0), (-4, 0), (-6, 0), (-6, 0), (-4, 0), (-2, 0), (0, 0), (0, 0)],
        MICRO_FRAME_COUNT,
        "weight-shift",
    ))
    write_state("shoulder-relax", offset_sequence(
        primary_frame,
        [(0, 0), (0, 1), (0, 3), (0, 5), (0, 7), (0, 7), (0, 5), (0, 3),
         (0, 1), (0, 0), (0, -1), (0, 0), (0, 1), (0, 0), (0, 0), (0, 0)],
        MICRO_FRAME_COUNT,
        "shoulder-relax",
    ))
    write_state("tiny-hand-adjust", micro_action_sequence(primary_frame, action_frames[1]))
    write_state("drag-release-settle", nod_sequence(primary_frame)[:SHORT_FEEDBACK_FRAME_COUNT])
    write_state("wake-up", wake_up_sequence(wake_up_clear_frame))

    write_state("turning", turntable_sequence(turn_frames))

    manifest = OUTPUT_ROOT / "manifest.txt"
    manifest.write_text(
        "\n".join(
            [
                "source=assets/reference/generated/base-shirt-skirt-hires.png",
                "source=assets/reference/generated/action-strip-shirt-skirt-consistent.png",
                "source=assets/reference/generated/turntable-strip-shirt-skirt-consistent.png",
                "source=assets/reference/generated/expression-keyframes-v1.png",
                "display_size=576x624",
                f"max_body_height={MAX_BODY_HEIGHT}",
                f"max_upscale={MAX_UPSCALE}",
                f"normalized_body_height={target_body_height}",
                f"normalized_body_baseline_y={target_baseline_y}",
                "motion=alpha-aware tweened transitions, normalized body height",
                f"action_frame_count={ACTION_FRAME_COUNT}",
                f"glance_frame_count={GLANCE_FRAME_COUNT}",
                f"micro_short_frame_count={MICRO_SHORT_FRAME_COUNT}",
                f"micro_frame_count={MICRO_FRAME_COUNT}",
                f"short_feedback_frame_count={SHORT_FEEDBACK_FRAME_COUNT}",
                f"nod_frame_count={NOD_FRAME_COUNT}",
                f"look_around_frame_count={LOOK_AROUND_FRAME_COUNT}",
                f"large_action_frame_count={LARGE_ACTION_FRAME_COUNT}",
                f"turn_frame_count={TURN_FRAME_COUNT}",
                *[
                    f"{state} {len(list((OUTPUT_ROOT / state).glob('*.png')))}"
                    for state in sorted(path.name for path in OUTPUT_ROOT.iterdir() if path.is_dir())
                ],
            ]
        ) + "\n",
        encoding="utf-8",
    )
    write_native_pet_package(native_sequences)
    print(f"Wrote shirt-skirt runtime frames to {OUTPUT_ROOT}")
    print(f"Wrote Lingxi OL native pet package to {PET_ROOT}")


if __name__ == "__main__":
    main()
