"""Register the four paintings per storybook and their walkable floor to the game."""
import json
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "tools" / "chapter_art"
OUTPUT = ROOT / "assets" / "world_pixels"
GRID = (452, 289)
NATIVE = (904, 578)
ORIGIN = (32, 140)
REAR_ROWS = 89


def read_layout():
    return json.loads((ART / "layout.json").read_text(encoding="utf-8"))


def render_book(member, scenes):
    # Both the plate and its collision outline use the same two vertical spans.
    # The rear wall is shallower than the walking surface in the game's perspective.
    with Image.open(ART / f"{member}.png") as atlas:
        atlas = atlas.convert("RGB")
    half_w, half_h = atlas.width // 2, atlas.height // 2
    for index, scene in enumerate(scenes):
        left, top, right, bottom = scene["crop"]
        rear = scene["rear"]
        origin_x, origin_y = (index % 2) * half_w, (index // 2) * half_h
        panel = Image.new("RGB", GRID)
        for y0, y1, row, end in [(top, rear, 0, REAR_ROWS), (rear, bottom, REAR_ROWS, GRID[1])]:
            box = (origin_x + left * half_w / 100, origin_y + y0 * half_h / 100,
                   origin_x + right * half_w / 100, origin_y + y1 * half_h / 100)
            strip = atlas.resize((GRID[0], end-row), Image.Resampling.LANCZOS, box=box)
            panel.paste(strip, (0, row))
        panel = panel.filter(ImageFilter.UnsharpMask(radius=.65, percent=85, threshold=3))
        palette = panel.quantize(colors=224, dither=Image.Dither.NONE)
        image = palette.resize(NATIVE, Image.Resampling.NEAREST)
        polygon = []
        for x, y in scene["outline"]:
            px = (x-left) / (right-left) * GRID[0]
            if y <= rear:
                py = (y-top) / (rear-top) * REAR_ROWS
            else:
                py = REAR_ROWS + (y-rear) / (bottom-rear) * (GRID[1]-REAR_ROWS)
            polygon.append([round(ORIGIN[0]+2*px), round(ORIGIN[1]+2*py)])
        yield image, polygon


def build():
    floors = {}
    for member, scenes in read_layout().items():
        floors[member] = []
        for index, (image, polygon) in enumerate(render_book(member, scenes)):
            image.save(OUTPUT / f"story_{member}_{index}.png", optimize=True)
            floors[member].append(polygon)
    (OUTPUT / "chapter_floors.json").write_text(json.dumps(floors, separators=(",", ":")), encoding="utf-8")
    build_details()


def build_details():
    """Import full-scene replacements without reapplying atlas crops/floor warps.

    These six paintings are registered to the *finished* game plates, not the
    four-panel source sheets. Geometry and chapter_floors.json stay unchanged.
    Keep a finer 904 px grid for close-ups instead of enlarging a comic cell.
    """
    detail = ART / "detail"
    for source in sorted(detail.glob("*.png")):
        with Image.open(source) as image:
            image = image.convert("RGB").resize(NATIVE, Image.Resampling.LANCZOS)
            image = image.quantize(colors=256, dither=Image.Dither.NONE).convert("RGB")
            image.save(OUTPUT / (source.stem + "_detail.png"), optimize=True)


if __name__ == "__main__":
    import sys
    build_details() if "--details-only" in sys.argv else build()
