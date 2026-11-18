extends RefCounted

# Pointer-owned interactions are transient: they never grant daily rewards.
const Furniture = preload("res://scripts/garden_furniture.gd")
const DRAG_DISTANCE := 8.0
const ETE_ACTIONS := {"chair":"read","tea":"tea","mat":"rest","camera":"greet"}
const ETE_LABELS := {"chair":"함께 읽기","tea":"차 한 잔","mat":"눈 감고 쉬기","camera":"카메라에 인사"}
const REACTIONS := ["wave","nod","smile"]
const REACTION_FRAMES := {
	"wave":[0,3,5,8,10,12,14,16,19,23],
	"nod":[0,16,18,19,23],
	"smile":[0,1,2,1,0]
}
var held := ""
var dragging := false
var press_screen := Vector2.ZERO
var pointer_screen := Vector2.ZERO
var grab_offset := Vector2.ZERO
var reactions := {}
var previous := {}
var cooldowns := {}
var ete_visit := {}

func reset() -> void:
	held=""
	dragging=false
	reactions.clear()
	previous.clear()
	cooldowns.clear()
	ete_visit.clear()

func available(g) -> bool:
	return g.mode=="play" and g.state.scene=="library" and g.comic_started<0

func over_ui(g, screen: Vector2) -> bool:
	for region in g.ui_regions:
		if region.has_point(screen): return true
	for button in g.buttons:
		if button.rect.has_point(screen): return true
	return false

func world(g, screen: Vector2) -> Vector2:
	return (screen-g.WORLD_OFFSET)/g.WORLD_SCALE

func locked(g, id: String) -> bool:
	return g.state.ink_visits.promoting(id) or g.state.yard_host==id or g.state.yard_session.get("member","")==id

func hit(g, point: Vector2) -> Dictionary:
	var result := {}
	for obj in g.objects:
		if obj.get("promo_away",false): continue
		if obj.type not in ["npc","librarian"]: continue
		var bounds := Rect2(obj.pos+Vector2(-29,-76),Vector2(58,80))
		if obj.type=="npc": bounds=g.Field.stella_hit_rect(g._costume_key(obj.id),obj.pos)
		elif obj.type=="librarian": bounds=g.Field.stella_hit_rect("aethe",obj.pos)
		if bounds.has_point(point):
			if result.is_empty() or obj.pos.y>=result.pos.y: result=obj
	return result

func frozen(id: String) -> bool:
	return held==id or reactions.has(id)

func cancel() -> void:
	held=""
	dragging=false

func clear_room_greetings(g) -> void:
	for npc in g.objects:
		if npc.get("in_studio",false):
			reactions.erase(npc.id)
			cooldowns.erase(npc.id)

func input(g, event: InputEvent) -> bool:
	if held!="":
		if not available(g):
			cancel()
			return false
		if event is InputEventKey and event.pressed:
			if event.physical_keycode==KEY_ESCAPE:
				cancel()
				return true
			if event.physical_keycode!=KEY_F11: cancel()
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			cancel()
			return true
		if event is InputEventMouseMotion:
			pointer_screen=event.position
			if event.position.distance_to(press_screen)>=DRAG_DISTANCE:
				dragging=true
				g.ete_interactions.clear_stroke()
			return true
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			pointer_screen=event.position
			var id := held
			# Some platforms coalesce motion events; release still determines a drag.
			dragging=dragging or event.position.distance_to(press_screen)>=DRAG_DISTANCE
			if dragging: drop(g)
			else: react(g,id)
			cancel()
			return true
	if not available(g): return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if over_ui(g,event.position): return false
		var obj := hit(g,world(g,event.position))
		if obj.is_empty(): return false
		if obj.get("in_studio",false) and (g.state.yard_host==obj.id or g.state.ink_visits.promoting(obj.id)):
			g._studio_interact(obj)
			return true
		if locked(g,obj.id):
			g._notify("지금은 약속한 활동 중이에요. 활동을 마치거나 취소한 뒤 옮겨 주세요.")
			return true
		held=obj.id
		dragging=false
		press_screen=event.position
		pointer_screen=event.position
		grab_offset=obj.pos-world(g,event.position)
		g.route.clear()
		g.pending_object=""
		g.ete_interactions.clear_stroke()
		return true
	return false

