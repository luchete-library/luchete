extends RefCounted

const Field = preload("res://scripts/field_sprites.gd")
const SAMPLES = preload("res://scripts/pose_samples.gd")
const SHEET = preload("res://assets/characters/interactions/motion/aethe.png")
const MANIFEST = preload("res://assets/characters/interactions/aethe.json")
const RANGE := 125.0
var active := ""
var elapsed := 0.0
var pet_cooldown := 0.0
var stroke_distance := 0.0
var stroke_direction := 0
var stroke_turns := 0
var stroke_age := 0.0
var texture: CanvasTexture
var direct := false
var previous_reaction := ""

func definition(id: String) -> Dictionary:
	for item in MANIFEST.data.actions:
		if item.id==id: return item
	return {}

func clear_stroke() -> void:
	stroke_distance=0.0
	stroke_direction=0
	stroke_turns=0
	stroke_age=0.0

func reset() -> void:
	active=""
	elapsed=0.0
	pet_cooldown=0.0
	direct=false
	clear_stroke()

func position(g) -> Vector2:
	var obj: Dictionary = g._find_object("ete")
	return g.AETHE_POS if obj.is_empty() else obj.pos

func nearby(g) -> bool:
	return g.state.scene=="library" and g.player_pos.distance_to(position(g))<=RANGE

func can_start(g, id: String, from_pointer: bool = false) -> bool:
	return g.mode=="play" and g.state.scene=="library" and (from_pointer or nearby(g)) and active=="" and not definition(id).is_empty() and (id!="recognize" or g.state.fan_form!="")

func start(g, id: String, from_pointer: bool = false) -> bool:
	if not can_start(g,id,from_pointer): return false
	active=id
	elapsed=0.0
	direct=from_pointer
	g.ete_facing="down"
	g.route.clear()
	g.pending_object=""
	clear_stroke()
	return true

func random_reaction(g) -> bool:
	if active!="" or pet_cooldown>0: return false
	var choices: Array = ["greet","listen","cheer","goodbye"]
	if g.state.fan_form!="": choices.append("recognize")
	choices.erase(previous_reaction)
	var chosen: String = choices.pick_random()
	if not start(g,chosen,true): return false
	previous_reaction=chosen
	return true

func phase() -> int:
	if active=="": return 4
	var remaining := elapsed
	var times: Array = definition(active).durations
	for column in range(times.size()):
		if remaining<float(times[column]): return column
		remaining-=float(times[column])
	return 4

func duration() -> float:
	var total := 0.0
	if active!="":
		for hold in definition(active).durations: total+=float(hold)
	return total

func update(g, delta: float) -> void:
	if g.state.scene!="library" or g.mode in ["chapter","rescue","title","new_confirm"]:
		reset()
		return
	if g.mode!="play" or g.character_touch.held=="ete":
		clear_stroke()
		return
	pet_cooldown=maxf(0.0,pet_cooldown-delta)
	stroke_age+=delta
	if stroke_age>.65: clear_stroke()
	if active=="": return
	# If the player leaves, finish the gesture through its recovery pose.
	if not direct and g.player_pos.distance_to(position(g))>RANGE+35 and phase()<3:
		var times: Array = definition(active).durations
		elapsed=float(times[0])+float(times[1])+float(times[2])
	elapsed+=maxf(0.0,delta)
	if elapsed>=duration():
		active=""
		elapsed=0.0
		pet_cooldown=1.0

func pointer_motion(g, event: InputEventMouseMotion) -> bool:
	if not can_start(g,"pet",true) or pet_cooldown>0 or g.character_touch.held!="" or not g.character_touch.ete_visit.is_empty():
		clear_stroke()
		return false
	for region in g.ui_regions:
		if region.has_point(event.position):
			clear_stroke()
			return false
	if g.character_touch.over_ui(g,event.position): return false
	var point: Vector2 = (event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
	var head := Field.head_hit_rect("aethe",position(g))
	if not head.has_point(point):
		clear_stroke()
		return false
	var movement: float = event.relative.x/g.WORLD_SCALE
	if absf(movement)<1.0: return false
	# A single fast pass/teleport cannot count as a stroke.
	if absf(movement)>32.0:
		clear_stroke()
		return false
	var direction := 1 if movement>0 else -1
	if stroke_direction!=0 and direction!=stroke_direction: stroke_turns+=1
	stroke_direction=direction
	stroke_distance+=absf(movement)
	stroke_age=0.0
	if stroke_turns>=2 and stroke_distance>=60.0: return start(g,"pet",true)
	return false

func draw_actor(g, feet: Vector2) -> bool:
	if active=="": return false
	if texture==null:
		texture=CanvasTexture.new()
		texture.diffuse_texture=SHEET
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var column := SAMPLES.gesture(definition(active).durations,elapsed)
	var row := int(definition(active).row)
	g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4)*Field.STELLA_ZOOM)
	g.draw_texture_rect_region(texture,Rect2(Field.origin(g,feet,Field.STELLA_SCALE),Vector2(Field.CELL)*Field.STELLA_SCALE),Rect2(column*96,row*112,96,112))
	return true
