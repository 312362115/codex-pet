#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = ROOT / "scripts" / "validate-codex-native-pet.py"


def load_validator():
    spec = importlib.util.spec_from_file_location("native_pet_validator", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load validator: {VALIDATOR_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_v2_fixture(pet_dir: Path, validator) -> None:
    pet_dir.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", validator.V2_SIZE, (0, 0, 0, 0))
    for row in range(validator.V2_ROWS):
        for column in range(validator.COLUMNS):
            if not validator.is_v2_used_cell(row, column):
                continue
            cell = Image.new("RGBA", validator.CELL_SIZE, (0, 0, 0, 0))
            draw = ImageDraw.Draw(cell)
            offset_y = column % 2
            if row == 4:
                offset_y -= (0, 4, 12, 4, 0)[column]
            draw.rectangle((32, 24 + offset_y, 160, 184 + offset_y), fill=(230, 180, 80, 255))
            atlas.alpha_composite(
                cell,
                (column * validator.CELL_SIZE[0], row * validator.CELL_SIZE[1]),
            )
    atlas.save(pet_dir / "spritesheet.webp", lossless=True, quality=100, method=6, exact=True)
    (pet_dir / "pet.json").write_text(
        json.dumps(
            {
                "id": pet_dir.name,
                "displayName": "V2 Fixture",
                "description": "Synthetic v2 validator fixture.",
                "spriteVersionNumber": 2,
                "spritesheetPath": "spritesheet.webp",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def expect_failure(action, expected_fragment: str) -> None:
    try:
        action()
    except SystemExit as error:
        if expected_fragment not in str(error):
            raise AssertionError(f"Expected {expected_fragment!r}, got {error!r}") from error
        return
    raise AssertionError(f"Expected validation failure containing {expected_fragment!r}")


def main() -> None:
    validator = load_validator()
    with tempfile.TemporaryDirectory(prefix="codex-pet-v2-validator-") as temp_dir:
        pet_dir = Path(temp_dir) / "v2-fixture"
        write_v2_fixture(pet_dir, validator)
        validator.validate_pet_dir(pet_dir)

        spritesheet_path = pet_dir / "spritesheet.webp"
        atlas = Image.open(spritesheet_path).convert("RGBA")
        draw = ImageDraw.Draw(atlas)
        left = 7 * validator.CELL_SIZE[0]
        draw.rectangle((left + 8, 8, left + 40, 40), fill=(255, 0, 0, 255))
        atlas.save(spritesheet_path, lossless=True, quality=100, method=6, exact=True)
        expect_failure(
            lambda: validator.validate_pet_dir(pet_dir),
            "v2 unused cell row=0 column=7 is not transparent",
        )

        write_v2_fixture(pet_dir, validator)
        metadata_path = pet_dir / "pet.json"
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        metadata.pop("id")
        metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
        expect_failure(lambda: validator.validate_pet_dir(pet_dir), "pet.json missing keys: ['id']")

        write_v2_fixture(pet_dir, validator)
        atlas = Image.open(spritesheet_path).convert("RGBA")
        first_idle = validator.atlas_cell(atlas, 0, 0)
        for column in range(validator.V2_STANDARD_FRAME_COUNTS[0]):
            atlas.paste(first_idle, (column * validator.CELL_SIZE[0], 0))
        atlas.save(spritesheet_path, lossless=True, quality=100, method=6, exact=True)
        expect_failure(
            lambda: validator.validate_pet_dir(pet_dir),
            "v2 standard row=0 is static",
        )

    print("PASS native pet v2 validator")


if __name__ == "__main__":
    main()
