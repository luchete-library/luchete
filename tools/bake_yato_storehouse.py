"""Stage the storehouse from Yato's comic and bake her field-sized reaction."""
from math import degrees

from PIL import Image, ImageDraw, ImageOps

from bake_yard_sprites import CELL, Motion, frame, limb, vec
from import_stella_interactions import social_pose
from yard_costumes import ART, KEYS, Costume


def storehouse():
    assets = ART.parent
    with Image.open(assets / "comics/source/yato.png") as strip:
        room = strip.crop((0, 110, 228, 220)).convert("RGB")
    # Bring the rear wall upstage, then extend its earthen floor toward the player.
    rear = room.resize((452, 163), Image.Resampling.NEAREST)
    floor = room.crop((44, 96, 201, 109))
    field = Image.new("RGB", (452, 289))
    field.paste(rear)
    y = rear.height
    for row in range(6):
        tile = ImageOps.flip(floor) if row % 2 == 0 else floor
        tile = tile.resize((452, 22 + row * 2), Image.Resampling.NEAREST)
        # Soften the join in the same dirt texture without blurring its pixels.
        blend = 5
        previous = field.crop((0, y-blend, 452, y))
        for dy in range(blend):
            a = previous.crop((0,dy,452,dy+1))
            b = tile.crop((0,dy,452,dy+1))
            field.paste(Image.blend(a,b,(dy+1)/blend),(0,y-blend+dy))
        field.paste(tile.crop((0,blend,452,tile.height)),(0,y))
        y += tile.height-blend
    field.save(assets / "world_pixels/yato_storehouse.png")


def provisions():
    # An open wicker tray. The folded cover stays attached to the far rim.
    sheet = Image.new("RGBA",(64*9,38))
    for col in range(9):
        cel = Image.new("RGBA",(64,38))
        d = ImageDraw.Draw(cel)
        d.polygon([(1,14),(61,14),(56,31),(49,35),(12,35),(6,30)],fill="#573925")
        for y,l,r in [(19,4,59),(23,5,58),(27,7,56),(31,10,53)]:
            d.line((l,y,r,y),fill="#bf8956",width=2)
            for x in range(l+1+(y%3),r-2,6):
                d.line((x,y+1,x+1,y-1),fill="#92613f")
                d.point((x+2,y),fill="#dbad75")
        d.ellipse((1,3,62,23),fill="#5a3c2e",outline="#4e352a")
        d.ellipse((2,3,61,21),fill="#c29661")
        d.ellipse((5,5,58,18),fill="#4b3328")
        d.ellipse((7,9,56,18),fill="#75523a")
        for x,y in [(15,13),(28,15),(45,12),(25,10),(40,16)]:
            d.line((x,y,x+1,y),fill="#aa8054")
        # Two roots in one corner make the large empty bottom easy to see.
        for x,y in [(37,14),(43,15)]:
            d.polygon([(x-4,y+1),(x-1,y-2),(x+2,y-2),(x+3,y),(x,y+1)],fill="#d78c4d")
            d.line((x+2,y-2,x+4,y-5),fill="#a1a068")
            d.point((x,y-1),fill="#f2bc76")
        edge = 55-round(col*5.1)
        drape = max(0,8-col)
        hem = [(1,8),(7,4),(edge,5),(edge+5,8),(edge+2,16+drape),(edge-5,18+drape),(5,16)]
        d.polygon(hem,fill="#717d67",outline="#505d51")
        d.line([(5,8),(edge-2,8),(edge+1,10)],fill="#b5b497")
        d.line([(6,14),(edge-5,16+drape),(edge,14+drape)],fill="#d2c49d")
        d.line([(6,11),(edge-7,12+drape)],fill="#8e9b81")
        sheet.paste(cel,(col*64,0))
    sheet.save(ART.parent / "world_pixels/yato_provisions.png")


def rabbit_family():
    # Preserve the forest rabbits' outlines. Paint two coats, a folded hind leg
    # and a tiny speaking mouth inside that same silhouette.
    world = ART.parent / "world_pixels"
    base = Image.open(world / "rabbit.png").convert("RGBA")
    sheet = Image.new("RGBA",(base.width*2,base.height*2))
    for row,(fur,lit,shade,inner) in enumerate([
        ("#bf9f7b","#e7d5ae","#aa8468","#d29f99"),
        ("#c6b5a6","#ede0ca","#a68d81","#d0a5a1")
    ]):
        for talking in range(2):
            cel = base.copy()
            d = ImageDraw.Draw(cel)
            d.polygon([(6,34),(11,30),(23,26),(26,19),(34,18),(40,22),(41,28),
                       (37,34),(29,40),(18,44),(11,41)],fill=fur)
            d.polygon([(9,32),(14,29),(21,27),(24,28),(22,30),(16,30),(12,33)],fill=lit)
            d.polygon([(20,31),(24,31),(25,34),(24,37),(21,39),(19,40),(22,37),(23,34)],fill=shade)
            d.line([(8,39),(12,41),(16,41)],fill=shade)
            d.polygon([(28,31),(34,28),(38,27),(41,28),(41,31),(37,33),(35,35),(29,37)],fill=lit)
            d.line([(26,17),(29,16),(34,17)],fill=lit)
            d.line([(25,5),(25,13)],fill=lit)
            d.line([(27,6),(27,14)],fill=inner)
            d.line([(36,8),(37,15)],fill=inner)
            d.rectangle((34,24,36,27),fill="#574239")
            d.point((35,24),fill="#fff4dd")
            d.point((38,29),fill=inner)
            d.line((40,30,41,30),fill="#966d69")
            d.point((39,32),fill="#7e594e")
            if talking: d.line((38,33,40,32),fill="#745249")
            d.line((12,43,18,43),fill=lit)
            d.line((33,44,37,44),fill=lit)
            cel.putalpha(base.getchannel("A"))
            sheet.paste(cel,(talking*base.width,row*base.height))
    sheet.save(world / "yato_rabbit_family.png")


def reaction():
    keys = KEYS["yato"]
    frames = 9
    sheet = Image.new("RGBA", (CELL[0]*frames, CELL[1]*len(keys)))
    for row, key in enumerate(keys):
        suit = Costume("yato", key)
        startled = social_pose(suit, "startled", 2)
        for i in range(frames):
            t = i / (frames-1)
            pose = Motion(suit, "idle", 0)
            pose.lean = startled.lean*t
            pose.head_angle = startled.head_angle*t
            pose.head_target = pose.on_body(pose.neck)-vec(0,t)
            pose.mood = "surprise" if i >= 2 else "open"
            pose.arms = [
                limb(source,pose.on_body(source[0])-vec(0,t),degrees(arm[3])*t,degrees(arm[4])*t)
                for source,arm in zip(suit.arms,startled.arms)
            ]
            pose.grips = [arm[2] for arm in pose.arms]
            cel = frame(suit,"idle",0,validate=True,motion=pose)
            sheet.paste(cel,(i*CELL[0],row*CELL[1]))
    sheet.save(ART / "interactions/motion/yato_storehouse_shock.png")


if __name__ == "__main__":
    storehouse()
    provisions()
    rabbit_family()
    reaction()
