extends RefCounted

# Each row preserves the authored poses and their baked full-body transitions.
const Field = preload("res://scripts/field_sprites.gd")
const Samples = preload("res://scripts/pose_samples.gd")
const DATA := {
	"yato":preload("res://assets/characters/interactions/yato.json"),
	"danming":preload("res://assets/characters/interactions/danming.json"),
	"kubby":preload("res://assets/characters/interactions/kubby.json"),
	"yune":preload("res://assets/characters/interactions/yune.json"),
	"dori":preload("res://assets/characters/interactions/dori.json"),
	"fuwa":preload("res://assets/characters/interactions/fuwa.json")
}
const SHEETS := {
	"yato":preload("res://assets/characters/interactions/motion/yato.png"),
	"danming":preload("res://assets/characters/interactions/motion/danming.png"),
	"kubby":preload("res://assets/characters/interactions/motion/kubby.png"),
	"yune":preload("res://assets/characters/interactions/motion/yune.png"),
	"dori":preload("res://assets/characters/interactions/motion/dori.png"),
	"fuwa":preload("res://assets/characters/interactions/motion/fuwa.png")
}
static var textures := {}

static func supports(g, member: String) -> bool:
	return DATA.has(member) and g.Wardrobe.COSTUMES[member].has(g._costume_key(member))

static func sheet_for(member: String, costume: String) -> Texture2D:
	if costume==DATA[member].data.costume: return SHEETS[member]
	return load("res://assets/characters/interactions/motion/"+costume+".png") as Texture2D

static func definition(member: String, action: String) -> Dictionary:
	if not DATA.has(member): return {}
	for item in DATA[member].data.actions:
		if item.id==action: return item
	return {}

static func click_actions(member: String) -> Array:
	var result := []
	for item in DATA[member].data.actions:
		if item.kind=="social": result.append(item.id)
	return result

static func duration(member: String, action: String) -> float:
	var total := 0.0
	for hold in definition(member,action).durations: total+=float(hold)
	return total

static func draw(g, member: String, action: String, feet: Vector2, column: int, costume: String="", tint: Color=Color.WHITE) -> void:
	var item := definition(member,action)
	if costume.is_empty(): costume=g._costume_key(member)
	if not textures.has(member) or textures[member].costume!=costume:
		var texture := CanvasTexture.new()
		texture.diffuse_texture=sheet_for(member,costume)
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[member]={"costume":costume,"texture":texture}
	g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4)*Field.STELLA_ZOOM)
	Field.Finish.cel(g,textures[member].texture,Rect2(Field.origin(g,feet,Field.STELLA_SCALE),Vector2(Field.CELL)*Field.STELLA_SCALE),Rect2(column*96,int(item.row)*112,96,112),tint)

static func draw_activity(g, member: String, feet: Vector2, action: String, seconds: float) -> bool:
	if action not in ["read","tea","yoga","stream"] or not supports(g,member): return false
	var total := 8.0
	var elapsed := seconds
	var agent: Dictionary = g.garden_residents.agents.get(member,{})
	if g.state.yard_session.get("member","")==member:
		total=g.State.Workout.DURATION
	elif agent.get("phase","")=="use":
		total=float(agent.elapsed)+float(agent.timer)
	else:
		elapsed=fmod(seconds,total) # Ongoing broadcasts can repeat a full greeting.
	draw(g,member,action,feet,Samples.furniture(action,elapsed,total))
	return true
