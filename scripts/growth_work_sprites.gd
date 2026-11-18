extends RefCounted

# First reconstruction only: fixed default costumes before the outfit shop.
const DIR := "res://assets/characters/growth_work/"
const FIELD = preload("res://scripts/field_sprites.gd")
const FURNITURE = preload("res://scripts/garden_furniture.gd")
const PARTICIPANTS := {"corridor":["yato","fuwa"],"shelves":["dori","danming"],"reading":["yune","kubby"]}
const FEET := {"yato":Vector2(395,605),"dori":Vector2(430,350),"danming":Vector2(550,350),"yune":Vector2(620,480),"kubby":Vector2(745,480)}
const BOX_START := Vector2(500,640)
const BOX_END := Vector2(780,640)
const LAMP := Vector2(711,424)
const CORRIDOR_TRACK := [
	[2.4,3.0,"ready"],[3.0,3.9,"crouch"],[3.9,4.6,"grip"],[4.6,5.2,"brace"],
	[5.2,6.1,"lift"],[6.1,6.6,"carry_start"],[6.6,11.1,"carry_walk"],
	[11.1,11.8,"carry_stop"],[11.8,12.9,"lower"],[12.9,13.6,"release"],
	[13.6,14.4,"stand"],[14.4,16.0,"relief"]
]
static var textures: Dictionary={}
static var corridor_data: Dictionary={}

static func participants(task: String) -> Array:
	return PARTICIPANTS.get(task,[])

static func hides_player(task: String) -> bool:
	return task=="corridor"

static func _texture(filename: String) -> Texture2D:
	if not textures.has(filename):
		var pixel:=CanvasTexture.new()
		pixel.diffuse_texture=load(DIR+filename) as Texture2D
		pixel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[filename]=pixel
	return textures[filename]

static func _data() -> Dictionary:
	if corridor_data.is_empty(): corridor_data=JSON.parse_string(FileAccess.get_file_as_string(DIR+"motions.json"))
	return corridor_data

static func _corridor_action(elapsed: float) -> Dictionary:
	for step in CORRIDOR_TRACK:
		if elapsed>=float(step[0]) and elapsed<float(step[1]):
			return {"id":step[2],"t":fposmod(elapsed-6.6,1.0) if step[2]=="carry_walk" else inverse_lerp(float(step[0]),float(step[1]),elapsed)}
	return {"id":"ready","t":0.0}

static func _pose(g,id: String,feet: Vector2,action: String,progress: float,part: String="both") -> void:
	var data:=_data()
	var size: float=data.actors[id].scale
	var column:=clampi(floori(progress*24.0) if action=="carry_walk" else roundi(progress*23.0),0,23)
	var row: int=data.actions.find(action)
	var dest:=Rect2(FIELD.origin(g,feet,size),Vector2(96,112)*size)
	var source:=Rect2(column*96,row*112,96,112)
	if part in ["body","both"]: g.draw_texture_rect_region(_texture(id+"_body.png"),dest,source)
	if part in ["arms","both"]: g.draw_texture_rect_region(_texture(id+"_arms.png"),dest,source)

static func _work_pose(g,task: String,id: String,feet: Vector2,elapsed: float) -> void:
	var n:=clampi(floori(elapsed*24.0),0,287)
	var source:=Rect2((n%24)*96,floori(n/24.0)*112,96,112)
	g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(23,6))
	g.draw_texture_rect_region(_texture(task+"_"+id+".png"),Rect2(FIELD.origin(g,feet,FIELD.STELLA_SCALE),Vector2(96,112)*FIELD.STELLA_SCALE),source)

static func draw(g,task: String,elapsed: float,offset: Vector2=Vector2.ZERO) -> void:
	match task:
		"corridor": draw_corridor(g,elapsed,offset)
		"shelves": draw_shelves(g,elapsed,offset)
		"reading": draw_reading(g,elapsed,offset)

static func draw_corridor(g,elapsed: float,offset: Vector2=Vector2.ZERO) -> void:
	var t:=clampf(elapsed,0,15.999)
	var action:=_corridor_action(t)
	var column:=clampi(roundi(float(action.t)*23.0),0,23)
	var lift: float=_data().actors.traveler.tracks[action.id][column].lift
	var center:=BOX_START.lerp(BOX_END,smoothstep(6.1,11.8,t))+offset
	var player:=center+Vector2(-55,5)
	var fuwa:=center+Vector2(58,18)
	g.draw_ellipse_shadow(center+Vector2(0,2),Vector2(59,6))
	g.draw_ellipse_shadow(player+Vector2(0,3),Vector2(16,4))
	g.draw_ellipse_shadow(fuwa+Vector2(0,3),Vector2(23,6))
	_pose(g,"traveler",player,action.id,action.t,"body")
	_pose(g,"fuwa",fuwa,action.id,action.t,"body")
	_crate(g,center-Vector2(0,lift*8.0))
	_pose(g,"traveler",player,action.id,action.t,"arms")
	_pose(g,"fuwa",fuwa,action.id,action.t,"arms")
	if t<1.5: _pose(g,"yato",FEET.yato+offset,"inspect",t/1.5)
	elif t<2.4: _pose(g,"yato",FEET.yato+offset,"point",(t-1.5)/.9)
	elif t>=14.4: _pose(g,"yato",FEET.yato+offset,"confirm",(t-14.4)/1.6)
	else: _pose(g,"yato",FEET.yato+offset,"ready",0)

