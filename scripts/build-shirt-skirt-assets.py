#!/opt/homebrew/bin/python3
from __future__ import annotations

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT / "assets" / "reference" / "generated"
OUTPUT_ROOT = ROOT / "assets" / "lingxi-ol-hires"
DISPLAY_SIZE = (576, 624)

STATE_POSES = {
    "idle": [0, 2, 11, 0, 2, 11],
    "running": [4, 5, 1, 7, 9, 11],
    "waiting": [0, 3, 10, 11, 3, 0],
    "review": [3, 6, 7, 3, 6, 7],
    "waving": [0, 8, 8, 11],
    "jumping": [4, 9, 10, 4, 9],
    "failed": [10, 3, 6, 10, 3, 6, 10, 11],
}


def is_chroma_green(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    dominance = green - max(red, blue)
    spread = green - min(red, blue)
    return green > 70 and dominance > 8 and spread > 24


def transparent_chroma(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for pixel in rgba.getdata():
        if is_chroma_green(pixel):
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append(pixel)
    rgba.putdata(pixels)
    return rgba


def clean_edge_residue(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba.getdata():
        greenish = green > 45 and green > max(red, blue) + 3 and green - min(red, blue) > 10
        if alpha == 0 or (greenish and alpha < 120):
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
    scale = min(canvas_width / cropped.width, canvas_height / cropped.height)
    scaled = cropped.resize((
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    ), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", DISPLAY_SIZE, (0, 0, 0, 0))
    x = (canvas_width - scaled.width) // 2
    y = canvas_height - scaled.height
    canvas.alpha_composite(scaled, (x, y))
    return clean_edge_residue(canvas)


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
    ambient_frames = split_grid(REFERENCE_ROOT / "ambient-actions-v1.png", columns=6, rows=2)
    turn_frames = split_grid(REFERENCE_ROOT / "turntable-shirt-skirt.png", columns=8, rows=1)

    for state, pose_indices in STATE_POSES.items():
        write_state(state, [ambient_frames[index] for index in pose_indices])

    write_state("running-right", turn_frames)
    write_state("running-left", list(reversed(turn_frames)))

    manifest = OUTPUT_ROOT / "manifest.txt"
    manifest.write_text(
        "\n".join(
            [
                "source=assets/reference/generated/turntable-shirt-skirt.png",
                "source=assets/reference/generated/ambient-actions-v1.png",
                "display_size=576x624",
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