func react(g, id: String) -> void:
	if cooldowns.get(id,0.0)>0 or reactions.has(id): return
	if id=="ete":
		if not ete_visit.is_empty(): return
		g.ete_interactions.random_reaction(g)
		return
	var agent: Dictionary = g.garden_residents.agents.get(id,{})
	if agent.get("phase","") in ["use","enter","leave"]: return
	var authored: bool = g.StellaInteractions.supports(g,id)
	var choices: Array = g.StellaInteractions.click_actions(id) if authored else REACTIONS.duplicate()
	var at_home: bool=g._find_object(id).get("in_studio",false)
	var room_lines: Dictionary={}
	if at_home:
		room_lines=g.FanRecognition.PAIRS[id].room if g.state.fan_form==id else g.Studios.GREETINGS[id]
		choices=room_lines.keys()
	choices.erase(previous.get(id,""))
	var chosen: String = choices.pick_random()
	previous[id]=chosen
	var total: float = g.StellaInteractions.duration(id,chosen) if authored else (2.4 if chosen=="wave" else 1.8)
	reactions[id]={"id":chosen,"elapsed":0.0,"duration":total,"authored":authored,"costume":g._costume_key(id)}
	if at_home:
		if g.state.fan_form!="" and g.state.fan_form!=id:
			reactions[id].greeting=g.FanRecognition.line(id,g.state.fan_form,"talk")
		else:
			reactions[id].greeting=room_lines[chosen]
		reactions[id].duration=maxf(total,2.4)

func target(g) -> Dictionary:
	if over_ui(g,pointer_screen): return {"error":"메뉴 밖 도서관 바닥에 놓아 주세요."}
	var point := world(g,pointer_screen)
	var feet := point+grab_offset
	if g.split_view():
		for i in range(g.MEMBERS.size()):
			if g.Studios.room(i).has_point(pointer_screen):
				if g.MEMBERS[i].id!=held: return {"error":"스텔라 자신의 개인실에 놓아 주세요."}
				return {"error":"","kind":"studio","pos":g.Studios.feet(i),"label":"개인실로 돌아가기"}
	# The pointer itself selects furniture, independent of where the body was grabbed.
	for item in g.state.furniture:
		var p := Furniture.position(item)
		if not Rect2(p+Vector2(-42,-62),Vector2(84,94)).has_point(point): continue
		if not item.enabled: return {"error":"이 가구는 이용이 꺼져 있어요."}
		if not Furniture.compatible(item,held): return {"error":"이 캐릭터가 이용할 수 없는 가구예요."}
		if Furniture.reserved_for_activity(g.state,item.kind): return {"error":"약속한 활동에 사용 중인 가구예요."}
		var owner: String = g.garden_residents.reservations.get(item.kind,"")
		if owner!="" and owner!=held: return {"error":"다른 캐릭터가 이용하거나 이동 중이에요."}
		var label: String = ETE_LABELS[item.kind] if held=="ete" else Furniture.ITEMS[item.kind].verb
		return {"error":"","kind":item.kind,"pos":p,"label":label}
	if not (g._walkable(feet) if g.world_map_active() else Furniture.walkable(feet,g.obstacles)): return {"error":"지나갈 수 있는 바닥에 놓아 주세요."}
	for obj in g.objects:
		if obj.id!=held and obj.type in ["npc","librarian"] and obj.pos.distance_to(feet)<30:
			return {"error":"다른 캐릭터 옆에 조금 떨어뜨려 놓아 주세요."}
	if feet.distance_to(g.player_pos)<25: return {"error":"플레이어 옆에 조금 떨어뜨려 놓아 주세요."}
	var home: Vector2=g.AETHE_POS
	if g.world_map_active():
		var layout=preload("res://scripts/library_world_layout.gd")
		home=layout.HOME_DOOR if layout.private_point(feet) else layout.ETE
	if g.garden_residents.path_between(g,feet,home).is_empty(): return {"error":"돌아올 수 있는 바닥에 놓아 주세요."}
	return {"error":"","kind":"","pos":feet,"label":"여기에 내려놓기"}

