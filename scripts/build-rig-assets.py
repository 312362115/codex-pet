#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/lingxi-ol-hires/waiting/00.png"
OUTPUT = ROOT / "assets/lingxi-ol-rig"
PARTS = OUTPUT / "parts"
WIDTH = 576
HEIGHT = 624


def normalize_hidden_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return rgba


def rectangle_mask(rect: tuple[int, int, int, int], feather: float = 2.0) -> Image.Image:
    mask = Image.new("L", (WIDTH, HEIGHT), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(rect, radius=16, fill=255)
    if feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
    return mask


def masked_part(source: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    part = source.copy()
    alpha = part.getchannel("A")
    mask = rectangle_mask(rect)
    part.putalpha(Image.composite(alpha, Image.new("L", (WIDTH, HEIGHT), 0), mask))
    return normalize_hidden_rgb(part)


def body_without_head(source: Image.Image) -> Image.Image:
    body = source.copy()
    alpha = body.getchannel("A")
    clear = rectangle_mask((236, 52, 354, 228), feather=3.0)
    alpha = Image.composite(Image.new("L", (WIDTH, HEIGHT), 0), alpha, clear)
    body.putalpha(alpha)
    return normalize_hidden_rgb(body)


def anchor_for(top_left_pivot: tuple[int, int]) -> tuple[float, float]:
    x, y = top_left_pivot
    return (round(x / WIDTH, 4), round((HEIGHT - y) / HEIGHT, 4))


def position_for(top_left_pivot: tuple[int, int]) -> dict[str, int]:
    x, y = top_left_pivot
    return {"x": x, "y": HEIGHT - y}


def relative_position_for(
    top_left_pivot: tuple[int, int],
    parent_top_left_pivot: tuple[int, int],
) -> dict[str, int]:
    x, y = top_left_pivot
    parent_x, parent_y = parent_top_left_pivot
    return {"x": x - parent_x, "y": parent_y - y}


def part_entry(
    part_id: str,
    image: str,
    z_index: int,
    top_left_pivot: tuple[int, int] = (288, 312),
    parent: str | None = None,
    parent_top_left_pivot: tuple[int, int] | None = None,
) -> dict[str, object]:
    ax, ay = anchor_for(top_left_pivot)
    position = (
        relative_position_for(top_left_pivot, parent_top_left_pivot)
        if parent_top_left_pivot is not None
        else position_for(top_left_pivot)
    )
    return {
        "id": part_id,
        "image": image,
        "parent": parent,
        "position": position,
        "anchor": {"x": ax, "y": ay},
        "zIndex": z_index,
    }


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source image: {SOURCE}")

    PARTS.mkdir(parents=True, exist_ok=True)
    for stale in PARTS.glob("*.png"):
        stale.unlink()
    source = normalize_hidden_rgb(Image.open(SOURCE))
    if source.size != (WIDTH, HEIGHT):
        raise SystemExit(f"Unexpected source size: {source.size}")

    outputs = {
        "body.png": body_without_head(source),
        "head.png": masked_part(source, (236, 52, 354, 228)),
    }

    for filename, image in outputs.items():
        image.save(PARTS / filename)

    manifest = {
        "canvas": {"width": WIDTH, "height": HEIGHT},
        "parts": [
            part_entry("body", "parts/body.png", 10, (288, 312)),
            part_entry("head", "parts/head.png", 30, (288, 190), parent="body", parent_top_left_pivot=(288, 312)),
        ],
    }
    (OUTPUT / "rig.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
