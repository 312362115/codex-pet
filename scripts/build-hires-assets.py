#!/opt/homebrew/bin/python3
from __future__ import annotations

from pathlib import Path
from PIL import Image


SOURCE_ROOT = Path("/private/tmp/hatch-pet-lingxi-ol/decoded")
OUTPUT_ROOT = Path("/private/tmp/codex-pet-companion/assets/lingxi-ol-hires")
DISPLAY_SIZE = (576, 624)
STATE_FRAME_COUNTS = {
    "idle": 6,
    "running-right": 8,
    "running-left": 8,
    "waving": 4,
    "jumping": 5,
    "failed": 8,
    "waiting": 6,
    "review": 6,
    "running": 6,
}


def is_chroma_green(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    return green > 145 and green > red * 1.65 and green > blue * 1.65


def transparent_chroma(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for pixel in rgba.getdata():
        if is_chroma_green(pixel):
            pixels.append((pixel[0], pixel[1], pixel[2], 0))
        else:
            pixels.append(pixel)
    rgba.putdata(pixels)
    return rgba


def padded_union_bbox(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    boxes = [frame.getbbox() for frame in frames]
    boxes = [box for box in boxes if box is not None]
    if not boxes:
        return (0, 0, frames[0].width, frames[0].height)

    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    pad_x = max(8, round((right - left) * 0.08))
    pad_y = max(8, round((bottom - top) * 0.06))
    return (
        max(0, left - pad_x),
        max(0, top - pad_y),
        min(frames[0].width, right + pad_x),
        min(frames[0].height, bottom + pad_y),
    )


def fit_on_canvas(frame: Image.Image) -> Image.Image:
    canvas_width, canvas_height = DISPLAY_SIZE
    scale = min(canvas_width / frame.width, canvas_height / frame.height)
    scaled_size = (
        max(1, round(frame.width * scale)),
        max(1, round(frame.height * scale)),
    )
    scaled = frame.resize(scaled_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", DISPLAY_SIZE, (0, 0, 0, 0))
    x = (canvas_width - scaled.width) // 2
    y = canvas_height - scaled.height
    canvas.alpha_composite(scaled, (x, y))
    return canvas


def split_state(state: str, count: int) -> list[Image.Image]:
    source = Image.open(SOURCE_ROOT / f"{state}.png").convert("RGBA")
    frames = []
    for index in range(count):
        left = round(index * source.width / count)
        right = round((index + 1) * source.width / count)
        slot = source.crop((left, 0, right, source.height))
        frames.append(transparent_chroma(slot))
    bbox = padded_union_bbox(frames)
    return [fit_on_canvas(frame.crop(bbox)) for frame in frames]


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    for state, count in STATE_FRAME_COUNTS.items():
        state_dir = OUTPUT_ROOT / state
        state_dir.mkdir(parents=True, exist_ok=True)
        for old in state_dir.glob("*.png"):
            old.unlink()
        frames = split_state(state, count)
        for index, frame in enumerate(frames):
            frame.save(state_dir / f"{index:02d}.png")

    manifest = OUTPUT_ROOT / "manifest.txt"
    manifest.write_text(
        "\n".join(f"{state} {count}" for state, count in STATE_FRAME_COUNTS.items()) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
