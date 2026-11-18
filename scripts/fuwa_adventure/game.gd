extends Node2D

# Entirely isolated scene: no State, Main, save, mission or campaign imports.
const Field=preload("res://scripts/field_sprites.gd")
const Fans=preload("res://scripts/fan_forms.gd")
const Yard=preload("res://scripts/yard_sprites.gd")
const Interactions=preload("res://scripts/stella_interactions.gd")
const Pixels=preload("res://scripts/library_pixels.gd")
const World=preload("res://scripts/world_pixels.gd")
const Art=preload("res://scripts/fuwa_adventure/art.gd")
const ReturnFlow=preload("res://scripts/fuwa_adventure/return_flow.gd")
const Markers=preload("res://scripts/story_markers.gd")
const COSTUME:="hakuten_fuwa_idle"
const MAP_SIZE:=Vector2(904,578)
const WORLD_SCALE:=1.6
const CELL:=16.0
const SPEED:=116.0
const PASS:=Vector2(615,205)
const START:=Vector2(220,482)
const TENBI_SPOTS:=[Vector2(666,285),Vector2(712,391),Vector2(500,214)]
const CORRIDOR:=[Vector2(220,495),Vector2(310,440),Vector2(400,360),Vector2(500,310),Vector2(620,205)]
const CLEARING:=[Vector2(120,510),Vector2(90,375),Vector2(140,265),Vector2(270,165),Vector2(455,125),Vector2(620,155),Vector2(780,270),Vector2(795,410),Vector2(720,485),Vector2(500,530),Vector2(280,540)]
const RESTART:=Rect2(1060,19,190,37)
const HELP:=Rect2(900,19,148,37)
const RESUME:=Rect2(470,460,340,52)
var WORLD_OFFSET: Vector2:
	get: return (Vector2(640,448)-player_pos*WORLD_SCALE).clamp(Vector2(1280,800)-MAP_SIZE*WORLD_SCALE,Vector2.ZERO).round()
var in_world:=true
var mode:="chapter"
var clock:=0.0
var zone:=0
var phase:="search"
var player_pos:=START
var checkpoint:=START
var facing:="up"
var distance:=0.0
var moving:=false
var observing:=false
var paused:=false
var pause_on_focus_loss:=true
var assist:=false
var held: Dictionary={}
var route:=PackedVector2Array()
var pending:=""
var nav:=AStarGrid2D.new()
var rocks: Array=[]
var ghosts: Array=[]
var exposure:=0.0
var protection:=0.0
var setbacks:=0
var discovered:=false
var tenbi:=TENBI_SPOTS[0]
var encounter:=0
var reunion_age:=0.0
var reunion_from:=Vector2.ZERO
var notice:="텐비가 보이지 않아. 눈산 안쪽을 찾아보자."
var notice_left:=5.0
var transition:=0.0
var font:=preload("res://scripts/game_font.gd").create()
var walk_texture: CanvasTexture
var seen_directions: Dictionary={}
var return_flow:=ReturnFlow.new()

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font.font_names=PackedStringArray(["Malgun Gothic","맑은 고딕"])
	get_window().title="루체테 · 후와 직접 조작 시안 · 눈산에서 도서관까지"
	get_window().min_size=Vector2i.ZERO if OS.has_feature("web") else Vector2i(960,600)
	walk_texture=CanvasTexture.new();walk_texture.diffuse_texture=Yard.SHEETS.walk
	walk_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	reset()
	if OS.get_cmdline_user_args().has("--fuwa-return-preview"): start_return_preview()

func start_return_preview() -> void:
	reset();zone=1;setup_zone();discovered=true
	player_pos=tenbi+Vector2(-52,8);facing="right";notice_left=0
	return_flow.enter(self,"return_ready")

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		held.clear();observing=false;route.clear();pending=""
		if pause_on_focus_loss: paused=true

