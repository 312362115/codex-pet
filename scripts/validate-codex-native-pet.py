#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image


CELL_SIZE = (192, 208)
GRID_SIZE = (8, 9)
EXPECTED_SIZE = (CELL_SIZE[0] * GRID_SIZE[0], CELL_SIZE[1] * GRID_SIZE[1])
REQUIRED_KEYS = {"displayName", "description", "spritesheetPath"}


def fail(message: str) -> None:
    raise SystemExit(f"FAIL Codex native pet: {message}")


def count_visible_pixels(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    return sum(1 for value in alpha.tobytes() if value > 48)


def expect_transparent_pixels_normalized(image: Image.Image) -> None:
    rgba = image.tobytes()
    for index in range(0, len(rgba), 4):
        red, green, blue, alpha = rgba[index : index + 4]
        if alpha == 0 and (red, green, blue) != (0, 0, 0):
            fail("spritesheet has hidden RGB residue in transparent pixels")


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

    missing_keys = sorted(REQUIRED_KEYS - set(metadata))
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
    if image.size != EXPECTED_SIZE:
        fail(f"spritesheet size should be {EXPECTED_SIZE}, got {image.size}")

    expect_transparent_pixels_normalized(image)

    for row in range(GRID_SIZE[1]):
        for column in range(GRID_SIZE[0]):
            cell = image.crop(
                (
                    column * CELL_SIZE[0],
                    row * CELL_SIZE[1],
                    (column + 1) * CELL_SIZE[0],
                    (row + 1) * CELL_SIZE[1],
                )
            )
            if count_visible_pixels(cell) < 600:
                fail(f"cell row={row} column={column} has too few visible pixels")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate-codex-native-pet.py /path/to/pet-dir")

    validate_pet_dir(Path(sys.argv[1]).resolve())
    print(f"PASS Codex native pet: custom:{Path(sys.argv[1]).resolve().name}")


if __name__ == "__main__":
    main()
