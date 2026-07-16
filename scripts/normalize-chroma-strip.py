#!/usr/bin/env python3
"""把 AI 生成的绿幕人物横条重新排成严格等宽网格。"""

from __future__ import annotations

import argparse
import math
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from statistics import median

from PIL import Image, ImageFilter


@dataclass(frozen=True)
class Component:
    area: int
    bbox: tuple[int, int, int, int]


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


def build_subject_mask(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    mask = Image.new("L", rgba.size)
    mask.putdata([
        0 if is_chroma_green(pixel) else 255
        for pixel in image_data(rgba)
    ])
    return mask


def find_components(mask: Image.Image) -> list[Component]:
    width, height = mask.size
    values = list(image_data(mask))
    seen = bytearray(width * height)
    components: list[Component] = []

    for start_index, alpha in enumerate(values):
        if seen[start_index] or alpha <= 8:
            continue

        queue = deque([start_index])
        seen[start_index] = 1
        area = 0
        min_x = width
        min_y = height
        max_x = 0
        max_y = 0

        while queue:
            index = queue.pop()
            x = index % width
            y = index // width
            area += 1
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x + 1)
            max_y = max(max_y, y + 1)

            for next_y in range(max(0, y - 1), min(height, y + 2)):
                row_start = next_y * width
                for next_x in range(max(0, x - 1), min(width, x + 2)):
                    next_index = row_start + next_x
                    if seen[next_index] or values[next_index] <= 8:
                        continue
                    seen[next_index] = 1
                    queue.append(next_index)

        components.append(Component(area=area, bbox=(min_x, min_y, max_x, max_y)))

    return components


def sample_background(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    sample_size = max(4, min(width, height) // 80)
    samples: list[tuple[int, int, int, int]] = []
    for left, top in (
        (0, 0),
        (width - sample_size, 0),
        (0, height - sample_size),
        (width - sample_size, height - sample_size),
    ):
        samples.extend(image_data(rgba.crop((left, top, left + sample_size, top + sample_size))))
    return tuple(round(median(channel)) for channel in zip(*samples))


def normalize_strip(
    source_path: Path,
    output_path: Path,
    columns: int,
    padding: int,
) -> None:
    source = Image.open(source_path).convert("RGBA")
    mask = build_subject_mask(source)
    components = sorted(find_components(mask), key=lambda component: component.area, reverse=True)
    if len(components) < columns:
        raise ValueError(
            f"Expected at least {columns} visible components, found {len(components)} in {source_path}"
        )

    # 每个人物及其手持足球在当前素材中属于同一主连通域；只取面积最大的 N 个，
    # 可稳定排除绿幕噪点，同时避免按理论格线切到相邻人物。
    selected = sorted(components[:columns], key=lambda component: component.bbox[0])
    max_subject_width = max(component.bbox[2] - component.bbox[0] for component in selected)
    tile_width = max(math.ceil(source.width / columns), max_subject_width + padding * 2)
    target_bottom = round(median(component.bbox[3] for component in selected))
    background = sample_background(source)
    output = Image.new("RGBA", (tile_width * columns, source.height), background)

    for column, component in enumerate(selected):
        left, top, right, bottom = component.bbox
        crop_left = max(0, left - 4)
        crop_top = max(0, top - 4)
        crop_right = min(source.width, right + 4)
        crop_bottom = min(source.height, bottom + 4)
        crop_box = (crop_left, crop_top, crop_right, crop_bottom)
        crop = source.crop(crop_box)
        crop_mask = mask.crop(crop_box).filter(ImageFilter.GaussianBlur(radius=0.35))

        subject_center_x = (left + right) / 2
        paste_x = round(
            column * tile_width
            + tile_width / 2
            - (subject_center_x - crop_left)
        )
        paste_y = target_bottom - (bottom - crop_top)
        output.paste(crop, (paste_x, paste_y), crop_mask)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path)
    print(
        f"Normalized {columns} characters from {source_path} to {output_path} "
        f"({output.width}x{output.height}, tile_width={tile_width})"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="输入绿幕横条 PNG")
    parser.add_argument("output", type=Path, help="输出严格等宽横条 PNG")
    parser.add_argument("--columns", required=True, type=int, help="人物格数")
    parser.add_argument("--padding", type=int, default=16, help="每格最小水平留白")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.columns <= 0:
        raise ValueError("--columns must be positive")
    if args.padding < 0:
        raise ValueError("--padding cannot be negative")
    normalize_strip(args.input, args.output, args.columns, args.padding)


if __name__ == "__main__":
    main()