func reset() -> void:
	return_flow.reset()
	clock=0;zone=0;phase="search";player_pos=START;checkpoint=START
	facing="up";distance=0;moving=false;observing=false;paused=false
	held.clear();route.clear();pending="";exposure=0;protection=0;setbacks=0
	discovered=false;tenbi=TENBI_SPOTS[encounter%TENBI_SPOTS.size()]
	reunion_age=0;transition=0;seen_directions.clear()
	notice="텐비가 보이지 않아. 눈산 안쪽을 찾아보자.";notice_left=5
	setup_zone();queue_redraw()

func setup_zone() -> void:
	if zone==0:
		rocks=[{"p":Vector2(345,382),"r":Vector2(31,22)},{"p":Vector2(540,265),"r":Vector2(32,23)}]
		ghosts=[{"a":Vector2(425,325),"b":Vector2(505,353),"period":7.0,"shift":0.0,"radius":73.0}]
	elif zone==1:
		rocks=[{"p":Vector2(375,345),"r":Vector2(37,23)},{"p":Vector2(575,350),"r":Vector2(33,22)},{"p":Vector2(685,208),"r":Vector2(40,24)}]
		ghosts=[{"a":Vector2(462,310),"b":Vector2(558,410),"period":9.0,"shift":1.8,"radius":67.0}]
	else:
		rocks.clear();ghosts.clear()
	nav.region=Rect2i(0,0,57,37);nav.cell_size=Vector2.ONE*CELL
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for y in range(37):
		for x in range(57):
			var cell:=Vector2i(x,y)
			nav.set_point_solid(cell,not walkable(Vector2(cell)*CELL))

func walkable(p: Vector2) -> bool:
	if zone==2: return ReturnFlow.LIBRARY_FLOOR.has_point(p)
	if not Rect2(24,110,856,430).has_point(p): return false
	if zone==0:
		var on_path:=false
		for i in range(CORRIDOR.size()-1):
			if Geometry2D.get_closest_point_to_segment(p,CORRIDOR[i],CORRIDOR[i+1]).distance_to(p)<69: on_path=true;break
		if not on_path: return false
	elif not Geometry2D.is_point_in_polygon(p,PackedVector2Array(CLEARING)): return false
	for rock in rocks:
		if ((p-rock.p)/Vector2(rock.r.x+8,rock.r.y*.62+8)).length()<1: return false
	return true

func node_for(p: Vector2) -> Vector2i:
	var center:=Vector2i((p/CELL).round())
	for ring in range(5):
		var closest:=Vector2i(-1,-1);var nearest:=INF
		for y in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				var cell:=center+Vector2i(x,y)
				if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
					var d:=p.distance_squared_to(Vector2(cell)*CELL)
					if d<nearest: closest=cell;nearest=d
		if closest.x>=0: return closest
	return Vector2i(-1,-1)

func segment_clear(a: Vector2,b: Vector2) -> bool:
	var steps:=maxi(1,ceili(a.distance_to(b)/6))
	for i in range(steps+1):
		if not walkable(a.lerp(b,float(i)/steps)): return false
	return true

func set_destination(p: Vector2,action: String="") -> bool:
	if phase not in ["search","arrived"] or paused: return false
	if not walkable(p):
		say("서가 앞의 빈 바닥을 둘러보자." if zone==2 else "바위와 눈벽 사이의 열린 길로 가자.",2);return false
	var start:=node_for(player_pos);var end:=node_for(p)
	if start.x<0 or end.x<0: return false
	var path:=nav.get_point_path(start,end)
	if path.is_empty(): return false
	route.clear();pending=action
	for point in path:
		if point.distance_to(player_pos)>6: route.append(point)
	if route.is_empty() or route[-1].distance_to(p)>1: route.append(p)
	# Smooth valid terrain segments only. Mouse routes never avoid yokai for you.
	var from:=player_pos;var smooth:=PackedVector2Array();var i:=0
	while i<route.size():
		var last:=i
		while last+1<route.size() and segment_clear(from,route[last+1]): last+=1
		smooth.append(route[last]);from=route[last];i=last+1
	route=smooth
	return true

