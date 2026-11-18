extends RefCounted

# A separate story pass: original faces, body proportions and cel anchors are
# untouched. Four one-pixel underlays separate fine outlines from busy scenery.
const PLATES := {
	"yato:1":"yato_storehouse_detail",
	"danming:2":"story_danming_2_detail",
	"dori:2":"story_dori_2_detail",
	"yune:2":"story_yune_2_detail",
	"kubby:1":"story_kubby_1_detail",
	"fuwa:0":"story_fuwa_0_detail",
}
const Pixels = preload("res://scripts/world_pixels.gd")

static func background(g, member: String, scene: int) -> bool:
	var key:=member+":"+str(scene)
	if not PLATES.has(key): return false
	g.draw_texture_rect(Pixels.texture(PLATES[key]),Rect2(32,140,904,578),false)
	return true

static func cel(g, texture: Texture2D, destination: Rect2, source: Rect2, tint: Color=Color.WHITE) -> void:
	if g.in_world and g.mode in ["chapter","rescue"] and tint.a>.5:
		var step:=destination.size/source.size
		var edge:=Color(.24,.20,.27,.40*tint.a)
		for offset: Vector2 in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
			g.draw_texture_rect_region(texture,Rect2(destination.position+offset*step,destination.size),source,edge)
	# This final pass is precisely the same authored cel at the original position.
	g.draw_texture_rect_region(texture,destination,source,tint)

static func contact(g, p: Vector2, size: Vector2) -> void:
	# Stepped pixel ellipses: soft outer contact, a smaller dense centre. No blur.
	for band in range(3):
		var radius:=size*(1.0-band*.22)
		var ink:=Color(.13,.12,.18,.065+band*.035)
		for y in range(-ceili(radius.y),ceili(radius.y)+1):
			var t:=float(y)/maxf(1,radius.y)
			if absf(t)>1: continue
			var width:=floorf(radius.x*sqrt(maxf(0,1-t*t)))
			g.draw_rect(Rect2((p+Vector2(-width,y)).round(),Vector2(width*2+1,1)),ink)
