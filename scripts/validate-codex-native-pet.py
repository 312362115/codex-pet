#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image


CELL_SIZE = (192, 208)
COLUMNS = 8
V1_ROWS = 9
V2_ROWS = 11
V1_SIZE = (CELL_SIZE[0] * COLUMNS, CELL_SIZE[1] * V1_ROWS)
V2_SIZE = (CELL_SIZE[0] * COLUMNS, CELL_SIZE[1] * V2_ROWS)
REQUIRED_KEYS = {"displayName", "description", "spritesheetPath"}
V2_REQUIRED_KEYS = REQUIRED_KEYS | {"id", "spriteVersionNumber"}
V2_STANDARD_FRAME_COUNTS = (6, 8, 8, 4, 5, 8, 6, 6, 6)
V2_NEUTRAL_FRAME = (0, 6)
V2_REQUIRED_ANIMATED_ROWS = (0, 1, 2, 3, 4, 6, 7, 8)


def fail(message: str) -> None:
    raise SystemExit(f"FAIL Codex native pet: {message}")


def count_visible_pixels(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    return sum(1 for value in alpha.tobytes() if value > 48)


def count_nontransparent_pixels(image: Image.Image) -> int:
    return sum(image.getchannel("A").histogram()[1:])


def expect_transparent_pixels_normalized(image: Image.Image) -> None:
    rgba = image.tobytes()
    for index in range(0, len(rgba), 4):
        red, green, blue, alpha = rgba[index : index + 4]
        if alpha == 0 and (red, green, blue) != (0, 0, 0):
            fail("spritesheet has hidden RGB residue in transparent pixels")


def atlas_cell(image: Image.Image, row: int, column: int) -> Image.Image:
    return image.crop(
        (
            column * CELL_SIZE[0],
            row * CELL_SIZE[1],
            (column + 1) * CELL_SIZE[0],
            (row + 1) * CELL_SIZE[1],
        )
    )


def validate_v1_atlas(image: Image.Image) -> None:
    if image.size != V1_SIZE:
        fail(f"v1 spritesheet size should be {V1_SIZE}, got {image.size}")

    for row in range(V1_ROWS):
        for column in range(COLUMNS):
            if count_visible_pixels(atlas_cell(image, row, column)) < 600:
                fail(f"v1 cell row={row} column={column} has too few visible pixels")


def is_v2_used_cell(row: int, column: int) -> bool:
    if row >= len(V2_STANDARD_FRAME_COUNTS):
        return True
    return column < V2_STANDARD_FRAME_COUNTS[row] or (row, column) == V2_NEUTRAL_FRAME


def validate_v2_standard_animations(image: Image.Image) -> None:
    for row in V2_REQUIRED_ANIMATED_ROWS:
        frame_count = V2_STANDARD_FRAME_COUNTS[row]
        fingerprints = {
            atlas_cell(image, row, column).tobytes()
            for column in range(frame_count)
        }
        if len(fingerprints) < 2:
            fail(f"v2 standard row={row} is static across all {frame_count} frames")

    jumping_bottoms = []
    for column in range(V2_STANDARD_FRAME_COUNTS[4]):
        bbox = atlas_cell(image, 4, column).getchannel("A").getbbox()
        if bbox is None:
            fail(f"v2 jumping frame column={column} is empty")
        jumping_bottoms.append(bbox[3])
    endpoint_bottom = min(jumping_bottoms[0], jumping_bottoms[-1])
    if jumping_bottoms[len(jumping_bottoms) // 2] > endpoint_bottom - 6:
        fail(
            "v2 jumping middle frame is not visibly airborne "
            f"(bottoms={jumping_bottoms})"
        )


def validate_v2_atlas(image: Image.Image) -> None:
    if image.size != V2_SIZE:
        fail(f"v2 spritesheet size should be {V2_SIZE}, got {image.size}")

    for row in range(V2_ROWS):
        for column in range(COLUMNS):
            cell = atlas_cell(image, row, column)
            visible_pixels = count_visible_pixels(cell)
            nontransparent_pixels = count_nontransparent_pixels(cell)
            if is_v2_used_cell(row, column):
                if visible_pixels < 400:
                    fail(f"v2 used cell row={row} column={column} has too few visible pixels")
            elif nontransparent_pixels:
                fail(
                    f"v2 unused cell row={row} column={column} is not transparent "
                    f"({nontransparent_pixels} pixels)"
                )
    validate_v2_standard_animations(image)


def validate_pet_dir(pet_dir: Path) -> None:
    if not pet_dir.is_dir():
        fail(f"missing pet directory: {pet_dir}")

    pet_json_path = pet_dir / "pet.json"
    if not pet_json_path.is_file():
        fail(f"missing pet.json in {pet_dir}")

    try:
        metadata = json.loads(pet_json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"invalid pet.json: {error}")

    sprite_version_number = metadata.get("spriteVersionNumber", 1)
    if (
        not isinstance(sprite_version_number, int)
        or isinstance(sprite_version_number, bool)
        or sprite_version_number not in {1, 2}
    ):
        fail(f"unsupported spriteVersionNumber: {sprite_version_number!r}")

    required_keys = V2_REQUIRED_KEYS if sprite_version_number == 2 else REQUIRED_KEYS
    missing_keys = sorted(required_keys - set(metadata))
    if missing_keys:
        fail(f"pet.json missing keys: {missing_keys}")

    if "id" in metadata and metadata["id"] != pet_dir.name:
        fail(f"pet.json id {metadata['id']!r} does not match directory {pet_dir.name!r}")

    spritesheet_path = pet_dir / str(metadata["spritesheetPath"])
    if spritesheet_path.name != "spritesheet.webp":
        fail(f"unexpected spritesheetPath: {metadata['spritesheetPath']!r}")
    if not spritesheet_path.is_file():
        fail(f"missing spritesheet: {spritesheet_path}")

    files = {path.name for path in pet_dir.iterdir() if path.is_file()}
    if files != {"pet.json", "spritesheet.webp"}:
        fail(f"native pet package should only contain pet.json and spritesheet.webp, got {sorted(files)}")

    image = Image.open(spritesheet_path).convert("RGBA")

    expect_transparent_pixels_normalized(image)
    if sprite_version_number == 2:
        validate_v2_atlas(image)
    else:
        validate_v1_atlas(image)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate-codex-native-pet.py /path/to/pet-dir")

    validate_pet_dir(Path(sys.argv[1]).resolve())
    print(f"PASS Codex native pet: custom:{Path(sys.argv[1]).resolve().name}")


if __name__ == "__main__":
    main()