static func draw_shelves(g,elapsed: float,offset: Vector2=Vector2.ZERO) -> void:
	for id in ["dori","danming"]:
		var feet: Vector2=FEET[id]+offset
		# Small sorting trolley and the destination slot are visible while a
		# book moves from the hands into the organised shelf.
		var shelf:=feet+Vector2(18,-51)
		g.draw_rect(Rect2(shelf+Vector2(-12,7),Vector2(40,4)),Color("7d583b"))
		g.draw_rect(Rect2(shelf+Vector2(-10,11),Vector2(3,35)),Color("5c4837"))
		g.draw_rect(Rect2(shelf+Vector2(23,11),Vector2(3,35)),Color("5c4837"))
		if elapsed>=5.0:
			g.draw_rect(Rect2(shelf+Vector2(-4,-7),Vector2(8,15)),Color("c18b97") if id=="danming" else Color("729497"))
			g.draw_rect(Rect2(shelf+Vector2(-3,-5),Vector2(1,10)),Color("e6ce9b"))
		if elapsed>=9.3 and id=="danming":
			g.draw_rect(Rect2(shelf+Vector2(8,-3),Vector2(16,9)),Color("eee1b9"))
			g.draw_line(shelf+Vector2(10,0),shelf+Vector2(20,0),Color("917b58"),1)
		_work_pose(g,"shelves",id,feet,elapsed)

static func draw_reading(g,elapsed: float,offset: Vector2=Vector2.ZERO) -> void:
	FURNITURE.draw_back(g,"chair",FEET.yune+offset)
	_work_pose(g,"reading","yune",FEET.yune+offset,elapsed)
	FURNITURE.draw_front(g,"chair",FEET.yune+offset)
	# The lamp is switched on by Kubby's reaching hand, with light appearing
	# after contact rather than after a dialogue or reward overlay.
	var lamp:=LAMP+offset
	g.draw_rect(Rect2(lamp+Vector2(-8,29),Vector2(18,4)),Color("554a43"))
	g.draw_rect(Rect2(lamp+Vector2(-1,0),Vector2(3,31)),Color("b79862"))
	g.draw_colored_polygon(PackedVector2Array([lamp+Vector2(-12,-12),lamp+Vector2(10,-12),lamp+Vector2(16,1),lamp+Vector2(-18,1)]),Color("ecd69b") if elapsed>=4.5 else Color("7c8580"))
	if elapsed>=4.5:
		g.draw_colored_polygon(PackedVector2Array([lamp+Vector2(-14,2),lamp+Vector2(12,2),lamp+Vector2(29,29),lamp+Vector2(-31,29)]),Color("f1d49332"))
	_work_pose(g,"reading","kubby",FEET.kubby+offset,elapsed)

static func _crate(g,p: Vector2) -> void:
	p=p.round()
	var left:=p.x-51
	var top:=p.y-36
	g.draw_rect(Rect2(left-2,top+9,106,26),Color("483a33"))
	g.draw_rect(Rect2(left,top+11,102,23),Color("a17851"))
	for i in range(3):
		var y:=top+11+i*8
		g.draw_rect(Rect2(left+2,y,98,7),Color("b48c60") if i%2==0 else Color("98734d"))
		for x in range(4,95,13):
			g.draw_rect(Rect2(left+x,y+3+(x%3),7,1),Color("79583e"))
			g.draw_rect(Rect2(left+x+2,y+1,4,1),Color("d2ae7c"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(left,top+9),Vector2(left+9,top),Vector2(left+94,top),Vector2(left+102,top+9)]),Color("d3b082"))
	for x in [left+16,left+82]:
		g.draw_rect(Rect2(x,top+9,5,25),Color("665e52"))
		g.draw_rect(Rect2(x+1,top+9,2,24),Color("a6a18c"))
		for y in [top+13,top+29]:g.draw_rect(Rect2(x+1,y,2,2),Color("d5c8a0"))
	g.draw_rect(Rect2(left+29,top-7,43,16),Color("666a66"))
	g.draw_rect(Rect2(left+31,top-8,39,13),Color("bfc0a6"))
	for x in [left+37,left+46,left+62]:g.draw_rect(Rect2(x,top-6,2,13),Color("929782"))
	g.draw_rect(Rect2(left+5,top-8,21,8),Color("6b5250"))
	g.draw_rect(Rect2(left+7,top-6,17,4),Color("dfcca7"))
	g.draw_rect(Rect2(left+9,top-13,18,5),Color("668377"))
	for x in [left-4,left+99]:
		g.draw_rect(Rect2(x,top+15,7,8),Color("4f4842"))
		g.draw_rect(Rect2(x+1,top+16,5,3),Color("c1ab81"))
