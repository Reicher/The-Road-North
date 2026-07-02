#!/usr/bin/env python3
"""Extract consistently sized transparent item icons from an authored sheet."""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image


def _background_mask(image: Image.Image) -> list[bool]:
    """Mark bright neutral checkerboard regions, including enclosed large regions."""
    width, height = image.size
    pixels = list(image.convert("RGB").get_flattened_data())
    candidates = [max(rgb) - min(rgb) <= 6 and sum(rgb) / 3 >= 224 for rgb in pixels]
    background = [False] * len(pixels)
    visited = [False] * len(pixels)

    for start, candidate in enumerate(candidates):
        if not candidate or visited[start]:
            continue
        queue = deque([start])
        visited[start] = True
        component: list[int] = []
        touches_edge = False
        while queue:
            index = queue.popleft()
            component.append(index)
            x, y = index % width, index // width
            touches_edge |= x == 0 or y == 0 or x == width - 1 or y == height - 1
            for neighbor in (index - 1, index + 1, index - width, index + width):
                if neighbor < 0 or neighbor >= len(pixels) or visited[neighbor] or not candidates[neighbor]:
                    continue
                nx, ny = neighbor % width, neighbor // width
                if abs(nx - x) + abs(ny - y) != 1:
                    continue
                visited[neighbor] = True
                queue.append(neighbor)
        if touches_edge or len(component) >= 100:
            for index in component:
                background[index] = True
    return background


def extract_icon(source: Image.Image, crop: list[int], canvas_size: int, margin: int) -> Image.Image:
    cell = source.crop(tuple(crop)).convert("RGBA")
    background = _background_mask(cell)
    pixels = list(cell.get_flattened_data())
    cell.putdata([(*rgba[:3], 0 if background[index] else 255) for index, rgba in enumerate(pixels)])
    bounds = cell.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"No item found in crop {crop}")
    item = cell.crop(bounds)
    available = canvas_size - margin * 2
    scale = min(available / item.width, available / item.height)
    target = (max(1, round(item.width * scale)), max(1, round(item.height * scale)))
    item = item.resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(item, ((canvas_size - item.width) // 2, (canvas_size - item.height) // 2))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path("assets/images/items"))
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    source = Image.open(args.source).convert("RGB")
    expected_size = tuple(manifest["source_size"])
    if source.size != expected_size:
        raise ValueError(f"Expected source size {expected_size}, got {source.size}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for entry in manifest["items"]:
        icon = extract_icon(source, entry["crop"], manifest["canvas_size"], manifest["margin"])
        destination = args.output_dir / entry["file"]
        icon.save(destination, optimize=True)
        print(f"{entry['name']}: {destination}")


if __name__ == "__main__":
    main()
