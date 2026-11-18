extends RefCounted

const NATIVE := preload("res://assets/characters/portrait_regions.json")

# Mouth and eye centres in the portrait artist's original pixel grid.
const LANDMARKS := {
	"yato_idle": [Vector2(530,274), Vector2(491,231), Vector2(567,231)],
	"yato_hood": [Vector2(526,345), Vector2(489,308), Vector2(557,308)],
	"yato_headset": [Vector2(530,275), Vector2(492,231), Vector2(568,231)],
	"yato_bunny": [Vector2(530,277), Vector2(491,229), Vector2(568,229)],
	"yato_knit": [Vector2(530,274), Vector2(492,231), Vector2(568,231)],
	"yato_track": [Vector2(530,274), Vector2(491,231), Vector2(567,231)],
	"odanming_idle": [Vector2(526,273), Vector2(482,224), Vector2(565,224)],
	"danming_origin": [Vector2(526,283), Vector2(482,239), Vector2(565,239)],
	"danming_racing": [Vector2(528,292), Vector2(483,249), Vector2(567,249)],
	"hamkubby_idle": [Vector2(529,310), Vector2(483,264), Vector2(571,264)],
	"kubby_origin": [Vector2(528,307), Vector2(486,260), Vector2(569,260)],
	"amiha_yune_idle": [Vector2(533,303), Vector2(490,263), Vector2(573,263)],
	"yune_unveiled": [Vector2(533,303), Vector2(494,265), Vector2(570,265)],
	"shokoko_dori_idle": [Vector2(525,393), Vector2(482,350), Vector2(566,350)],
	"hakuten_fuwa_idle": [Vector2(519,362), Vector2(476,317), Vector2(561,317)],
}
var warm_portraits: Dictionary = {}

static func portrait_region(base: Texture2D, key: String) -> Rect2:
	if NATIVE.data.has(key):
		var r: Array=NATIVE.data[key].region
		return Rect2(r[0],r[1],r[2],r[3])
	var mouth: Vector2 = LANDMARKS[key][0]
	var scale_factor := base.get_height()/1484.0
	var framing := Rect2(-193,-229,386,360)
	if key in ["shokoko_dori_idle","hakuten_fuwa_idle","yato_hood"]:
		framing = Rect2(-222,-287,444,414)
	return Rect2((mouth+framing.position)*scale_factor,framing.size*scale_factor)

# Use the artist's expression. Warm only the skin below the eyes on a tagged line.
func warm_portrait(base: Texture2D, key: String) -> Texture2D:
	if warm_portraits.has(key):
		return warm_portraits[key]
	var image := base.get_image()
	if image == null: return base
	if NATIVE.data.has(key):
		for eye: Array in NATIVE.data[key].eyes:
			for dx in [-1,0,1]:
				var p:=Vector2i(int(eye[0])+dx,int(eye[1])+3)
				var ink:=image.get_pixelv(p)
				if ink.a>.9 and ink.r>.65 and ink.g>.5:
					image.set_pixelv(p,ink.lerp(Color("f19a91"),.18))
		var native_texture:=ImageTexture.create_from_image(image)
		warm_portraits[key]=native_texture
		return native_texture
	var points: Array = LANDMARKS[key]
	var mouth: Vector2 = points[0]
	var scale_factor := base.get_height()/1484.0
	for i in [1,2]:
		var eye: Vector2 = points[i]
		var center := Vector2(eye.x,lerpf(eye.y,mouth.y,0.63))*scale_factor
		var radius := Vector2(14,6)*scale_factor
		for y in range(floori(center.y-radius.y),ceili(center.y+radius.y)):
			for x in range(floori(center.x-radius.x),ceili(center.x+radius.x)):
				var pos := (Vector2(x+0.5,y+0.5)-center)/radius
				var ink := image.get_pixel(x,y)
				var warmth := (1.0-smoothstep(0.15,1.0,pos.length()))*smoothstep(0.5,0.83,ink.g)*0.24
				image.set_pixel(x,y,ink.lerp(Color("f19a91"),warmth))
	var texture := ImageTexture.create_from_image(image)
	warm_portraits[key] = texture
	return texture