func release_ete(g) -> void:
	var kind: String = ete_visit.get("kind","")
	if g.garden_residents.reservations.get(kind,"")=="ete": g.garden_residents.reservations.erase(kind)
	ete_visit.clear()

func drop(g) -> void:
	var destination := target(g)
	if destination.error!="":
		g._notify(destination.error+" 원래 자리를 유지해요.")
		return
	var obj: Dictionary = g._find_object(held)
	if obj.is_empty(): return
	reactions.erase(held)
	if held=="ete":
		var home: Vector2 = ete_visit.get("home",obj.pos)
		release_ete(g)
		g.ete_interactions.reset()
		if destination.kind=="":
			obj.pos=destination.pos
		else:
			var item := Furniture.find(g.state.furniture,destination.kind)
			obj.pos=Furniture.approach(item)
			g.garden_residents.reservations[destination.kind]="ete"
			ete_visit={"kind":destination.kind,"home":home,"phase":"use","path":PackedVector2Array(),"distance":0.0}
			g.ete_interactions.start(g,ETE_ACTIONS[destination.kind],true)
	else:
		if destination.kind=="studio":
			g.garden_residents.enter_studio(obj)
			return
		g.garden_residents.release(held)
		var agent: Dictionary = g.garden_residents.agents[held]
		obj.in_studio=g.world_map_active() and destination.pos.x>=1280
		agent.public_time=32.0
		obj.pos=destination.pos
		agent.elapsed=0.0
		obj.yard_action=""
		obj.yard_seconds=0.0
		if destination.kind=="":
			agent.phase="studio" if obj.in_studio else "idle"
			agent.timer=4.0
		else:
			obj.facing="down"
			agent.kind=destination.kind
			agent.phase="use"
			agent.timer=8.0
			g.garden_residents.reservations[destination.kind]=held
			obj.yard_action=Furniture.ITEMS[destination.kind].action

func update(g, delta: float) -> void:
	if g.state.scene!="library" or g.mode in ["title","new_confirm","chapter","rescue"]:
		release_ete(g)
		reset()
		return
	if not available(g):
		cancel()
		return
	for id in cooldowns: cooldowns[id]=maxf(0.0,cooldowns[id]-delta)
	for id in reactions.keys():
		if reactions[id].get("costume",g._costume_key(id))!=g._costume_key(id):
			reactions.erase(id)
			continue
		if held==id: continue
		reactions[id].elapsed+=maxf(0.0,delta)
		if reactions[id].elapsed>=reactions[id].duration:
			reactions.erase(id)
			cooldowns[id]=.6
	if ete_visit.is_empty() or held=="ete" or g.pending_object=="ete": return
	var obj: Dictionary = g._find_object("ete")
	if obj.is_empty():
		release_ete(g)
		return
	if ete_visit.phase=="use":
		if g.ete_interactions.active!="": return
		g.garden_residents.reservations.erase(ete_visit.kind)
		ete_visit.kind=""
		ete_visit.phase="return"
		ete_visit.path=g.garden_residents.path_between(g,obj.pos,ete_visit.home)
	if ete_visit.phase=="return":
		var before: Vector2 = obj.pos
		ete_visit.distance+=g.garden_residents.walk(obj,ete_visit,delta)
		var offset: Vector2 = obj.pos-before
		if offset.length_squared()>0.01: g.ete_facing=g.Field.direction_for(offset,g.ete_facing)
		if ete_visit.path.is_empty(): release_ete(g)

