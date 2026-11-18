"""Package actual Godot review frames; does not change any game asset."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "polish_20261118"
for task in ("corridor", "shelves", "reading"):
    paths = sorted((OUT / f"frames_{task}").glob("*.png"))
    # The full native screenshots remain beside the animation. A smaller crop
    # makes the actual approach, work and return readable in an embedded GIF.
    rgb = [Image.open(path).convert("RGB").crop((0, 130, 530, 510)) for path in paths]
    sample = Image.new("RGB", (530 * 4, 380))
    for i, index in enumerate((0, len(rgb)//3, len(rgb)//2, len(rgb)*3//4)):
        sample.paste(rgb[index], (530*i, 0))
    palette = sample.quantize(colors=256)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rgb]
    target = OUT / f"{task}_approach_work_return.gif"
    frames[0].save(target, save_all=True, append_images=frames[1:], duration=100, loop=0, optimize=True, disposal=1)
    print(task, len(frames), "frames", target.stat().st_size, "bytes")
    for image in rgb + frames:
        image.close()
