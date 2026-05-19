#!/opt/homebrew/bin/python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT / "assets" / "reference" / "generated"
OUTPUT_ROOT = ROOT / "assets" / "lingxi-ol-hires"
DISPLAY_SIZE = (576, 624)
MAX_BODY_HEIGHT = 540
MAX_UPSCALE = 1.0
ACTION_FRAME_COUNT = 24
ACTION_START_HOLD_FRAMES = 3
ACTION_TARGET_HOLD_FRAMES = 5
ACTION_TRANSITION_FRAMES = 8
TURN_FRAME_COUNT = 25
TURN_SEGMENT_FRAMES = 3
ACTION_STRIP_SOURCE = REFERENCE_ROOT / "action-strip-shirt-skirt-consistent.png"
TURNTABLE_STRIP_SOURCE = REFERENCE_ROOT / "turntable-strip-shirt-skirt-consistent.png"
PRIMARY_SOURCE = REFERENCE_ROOT / "base-shirt-skirt-hires.png"

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


def trim_and_fit(frame: Image.Image) -> Image.Image:
    bbox = frame.getbbox()
    if bbox is None:
        cropped = frame
    else:
        left, top, right, bottom = bbox
        width = right - left
        height = bottom - top
        pad_x = max(10, round(width * 0.08))
        pad_y = max(10, round(height * 0.06))
        cropped = frame.crop((
            max(0, left - pad_x),
            max(0, top - pad_y),
            min(frame.width, right + pad_x),
            min(frame.height, bottom + pad_y),
        ))

    canvas_width, canvas_height = DISPLAY_SIZE
    scale = min(canvas_width / cropped.width, MAX_BODY_HEIGHT / cropped.height, MAX_UPSCALE)
    scaled = cropped.resize((
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    ), Image.Resampling.LANCZOS)
    scaled = scaled.filter(ImageFilter.UnsharpMask(radius=0.45, percent=28, threshold=8))

    canvas = Image.new("RGBA", DISPLAY_SIZE, (0, 0, 0, 0))
    x = (canvas_width - scaled.width) // 2
    y = canvas_height - scaled.height
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


def split_grid(path: Path, columns: int, rows: int) -> list[Image.Image]:
    source = Image.open(path).convert("RGBA")
    frames: list[Image.Image] = []
    for row in range(rows):
        for column in range(columns):
            left = round(column * source.width / columns)
            right = round((column + 1) * source.width / columns)
            top = round(row * source.height / rows)
            bottom = round((row + 1) * source.height / rows)
            frame = source.crop((left, top, right, bottom))
            frames.append(trim_and_fit(transparent_chroma(frame)))
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


def main() -> None:
    primary_frame = load_single_frame(PRIMARY_SOURCE)
    action_frames = split_grid(ACTION_STRIP_SOURCE, columns=4, rows=1)
    turn_frames = split_grid(TURNTABLE_STRIP_SOURCE, columns=8, rows=1)

    for state in ["idle", "waiting", "review", "jumping", "failed"]:
        write_state(state, [primary_frame.copy() for _ in range(10 if state != "jumping" else 8)])

    write_state("running", brief_action_sequence(primary_frame, action_frames[2]))
    write_state("waving", brief_action_sequence(primary_frame, action_frames[3]))

    write_state("running-right", turntable_sequence(turn_frames))
    write_state("running-left", turntable_sequence(list(reversed(turn_frames))))
    write_state("turning", turntable_sequence(turn_frames))

    manifest = OUTPUT_ROOT / "manifest.txt"
    manifest.write_text(
        "\n".join(
            [
                "source=assets/reference/generated/base-shirt-skirt-hires.png",
                "source=assets/reference/generated/action-strip-shirt-skirt-consistent.png",
                "source=assets/reference/generated/turntable-strip-shirt-skirt-consistent.png",
                "display_size=576x624",
                f"max_body_height={MAX_BODY_HEIGHT}",
                f"max_upscale={MAX_UPSCALE}",
                "motion=alpha-aware tweened transitions, no body scale, no upscale",
                f"action_frame_count={ACTION_FRAME_COUNT}",
                f"turn_frame_count={TURN_FRAME_COUNT}",
                *[
                    f"{state} {len(list((OUTPUT_ROOT / state).glob('*.png')))}"
                    for state in sorted(path.name for path in OUTPUT_ROOT.iterdir() if path.is_dir())
                ],
            ]
        ) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote shirt-skirt runtime frames to {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
