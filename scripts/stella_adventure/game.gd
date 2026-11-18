extends Node2D

const Markers=preload("res://scripts/story_markers.gd")
const MARKER_LABELS={
	"disguise":["둔갑 연습하기"],"watch":["돌로 둔갑하기","기척 살피기"],
	"sleep":["둔갑해 기다리기"],"deduce":["에테에게 이야기하기"],
	"birth":["드림캐처 살펴보기"],"dreams":["악몽 먹기","악몽 먹기","악몽 먹기"],
	"fading":["옅어진 꿈빛 건너기"],"follow":["빛 따라가기","빛 따라가기","빛 따라가기"],
	"door":["문 안으로 들어가기"],"workdoor":["일터로 들어가기"],"arrows":["화살 손질하기"],
	"weary":["마지막 화살 손질하기","작업대에서 물러나기"],
	"village":["아랫마을로 가기"],"hamster":["햄스터 살펴보기"],
	"takehome":["햄스터 데려가기","왔던 길로 돌아가기"],
	"nightwalk":["밤길 걷기","밤길 걷기","밤길 걷기"],"meeting":["리스텔라 만나기"],
	"family":["가족에게 인사하기"],"food":["곳간 살펴보기","가족에게 다가가기"],
	"mountain":["산 아래로 가기","산 아래로 가기","마을로 내려가기"],
	"cold":["문 앞에서 말 걸기","문 앞에서 말 걸기"],"light":["마음에 집중하기"]
}

signal arrived
signal checkpoint_changed
signal exit_requested
signal save_requested
const Chapters=preload("res://scripts/stella_adventure/chapters.gd")
const Art=preload("res://scripts/stella_adventure/art.gd")
const Field=preload("res://scripts/field_sprites.gd")
const Yard=preload("res://scripts/yard_sprites.gd")
const Interactions=preload("res://scripts/stella_interactions.gd")
const World=preload("res://scripts/world_pixels.gd")
const Pixels=preload("res://scripts/library_pixels.gd")
const Library=preload("res://scripts/fuwa_adventure/return_flow.gd")
const MAP_SIZE=Vector2(904,578)
const WORLD_SCALE=1.6
const SPEED=130.0
const EXIT=Rect2(1070,20,182,38)
const CONTINUE=Rect2(964,685,270,43)
var member:="dori"
var replay:=false
var completed:=false
var stage:=0
var done:=0
var phase:="play"
var intro:=true
var paused:=false
var pause_on_focus_loss:=true
var player_pos:=Vector2(230,460)
var facing:="up"
var moving:=false
var distance:=0.0
var clock:=0.0
var age:=0.0
var charge:=0.0
var stone:=false
var working:=false
var action:=""
var action_age:=0.0
var action_from:=Vector2.ZERO
var held: Dictionary={}
var route:=PackedVector2Array()
var pending:=false
var nav:=AStarGrid2D.new()
var notice:=""
var notice_left:=0.0
var dragging:=false
var last_pointer:=Vector2.ZERO
var in_world:=false
var mode:="chapter"
var font:=preload("res://scripts/game_font.gd").create()
var walk_texture: CanvasTexture
var library_art:=Library.new()
var WORLD_OFFSET: Vector2:
	get: return (Vector2(640,448)-player_pos*WORLD_SCALE).clamp(Vector2(1280,800)-MAP_SIZE*WORLD_SCALE,Vector2.ZERO).round()

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font.font_names=PackedStringArray(["Malgun Gothic","맑은 고딕"])
	walk_texture=CanvasTexture.new();walk_texture.diffuse_texture=Yard.SHEETS.walk
	walk_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false);set_process_unhandled_input(false)
	setup_nav()