func ghost_position(index: int) -> Vector2:
	var ghost: Dictionary=ghosts[index]
	var t: float=fposmod(clock/(1.25 if assist else 1.0)+ghost.shift,ghost.period)/ghost.period
	return ghost.a.lerp(ghost.b,smoothstep(0,1,t*2 if t<.5 else (1-t)*2))

func sheltered_from(source: Vector2,p: Vector2) -> bool:
	for rock in rocks:
		var foot: Vector2=Geometry2D.get_closest_point_to_segment(rock.p,source,p)
		if foot.distance_to(rock.p)<rock.r.x*.9 and source.distance_to(foot)<source.distance_to(p)-6: return true
	return false

func threatened() -> bool:
	for i in range(ghosts.size()):
		var p:=ghost_position(i)
		if p.distance_to(player_pos)<ghosts[i].radius and not sheltered_from(p,player_pos): return true
	return false

func wind_strength() -> float:
	return smoothstep(.15,.85,.5+.5*sin(clock*.8))

func tenbi_visible() -> bool:
	if zone==2: return true
	if zone!=1: return false
	return discovered or player_pos.distance_to(tenbi)<80 or (wind_strength()<.55 and (observing or player_pos.distance_to(tenbi)<220))

func say(line: String,seconds: float=3.0) -> void:
	notice=line;notice_left=seconds

func enter_clearing() -> void:
	zone=1;player_pos=Vector2(210,476);checkpoint=player_pos;facing="up"
	route.clear();pending="";exposure=0;protection=2.0;transition=.6
	setup_zone();say("공터다. 눈발이 잦아들 때 주변을 살펴보자.",4)

func retreat() -> void:
	setbacks+=1;player_pos=checkpoint;route.clear();pending="";exposure=0
	protection=2.0;held.clear();observing=false;moving=false
	say("기척이 가까워졌어. 안전한 자리에서 다시 살펴보자.",3)

func interact() -> void:
	if phase in ReturnFlow.STAGES: return_flow.interact(self);return
	if phase!="search" or paused: return
	if zone==0 and player_pos.distance_to(PASS)<65: enter_clearing();return
	if zone==1 and player_pos.distance_to(tenbi)<66 and tenbi_visible():
		discovered=true;phase="reunion";reunion_from=player_pos;reunion_age=0
		route.clear();pending="";held.clear();observing=false;moving=false;exposure=0
		say("텐비, 여기 있었구나.",5);return
	if zone==1: say("잠깐 멈추고 E를 누른 채 주변을 살펴보자.",2)
	else: say("기척의 움직임을 보고 바위 뒤에서 다음 길로 가자.",2)

func _process(dt: float) -> void:
	advance(minf(dt,.05));queue_redraw()

