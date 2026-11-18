"""Pack imagegen-authored Ete cels into the game's fixed native pixel grid.

No synthesized anatomy or slice deformation: each cel is a complete authored pose.
The only image operations are atlas extraction, scale normalization and alpha cleanup.
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from preview_yard_sprites import save_gif

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/source/aethe_directional_v1.png"
OUT = ROOT / "assets/characters/directional"
ARTIFACTS = ROOT / "artifacts"
CELL = (96, 112)
FOOT = (48, 103)
DIRECTIONS = ("down", "left", "right", "up")
LABELS = ("정면", "왼쪽", "오른쪽", "뒷모습")
# Source gutters inspected from alpha bounds; not assumed from image dimensions.
X_CUTS = (0, 270, 515, 740, 980, 1233)
Y_CUTS = (0, 310, 620, 930, 1276)


def pack():
    source = Image.open(SOURCE).convert("RGBA")
    assert source.size == (1233, 1276), "Reinspect cell gutters when replacing source art"
    atlas = Image.new("RGBA", (CELL[0]*5, CELL[1]*4))
    cels = []
    bounds = []
    for row in range(4):
        poses = []
        for col in range(5):
            pixels = np.array(source.crop((X_CUTS[col], Y_CUTS[row], X_CUTS[col+1], Y_CUTS[row+1])))
            # Generation includes near-transparent RGB residue (alpha <= 4).
            pixels[pixels[:, :, 3] <= 16] = 0
            pose = Image.fromarray(pixels)
            box = pose.getbbox()
            assert box and box[0] > 0 and box[1] > 0
            pose = pose.crop(box)
            # Uniform scaling preserves anatomy; all four directions are 88 px tall.
            scale = 88 / pose.height
            pose = pose.resize((round(pose.width*scale), 88), Image.Resampling.NEAREST)
            assert pose.width <= 64
            cel = Image.new("RGBA", CELL)
            cel.alpha_composite(pose, (FOOT[0]-pose.width//2, FOOT[1]+1-pose.height))
            atlas.alpha_composite(cel, (col*CELL[0], row*CELL[1]))
            poses.append(cel)
            bounds.append({"direction": DIRECTIONS[row], "column": col, "bounds": cel.getbbox()})
        cels.append(poses)
    OUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT / "aethe.png")
    # Keep the older single-pose consumers and the comparison preview in sync.
    neutral = cels[0][0]
    neutral.crop((16,14,80,104)).save(ROOT / "assets/characters/field/aethe.png")
    idle_path = ROOT / "assets/characters/yard/idle.png"
    if idle_path.exists():
        idle = Image.open(idle_path).convert("RGBA")
        assert idle.size == (96,112*16)
        idle.paste(neutral,(0,112*15))
        idle.save(idle_path,optimize=True)
    manifest = {"source": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
                "cell": CELL, "foot": FOOT, "directions": DIRECTIONS,
                "idle_column": 0, "walk_columns": [1, 2, 3, 4],
                "world_units_per_step_frame": 8.0, "cels": bounds}
    (OUT / "aethe.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    return cels


def preview(cels):
    font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 19)
    title = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 26)
    frames = []
    for tick in range(40):
        canvas = Image.new("RGB", (1060, 620), "#2e443b")
        draw = ImageDraw.Draw(canvas)
        draw.text((26, 17), "에테 · 4방향 대기와 걷기", font=title, fill="#f3dfb8")
        draw.text((26, 57), "같은 발 기준점 / 걷는 동안 책·손·몸통이 함께 이동", font=font, fill="#b7e1c4")
        for row in range(4):
            x = 130+row*264
            draw.text((x-30, 98), LABELS[row], font=font, fill="#f0dfbd")
            for line, col in enumerate((0, 1+(tick//2)%4)):
                top = 124+line*234
                draw.line((x-100, top+206, x+100, top+206), fill="#7a8f80")
                cel = cels[row][col].resize((192, 224), Image.Resampling.NEAREST)
                canvas.paste(cel, (x-96, top), cel)
        draw.text((26, 594), "위: 대기     아래: 걷기 4프레임 · 10 fps / 멈추면 대기 자세", font=font, fill="#cfdbca")
        frames.append(canvas)
    ARTIFACTS.mkdir(exist_ok=True)
    frames[2].save(ARTIFACTS / "aethe_directions.png")
    save_gif(frames, ARTIFACTS / "aethe_directions.gif", [50]*len(frames), disposal=2)


if __name__ == "__main__":
    result = pack()
    preview(result)
    print("Packed 20 complete Ete poses: 4 directions, 4 walk cels + neutral each.")
