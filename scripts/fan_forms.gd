extends RefCounted

# One native pixel grid for library, garden, Ete cards and book roles.
# Complete connected frames; never warp strips or individual face rows.
const DATA = preload("res://assets/characters/fans/manifest.json")
const Motion = preload("res://scripts/fan_motion.gd")
const Field = preload("res://scripts/field_sprites.gd")
static var textures := {}

static func texture(id: String) -> CanvasTexture:
	if not textures.has(id):
		var tex := CanvasTexture.new()
		tex.diffuse_texture = load("res://assets/characters/fans/"+id+".png")
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		textures[id] = tex
	return textures[id]

static func frame_at(id: String, clock: float, walking: bool) -> int:
	if walking:
		var gait: Array = DATA.data.animations.walk
		return int(gait[posmod(floori(clock*float(DATA.data.walk_fps)),gait.size())])
	return Motion.idle_frame(id,clock)

static func region_for(frame: int, direction: String = "down") -> Rect2:
	var row: int = DATA.data.directions.find(direction)
	return Rect2(clampi(frame,0,int(DATA.data.frames)-1)*64,maxi(row,0)*64,64,64)

static func draw(g, id: String, feet: Vector2, walking: bool, tilt: float = 0.0, stretch: Vector2 = Vector2.ONE, flutter: float = 0.0) -> void:
	if not DATA.data.members.has(id): return
	var frame: int = frame_at(id,g.clock,false) if g.mode=="fan_forms" else g.fan_motion.frame_for(id)
	var motion: Dictionary = DATA.data.members[id].motion
	var shadow_scale: float = float(motion.shadow_scale[frame])
	g.draw_ellipse_shadow(feet+Vector2(0,2),Vector2(float(motion.shadow_width)*shadow_scale,3*shadow_scale))
	# Each direction has its own full row, including idle and stopping poses.
	var direction: String = "down" if g.mode=="fan_forms" else g.fan_motion.facing_for(id)
	# Body lift and planted feet are already drawn together in the atlas.
	g._transform(Field.pixel_position(g,feet-Vector2(0,absf(flutter))),stretch,tilt)
	Field.Finish.cel(g,texture(id),Rect2(-32,-58,64,64),region_for(frame,direction))
	g._transform()