func advance(dt: float) -> void:
	if paused: moving=false;return
	clock+=dt;notice_left=maxf(0,notice_left-dt);transition=maxf(0,transition-dt)
	protection=maxf(0,protection-dt)
	if phase=="reunion":
		reunion_age+=dt
		var target:=tenbi+Vector2(-52,8)
		var before:=player_pos
		player_pos=reunion_from.lerp(target,smoothstep(0,1.4,reunion_age))
		moving=before.distance_to(player_pos)>.01;distance+=before.distance_to(player_pos)
		facing="right"
		if reunion_age>=2.0: return_flow.enter(self,"return_ready")
		return
	if return_flow.update(self,dt): return
	observing=phase=="search" and bool(held.get(KEY_E,false))
	var axis:=Vector2(float(held.get(KEY_D,false) or held.get(KEY_RIGHT,false))-float(held.get(KEY_A,false) or held.get(KEY_LEFT,false)),float(held.get(KEY_S,false) or held.get(KEY_DOWN,false))-float(held.get(KEY_W,false) or held.get(KEY_UP,false)))
	if axis.length_squared()>0: route.clear();pending="";axis=axis.normalized()
	elif not route.is_empty():
		while not route.is_empty() and player_pos.distance_to(route[0])<4: route.remove_at(0)
		if not route.is_empty(): axis=(route[0]-player_pos).normalized()
	if observing: axis=Vector2.ZERO
	var before:=player_pos
	if axis!=Vector2.ZERO:
		var step:=axis*SPEED*dt
		if not route.is_empty() and step.length()>player_pos.distance_to(route[0]): step=route[0]-player_pos
		if walkable(player_pos+Vector2(step.x,0)): player_pos.x+=step.x
		if walkable(player_pos+Vector2(0,step.y)): player_pos.y+=step.y
		if before.distance_to(player_pos)<.001 and not route.is_empty(): route.clear();pending="";say("열린 길 쪽으로 조금 돌아가자.",2)
	moving=before.distance_to(player_pos)>.001
	distance+=before.distance_to(player_pos)
	if moving:
		facing=Field.direction_for(axis*10,facing);seen_directions[facing]=true
	var danger:=threatened() and protection<=0
	exposure=move_toward(exposure,1.0 if danger else 0.0,dt/(2.0 if assist else 1.25) if danger else dt*1.7)
	if exposure>=1: retreat();return
	if zone==0 and player_pos.distance_to(Vector2(345,426))<45 and not danger: checkpoint=Vector2(315,438)
	if zone==1 and player_pos.distance_to(Vector2(348,395))<32 and not danger: checkpoint=Vector2(330,405)
	if zone==1 and observing and tenbi_visible() and player_pos.distance_to(tenbi)<235 and not discovered:
		discovered=true;say("텐비다! 가까이 가 보자.",4)
	if route.is_empty() and pending!="":
		var action:=pending;pending=""
		if action=="pass" and player_pos.distance_to(PASS)<65: enter_clearing()
		elif action=="tenbi": interact()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: int=event.physical_keycode if event.physical_keycode else event.keycode
		if event.pressed and not event.echo:
			if code==KEY_ESCAPE:
				paused=not paused;held.clear();route.clear();pending="";observing=false;queue_redraw();return
			if code==KEY_R: encounter+=1;reset();return
			if code==KEY_F1: assist=not assist;queue_redraw();return
			if code==KEY_F11:
				get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN;return
			if code==KEY_E and not paused: interact()
		if code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_E]:
			held[code]=event.pressed and not paused
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var p: Vector2=event.position
		if RESTART.has_point(p): encounter+=1;reset();return
		if HELP.has_point(p): assist=not assist;return
		if paused:
			if RESUME.has_point(p): paused=false
			return
		if phase=="return_ready" and ReturnFlow.ACTION.has_point(p): return_flow.interact(self);return
		if p.y>=95 and p.y<=734:
			for marker in story_markers():
				if Markers.hit(font,screen_world(marker.point),marker.label,p):
					activate_marker(marker.action);return
		if p.y<95 or p.y>(630 if phase=="arrived" else 734) or phase not in ["search","arrived"]: return
		var target: Vector2=(p-WORLD_OFFSET)/WORLD_SCALE
		if zone==0 and target.distance_to(PASS)<46: set_destination(PASS,"pass")
		elif zone==1 and tenbi_visible() and Rect2(tenbi-Vector2(30,65),Vector2(60,80)).has_point(target): set_destination(tenbi+Vector2(-45,10),"tenbi")
		else: set_destination(target)

func draw_ellipse_shadow(p: Vector2,size: Vector2) -> void:
	Field.Finish.contact(self,p,size)

