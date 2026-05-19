#!/opt/homebrew/bin/python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT / "assets" / "reference" / "generated"
OUTPUT_ROOT = ROOT / "assets" / "lingxi-ol-hires"
DISPLAY_SIZE = (576, 624)
MAX_UPSCALE = 1.0
HIRES_SOURCE = REFERENCE_ROOT / "base-shirt-skirt-hires.png"

STATE_POSE = {
    "idle": "base",
    "running": "base",
    "waiting": "base",
    "review": "base",
    "waving": "base",
    "jumping": "base",
    "failed": "base",
}

STATE_MOTION = {
    "idle": [(1.000, 0, 0), (1.006, 0, -1), (1.012, 0, -2), (1.018, 0, -3), (1.022, 0, -4), (1.018, 0, -3), (1.012, 0, -2), (1.006, 0, -1), (1.000, 0, 0), (0.998, 0, 0)],
    "running": [(1.000, 0, 0), (1.006, -1, -1), (1.012, -1, -2), (1.018, 1, -3), (1.022, 1, -4), (1.018, 0, -3), (1.012, -1, -2), (1.006, 0, -1), (1.000, 0, 0), (0.998, 0, 0)],
    "waiting": [(1.000, 0, 0), (1.006, 0, -1), (1.012, 0, -2), (1.018, 0, -3), (1.022, 0, -4), (1.018, 0, -3), (1.012, 0, -2), (1.006, 0, -1), (1.000, 0, 0), (0.998, 0, 0)],
    "review": [(1.000, 0, 0), (1.006, 0, -1), (1.012, 0, -2), (1.018, 0, -3), (1.022, 0, -4), (1.018, 0, -3), (1.012, 0, -2), (1.006, 0, -1), (1.000, 0, 0), (0.998, 0, 0)],
    "jumping": [(1.000, 0, 0), (1.006, 0, -3), (1.012, 0, -6), (1.018, 0, -9), (1.012, 0, -6), (1.006, 0, -3), (1.000, 0, 0), (0.998, 0, 0)],
    "failed": [(1.000, 0, 0), (1.006, 0, -1), (1.012, 0, -2), (1.018, 0, -3), (1.022, 0, -4), (1.018, 0, -3), (1.012, 0, -2), (1.006, 0, -1), (1.000, 0, 0), (0.998, 0, 0)],
}


def is_chroma_green(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    dominance = green - max(red, blue)
    spread = green - min(red, blue)
    return green > 64 and dominance > 14 and spread > 28


def transparent_chroma(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    mask_values = []
    for red, green, blue, alpha in rgba.getdata():
        if is_chroma_green((red, green, blue, alpha)):
            mask_values.append(0)
        else:
            mask_values.append(255)

    mask = Image.new("L", rgba.size)
    mask.putdata(mask_values)
    # 去掉贴近绿幕的一圈边，再做非常轻的羽化，避免绿边和锯齿同时出现。
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(radius=0.75))

    pixels = []
    for (red, green, blue, alpha), mask_alpha in zip(rgba.getdata(), mask.getdata()):
        if mask_alpha < 22:
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
    for red, green, blue, alpha in rgba.getdata():
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
    scale = min(canvas_width / cropped.width, canvas_height / cropped.height, MAX_UPSCALE)
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


def prepare_hires_frame(path: Path) -> Image.Image:
    return trim_and_fit(transparent_chroma(Image.open(path).convert("RGBA")))


def transform_frame(frame: Image.Image, scale: float, dx: int, dy: int) -> Image.Image:
    if scale == 1.0 and dx == 0 and dy == 0:
        return frame.copy()

    width, height = frame.size
    scaled = frame.resize((
        max(1, round(width * scale)),
        max(1, round(height * scale)),
    ), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    x = round((width - scaled.width) / 2) + dx
    y = height - scaled.height + dy
    canvas.alpha_composite(scaled, (x, y))
    return clean_edge_residue(canvas)


def motion_sequence(frame: Image.Image, motions: list[tuple[float, int, int]]) -> list[Image.Image]:
    return [transform_frame(frame, scale, dx, dy) for scale, dx, dy in motions]


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


def write_state(state: str, frames: list[Image.Image]) -> None:
    state_dir = OUTPUT_ROOT / state
    state_dir.mkdir(parents=True, exist_ok=True)
    for old in state_dir.glob("*.png"):
        old.unlink()
    for index, frame in enumerate(frames):
        frame.save(state_dir / f"{index:02d}.png")


def main() -> None:
    base_frame = prepare_hires_frame(HIRES_SOURCE)
    turn_frames = split_grid(REFERENCE_ROOT / "turntable-shirt-skirt.png", columns=8, rows=1)

    for state in STATE_POSE:
        write_state(state, motion_sequence(base_frame, STATE_MOTION[state if state != "waving" else "idle"]))

    write_state("running-right", turn_frames)
    write_state("running-left", list(reversed(turn_frames)))

    manifest = OUTPUT_ROOT / "manifest.txt"
    manifest.write_text(
        "\n".join(
            [
                "source=assets/reference/generated/turntable-shirt-skirt.png",
                "source=assets/reference/generated/base-shirt-skirt-hires.png",
                "display_size=576x624",
                f"max_upscale={MAX_UPSCALE}",
                "motion=fixed suites from high-resolution same-pose micro-motion frames",
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