func entry() -> Array: return Chapters.CHAPTERS[member][stage]
func kind() -> String: return entry()[2]
func points() -> Array: return entry()[5]
func costume() -> String: return Chapters.COSTUMES[member]
func screen_world(p: Vector2) -> Vector2: return (WORLD_OFFSET+p*WORLD_SCALE).round()
func say(line: String,seconds: float=4.0) -> void: notice=line;notice_left=seconds
func snapshot() -> Dictionary:
	return {"version":1,"stage":stage,"done":done,"x":player_pos.x,"y":player_pos.y,"clock":clock,"phase":phase,"intro":intro}
func restore_snapshot(raw: Dictionary) -> void:
	var saved:=Chapters.clean(member,raw)
	stage=0;done=0;phase="play";player_pos=Vector2(230,460);intro=true;clock=0
	if not saved.is_empty():
		stage=saved.stage;done=saved.done;phase=saved.phase;intro=saved.intro;clock=saved.clock
		player_pos=Vector2(saved.x,saved.y)
	age=0;charge=0;stone=false;working=false;action="";action_age=0;completed=false
	held.clear();route.clear();pending=false;paused=false
	setup_nav()
	if not walkable(player_pos): player_pos=Vector2(230,460)
	# Completed ending snapshots replay the arrival before acknowledging it.
	if phase=="arrived": phase="play";intro=false

func enter_stage(next: int) -> void:
	var previous_record: int=entry()[1]
	stage=next;done=0;charge=0;age=0;action="";action_age=0;stone=false;working=false
	held.clear();route.clear();pending=false;moving=false;dragging=false
	intro=entry()[1]!=previous_record or kind()=="ending"
	player_pos=Vector2(230,460);facing="up"
	if kind() in ["carry","punishment"]: player_pos=Vector2(535,365)
	setup_nav();checkpoint_changed.emit();queue_redraw()
func next_stage() -> void: enter_stage(stage+1)
func mark(index: int) -> void:
	done|=1<<index;charge=0;checkpoint_changed.emit()
func has_mark(index: int) -> bool: return (done&(1<<index))!=0
func target(index: int) -> Vector2:
	var p: Vector2=points()[index]
	if kind()=="dreams": p+=Vector2(sin(clock*.65+index*2)*25,cos(clock*.5+index)*13)
	return p
func nearest() -> int:
	var index:=-1;var best:=INF
	for i in range(points().size()):
		if has_mark(i): continue
		if kind() in ["follow","nightwalk","mountain","takehome","food","weary"] and i>0 and not has_mark(i-1): continue
		var d:=player_pos.distance_to(target(i))
		if d<best: best=d;index=i
	return index
func near(index: int,radius: float=58.0) -> bool:
	return index>=0 and player_pos.distance_to(target(index))<radius

func story_markers() -> Array:
	if intro or paused or phase!="play" or not action.is_empty(): return []
	# A completed stakeout still needs an explicit release before Dori can walk.
	if stone: return [{"index":-1,"point":player_pos,"label":"둔갑 풀기"}]
	var markers: Array=[]
	for i in range(points().size()):
		# Arrow marks are parts of one arrow, not three separate floor targets.
		if kind()!="arrows" and has_mark(i): continue
		if kind() in ["follow","nightwalk","mountain","food","takehome","weary"] and i!=nearest(): continue
		markers.append({"index":i,"point":target(i),"label":MARKER_LABELS[kind()][i]})
	return markers

func activate_marker(index: int) -> void:
	if index<0: interact();return
	if stone: interact()
	if near(index):
		interact()
		if kind() in ["dreams","light"]: working=true
	else: set_destination(target(index),true)

func walkable(p: Vector2) -> bool:
	# Authored central floors: scenery is kept outside the actor path. Props use
	# approach feet in front of them, so click routing never enters their bodies.
	if not Rect2(170,215,560,310).has_point(p): return false
	if kind()=="mountain":
		var path: Array=[Vector2(230,460)]+points()
		for i in range(path.size()-1):
			if Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1]).distance_to(p)<65: return true
		return false
	if kind() in ["arrows","weary"] and Rect2(360,260,180,58).has_point(p): return false
	return true
