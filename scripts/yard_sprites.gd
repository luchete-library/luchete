extends RefCounted

# Subsampled full-body poses. Hair follows the head, the hem follows the
# torso, and padded neck/limb joints remain attached through weight shifts.
const Field = preload("res://scripts/field_sprites.gd")
const COSTUMES = Field.COSTUMES
const SHEETS := {
	"pilates":preload("res://assets/characters/yard/pilates.png"),"yoga":preload("res://assets/characters/yard/yoga.png"),
	"gym":preload("res://assets/characters/yard/gym.png"),"rope":preload("res://assets/characters/yard/rope.png"),
	"stream":preload("res://assets/characters/yard/stream.png"),"walk":preload("res://assets/characters/yard/walk.png"),
	"read":preload("res://assets/characters/yard/read.png"),"tea":preload("res://assets/characters/yard/tea.png")
}
const CELL = Field.CELL
const FRAMES := 72
const COLUMNS := 36
const PIXEL_SCALE = Field.STELLA_SCALE
const FPS := {"yoga":18.0,"pilates":24.0,"rope":36.0,"gym":36.0,"stream":24.0,"walk":36.0,"read":18.0,"tea":24.0}
const LABELS := {"idle":"쉬는 중","walk":"이동 중","read":"독서 중","tea":"차 마시는 중","stream":"도서관 방송"}
const JUMP := [1,2,0,-4,-7,-8,-8,-5,-1,2,2,1]
const SPOTS = preload("res://scripts/garden_furniture.gd").HOME_SPOTS
static var pixel_textures := {}

static func routine(state, slot: int, id: String) -> String:
	if state.yard_session.get("member","") == id: return state.yard_session.routine
	if state.yard_host == id: return "stream"
	return "idle"

static func draw_station(g, pos: Vector2, act: String) -> void:
	if act in ["yoga","pilates","stream"]:
		g.Pixels.furniture(g,"camera" if act=="stream" else "mat",pos,false)
	elif act=="gym":
		g.Pixels.sprite(g,"gym_rack",pos+Vector2(29,-3))

static func draw_actor(g, member: Dictionary, pos: Vector2, act: String, seconds: float, facing: String = "down", distance: float = 0.) -> void:
	if act in ["idle","walk"] and facing!="down":
		Field.draw_stella_turn(g,member.id,g._costume_key(member.id),pos,facing,act=="walk",distance)
		return
	if act=="idle":
		g._draw_member(pos,member.id,Field.STELLA_HEIGHT,true)
		return
	if g.StellaInteractions.draw_activity(g,member.id,pos,act,seconds): return
	if not pixel_textures.has(act):
		var tex := CanvasTexture.new()
		tex.diffuse_texture = SHEETS[act]
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pixel_textures[act] = tex
	var frame := floori(seconds*FPS[act])%FRAMES
	var row := COSTUMES.find(g._costume_key(member.id))
	var airborne := 0.0
	if act == "rope":
		var beat := seconds*12.0
		var start := floori(beat)%JUMP.size()
		airborne = maxf(0,-lerpf(JUMP[start],JUMP[(start+1)%JUMP.size()],fmod(beat,1.0)))/8.0
	g.draw_ellipse_shadow(pos+Vector2(0,3),Vector2(16-airborne*3,4-airborne*0.6)*Field.STELLA_ZOOM)
	var origin := Field.origin(g,pos,PIXEL_SCALE)
	var cell := Vector2i(frame%COLUMNS,row*2+int(frame/float(COLUMNS)))
	g.draw_texture_rect_region(pixel_textures[act],Rect2(origin,Vector2(CELL)*PIXEL_SCALE),Rect2(Vector2(cell*CELL),Vector2(CELL)))
