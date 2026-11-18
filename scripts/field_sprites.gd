extends RefCounted

const Finish = preload("res://scripts/story_finish.gd")

# Neutral and animated field poses share one pixel grid and one foot anchor.
# Accessories retain their own silhouettes; portraits are separate artwork.
# Packed atlas row order; independent of selectable/default outfits.
const COSTUMES := ["yato_idle","yato_hood","yato_headset","yato_bunny","yato_knit","yato_track","odanming_idle","danming_origin","danming_racing","hamkubby_idle","kubby_origin","amiha_yune_idle","yune_unveiled","shokoko_dori_idle","hakuten_fuwa_idle"]
const IDLE := preload("res://assets/characters/yard/idle.png")
const LOBBY_IDLE := preload("res://assets/characters/yard/lobby_idle.png")
const CELL := Vector2i(96,112)
const FOOT := Vector2(48,103)
const BODY_HEIGHT := 90.0
const PIXEL_SCALE := 5.0/6.0
const STELLA_ZOOM := 1.5
const STELLA_SCALE := PIXEL_SCALE*STELLA_ZOOM
const STELLA_HEIGHT := BODY_HEIGHT*STELLA_SCALE
const DIRECTIONS := ["down","left","right","up"]
const DIRECTIONAL := {"aethe":preload("res://assets/characters/directional/aethe.png")}
const WALK_SHEET := preload("res://assets/characters/directional/aethe_walk.png")
const STORY_HANDS := preload("res://assets/characters/directional/aethe_story.png")
const CARRY_WALK := preload("res://assets/characters/directional/aethe_carry_walk.png")
const WALK_FRAME_DISTANCE := 8.0
const FACE_REGIONS := preload("res://assets/characters/portrait_regions.json")
static var pixel_texture: CanvasTexture
static var directional_textures := {}
static var touch_regions := {}
static var resident_turns := {}
const TURN_STEPS := 16
# The front walk completes a stride per 66 world units as well.
const STRIDE_DISTANCE := 66.0

static func draw_stella_turn(g, member: String, key: String, feet: Vector2, direction: String, walking: bool, distance: float, tint: Color=Color.WHITE) -> void:
	var row:=DIRECTIONS.find(direction)-1
	assert(row>=0,"Expected a side or rear view")
	if not resident_turns.has(member) or resident_turns[member].key!=key:
		var tex:=CanvasTexture.new()
		tex.diffuse_texture=load("res://assets/characters/directional/"+key+".png") as Texture2D
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		resident_turns[member]={"key":key,"texture":tex}
	var col:=1+floori(maxf(distance,0.)*TURN_STEPS/STRIDE_DISTANCE)%TURN_STEPS if walking else 0
	var source:=Rect2(Vector2(Vector2i(col,row)*CELL),Vector2(CELL))
	g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4)*STELLA_ZOOM)
	Finish.cel(g,resident_turns[member].texture,Rect2(origin(g,feet,STELLA_SCALE),Vector2(CELL)*STELLA_SCALE),source,tint)


static func stella_hit_rect(key: String, feet: Vector2) -> Rect2:
	if touch_regions.is_empty():
		var image:=IDLE.get_image()
		for row in range(COSTUMES.size()):
			var used:=image.get_region(Rect2i(0,row*CELL.y,CELL.x,CELL.y)).get_used_rect()
			touch_regions[COSTUMES[row]]=Rect2(used).grow_individual(8,4,8,4)
		var ete_used:=image.get_region(Rect2i(0,COSTUMES.size()*CELL.y,CELL.x,CELL.y)).get_used_rect()
		touch_regions["aethe"]=Rect2(ete_used).grow_individual(8,4,8,4)
	var region: Rect2=touch_regions[key]
	return Rect2(feet+(region.position-FOOT)*STELLA_SCALE,region.size*STELLA_SCALE)

