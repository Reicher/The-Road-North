# Item spritesheets

Each JSON manifest maps rectangular regions in one source sheet to item icon files.
The extractor removes a bright neutral checkerboard, trims each item, and centers it
on a transparent 256×256 canvas with a consistent margin.

Run from the project root with Python and Pillow installed:

```sh
python3 scripts/extract_item_spritesheet.py SOURCE.png data/item_spritesheets/MANIFEST.json
```

For a new sheet, copy an existing manifest and update `source_size`, names, output
filenames, and crop rectangles. Crop coordinates are `[left, top, right, bottom]`.
The extraction tool is development-only; Pillow is not a game dependency.