func draw_fuwa() -> void:
	if return_flow.draw_pose(self): return
	if phase=="return_ready":
		Interactions.draw(self,"fuwa","welcome",player_pos,Interactions.Samples.gesture(Interactions.definition("fuwa","welcome").durations,return_flow.elapsed),COSTUME)
	elif observing and facing=="down": Interactions.draw(self,"fuwa","focus",player_pos,8,COSTUME)
	elif facing!="down": Field.draw_stella_turn(self,"fuwa",COSTUME,player_pos,facing,moving,distance)
	elif not moving: Field.draw(self,COSTUME,player_pos,Field.STELLA_HEIGHT)
	else:
		var frame:=floori(distance/Field.STRIDE_DISTANCE*72)%72
		var cell:=Vector2i(frame%36,Field.COSTUMES.find(COSTUME)*2+frame/36)
		draw_ellipse_shadow(player_pos+Vector2(0,3),Vector2(24,6))
		Field.Finish.cel(self,walk_texture,Rect2(Field.origin(self,player_pos,Field.STELLA_SCALE),Vector2(Field.CELL)*Field.STELLA_SCALE),Rect2(Vector2(cell*Field.CELL),Vector2(Field.CELL)))

func text_at(p: Vector2,line: String,size: int=20,color: Color=Color("f5ecd7")) -> void:
	draw_string(font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func screen_world(p: Vector2) -> Vector2: return (WORLD_OFFSET+p*WORLD_SCALE).round()

func story_markers() -> Array:
	if paused: return []
	if phase=="return_ready": return [{"action":"spell","point":return_flow.spell_center(self),"label":"귀환술 쓰기"}]
	if phase!="search": return []
	if zone==0: return [{"action":"pass","point":PASS,"label":"고개 너머로"}]
	# Never expose Tenbi's hidden position before she is actually visible.
	if zone==1 and tenbi_visible(): return [{"action":"tenbi","point":tenbi,"label":"텐비에게 다가가기"}]
	return []

func activate_marker(action: String) -> void:
	match action:
		"pass": set_destination(PASS,"pass")
		"tenbi": set_destination(tenbi+Vector2(-45,10),"tenbi")
		"spell": return_flow.interact(self)

func _draw() -> void:
	in_world=true;draw_set_transform(WORLD_OFFSET,0,Vector2.ONE*WORLD_SCALE)
	if zone==2: return_flow.draw_library(self)
	else: draw_texture_rect(World.texture("story_fuwa_1" if zone==0 else "story_fuwa_2"),Rect2(Vector2.ZERO,MAP_SIZE),false)
	if phase=="search":
		for i in range(ghosts.size()): Art.danger(self,ghost_position(i),ghosts[i].radius,exposure)
	for rock in rocks: Art.rock(self,rock.p,rock.r)
	if zone!=2: Art.snow(self,wind_strength())
	return_flow.draw_spell(self);return_flow.draw_rift(self)
	draw_set_transform(Vector2.ZERO)
	for marker in story_markers(): Markers.draw_marker(self,screen_world(marker.point),marker.label)
	draw_set_transform(WORLD_OFFSET,0,Vector2.ONE*WORLD_SCALE)
	var actors: Array=[{"id":"fuwa","p":player_pos}]
	if tenbi_visible(): actors.append({"id":"tenbi","p":tenbi})
	for i in range(ghosts.size()): actors.append({"id":"ghost","p":ghost_position(i),"index":i})
	actors.sort_custom(func(a,b): return a.p.y<b.p.y)
	for actor in actors:
		if actor.id=="fuwa": draw_fuwa()
		elif actor.id=="ghost": Art.yokai(self,actor.p,exposure)
		else:
			draw_ellipse_shadow(tenbi+Vector2(0,2),Vector2(13,3))
			Field.Finish.cel(self,Fans.texture("fuwa"),Rect2(Field.pixel_position(self,tenbi-Vector2(32,58)),Vector2(64,64)),Fans.region_for(Fans.frame_at("fuwa",clock,false),"left"))
	# Actors remain above snow and scenery; no individual body parts are warped.
	in_world=false;draw_set_transform(Vector2.ZERO)
	if transition>0: draw_rect(Rect2(0,0,1280,800),Color(.8,.9,1,transition*.7))
	return_flow.draw_overlay(self)
	draw_hud()
	if paused: draw_pause()

func draw_hud() -> void:
	draw_rect(Rect2(18,14,1244,77),Color("172c42e8"))
	draw_rect(Rect2(18,88,1244,3),Color("90aab8"))
	text_at(Vector2(36,42),return_flow.title(self),23)
	text_at(Vector2(470,40),"조작: 후와   ·   도서관 도착까지의 시안",16,Color("b5d3e5"))
	text_at(Vector2(36,75),goal(),20,Color("fbdfaa"))
	button(HELP,"여유롭게: "+("켜짐" if assist else "꺼짐"))
	button(RESTART,"처음부터  R")
	if notice_left>0 and phase in ["search","arrived"]:
		draw_rect(Rect2(230,101,820,37),Color("183044d9"))
		var width:=font.get_string_size(notice,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		text_at(Vector2(640-width/2,126),notice,18)
	if phase=="search":
		var tip:="WASD / 방향키 · 바닥 클릭: 이동    E 누르고 있기: 멈춰서 살피기    Esc: 쉬기"
		if zone==0 and player_pos.distance_to(PASS)<65: tip="E 또는 고갯길 표시 클릭: 안쪽 공터로 넘어가기"
		elif zone==1 and player_pos.distance_to(tenbi)<66 and tenbi_visible(): tip="E 또는 텐비 클릭: 다가가서 만나기"
		draw_rect(Rect2(18,742,1244,43),Color("172c42ed"));text_at(Vector2(36,770),tip,19)
		if exposure>.04:
			var p:=screen_world(player_pos)+Vector2(-65,16)
			draw_rect(Rect2(p,Vector2(130,8)),Color("272b37"));draw_rect(Rect2(p+Vector2(1,1),Vector2(128*exposure,6)),Color("f0ad81"))
			text_at(p+Vector2(-10,32),"기척이 가까워",17,Color("ffdec0"))
		elif observing:
			var p:=screen_world(player_pos)+Vector2(-44,30)
			text_at(p,"살피는 중",17,Color("203c58"))
		if zone==1 and discovered:
			var p:=screen_world(tenbi)+Vector2(-18,24)
			text_at(p,"텐비",17,Color("233f55"))
	else:
		return_flow.draw_hud(self)

func goal() -> String:
	if phase!="search": return return_flow.goal(self)
	if zone==0: return "요괴의 움직임을 살피며 고개 너머로 가자. 바위 뒤에서는 기척을 피할 수 있어."
	return "텐비에게 다가가자." if discovered else "눈발이 잦아들 때 E를 누르고 공터를 살펴 텐비를 찾자."

func button(rect: Rect2,label: String) -> void:
	draw_rect(rect,Color("304b62"));draw_rect(rect,Color("9db8c3"),false,1)
	text_at(rect.position+Vector2(10,25),label,17)

func draw_pause() -> void:
	draw_rect(Rect2(0,0,1280,800),Color(0.04,.08,.13,.65))
	Pixels.panel(self,Rect2(340,250,600,292),Color("f0dfb6"))
	text_at(Vector2(392,305),"잠깐 쉬기",29,Color("513520"))
	text_at(Vector2(392,352),"후와로 텐비를 찾고 도서관에 도착하는 시안이야.",19,Color("513520"))
	text_at(Vector2(392,386),"기척에 닿아도 가까운 안전 지점에서 다시 시작해.",19,Color("513520"))
	text_at(Vector2(392,420),"F1: 위험 구간을 여유롭게   ·   F11: 전체 화면",18,Color("806047"))
	button(RESUME,"계속하기   Esc")