static func draw_idle(g, row: int, feet: Vector2, height: float, tint: Color) -> void:
	if pixel_texture==null:
		pixel_texture=CanvasTexture.new()
		pixel_texture.diffuse_texture=LOBBY_IDLE
		pixel_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var column:=0
	if g.in_world:
		g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4)*height/(BODY_HEIGHT*PIXEL_SCALE))
		var phase:=fposmod(float(g.clock)+row*.71,3.8+(row%4)*.38)
		if phase<.065: column=1
		elif phase<.145: column=2
		elif phase<.21: column=1
	var scale_factor:=height/BODY_HEIGHT
	Finish.cel(g,pixel_texture,Rect2(origin(g,feet,scale_factor),Vector2(CELL)*scale_factor),Rect2(column*CELL.x,row*CELL.y,CELL.x,CELL.y),tint)

static func direction_for(vector: Vector2, previous: String = "down") -> String:
	if vector.length_squared()<4.0: return previous
	# Keep the current axis near diagonals, so a moving target cannot cause flicker.
	var horizontal := previous in ["left","right"]
	if absf(vector.x)>absf(vector.y)*1.25: horizontal=true
	elif absf(vector.y)>absf(vector.x)*1.25: horizontal=false
	return ("right" if vector.x>0 else "left") if horizontal else ("down" if vector.y>0 else "up")

static func directional_region(direction: String, walking: bool, distance: float) -> Rect2:
	var row := DIRECTIONS.find(direction)
	assert(row>=0,"Unknown field direction: "+direction)
	var column := (floori(maxf(0.0,distance)*4.0/WALK_FRAME_DISTANCE)%16) if walking else 0
	return Rect2(column*CELL.x,row*CELL.y,CELL.x,CELL.y)

static func draw_facing(g, key: String, feet: Vector2, direction: String, walking: bool = false, distance: float = 0.0, height: float = STELLA_HEIGHT, tint: Color = Color.WHITE) -> void:
	assert(DIRECTIONAL.has(key),"Missing directional costume: "+key)
	if key=="aethe" and direction=="down" and not walking:
		draw_idle(g,COSTUMES.size(),feet,height,tint)
		return
	var sheet_key := key+"_walk" if walking else key
	if not directional_textures.has(sheet_key):
		var texture := CanvasTexture.new()
		texture.diffuse_texture=WALK_SHEET if walking else DIRECTIONAL[key]
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		directional_textures[sheet_key]=texture
	if g.in_world: g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4))
	var scale_factor := height/BODY_HEIGHT
	var region := directional_region(direction,walking,distance)
	Finish.cel(g,directional_textures[sheet_key],Rect2(origin(g,feet,scale_factor),Vector2(CELL)*scale_factor),region,tint)

static func draw_story_librarian(g, feet: Vector2, pose: Dictionary, carrying: bool) -> void:
	if pose.walking and not carrying:
		draw_facing(g,"aethe",feet,pose.direction,true,pose.distance)
		return
	var texture: Texture2D=CARRY_WALK if pose.walking else STORY_HANDS
	var column: int=floori(pose.distance*4.0/WALK_FRAME_DISTANCE)%16 if pose.walking else int(carrying)
	g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4)*STELLA_ZOOM)
	Finish.cel(g,texture,Rect2(origin(g,feet,STELLA_SCALE),Vector2(CELL)*STELLA_SCALE),Rect2(column*96,0,96,112))

static func head_hit_rect(key: String, feet: Vector2) -> Rect2:
	var eyes: Array=FACE_REGIONS.data[key].eyes
	var eye_y:=float(eyes[0][1])
	return Rect2(feet+(Vector2(16+18,14+eye_y-16)-FOOT)*STELLA_SCALE,Vector2(28,24)*STELLA_SCALE)

static func origin(g, feet: Vector2, scale_factor: float) -> Vector2:
	return pixel_position(g,feet-FOOT*scale_factor)

static func pixel_position(g, p: Vector2) -> Vector2:
	return ((p*g.WORLD_SCALE+g.WORLD_OFFSET).round()-g.WORLD_OFFSET)/g.WORLD_SCALE if g.in_world else p.round()

static func draw(g, key: String, feet: Vector2, height: float = 75.0, tint: Color = Color.WHITE) -> void:
	if DIRECTIONAL.has(key):
		draw_facing(g,key,feet,"down",false,0.0,height,tint)
		return
	var row := COSTUMES.size() if key=="aethe" else COSTUMES.find(key)
	assert(row>=0,"Missing field costume: "+key)
	draw_idle(g,row,feet,height,tint)