func setup_nav() -> void:
	nav.region=Rect2i(0,0,57,37);nav.cell_size=Vector2(16,16)
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;nav.update()
	for y in range(37):
		for x in range(57): nav.set_point_solid(Vector2i(x,y),not walkable(Vector2(x,y)*16))
func node_for(p: Vector2) -> Vector2i:
	var center:=Vector2i((p/16).round())
	for ring in range(6):
		var best:=Vector2i(-1,-1);var distance_to_cell:=INF
		for y in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				var cell:=center+Vector2i(x,y)
				if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
					var d:=p.distance_squared_to(Vector2(cell)*16)
					if d<distance_to_cell: distance_to_cell=d;best=cell
		if best.x>=0: return best
	return Vector2i(-1,-1)
func set_destination(p: Vector2,interacting: bool=false) -> bool:
	if paused or intro or phase!="play" or not action.is_empty() or stone: return false
	if not walkable(p): say("열린 바닥으로 이동해 보자.",2);return false
	var a:=node_for(player_pos);var b:=node_for(p)
	if a.x<0 or b.x<0: return false
	var path:=nav.get_point_path(a,b)
	if path.is_empty(): return false
	route=path;route.append(p);pending=interacting;working=false;dragging=false
	return true

func begin_action(id: String) -> void:
	action=id;action_age=0;action_from=player_pos;route.clear();pending=false;moving=false;held.clear()
	notice_left=0
func interact() -> void:
	if paused: return
	if intro: intro=false;held.clear();checkpoint_changed.emit();return
	if phase=="arrived": exit_requested.emit();return
	if not action.is_empty(): return
	var index:=nearest()
	match kind():
		"called": next_stage()
		"disguise":
			if near(index): stone=true;begin_action("practice")
		"watch","sleep":
			if stone: stone=false;charge=0
			elif near(index): stone=true;route.clear();pending=false;charge=0
			else: say("표시된 잠복 자리까지 먼저 걸어가자.")
		"arrows","weary":
			if near(0) and (kind()=="arrows" or not has_mark(0)): working=true;route.clear();pending=false;facing="down"
		"dreams","light":
			if near(index,82): working=true;route.clear();pending=false
		"food":
			if near(index):
				if index==0: begin_action("uncover")
				else: begin_action("confession")
		"takehome":
			if near(0) and not has_mark(0): mark(0);say("햄스터를 데려왔다. 왔던 길로 돌아가자.")
		"cold":
			if near(index): mark(index);say("다가갔지만, 반응은 차가웠다.",3)
		_: 
			if near(index) and kind() not in ["follow","nightwalk","mountain","fading","hamster"]:
				begin_action("deduce" if kind()=="deduce" else "greet")

