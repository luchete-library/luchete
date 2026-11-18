"""Build the two studio atlases. All coordinates for interactive props are native pixels."""
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/studio_art/room_plates.png"
OUT = ROOT / "assets/studio_pixels"
CELL = 176
DESK_Y = 153


def make_desk(image, seed, colors, finish):
    """A solid front lip at y=153 hides the broadcaster's hips in both views."""
    d = ImageDraw.Draw(image)
    rng = Random(seed)
    shadow, dark, mid, light, edge = colors
    y = DESK_Y
    d.polygon([(3,y),(172,y),(175,y+5),(175,175),(0,175),(0,y+5)], fill=shadow)
    d.polygon([(4,y+1),(171,y+1),(175,y+9),(175,y+12),(0,y+12),(0,y+8)], fill=light)
    if finish == "wood":
        for _ in range(32):
            xx = rng.randrange(4,166)
            yy = rng.randrange(y+2,y+12)
            span = rng.randrange(3,17)
            d.line([(xx,yy),(xx+span//2,yy),(min(174,xx+span),yy-1)],fill=rng.choice([mid,edge]))
    elif finish == "stone":
        for xx,yy in [(1,158),(39,160),(115,157),(152,162)]:
            d.line([(xx,yy),(xx+4,yy),(xx+7,yy-1),(xx+11,yy),(xx+14,yy-1)],fill=mid)
            d.line([(xx+7,yy-1),(xx+8,yy-2),(xx+10,yy-2)],fill=edge)
    else:
        for xx,yy,length in [(4,155,13),(37,163,19),(107,155,14),(142,164,26)]:
            d.line((xx,yy,xx+length,yy),fill=edge)
    d.rectangle((0,y+13,175,175),fill=dark)
    d.line((0,y+12,175,y+12),fill=edge)
    d.line((0,y+14,175,y+14),fill=mid)
    d.line((0,173,175,173),fill=shadow)
    if finish == "wood":
        for x in (3,60,117):
            d.line((x,171,x+3,168,x+51,168,x+53,171),fill=shadow)
            d.line((x+5,169,x+50,169),fill=mid)
    else:
        for x in (2,58,115):
            d.line((x,169,x,172,x+54,172),fill=mid)


def keyboard(d, x, y, colors):
    shade, case, key, glint = colors
    d.polygon([(x+2,y),(x+42,y),(x+45,y+7),(x+44,y+9),(x-1,y+9),(x-1,y+6)],fill=shade)
    d.polygon([(x+3,y),(x+41,y),(x+43,y+6),(x,y+6)],fill=case)
    for row in range(3):
        for col in range(10):
            xx = x+3+col*4+(row%2)
            if row==2 and 2<=col<=5: continue
            d.line((xx,y+row*2+1,xx+2,y+row*2+1),fill=key)
            d.point((xx,y+row*2+1),fill=glint)
    d.line((x+11,y+5,x+26,y+5),fill=key)
    d.line((x+2,y+7,x+42,y+7),fill=case)


def doll(d, x, y, hair, light, dress, bow):
    d.ellipse((x-8,y-1,x+8,y+2),fill="#9e796b")
    d.polygon([(x-6,y-13),(x-7,y-8),(x-5,y-2),(x,y),(x+6,y-2),(x+5,y-11)],fill=dress,outline="#70524e")
    d.ellipse((x-6,y-20,x+6,y-8),fill=hair,outline="#795849")
    d.ellipse((x-4,y-17,x+4,y-10),fill="#f4d3ae")
    d.line((x-5,y-15,x-4,y-18,x-1,y-19,x+1,y-17,x+3,y-18,x+5,y-15),fill=hair,width=2)
    d.line((x-4,y-17,x-2,y-19,x,y-19),fill=light)
    for dx in (-2,2): d.point((x+dx,y-13),fill="#594648")
    d.line((x-5,y-7,x-3,y-6,x,y-8,x+3,y-6),fill=bow)
    d.line((x-4,y-3,x-2,y-4,x,y-3,x+3,y-4),fill=light)
    d.line((x+5,y-16,x+7,y-17,x+7,y-14,x+5,y-15),fill=bow)


def yato(image):
    make_desk(image,1,("#57402f","#98734c","#c5a173","#e1c69a","#f8dcb2"),"wood")
    d=ImageDraw.Draw(image)
    keyboard(d,65,155,("#735b49","#b7a28a","#e3d6bc","#fff0cf"))
    doll(d,24,160,"#d59941","#ffe2a1","#f5dabc","#958561")
    # Parallel metal struts with a separate cable and screws at each hinge.
    d.line((145,135,148,140,158,128,164,123,169,156),fill="#594d42")
    for dy in (0,4): d.line((144,132+dy,163,118+dy,170,154+dy),fill="#775f49",width=3)
    d.line((146,132,163,120,169,152),fill="#f7dfb6",width=2)
    d.line((148,135,162,125,167,152),fill="#d3b88f")
    d.rounded_rectangle((165,155,175,161),1,fill="#9a7b5d",outline="#694f41")
    for x,y in [(164,121),(170,155),(145,133)]:
        d.ellipse((x-3,y-3,x+3,y+3),fill="#ebcda7",outline="#876b52")
        d.line((x-1,y+1,x+1,y-1),fill="#886d51")
    d.polygon([(122,110),(126,110),(132,114),(144,127),(145,132),(141,135),(137,133),(129,122)],fill="#da792d",outline="#7a4a31")
    d.line((125,112,131,116,140,127),fill="#ffb45a",width=2)
    for x,y in [(129,117),(133,122),(138,128)]: d.line((x,y+2,x+3,y),fill="#aa4f26")
    for pts,c in [([(143,132),(151,132),(148,136)],"#627c46"), ([(142,133),(147,140),(144,139)],"#88a650"), ([(142,132),(142,139),(139,135)],"#52683b")]:
        d.polygon(pts,fill=c)


def danming(image):
    make_desk(image,2,("#865565","#b78485","#d6af9f","#edcfb8","#ffe3cd"),"lacquer")
    d=ImageDraw.Draw(image)
    d.polygon([(49,153),(121,153),(128,164),(42,164)],fill="#c68188",outline="#9a586b")
    d.line((47,162,124,162),fill="#f3b4ab")
    keyboard(d,64,155,("#945c6e","#c7939b","#f1cbcb","#fff1db"))
    d.ellipse((114,156,121,162),fill="#dfc1bc",outline="#ab7b83")
    d.line((117,157,117,159),fill="#fff0d6")
    doll(d,148,159,"#dcab69","#ffe4aa","#bc6978","#923e59")
    d.ellipse((10,157,30,162),fill="#a08084",outline="#775963")
    d.ellipse((12,156,28,159),fill="#ead4c7"); d.line((20,138,20,157),fill="#94797c",width=3)
    d.line((19,140,19,157),fill="#f9e8d6")
    d.arc((12,123,28,143),0,180,fill="#9b7c7f",width=2)
    d.rounded_rectangle((15,118,25,137),4,fill="#d3c3bb",outline="#826f78")
    d.line((17,121,17,132),fill="#fff2dc")
    for yy in range(121,131,2):
        for xx in range(18+(yy//2)%2,24,2): d.point((xx,yy),fill="#97878a")
    d.line((16,131,24,131),fill="#e4ac9f")
    d.point((21,134),fill="#a36373"); d.line((24,161,33,162,42,160),fill="#b18885")


def kubby(image):
    make_desk(image,3,("#302631","#614047","#977255","#af8059","#cb9b6e"),"wood")
    d=ImageDraw.Draw(image)
    d.polygon([(65,154),(117,154),(123,163),(59,163)],fill="#557069",outline="#424548")
    d.line((62,162,120,162),fill="#acac7d")
    # Two glazed bowls with different toppings. The spoon casts a one-pixel shadow.
    for x,y,cream in [(20,152,"#d6b278"),(43,154,"#c59570")]:
        d.ellipse((x-11,y+4,x+10,y+8),fill="#7c574b")
        d.ellipse((x-10,y-2,x+10,y+4),fill="#d3bfa1",outline="#6b5960")
        d.ellipse((x-7,y-8,x+7,y+2),fill=cream,outline="#936850")
        d.arc((x-6,y-7,x+5,y+1),195,290,fill="#ffe0a0",width=2)
        d.pieslice((x-10,y-2,x+10,y+9),0,180,fill="#b0a69b",outline="#594d52")
        d.line((x-7,y+3,x-4,y+5,x+3,y+5),fill="#e2d7c2")
        d.line((x-4,y+7,x+4,y+7),fill="#887d7e")
    d.line((19,147,25,134),fill="#955e78",width=2);d.line((20,145,25,135),fill="#d9abc1")
    for x in (40,45):d.point((x,150),fill="#4b3643")
    d.point((43,152),fill="#a55e54")
    d.line((171,157,165,137,151,133),fill="#3e3540",width=4)
    d.line((171,155,165,137,154,134),fill="#99826c")
    d.polygon([(140,125),(144,124),(157,130),(158,135),(154,139),(140,133),(137,130)],fill="#326566",outline="#343741")
    d.line((139,128,143,126,154,131),fill="#82c2b1",width=2)
    for x,y in [(141,129),(144,130),(147,131)]:d.line((x,y,x-1,y+3),fill="#234f58")
    d.line((153,136,160,143,165,144),fill="#433440")


def yune(image):
    make_desk(image,4,("#625368","#99869e","#c1afc3","#dad0d5","#f7eadf"),"stone")
    d=ImageDraw.Draw(image)
    keyboard(d,61,155,("#81708b","#b09eb6","#d7c7da","#f5e2e5"))
    # Crescent inside a transparent lantern; keep the glass panels open.
    d.ellipse((11,157,29,161),fill="#98859b"); d.line((12,158,28,158),fill="#cda873",width=2)
    d.polygon([(13,141),(16,137),(24,137),(27,141),(26,156),(14,156)],outline="#a58a91")
    d.arc((15,140,24,152),5,215,fill="#ffe7a9",width=2)
    d.line((15,141,15,147),fill="#f2e7df");d.line((13,141,27,141),fill="#caaa82")
    d.arc((16,132,24,141),180,360,fill="#977653")
    # Armillary: a foot, open meridians, a tilted ecliptic and the shaded nucleus.
    d.ellipse((133,157,161,161),fill="#988299")
    d.ellipse((134,155,159,159),fill="#83634e",outline="#594554");d.arc((136,154,157,158),160,350,fill="#e7ba76",width=2)
    d.polygon([(143,143),(150,144),(148,151),(152,155),(140,155),(144,151)],fill="#a07b55",outline="#66504d")
    d.line((145,146,145,151,142,154),fill="#e5bc82")
    for box in [(129,115,161,147),(134,116,155,146),(128,125,161,139)]:
        d.ellipse(box,outline="#7a5a52",width=2)
        d.arc(box,175,290,fill="#f0cd8b",width=2)
        d.arc(box,290,50,fill="#bc9466")
    d.ellipse((140,126,150,137),fill="#846695",outline="#594965")
    d.arc((141,127,150,137),180,284,fill="#c1abc5",width=2)
    d.line((129,138,156,120),fill="#8a674a",width=3);d.line((130,137,156,120),fill="#f4cc84")
    for x,y in [(144,115),(157,121),(131,137)]: d.point((x,y),fill="#fff2bd")


def dori(image):
    make_desk(image,5,("#704d3b","#ad795a","#d5a478","#eac69b","#ffe0ae"),"wood")
    d=ImageDraw.Draw(image)
    keyboard(d,61,155,("#896554","#c4a58e","#eddbc0","#fff0d4"))
    # Blown heart-topped bottle: two edges of the glass, thin neck, rosy liquid.
    d.ellipse((10,157,32,161),fill="#bf9378")
    d.rounded_rectangle((15,141,27,159),3,fill="#cc9688",outline="#89695d")
    d.rectangle((19,135,23,142),fill="#c8a186",outline="#937865")
    d.line((17,146,17,155,19,157),fill="#fae4bf"); d.line((25,145,25,156),fill="#ab756a")
    d.rectangle((20,146,24,153),fill="#ecd8b8");d.line((21,148,23,148),fill="#ac8c70")
    d.polygon([(21,136),(13,129),(13,125),(16,122),(19,123),(21,126),(24,122),(28,122),(31,125),(30,130),(23,135)],fill="#ad775b",outline="#785541")
    d.line((15,127,16,124,19,125),fill="#f8d5a6");d.line((24,132,28,129,29,126),fill="#895c49")
    d.ellipse((130,155,157,161),fill="#c7a78a",outline="#8b6e5a")
    d.ellipse((131,154,156,159),fill="#f5dec0",outline="#b99c83")
    d.polygon([(135,155),(138,146),(147,145),(152,154),(147,157),(140,157)],fill="#e0a34e",outline="#98663e")
    d.line((138,153,140,148,141,150,140,154),fill="#f9cc75",width=2)
    d.ellipse((137,143,148,148),fill="#9b5835",outline="#915337")
    d.line((138,147,139,150,140,148,145,148,147,150),fill="#b36b39")
    d.line((140,144,142,141,145,143),fill="#fff1ca",width=2)
    d.ellipse((143,140,146,143),fill="#ab524d")
    d.line((155,158,165,155),fill="#9b8170");d.ellipse((163,153,168,156),fill="#d8c9ac",outline="#a98a72")


def fuwa(image):
    """Low writing desk in the broadcast close-up. The overview shows the open tatami."""
    make_desk(image,6,("#2c302c","#493d37","#675244","#846a52","#a58a68"),"wood")
    d=ImageDraw.Draw(image)
    d.polygon([(16,155),(41,155),(44,162),(12,162)],fill="#4a4947",outline="#343735")
    d.ellipse((21,156,34,160),fill="#343a3b");d.arc((21,155,34,160),185,300,fill="#8c8f80")
    d.line((20,153,42,148),fill="#493e3a",width=2);d.line((20,152,38,148),fill="#bc9b6a")
    d.polygon([(132,158),(133,151),(141,150),(143,157),(139,161),(134,161)],fill="#8daba3",outline="#526b68")
    d.arc((133,150,141,154),175,355,fill="#dce2c6");d.line((134,154,135,158),fill="#cccfab")
    for x,y in [(133,140),(138,139),(144,142)]:
        d.line((137,151,x,y+2),fill="#bc9c73")
        d.line((x,y+2,x-1,y),fill="#4d4744")


ROOMS = [yato, danming, kubby, yune, dori, fuwa]


def backplate(tile, size, reserve_mint):
    # Sample each room independently to avoid colour bleeding across atlas seams.
    pixels = tile.resize((size,size), Image.Resampling.LANCZOS)
    pixels = pixels.filter(ImageFilter.UnsharpMask(radius=.72, percent=85, threshold=3))
    palette = pixels.quantize(colors=192)
    if not reserve_mint:
        return palette.convert("RGB")
    # The two tiny wisps share almost no colours with Kubby's purple outdoor scene.
    # Median cut alone can replace their mint with the ivory of the paper lamps.
    sample = tile.crop(tuple(round(f*tile.width) for f in (.695,.478,.754,.535)))
    accents = sample.quantize(colors=12).getpalette()[:36]
    entries = palette.getpalette()[:192*3] + accents
    palette.putpalette(entries + entries[:3]*((768-len(entries))//3))
    return pixels.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")


def build():
    OUT.mkdir(exist_ok=True)
    with Image.open(SOURCE) as source:
        width,height=source.size
        if width%3 or height%2 or width//3!=height//2:
            raise ValueError("Expected a 3 by 2 atlas of square source paintings")
        side=width//3
        native=Image.new("RGBA",(CELL*3,CELL*4))
        closeup=Image.new("RGB",(CELL*6,CELL*4))
        for index,draw_props in enumerate(ROOMS):
            col,row=index%3,index//3
            box=(col*side,row*side,(col+1)*side,(row+1)*side)
            tile=source.crop(box).convert("RGB")
            native.paste(backplate(tile,CELL,draw_props is kubby),(col*CELL,row*CELL))
            closeup.paste(backplate(tile,CELL*2,draw_props is kubby),(col*CELL*2,row*CELL*2))
            front=Image.new("RGBA",(CELL,CELL))
            draw_props(front)
            native.alpha_composite(front,(col*CELL,(row+2)*CELL))
    native.save(OUT/"rooms.png",optimize=True)
    closeup.save(OUT/"rooms_closeup.png",optimize=True)


if __name__=="__main__":
    build()
