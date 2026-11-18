"""Fit the illustrated hall to the game's existing world grid and furniture anchors."""
from functools import lru_cache
from pathlib import Path
from random import Random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps


SOURCE = Path(__file__).resolve().parent / "library_art"
WORLD_ORIGIN = (32, 140)
LIGHT_ORIGIN = (426, 238)


@lru_cache(maxsize=4)
def source(name):
    with Image.open(SOURCE / (name + ".png")) as image:
        return image.convert("RGBA")


def pixel_cutout(image, size, tones=160):
    # Resize through premultiplied alpha, then snap outlines to the native grid.
    image = image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 116 else 0)
    rgb = image.convert("RGB").filter(ImageFilter.UnsharpMask(.68, 82, 3))
    result = rgb.quantize(colors=tones, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


@lru_cache(maxsize=1)
def hall():
    plate = source("hall").convert("RGB")
    # Register the back rail with the walkable floor and garden doorway.
    room = Image.new("RGB", (904,578))
    for top,bottom,dest_top,dest_bottom in [(0,219,0,107),(219,1024,107,578)]:
        strip = plate.crop((0,top,plate.width,bottom))
        room.paste(strip.resize((904,dest_bottom-dest_top), Image.Resampling.LANCZOS), (0,dest_top))
    return room.filter(ImageFilter.UnsharpMask(.75,85,3)).quantize(colors=180).convert("RGBA")


# Exact bounds separate oversized props on the production sheet. Destination
# rectangles use native pixels; positions in the manifest remain in world units.
PROPS = {
    "work_table": ((17,85,535,418), (2,0,194,92)),
    "lending_desk": ((560,73,1034,451), (2,0,126,93)),
    "chair": ((1095,6,1468,485), (17,0,81,82)),
    "tea_front": ((38,562,508,945), (3,30,94,83)),
    "window": ((538,509,993,967), (1,0,95,94)),
    "garden_door": ((1066,491,1502,966), (2,0,112,128)),
}


@lru_cache(maxsize=10)
def prop(name, size, target=None):
    if name in PROPS:
        crop, default_target=PROPS[name]
        sprite=source("furnishings").crop(crop)
    else:
        col,row=DETAILS[name]
        sprite=source("room_details").crop((col*512,row*512,(col+1)*512,(row+1)*512))
        default_target=(1,1,size[0]-1,size[1]-1)
    bounds = sprite.getchannel("A").point(lambda value: 255 if value>96 else 0).getbbox()
    left,top,right,bottom = target or default_target
    result = Image.new("RGBA",size)
    result.alpha_composite(pixel_cutout(sprite.crop(bounds),(right-left,bottom-top)),(left,top))
    return result


DETAILS={"rug":(0,0),"fern":(1,0),"notice_board":(2,0),"lamp":(0,1),"camera":(1,1),"mat":(2,1)}
RUG_DYES={"rug_main":(0,0,0),"rug_read":(18,17,1),"rug_tea":(56,-8,3),
          "rug_exercise":(33,-11,36),"rug_stream":(-7,2,28)}


def woven_rug(name,size):
    pixels=np.array(prop("rug",size))
    r,g,b=pixels[:,:,:3].astype(int).transpose(2,0,1)
    warp=(g>r+4)&(g>b)&(pixels[:,:,3]>0)
    for i,delta in enumerate(RUG_DYES[name]):
        channel=pixels[:,:,i]
        channel[warp]=np.clip(channel[warp].astype(int)+delta,0,255)
    return Image.fromarray(pixels)


def wall_lamp(lit):
    image=prop("lamp",(32,64),(3,2,29,55)).copy()
    if not lit:
        glass=Image.new("L",image.size)
        ImageDraw.Draw(glass).polygon([(6,28),(26,28),(23,44),(10,44)],fill=255)
        tarnish=ImageOps.colorize(ImageOps.grayscale(image),"#3d413c","#96957c")
        image.paste(tarnish,(0,0),glass)
    return image


@lru_cache(maxsize=2)
def reading_chair(tea):
    image = prop("chair",(96,84)).copy()
    if tea:
        pixels = np.array(image)
        # Tint the green velvet only. The gilded fittings retain their amber highlights.
        r,g,b = pixels[:,:,:3].astype(float).transpose(2,0,1)
        fabric = (g>r*.89) & (g>b*1.19) & (pixels[:,:,3]>0)
        value = .3*r+.59*g+.11*b
        for channel,factor,offset in [(0,1.17,11),(1,.73,8),(2,.83,15)]:
            pixels[:,:,channel][fabric] = np.clip(value[fabric]*factor+offset,0,255)
        image = Image.fromarray(pixels)
    return image


def chair_layer(name):
    chair = reading_chair(name=="tea_back").copy()
    if name=="tea_back": return chair
    # Only the two arms and front feet overlap a seated actor. Preserve every
    # silhouette pixel exactly once between the two passes of the y-sorted draw.
    mask = Image.new("L",chair.size)
    d = ImageDraw.Draw(mask)
    for shape in [[(16,40),(22,40),(28,43),(28,56),(25,66),(26,81),(17,81)],
                  [(72,40),(81,40),(81,81),(71,81),(71,66),(69,55),(69,45)]]:
        d.polygon(shape,fill=255)
    alpha = np.array(chair.getchannel("A"))
    front = np.array(mask)>0
    chair.putalpha(Image.fromarray(np.where(front if name=="chair_front" else ~front,alpha,0).astype("uint8")))
    return chair


def window(boarded):
    im = prop("window",(96,96)).copy()
    if not boarded: return im
    # The same carved sill is visible before and after the window is repaired.
    dull = ImageOps.colorize(ImageOps.grayscale(im), "#272d31", "#9c9986")
    dull.putalpha(im.getchannel("A"))
    d = ImageDraw.Draw(dull)
    for left,right in [(21,16),(54,59)]:
        d.polygon([(6,left),(89,right),(89,right+8),(6,left+9)],fill="#554539",outline="#352e2d")
        d.line((8,left+1,87,right+1),fill="#9e8261")
        d.line((14,left+5,42,(left+right)//2+3,66,right+5,83,right+4),fill="#77624d")
        for x,y in [(11,left+4),(84,right+4)]: d.point((x,y),fill="#c1ae88")
    return dull


# Interior coordinates in the source painting. Each run ends between complete
# books; stacked and leaning books are restored together with their support.
SHELF_ROWS = [
    ((159,391),[[120,218,348,497,652],[675,856,940,1024,1090,1223],[1248,1365,1434,1516,1640,1783]]),
    ((418,652),[[120,216,265,403,488,524,650],[675,758,816,909,970,1223],[1248,1332,1429,1518,1592,1686,1783]]),
]


def walnut_back(width,height):
    rng = Random(27)
    backing = Image.new("RGBA",(width,height))
    d = ImageDraw.Draw(backing)
    for y in range(height):
        lift=min(1,y/max(1,height*.33))
        d.line((0,y,width,y),fill=(int(46+16*lift),int(32+7*lift),int(35+3*lift),255))
    for x in range(6,width,15):
        d.line((x,1,x,height-1),fill="#352329")
        d.line((x+1,4,x+1,height-1),fill="#49302e")
        yy=rng.randrange(4,max(5,height//2))
        d.line((x+5,yy,x+5,yy+4,x+6,yy+6),fill="#452d2c")
    return backing


def bookcase(width, stage, story):
    art = source("bookcase")
    native = Image.new("RGBA",(width,100))
    # Keep the bottom rail at y=85 so six live covers rest on it at world y=243.
    source_x=(24,1881)
    for y0,y1,top,bottom in [(46,159,0,10),(159,391,10,43),(391,418,43,48),
                             (418,652,48,85),(652,792,85,100)]:
        band=art.crop((source_x[0],y0,source_x[1],y1))
        native.paste(pixel_cutout(band,(width,bottom-top),144),(0,top))
    def dest_x(value): return round((value-source_x[0])*width/(source_x[1]-source_x[0]))
    for row,(_limits,bays) in enumerate(SHELF_ROWS):
        top,bottom=(10,43) if row==0 else (48,85)
        if story and row==1:
            lo,hi=dest_x(120),dest_x(1783)
            native.paste(walnut_back(hi-lo,bottom-top),(lo,top))
            continue
        for bay, dividers in enumerate(bays):
            lo,hi=dest_x(dividers[0]),dest_x(dividers[-1])
            edges=[dest_x(edge) for edge in dividers]
            if story:
                # Curate the shorter collections above the six live covers.
                # Keep the end of each reveal between whole volumes in its source bay.
                source_row,source_bay=[(1,1),(0,2),(1,0)][bay]
                (sy0,sy1),collections=SHELF_ROWS[source_row]
                divisions=collections[source_bay]
                first,last=divisions[0],divisions[-1]
                collection=art.crop((first,sy0,last,sy1))
                native.paste(pixel_cutout(collection,(hi-lo,bottom-top),144),(lo,top))
                edges=[lo+round((edge-first)*(hi-lo)/(last-first)) for edge in divisions]
            backing=walnut_back(hi-lo,bottom-top)
            for j,(x0,x1) in enumerate(zip(edges,edges[1:])):
                # A single surviving bundle per case at first. Every rescue
                # subsequently returns a few bundles, independent of rescue order.
                tier=1+(j*2+bay*3+row+(2 if story else 0))%6
                if j==0 and bay==0 and row==0: tier=0
                if stage<tier:
                    native.paste(backing.crop((x0-lo,0,x1-lo,bottom-top)),(x0,top))
    return native


def furnishing(name, size):
    if name.startswith("shelf_"):
        return bookcase(size[0],int(name[-1]),"_story_" in name)
    if name in ("work_table","lending_desk","tea_front"): return prop(name,size)
    if name=="garden_door": return prop(name,size,(1,0,size[0]-1,size[1]-2))
    if name in ("chair_back","chair_front","tea_back"): return chair_layer(name)
    if name in ("window_boarded","window_clear"): return window(name=="window_boarded")
    if name in RUG_DYES: return woven_rug(name,size)
    if name=="notice_board": return prop(name,size)
    if name.startswith("plant_"):
        target=(0,20,56,78) if name=="plant_lush" else (7,33,49,78)
        return prop("fern",size,target)
    if name in ("lamp_on","lamp_off"): return wall_lamp(name=="lamp_on")
    if name=="camera_back": return prop("camera",size,(51,3,93,64))
    if name=="mat_back": return prop("mat",size,(2,3,86,34))
    return None


def window_light():
    # Project the four panes down-left from the window at world (682,142).
    # The feathered edge and leaf shadows are quantized to native pixel steps.
    width,height=390,270
    y,x=np.mgrid[0:height,0:width]
    u=(x+.71*y-253)/(73+.15*y)
    falloff=np.clip(1-y/247,0,1)
    edge=np.minimum(u,1-u)
    soft=.013+y*.00021
    beam=np.clip(edge/soft,0,1)*np.clip((abs(u-.5)-.018)/soft,0,1)
    beam*=np.clip((abs(y-81)-3)/(2+.04*y),0,1)
    leaves=Image.new("L",(width,height),255)
    d=ImageDraw.Draw(leaves)
    for dx,dy,r in [(0,19,8),(9,27,6),(3,38,6),(14,47,7),(8,60,6),
                    (58,64,7),(48,76,6),(59,83,9),(63,101,7),(68,115,6)]:
        xx=round(254+dx-.71*dy)
        d.polygon([(xx-r,dy),(xx-2,dy-r//2),(xx+r,dy-r),(xx+3,dy+1),(xx-2,dy+3)],fill=94)
    branch=np.asarray(leaves.filter(ImageFilter.BoxBlur(1)))/255.
    spill=np.maximum(0,1-abs(u-.5)*1.53)*falloff**1.9
    strength=100*beam*branch*falloff**.63+15*spill
    rgba=np.empty((height,width,4),dtype=np.uint8)
    rgba[:,:,:3]=(255,219,144)
    rgba[:,:,3]=np.rint(strength/3)*3
    return Image.fromarray(rgba)
