#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RIG_ROOT = ROOT / "assets/lingxi-ol-rig"
MANIFEST_PATH = RIG_ROOT / "rig.json"
EXPECTED_CANVAS = (576, 624)
EXPECTED_PARTS = {"body", "head"}
FORBIDDEN_PART_HINTS = (
    "blink",
    "eye",
    "face",
    "glasses",
    "hair",
    "lid",
    "mouth",
    "smile",
)


def fail(message: str) -> None:
    raise SystemExit(f"FAIL rig assets: {message}")


def load_manifest() -> dict[str, object]:
    if not MANIFEST_PATH.exists():
        fail(f"missing {MANIFEST_PATH}")
    try:
        return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"invalid rig.json: {error}")


def validate_canvas(manifest: dict[str, object]) -> None:
    canvas = manifest.get("canvas")
    if not isinstance(canvas, dict):
        fail("manifest.canvas must be an object")
    size = (canvas.get("width"), canvas.get("height"))
    if size != EXPECTED_CANVAS:
        fail(f"unexpected canvas size {size}, expected {EXPECTED_CANVAS}")


def validate_hidden_rgb(image: Image.Image, path: Path) -> None:
    rgba = image.convert("RGBA")
    pixels = rgba.tobytes()
    for index in range(0, len(pixels), 4):
        red, green, blue, alpha = pixels[index:index + 4]
        if alpha == 0 and (red, green, blue) != (0, 0, 0):
            fail(f"{path} has non-zero hidden RGB at pixel index {index // 4}")


def validate_part_image(part_id: str, relative_path: str) -> None:
    path = RIG_ROOT / relative_path
    if not path.exists():
        fail(f"missing image for {part_id}: {relative_path}")
    image = Image.open(path).convert("RGBA")
    if part_id in {"body", "head"} and image.size != EXPECTED_CANVAS:
        fail(f"{relative_path} size is {image.size}, expected {EXPECTED_CANVAS}")
    if image.getchannel("A").getbbox() is None:
        fail(f"{relative_path} has no visible pixels")
    validate_hidden_rgb(image, path)


def validate_parts(manifest: dict[str, object]) -> None:
    parts = manifest.get("parts")
    if not isinstance(parts, list):
        fail("manifest.parts must be a list")

    seen_ids: set[str] = set()
    seen_images: set[str] = set()
    for raw_part in parts:
        if not isinstance(raw_part, dict):
            fail("each part must be an object")
        part_id = raw_part.get("id")
        image = raw_part.get("image")
        if not isinstance(part_id, str) or not part_id:
            fail("part.id must be a non-empty string")
        if not isinstance(image, str) or not image:
            fail(f"part {part_id} image must be a non-empty string")
        if any(hint in part_id.lower() or hint in image.lower() for hint in FORBIDDEN_PART_HINTS):
            fail(f"forbidden high-risk overlay part is present: {part_id} -> {image}")
        if part_id in seen_ids:
            fail(f"duplicate part id: {part_id}")
        seen_ids.add(part_id)
        seen_images.add(image)
        validate_part_image(part_id, image)

    if seen_ids != EXPECTED_PARTS:
        fail(f"unexpected part ids {sorted(seen_ids)}, expected {sorted(EXPECTED_PARTS)}")
    parent_by_id = {
        part.get("id"): part.get("parent")
        for part in parts
        if isinstance(part, dict)
    }
    if parent_by_id.get("body") is not None:
        fail("body must be the root rig part")
    if parent_by_id.get("head") != "body":
        fail("head must be parented to body for the current body/head rig")

    actual_images = {
        path.relative_to(RIG_ROOT).as_posix()
        for path in (RIG_ROOT / "parts").glob("*.png")
    }
    if actual_images != seen_images:
        fail(f"parts directory does not match manifest images: {sorted(actual_images)} vs {sorted(seen_images)}")


def main() -> None:
    manifest = load_manifest()
    validate_canvas(manifest)
    validate_parts(manifest)
    print("PASS rig assets")


if __name__ == "__main__":
    main()
