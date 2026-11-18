"""Validate dense comic motion and exported timing without touching player saves."""
from bisect import bisect_right
from collections import defaultdict
import hashlib
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image, ImageDraw

import render_dori_comic as comic

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/comic_smooth_20261117"
BEFORE = OUT / "before"


def digest(image):
    return hashlib.sha256(image.convert("RGB").tobytes()).hexdigest()


def cell(atlas, cut, frame, columns, rows):
    x = frame % columns * comic.W
    y = (cut * rows + frame // columns) * comic.H
    return atlas.crop((x, y, x + comic.W, y + comic.H))


def load_previous():
    spec = importlib.util.spec_from_file_location("comic_before_dense_motion", BEFORE / "tools/render_dori_comic.py")
    previous = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(previous)
    previous.ROOT = ROOT
    previous.CHARACTERS = ROOT / "assets/characters"
    previous.COMICS = ROOT / "assets/comics"
    return previous


def collect(module, member, count, atlas, columns, rows, check_clipping):
    """Measure actual composited actor placement, independent of travel helpers."""
    front, profile, grounded = module.front, module.profile, module.draw_grounded
    actor = None
    tick = cut = 0
    tracks = defaultdict(dict)
    samples, images, hashes = [], [], []
    occurrence = defaultdict(int)

    def draw_front(im, name, *args, **kwargs):
        nonlocal actor
        actor = (name, "front")
        return front(im, name, *args, **kwargs)

    def draw_profile(im, name, x, floor, view, *args, **kwargs):
        nonlocal actor
        actor = (name, view)
        return profile(im, name, x, floor, view, *args, **kwargs)

    def draw(im, cel, x, floor, opacity=255, shadow=False, shadow_floor=None):
        occurrence[actor] += 1
        key = (cut, *actor, occurrence[actor])
        if opacity:
            ys, xs = np.where(np.asarray(cel.getchannel("A")) > 0)
            ox, oy = round(x) - 48, round(floor) - 104
            lost = int(np.count_nonzero((xs + ox < 0) | (xs + ox >= comic.W)
                                       | (ys + oy < 0) | (ys + oy >= comic.H)))
            record = {"book": member, "cut": cut + 1, "frame": tick + 1,
                      "actor": actor, "clipped_pixels": lost}
            samples.append(record)
            if check_clipping:
                assert lost == 0, record
            tracks[key][tick] = (float(x), float(floor), hashlib.sha256(cel.tobytes()).hexdigest())
        return grounded(im, cel, x, floor, opacity, shadow, shadow_floor=shadow_floor)

    with patch.object(module, "front", draw_front), patch.object(module, "profile", draw_profile), patch.object(module, "draw_grounded", draw):
        for cut in range(4):
            cut_images, cut_hashes = [], []
            for tick in range(count):
                occurrence.clear()
                if hasattr(module, "render_panel"):
                    rendered = module.render_panel(member, cut, tick)
                else:
                    rendered = module.dori_panel(cut, tick) if member == "dori" else module.illustrated_panel(member, cut, tick)
                packed = cell(atlas, cut, tick, columns, rows)
                assert packed.tobytes() == rendered.tobytes(), (member, cut, tick, "stale atlas")
                cut_images.append(packed)
                cut_hashes.append(digest(packed))
            images.append(cut_images)
            hashes.append(cut_hashes)
    return tracks, samples, images, hashes


def steps(tracks):
    distances = []
    for frames in tracks.values():
        for tick in sorted(frames):
            if tick + 1 in frames:
                first, second = frames[tick], frames[tick + 1]
                distances.append(float(np.hypot(second[0] - first[0], second[1] - first[1])))
    moving = [distance for distance in distances if distance > 0]
    return {"sample_pairs": len(distances), "moving_pairs": len(moving),
            "maximum_px": max(distances, default=0),
            "mean_all_pairs_px": float(np.mean(distances)) if distances else 0,
            "mean_moving_pairs_px": float(np.mean(moving)) if moving else 0}


def exported_timeline(path, full_color=False):
    records = []
    with Image.open(path) as animation:
        assert animation.is_animated and animation.size == (992, 756), path
        assert animation.info.get("loop") == 0, path
        at = 0.0
        for frame in range(animation.n_frames):
            animation.seek(frame)
            duration = float(animation.info["duration"])
            assert duration > 0, (path, frame, duration)
            records.append({"start": at, "end": at + duration,
                            "hash": digest(animation) if full_color else None})
            at += duration
    return records


def check_exports(member, panels, cues):
    expected_durations = [ms for cue in cues for ms in cue["frames_ms"]]
    expected_total = sum(expected_durations)
    gif = exported_timeline(ROOT / "artifacts" / f"{member}_pixel_comic.gif")
    apng = exported_timeline(ROOT / "artifacts/comic_previews" / f"{member}_pixel_comic_smooth.png", True)
    assert gif[-1]["end"] == expected_total, (member, "GIF duration")
    assert apng[-1]["end"] == expected_total, (member, "APNG duration")
    starts = [row["start"] for row in apng]
    at = 0
    checked = 0
    # Build the canonical full page from the just-validated shipped atlas,
    # avoiding a second procedural render while still testing decoded pixels.
    with patch.object(comic, "still", lambda name, cut, tick: panels[cut][tick]):
        for cut in range(4):
            for tick in range(comic.FRAMES):
                duration = cues[cut]["frames_ms"][tick]
                expected = comic.frame(member, cut, tick).resize((992, 756), Image.Resampling.NEAREST)
                target = digest(expected)
                index = bisect_right(starts, at) - 1
                while index < len(apng) and apng[index]["start"] < at + duration:
                    assert apng[index]["hash"] == target, (member, cut, tick, index, "APNG differs from original pixels")
                    index += 1
                at += duration
                checked += 1
    return {"gif_encoded_frames": len(gif), "apng_encoded_frames": len(apng),
            "duration_ms": expected_total, "lossless_source_frames_checked": checked}


def fuwa_background():
    # Capture the blend argument actually used by the scene, not a parallel
    # implementation of the desired formula. A fractional dict lookup reset
    # would violate this monotonicity check immediately.
    blend = comic.Image.blend
    observed = []

    def record(first, second, amount):
        observed.append(float(amount))
        return blend(first, second, amount)

    with patch.object(comic.Image, "blend", record):
        for tick in range(comic.FRAMES):
            comic.render_panel("fuwa", 3, tick)
    assert len(observed) == comic.FRAMES
    assert observed[0] == 0 and observed[-1] == 1
    assert all(0 <= value <= 1 for value in observed)
    assert all(second >= first for first, second in zip(observed, observed[1:])), observed
    return {"samples": len(observed), "unique_background_mix_levels": len(set(observed)),
            "maximum_step": max(b - a for a, b in zip(observed, observed[1:])),
            "reversals": 0}


def comparison_strips():
    for member, cut, key in (("dori", 2, 8), ("fuwa", 3, 11)):
        board = Image.new("RGB", (comic.W * 2 * 4, (comic.H * 2 + 30) * 2), "#ecddbd")
        draw = ImageDraw.Draw(board)
        with Image.open(BEFORE / "assets/comics" / f"{member}.png") as old, Image.open(comic.COMICS / f"{member}.png") as new:
            for column in range(4):
                for row, atlas in enumerate((old, new)):
                    tick = key + (column // 3) if row == 0 else key * 3 + column
                    art = cell(atlas, cut, tick, 13 if row == 0 else comic.COLUMNS, 2 if row == 0 else comic.ROWS_PER_CUT)
                    x, y = column * comic.W * 2, row * (comic.H * 2 + 30)
                    draw.text((x + 5, y + 7), f'{"BEFORE / held pose" if row == 0 else "AFTER / joint redraw"} - {key + column / 3:.2f}', fill="#49372d")
                    board.paste(art.resize((comic.W * 2, comic.H * 2), Image.Resampling.NEAREST), (x, y + 30))
        board.save(OUT / f"{member}_inbetween_comparison.png")


def pickup_joints():
    from bake_stella_directions import masked, shade, X, Y
    from bake_yard_sprites import place, reach, vec

    def overlap(first, second):
        return int(np.count_nonzero((np.asarray(first.getchannel("A")) > 0) &
                                    (np.asarray(second.getchannel("A")) > 0)))

    rig = comic.dori_pickup_rig()
    samples = []
    for frame in range(6 * comic.SUBSTEPS, 18 * comic.SUBSTEPS):
        tick = frame / comic.SUBSTEPS
        pose = comic.dori_pickup_placement(tick)
        shoulder = rig.shoulder.astype(float)
        palm = vec(52, 73)
        elbow = shoulder + (palm - shoulder) * .52
        offset = vec(130 + pose["dx"] - 48, 94 + pose["crouch"] - 104)
        target = np.array(pose["hand"], float) - offset
        chain = reach((shoulder, elbow, palm), shoulder, target, -1)
        upper = place(masked(rig.arms[0], Y <= elbow[1] + 1.5), shoulder, shoulder, chain[3])
        lower = place(masked(rig.arms[0], Y >= elbow[1] - 1.5), elbow, chain[1], chain[4])
        shoulder_overlap = overlap(upper, rig.body)
        elbow_overlap = overlap(upper, lower)
        assert shoulder_overlap >= 3, (tick, "detached shoulder", shoulder_overlap)
        assert elbow_overlap >= 3, (tick, "detached elbow", elbow_overlap)
        hand_error = float(np.linalg.norm(chain[2] + offset - pose["hand"]))
        assert hand_error <= 1.5, (tick, "unreachable hand", hand_error)
        stone = Image.new("RGBA", (comic.W, comic.H))
        comic.rock(ImageDraw.Draw(stone), *pose["stone"])
        hx, hy = pose["hand"]
        contact = bool(np.any(np.asarray(stone.getchannel("A"))[hy - 1:hy + 2, hx - 1:hx + 2]))
        if tick >= 10:
            assert contact, (tick, "hand loses stone contact")
        if tick <= 12:
            assert pose["stone"] == (112, 91), (tick, "stone lifts before grip")
        hip, ankle = vec(rig.axis, rig.cut + 1), vec(rig.axis, 100)
        knee = hip + (ankle - hip) * .52
        leg = masked(rig.art, (Y >= rig.cut) & (X >= rig.axis - 7) & (X <= rig.axis + 8))
        leg_overlaps = []
        for side, piece in enumerate((shade(leg), leg)):
            target = ankle + vec(-pose["dx"] + side * 2, -pose["crouch"])
            bones = reach((hip, knee, ankle), hip, target, -1)
            thigh = place(masked(piece, Y <= knee[1] + 1.5), hip, hip, bones[3])
            shin = place(masked(piece, (Y >= knee[1] - 1.5) & (Y < 100)), knee, bones[1], bones[4])
            shoe = place(masked(piece, Y >= 99), ankle, bones[2])
            knee_overlap, ankle_overlap = overlap(thigh, shin), overlap(shin, shoe)
            assert knee_overlap >= 3, (tick, side, "detached knee", knee_overlap)
            assert ankle_overlap >= 3, (tick, side, "detached ankle", ankle_overlap)
            leg_overlaps.append({"knee_px": knee_overlap, "ankle_px": ankle_overlap})
        samples.append({"frame": frame, "key_tick": tick, "shoulder_px": shoulder_overlap,
                        "elbow_px": elbow_overlap, "hand_error_px": hand_error,
                        "hand_stone_contact": contact, "legs": leg_overlaps})
    return {"arm_poses": len(samples), "leg_poses": len(samples) * 2, "samples": samples}


def main():
    OUT.mkdir(exist_ok=True)
    current_story = (comic.COMICS / "debuts.json").read_bytes()
    assert current_story == (BEFORE / "assets/comics/debuts.json").read_bytes(), "Official captions or authored timing changed"
    # Earlier full-project audit includes the independent playable-story file.
    story_hashes = json.loads((ROOT / "artifacts/comic_upgrade_20261117/story_hash_before.json").read_text(encoding="utf-8-sig"))
    for item in story_hashes:
        assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper() == item["Hash"], item["Path"]
    timeline = json.loads((comic.COMICS / "playback.json").read_text(encoding="utf-8"))
    assert timeline["frames"] == comic.FRAMES == 70
    assert timeline["columns"] == comic.COLUMNS and timeline["rows_per_cut"] == comic.ROWS_PER_CUT
    previous = load_previous()
    results = {}
    actors = 0
    new_images = 0
    for member, book in comic.BOOKS.items():
        cues = timeline["books"][member]["cues"]
        for old, new in zip(book["cues"], cues):
            assert len(new["frames_ms"]) == comic.FRAMES
            assert sum(old["frames_ms"]) == sum(new["frames_ms"])
            assert old["frames_ms"][-1] == new["frames_ms"][-1], (member, "reading hold changed")
            assert sum(old["frames_ms"][:old["reveal"]]) == sum(new["frames_ms"][:new["reveal"]]), (member, "caption reveal moved")
            for key in range(24):
                assert sum(old["frames_ms"][:key]) == sum(new["frames_ms"][:key * 3]), (member, key, "authored event time moved")
        with Image.open(BEFORE / "assets/comics" / f"{member}.png") as atlas:
            old_tracks, _, _, old_hashes = collect(previous, member, 24, atlas, 13, 2, False)
        with Image.open(comic.COMICS / f"{member}.png") as atlas:
            assert atlas.size == (comic.COLUMNS * comic.W, 4 * comic.ROWS_PER_CUT * comic.H)
            tracks, samples, panels, hashes = collect(comic, member, comic.FRAMES, atlas, comic.COLUMNS, comic.ROWS_PER_CUT, True)
        cut_stats = []
        for cut in range(4):
            between = [i for i in range(comic.FRAMES) if i % 3]
            novel = sum(hashes[cut][i] not in (hashes[cut][i // 3 * 3], hashes[cut][(i // 3 + 1) * 3]) for i in between)
            cut_stats.append({"cut": cut + 1, "old_distinct_images": len(set(old_hashes[cut])),
                              "new_distinct_images": len(set(hashes[cut])), "genuine_between_images": novel})
            new_images += novel
        assert sum(row["genuine_between_images"] for row in cut_stats) > 0, (member, "only duplicate frames added")
        old_steps, new_steps = steps(old_tracks), steps(tracks)
        # Changed camera cuts are excluded naturally by matching actor/view.
        # A higher sample rate must not create a larger spatial step.
        assert new_steps["maximum_px"] <= old_steps["maximum_px"], (member, "larger motion jump", old_steps, new_steps)
        actors += len(samples)
        results[member] = {"cuts": cut_stats, "movement_before": old_steps,
                           "movement_after": new_steps, "visible_actor_samples": len(samples),
                           "exports": check_exports(member, panels, cues)}
        print(f"MOTION VERIFIED {member}: 280 source frames, {len(samples)} actor samples, exact lossless export", flush=True)
    report = {"status": "passed", "source_frames": len(comic.BOOKS) * 4 * comic.FRAMES,
              "visible_actor_samples": actors, "clipped_actor_samples": 0,
              "genuine_between_images": new_images, "official_story_and_captions_unchanged": True,
              "original_cue_times_and_reading_holds_unchanged": True,
              "fuwa_background": fuwa_background(), "pickup_joints": pickup_joints(), "books": results}
    comparison_strips()
    (OUT / "motion_validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "books"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