func draw_reaction(g, actor: Dictionary) -> bool:
	if not reactions.has(actor.id): return false
	var reaction: Dictionary = reactions[actor.id]
	if reaction.get("authored",false):
		if not g.StellaInteractions.supports(g,actor.id): return false
		var action: Dictionary = g.StellaInteractions.definition(actor.id,reaction.id)
		var column: int = g.StellaInteractions.Samples.gesture(action.durations,reaction.elapsed,action.get("travel_seconds",[]))
		g.StellaInteractions.draw(g,actor.id,reaction.id,actor.pos,column)
		return true
	var frames: Array = REACTION_FRAMES[reaction.id]
	var cursor := clampf(reaction.elapsed/reaction.duration,0.0,1.0)*(frames.size()-1)
	var index := floori(cursor)
	var beat := lerpf(frames[index],frames[mini(index+1,frames.size()-1)],cursor-index)
	g.Yard.draw_actor(g,g.MEMBERS[actor.index],actor.pos,"stream",beat/8.0)
	return true

func draw_drag(g) -> void:
	if not dragging or held=="": return
	var obj: Dictionary = g._find_object(held)
	if obj.is_empty(): return
	var destination := target(g)
	var good: bool = destination.error==""
	var tint := Color("a4dec0") if good else Color("eaa08c")
	var feet := world(g,pointer_screen)+grab_offset
	for item in g.state.furniture:
		var owner: String = g.garden_residents.reservations.get(item.kind,"")
		var usable: bool = item.enabled and (owner=="" or owner==held) and not Furniture.reserved_for_activity(g.state,item.kind)
		var outline := Color("a4dec0") if usable else Color("ba887a")
		g.draw_rect(Furniture.zone(Furniture.position(item)),Color(outline,.65),false,1)
	if good:
		g.draw_rect(Furniture.zone(destination.pos),Color(tint,.15))
		g.draw_rect(Furniture.zone(destination.pos),tint,false,2)
	g.draw_ellipse_shadow(feet,Vector2(20,5))
	var key: String = "aethe" if held=="ete" else g._costume_key(held)
	var height: float=g.Field.STELLA_HEIGHT
	if held!="ete" and obj.facing!="down":
		g.Field.draw_stella_turn(g,held,key,feet+Vector2(0,-10),obj.facing,false,0.)
	else:
		g.Field.draw(g,key,feet+Vector2(0,-10),height)
	g._world_sign(feet+Vector2(0,20),"놓으면 · "+destination.label if good else "여기는 놓을 수 없어요")

func draw_hint(g) -> void:
	if g.state.scene!="library": return
	var seat: Dictionary=g.shared.nearby(g)
	if not seat.is_empty():
		var name: String=g.MEMBERS[g._mission_index_for(seat.id)].short
		g._button(Rect2(390,648,500,44),"%s · %s   R" % [name,g.SharedActivity.NAMES[seat.kind]],"join_"+seat.id,true)
		return
	if g.state.ink_visits.topic>=0 and not dragging: return # Keep the entrance visible during arrivals.
	var panel := Rect2(306,653,668,36)
	g._panel(panel,g.PAPER)
	g.ui_regions.append(panel)
	var hint := "캐릭터 클릭 · 랜덤 반응     끌어서 가구에 놓기     가까이에서 E · 대화"
	if g.split_view(): hint="개인실 클릭 · 인사 / 방송 채팅     도서관 E · 대화     독서 의자와 티 테이블 곁에서 R · 함께하기"
	if dragging:
		var destination := target(g)
		hint=("놓으면 · "+destination.label if destination.error=="" else destination.error)+"    Esc / 우클릭 · 취소"
	g._center(677,hint,14,g.CREAM)