func advance(dt: float) -> void:
	if paused: moving=false;return
	clock+=dt;notice_left=maxf(0,notice_left-dt)
	if intro: return
	age+=dt
	if phase=="arrived": return
	if kind()=="ending":
		if age>=4.0: phase="arrived";arrived.emit()
		return
	if kind() in ["carry","punishment"]:
		if age>=6: next_stage()
		return
	if not action.is_empty():
		action_age+=dt
		if action=="flinch": player_pos=action_from+Vector2(-12*smoothstep(0,.25,action_age),0)
		if action_age>= (3.2 if action in ["confession","deduce"] else 1.8):
			if action=="uncover": action="";mark(0);say("바구니에 남은 식량이 적다. 가족에게 가 보자.")
			else: next_stage()
		return
	var axis:=Vector2(float(held.get(KEY_D,false) or held.get(KEY_RIGHT,false))-float(held.get(KEY_A,false) or held.get(KEY_LEFT,false)),float(held.get(KEY_S,false) or held.get(KEY_DOWN,false))-float(held.get(KEY_W,false) or held.get(KEY_UP,false)))
	if axis!=Vector2.ZERO:
		route.clear();pending=false;working=false;dragging=false
		axis=axis.normalized()
	elif not route.is_empty():
		while not route.is_empty() and player_pos.distance_to(route[0])<3: route.remove_at(0)
		if not route.is_empty(): axis=(route[0]-player_pos).normalized()
	if stone or working: axis=Vector2.ZERO
	var before:=player_pos
	var step:=axis*SPEED*dt*(.72 if kind()=="fading" else 1.0)
	if not route.is_empty() and step.length()>player_pos.distance_to(route[0]): step=route[0]-player_pos
	if walkable(player_pos+Vector2(step.x,0)): player_pos.x+=step.x
	if walkable(player_pos+Vector2(0,step.y)): player_pos.y+=step.y
	moving=before.distance_to(player_pos)>.001;distance+=before.distance_to(player_pos)
	if moving: facing=Field.direction_for(axis*10,facing)
	if not route.is_empty() and axis!=Vector2.ZERO and not moving and not stone and not working:
		route.clear();pending=false;say("가구 앞의 열린 바닥으로 돌아가자.",2)
	if route.is_empty() and pending: pending=false;interact()
	var index:=nearest()
	match kind():
		"watch","sleep":
			if stone and near(index):
				charge+=dt
				if charge>=2.5:
					if kind()=="sleep": next_stage();return
					mark(index);say("이쪽을 살폈다. E로 둔갑을 풀고 다음 자리를 살펴보자.")
			if kind()=="watch" and done==3 and not stone: next_stage()
		"dreams":
			if near(index,82) and (held.get(KEY_E,false) or working) and not moving:
				charge+=dt;facing="down"
				if charge>=1.8: mark(index);working=false;say("악몽을 먹었다. 좋은 꿈의 빛이 남는다.")
			else: charge=maxf(0,charge-dt*.3)
			if done==7: next_stage()
		"arrows","weary":
			if working and held.get(KEY_E,false): polish(dt*.65)
			if kind()=="weary" and has_mark(0) and near(1): next_stage()
		"fading":
			if near(0): next_stage()
		"follow","nightwalk","mountain":
			if near(index,30): mark(index)
			if done==7: next_stage()
		"hamster":
			if near(0,83): begin_action("flinch")
		"takehome":
			if has_mark(0) and near(1,36): next_stage()
		"cold":
			if done==3 and notice_left<=0: next_stage()
		"light":
			if near(0) and (held.get(KEY_E,false) or working):
				charge+=dt
				if charge>=3.2: next_stage()
	queue_redraw()

func polish(amount: float) -> void:
	if not working or kind() not in ["arrows","weary"] or (kind()=="weary" and has_mark(0)): return
	charge=minf(1,charge+amount)
	if charge>=1:
		if kind()=="weary": mark(0);working=false;say("손질은 끝났다. 작업대에서 조금 물러나자.");return
		# Three parts of the same arrow: shaft, left feather, right feather.
		var bit:=0
		while has_mark(bit): bit+=1
		mark(bit)
		if done==7: next_stage()
		else: say("다음 부분도 같은 화살 위에서 손질해 보자.",2)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_controls()
		if pause_on_focus_loss: paused=true
func clear_controls() -> void:
	held.clear();route.clear();pending=false;dragging=false;working=false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if event.pressed and not event.echo:
			if key==KEY_Q: exit_requested.emit();return
			if key==KEY_F5: save_requested.emit();return
			if key==KEY_ESCAPE: paused=not paused;clear_controls();return
			if key==KEY_F11: get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN;return
			if key==KEY_E and not paused: interact()
		if key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_E]: held[key]=event.pressed and not paused
		if key==KEY_E and not event.pressed and kind() in ["dreams","light"]: working=false
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed: dragging=false;return
		var p: Vector2=event.position
		if EXIT.has_point(p): exit_requested.emit();return
		if paused: return
		if (intro or phase=="arrived" or kind()=="called") and CONTINUE.has_point(p): interact();return
		if intro or phase=="arrived" or not action.is_empty() or p.y<96 or p.y>735: return
		var world_p: Vector2=(p-WORLD_OFFSET)/WORLD_SCALE
		if working and kind() in ["arrows","weary"] and Rect2(370,260,160,55).has_point(world_p):
			dragging=true;last_pointer=world_p;return
		if stone: interact();return
		for marker in story_markers():
			if Markers.hit(font,screen_world(marker.point),marker.label,p) or world_p.distance_to(marker.point)<65:
				activate_marker(marker.index)
				return
		set_destination(world_p)
	elif event is InputEventMouseMotion and dragging and not paused:
		var p: Vector2=(event.position-WORLD_OFFSET)/WORLD_SCALE
		if Rect2(370,260,160,55).has_point(p): polish(minf(p.distance_to(last_pointer),18)/160.0)
		last_pointer=p

func draw_ellipse_shadow(p: Vector2,size: Vector2) -> void: Field.Finish.contact(self,p,size)
func draw_actor() -> void:
	if action=="confession": return # The authored full-body shock cel is drawn once.
	if stone or kind()=="carry": Art.stone(self,player_pos);return
	var gesture:=""
	if action in ["flinch","confession"]: gesture="startled"
	elif working or charge>0 or action=="deduce": gesture={"dori":"inspect","yune":"dreamy","danming":"ponder","kubby":"curious","yato":"curious"}[member]
	if not gesture.is_empty() and not Interactions.definition(member,gesture).is_empty():
		var definition:=Interactions.definition(member,gesture)
		var elapsed: float=action_age if not action.is_empty() else fmod(clock,Interactions.duration(member,gesture))
		Interactions.draw(self,member,gesture,player_pos,Interactions.Samples.gesture(definition.durations,elapsed,definition.travel_seconds),costume());return
	var tint:=Color.WHITE
	if kind()=="punishment" and age<2.5: tint=Color(.2,.25,.4,1)
	if facing!="down": Field.draw_stella_turn(self,member,costume(),player_pos,facing,moving,distance,tint)
	elif not moving: Field.draw(self,costume(),player_pos,Field.STELLA_HEIGHT,tint)
	else:
		var frame:=floori(distance/Field.STRIDE_DISTANCE*72)%72
		var cell:=Vector2i(frame%36,Field.COSTUMES.find(costume())*2+frame/36)
		draw_ellipse_shadow(player_pos+Vector2(0,3),Vector2(24,6))
		Field.Finish.cel(self,walk_texture,Rect2(Field.origin(self,player_pos,Field.STELLA_SCALE),Vector2(Field.CELL)*Field.STELLA_SCALE),Rect2(Vector2(cell*Field.CELL),Vector2(Field.CELL)),tint)
func text_at(p: Vector2,line: String,size: int=20,color: Color=Color("f5ecd7")) -> void:
	draw_string(font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func wrap_text(p: Vector2,line: String,width: float,size: int,color: Color) -> void:
	var buffer:="";var row:=0
	for ch in line:
		if font.get_string_size(buffer+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			text_at(p+Vector2(0,row*(size+10)),buffer,size,color);row+=1;buffer=""
		buffer+=ch
	text_at(p+Vector2(0,row*(size+10)),buffer,size,color)
func button(rect: Rect2,label: String) -> void:
	draw_rect(rect,Color("304b62"));draw_rect(rect,Color("9db8c3"),false,1);text_at(rect.position+Vector2(12,26),label,17)
func _draw() -> void:
	in_world=true;draw_set_transform(WORLD_OFFSET,0,Vector2.ONE*WORLD_SCALE)
	var in_library:=kind() in ["deduce","ending"]
	if in_library: library_art.draw_library(self)
	else:
		var background: String=Field.Finish.PLATES.get(member+":"+str(entry()[0]),"story_%s_%d"%[member,entry()[0]])
		if kind()=="mountain": background="yato_mountain"
		draw_texture_rect(World.texture(background),Rect2(Vector2.ZERO,MAP_SIZE),false)
	Art.scenery(self)
	# Markers sit above the background, below whole actors and the HUD.
	draw_set_transform(Vector2.ZERO)
	for marker in story_markers(): Markers.draw_marker(self,screen_world(marker.point),marker.label)
	draw_set_transform(WORLD_OFFSET,0,Vector2.ONE*WORLD_SCALE)
	if not (kind()=="carry" and age>2.5): draw_actor()
	Art.foreground(self)
	in_world=false;draw_set_transform(Vector2.ZERO)
	if kind()=="ending" and not intro and phase!="arrived": draw_rect(Rect2(0,0,1280,800),Color(0,0,0,1.0-smoothstep(0,1.8,age)))
	draw_rect(Rect2(18,14,1244,77),Color("172c42eb"));draw_rect(Rect2(18,88,1244,3),Color("90aab8"))
	text_at(Vector2(36,42),entry()[3],23)
	text_at(Vector2(620,40),Chapters.NAMES[member]+" 직접 조작"+(" · 재체험" if replay else ""),17,Color("b5d3e5"))
	text_at(Vector2(36,75),entry()[4],19,Color("fbdfaa"));button(EXIT,"책 덮기   Q")
	if intro or phase=="arrived":
		Pixels.panel(self,Rect2(46,598,1188,134),Color("f0dfb6"))
		var line: String=Chapters.RECORDS.data.books[member].records[entry()[1]]
		if phase=="arrived": line=Chapters.NAMES[member]+("의 이야기를 다시 마쳤다. 도서관으로 돌아가자." if replay else "가 루체테에 합류했다. 에테에게서 팬 모습으로 변신할 수 있다.")
		wrap_text(Vector2(70,630),line,1115,20,Color("513520"))
		if member=="yato" and kind()=="ending": text_at(Vector2(70,707),"빛이 난 뒤 도서관으로 이어지는 장면은 팬게임의 연결입니다.",16,Color("806047"))
		button(CONTINUE,"도서관으로   E" if phase=="arrived" else "이야기 이어가기   E")
	elif kind()=="called":
		button(CONTINUE,"부름 따라가기   E")
	elif notice_left>0:
		draw_rect(Rect2(110,650,1060,70),Color("172c42ed"));wrap_text(Vector2(132,679),notice,1000,19,Color("f5ecd7"))
	var hint:="WASD / 방향키 · 바닥 클릭: 이동    E: 가까운 대상과 행동    F5: 저장    Esc: 쉬기"
	if stone: hint="E 또는 클릭: 둔갑 풀기    돌이 된 동안에는 움직일 수 없어."
	elif working and kind() in ["arrows","weary"]: hint="화살 위를 드래그해 손질하기    같은 자리에서 E 누르고 있어도 손질할 수 있어."
	elif kind() in ["dreams","light"]: hint="WASD / 방향키 · 클릭: 이동    대상 곁에서 E 누르고 있기 / 대상 클릭: 행동"
	if kind() in ["carry","punishment","ending"] and phase!="arrived": hint="이야기가 이어지고 있어.    Esc: 잠시 쉬기    Q: 책 덮기"
	draw_rect(Rect2(18,742,1244,43),Color("172c42ed"));text_at(Vector2(36,770),hint,18)
	if paused:
		draw_rect(Rect2(0,0,1280,800),Color(0.04,.08,.13,.7));Pixels.panel(self,Rect2(340,280,600,225),Color("f0dfb6"))
		text_at(Vector2(390,330),"잠깐 쉬기",28,Color("513520"));text_at(Vector2(390,376),"Esc: 계속하기 · F5: 저장 · Q: 도서관으로",20,Color("513520"))
		text_at(Vector2(390,423),"완료한 행동은 책갈피에 남아 있어.",19,Color("806047"))
