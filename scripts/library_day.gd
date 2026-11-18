extends RefCounted

const Data = preload("res://scripts/library_day_state.gd")
const Layout = preload("res://scripts/library_world_layout.gd")
const UI = preload("res://scripts/library_day_ui.gd")
const CareArt = preload("res://scripts/library_care_art.gd")
const Preferences = preload("res://scripts/ink_reading_preferences.gd")
const Bubbles = preload("res://scripts/library_speech_bubbles.gd")
const ETE_SPEECH_SECONDS := 5.6
const CART := Vector2(284,504)
const SEATS := [Vector2(912,448),Vector2(1056,448)]
const STAGE := Vector2(552,616)
const LEAFLETS := Vector2(696,616)
const PROSPECTS := [Vector2(448,640),Vector2(704,640)]
const BROADCAST_SPOTS := [Vector2(212,280),Vector2(648,232),Vector2(1000,240),Vector2(216,648),Vector2(600,648),Vector2(1048,672)]
var topic := 0
var member_index := 4
var book := 0
var choice := ""
var selected_uid := -1
var action_kind := ""
var action_elapsed := 0.0
var action_index := 0
var previous_position := Vector2.ZERO
var distance := 0.0
var facing := "down"
var choice_return := "play"
var reply := 0
var ete_elapsed := -1.0
var ete_texture: CanvasTexture

func enabled(g) -> bool:
	return g.world_map_active() and g.growth.phase=="open"

func active(g) -> bool:
	return enabled(g) and not g.state.library_day.direct.is_empty()

func controls_mode(g) -> bool:
	return g.mode.begins_with("day_") or (g.mode=="promotion" and enabled(g))

func member(g) -> Dictionary:
	return g.MEMBERS[member_index]

func snapshot(g) -> void:
	if not active(g): return
	var s: Dictionary=g.state.library_day.direct
	s.position=[g.player_pos.x,g.player_pos.y];s.facing=facing

func resume(g) -> void:
	if not active(g): sync_targets(g);return
	var s: Dictionary=g.state.library_day.direct
	g.player_pos=Vector2(s.position[0],s.position[1])
	facing=s.facing;previous_position=g.player_pos
	g.mode="day_promotion"
	_claim(g)
	sync_targets(g)

func _claim(g) -> void:
	if not active(g): return
	var s: Dictionary=g.state.library_day.direct
	var obj: Dictionary=g._find_object(s.member)
	if obj.is_empty(): return
	if not obj.get("direct_control",false): g.garden_residents.release(s.member)
	obj.direct_control=true;obj.pos=g.player_pos
	obj.in_studio=Layout.private_point(obj.pos);obj.promo_away=false
	obj.facing=facing;obj.promo_ready=false

func error(g) -> String:
	var id: String=member(g).id
	if g.state.yard_host==id or g.state.yard_session.get("member","")==id:
		return "이 스텔라는 방송이나 운동 중이에요. 다른 친구를 골라 주세요."
	return g.state.ink_visits.start_error(g.state,topic,id)

func begin(g, direct_play: bool) -> bool:
	if g.mode!="promotion" or not enabled(g): return false
	var reason:=error(g)
	if reason!="": g._notify(reason);return false
	g.state.library_day.ensure(g.state.day)
	var id: String=member(g).id
	if not g.state.ink_visits.start(g.state,topic,id,direct_play,book): return false
	if not direct_play:
		g.mode="play";g._save()
		g._notify(member(g).short+"에게 홍보를 맡겼어요. 도서관에서 손님을 맞이해요.")
		return true
	g.character_touch.cancel()
	g.state.library_day.direct={"member":id,"topic":topic,"book":book,"stage":0,"campaign":g.state.ink_visits.campaigns,"origin":[g.player_pos.x,g.player_pos.y],"position":[0,0],"facing":"down"}
	var start: Vector2=Layout.HOMES[member_index] if topic==0 else STAGE+Vector2(0,72)
	g.player_pos=safe_point(g,start)
	previous_position=g.player_pos;distance=0.0;facing="down"
	g.route.clear();g.pending_object="";g.mode="day_promotion"
	_claim(g);sync_targets(g);g._save()
	g._notify(member(g).short+"의 시점이에요. 빛나는 표시로 걸어가 E로 살펴봐요.")
	return true

func safe_point(g, point: Vector2) -> Vector2:
	var cell: Vector2i=Layout.nearest(g.navigation,point)
	return g.navigation.get_point_position(cell) if cell.x>=0 else point

func station(g, step: int) -> Vector2:
	var s: Dictionary=g.state.library_day.direct
	if s.topic==0:
		var index: int=g._mission_index_for(s.member)
		return safe_point(g,Layout.HOMES[index]+Vector2(-80,0) if step==0 else Layout.HOME_OFFSET+BROADCAST_SPOTS[index])
	if s.topic==1: return safe_point(g,LEAFLETS if step==0 else prospect(g,step-1)+Vector2(0,-24))
	return safe_point(g,STAGE+Vector2(-64,0) if step==0 else STAGE)

func prospect(g, index: int) -> Vector2:
	return safe_point(g,PROSPECTS[index])

func instruction(g) -> String:
	var s: Dictionary=g.state.library_day.direct
	var steps: Array=[
		["소개할 책 고르기","방송 자리에서 책 펼치기","들어온 채팅에 답하기"],
		["배포할 책 소식 고르기","잉크에게 책 소식 건네기","다음 잉크에게 길 알려 주기"],
		["소개할 이야기 고르기","무대 표시에서 짧은 공연하기","관객에게 도서관 소개하기"]
	]
	return steps[s.topic][s.stage]

func sync_targets(g) -> void:
	g.objects=g.objects.filter(func(obj): return obj.type!="day_target")
	if not enabled(g): return
	var d=g.state.library_day
	if active(g):
		var reach:=28.0 if d.direct.topic==1 and d.direct.stage>0 else 42.0
		g.objects.append({"id":"day_station","type":"day_target","kind":"station","pos":station(g,int(d.direct.stage)),"label":instruction(g),"reach":reach})
		return
	if not d.carried.is_empty():
		var shelf: Dictionary=Data.BOOKS[d.carried[0]]
		g.objects.append({"id":"day_shelf","type":"day_target","kind":"shelve","pos":shelf.shelf,"label":shelf.mark+" 표시 서가 · 책 묶음 꽂기","reach":70.0})
	elif not d.returned.is_empty():
		g.objects.append({"id":"day_cart","type":"day_target","kind":"cart","pos":CART,"label":"돌아온 책 · 같은 표시끼리 함께 옮기기","reach":65.0})
	for seat in d.dirty:
		g.objects.append({"id":"day_seat_%d"%seat,"type":"day_target","kind":"seat","value":seat,"pos":SEATS[seat],"label":"다 쓴 자리 · 가볍게 정돈하기","reach":28.0})
	for index in range(d.grime.size()):
		if d.grime[index]<=0: continue
		g.objects.append({"id":"day_floor_%d"%index,"type":"day_target","kind":"floor","value":index,"pos":safe_point(g,CareArt.FLOOR_POINTS[index]),"label":"떨어진 책과 바닥 · 함께 정리하기" if d.grime[index]>=2 else "바닥 얼룩 · 닦아 정리하기","reach":44.0})
	for visitor in g.state.ink_visits.guests:
		if visitor.phase!="browse" or (not visitor.get("request",false) and not visitor.get("noisy",false)): continue
		g.objects.append({"id":"day_ink_%d"%visitor.uid,"type":"day_target","kind":"request" if visitor.get("request",false) else "quiet","value":visitor.uid,"pos":visitor.pos,"label":"소개한 책을 찾는 잉크" if visitor.get("request",false) else "목소리가 커진 잉크 · 조용히 안내하기","reach":78.0})
	if g.pending_object.begins_with("day_") and g._find_object(g.pending_object).is_empty():
		g.pending_object="";g.route.clear()

func update(g, delta: float) -> void:
	if not enabled(g): return
	g.state.library_day.ensure(g.state.day)
	var d=g.state.library_day
	if g.state.minutes>=600 and g.state.minutes<1200 and not g.state.operating.closing:
		if d.advance_care(delta): g._save()
	if ete_elapsed>=0:
		ete_elapsed+=minf(delta,.15)
		if ete_elapsed>=ETE_SPEECH_SECONDS or d.unfiled()==0: ete_elapsed=-1.0
	if g.mode=="play" and not Layout.private_point(g.player_pos) and not d.ete_warned and d.unfiled()>=4 and d.neglect_seconds>=Data.ETE_WARNING_AFTER and g.character_touch.held!="ete" and g.character_touch.ete_visit.is_empty() and g.ete_interactions.active=="":
		d.ete_warned=true;ete_elapsed=0.0;g._save()
	if active(g):
		var change: Vector2=g.player_pos-previous_position
		distance+=change.length()
		if change.length()>.01: facing=g.Field.direction_for(change,facing)
		previous_position=g.player_pos
		_claim(g);snapshot(g)
	if g.mode=="day_action":
		action_elapsed+=minf(delta,.15)
		if action_elapsed>=3.0: finish_action(g)
	sync_targets(g)

func interact(g, obj: Dictionary) -> bool:
	if obj.get("type")!="day_target": return false
	if not enabled(g) or g.mode not in ["play","day_promotion"]: return true
	g.route.clear();g.pending_object=""
	match obj.kind:
		"station":
			var s: Dictionary=g.state.library_day.direct
			if s.is_empty(): return true
			if s.stage==0: open_choice(g,"book")
			elif s.topic==0 and s.stage==1: start_action(g,"present")
			elif s.topic==2 and s.stage==1: start_action(g,"perform")
			else: open_choice(g,"chat" if s.topic==0 else "leaflet" if s.topic==1 else "invite")
		"cart":
			var count: int=g.state.library_day.take_books()
			if count>0:
				g._notify("같은 표시의 책 %d권을 들었어요. 서가의 표시를 찾아봐요."%count);g._save()
		"shelve": start_action(g,"shelve")
		"seat": action_index=int(obj.value);start_action(g,"clean")
		"floor": action_index=int(obj.value);start_action(g,"mop")
		"request","quiet": selected_uid=int(obj.value);open_choice(g,obj.kind)
	sync_targets(g)
	return true

func open_choice(g, kind: String) -> void:
	choice_return="day_promotion" if active(g) else "play"
	choice=kind;g.mode="day_choice";g.route.clear();g.pending_object=""

func start_action(g, kind: String) -> void:
	action_kind=kind;action_elapsed=0.0
	g.mode="day_action";g.route.clear();g.pending_object=""

func finish_action(g) -> void:
	var d=g.state.library_day
	match action_kind:
		"shelve":
			var count: int=d.shelve(d.carried[0]) if not d.carried.is_empty() else 0
			g._notify("책 %d권을 한 번에 꽂았어요. 잉크들이 꺼내 읽을 수 있어요."%count)
		"clean":
			d.dirty.erase(action_index);d.tidied+=1
			g._notify("책과 찻잔을 정돈했어요. 다음 손님이 쉴 자리예요.")
		"mop":
			var had_books: bool=d.grime[action_index]>=2
			d.clean_floor(action_index)
			g._notify("떨어진 책을 챙기고 바닥까지 정돈했어요." if had_books else "검게 남은 발자국과 얼룩을 닦았어요.")
		"present","perform": d.direct.stage=2
		"handoff":
			if int(d.direct.stage)==1: d.direct.stage=2
			else: end_direct(g,false);return
		"signoff": end_direct(g,false);return
	action_kind="";g.mode="day_promotion" if active(g) else "play"
	sync_targets(g);g._save()

func end_direct(g, assign: bool) -> void:
	if not active(g): return
	var s: Dictionary=g.state.library_day.direct.duplicate(true)
	var obj: Dictionary=g._find_object(s.member)
	if not obj.is_empty():
		obj.erase("direct_control");obj.promo_ready=false;obj.yard_action="idle"
		if g.garden_residents.agents.has(s.member):
			var a: Dictionary=g.garden_residents.agents[s.member]
			a.phase="studio" if obj.in_studio else "idle";a.timer=4.0;a.path=PackedVector2Array()
	g.state.ink_visits.featured_book=int(s.book)
	if assign: g.state.ink_visits.direct_campaign=false
	else: g.state.ink_visits._complete_promotion(g.state)
	g.state.library_day.direct.clear()
	g.player_pos=safe_point(g,Vector2(s.origin[0],s.origin[1]))
	g.state.world_player=g.player_pos;g.state.player=g.player_pos
	g.mode="play";g.route.clear();g.pending_object="";action_kind=""
	sync_targets(g);g._save()
	g._notify("스텔라가 이어서 홍보해요. 원래 팬 모습으로 돌아왔어요." if assign else "홍보를 마쳤어요. 소개한 책을 기억하는 잉크들이 예약 시간에 찾아와요.")

func guest(g) -> Dictionary:
	for v in g.state.ink_visits.guests:
		if v.uid==selected_uid: return v
	return {}

func action(g, id: String) -> bool:
	if not id.begins_with("day_"): return false
	if not enabled(g): return true
	if id.begins_with("day_topic_") and g.mode=="promotion": topic=int(id.get_slice("_",2))
	elif id.begins_with("day_member_") and g.mode=="promotion": member_index=clampi(int(id.get_slice("_",2)),0,5)
	elif id=="day_direct": begin(g,true)
	elif id=="day_assign": begin(g,false)
	elif id=="day_resume": g.mode="day_promotion" if active(g) else "play"
	elif id=="day_handback" and active(g): end_direct(g,true)
	elif id=="day_back": g.mode=choice_return
	elif id.begins_with("day_pick_") and g.mode=="day_choice":
		var pick:=clampi(int(id.get_slice("_",2)),0,1)
		match choice:
			"book":
				if not active(g): return true
				g.state.library_day.direct.book=pick;g.state.library_day.direct.stage=1
				g.state.ink_visits.featured_book=pick;g.mode="day_promotion"
			"chat","invite": reply=pick;start_action(g,"signoff")
			"leaflet": reply=pick;start_action(g,"handoff")
			"request":
				var v:=guest(g)
				if not v.is_empty() and v.phase=="browse" and v.get("request",false):
					# The preference is inferred from spoken clues, not a visible score.
					v.feature=pick;v.helped=true;v.request=false;v.elapsed=0
					g.state.library_day.recommended+=1
					g.state.ink_visits._next_use(v)
					g._notify("‘%s’ · %s"%[Data.BOOKS[pick].title,Preferences.response(v)])
				g.mode="play"
			"quiet":
				var v:=guest(g)
				if not v.is_empty() and v.get("noisy",false):
					v.noisy=false;v.elapsed=0;g.state.library_day.guided+=1
					if pick==1: g.state.ink_visits._next_use(v)
					g._notify("잉크가 고개를 끄덕이고 목소리를 낮췄어요." if pick==0 else "잉크가 읽을 책을 챙겨 이용 자리로 이동해요.")
				g.mode="play"
		sync_targets(g);g._save()
	return true

func input(g, event: InputEvent) -> bool:
	if not enabled(g): return false
	if controls_mode(g):
		if event is InputEventKey and event.pressed and not event.echo:
			var key: int=event.physical_keycode
			if key in [KEY_F5,KEY_F11]: return false
			if key==KEY_ESCAPE:
				if active(g):
					if g.mode=="day_pause": g.mode="day_promotion"
					elif g.mode!="day_action": g.mode="day_pause";g.route.clear();g.pending_object=""
				elif g.mode!="day_action": g.mode="play"
			elif key==KEY_E and g.mode=="day_promotion":
				var obj: Dictionary=g._find_object("day_station")
				if not obj.is_empty():
					if g.player_pos.distance_to(obj.pos)<obj.reach: interact(g,obj)
					else: g._go_to(obj)
			elif g.mode=="promotion" and key>=KEY_1 and key<=KEY_3: topic=key-KEY_1
			return true
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			for i in range(g.buttons.size()-1,-1,-1):
				var b: Dictionary=g.buttons[i]
				if b.rect.has_point(event.position):
					if not b.get("disabled",false): g._action(b.id)
					return true
			for area in g.ui_regions:
				if area.has_point(event.position): return true
			if g.mode=="day_promotion":
				var p: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
				var obj: Dictionary=g._find_object("day_station")
				if not obj.is_empty() and p.distance_to(obj.pos+Vector2(0,-24))<55: g._go_to(obj)
				elif Layout.floor_contains(p) and Layout.private_point(p)==Layout.private_point(g.player_pos): g.pending_object="";g._path_to(p)
			return true
		return event is InputEventMouse
	if g.mode=="play" and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if Bubbles.click(g,self,event.position): return true
		for b in g.buttons:
			if b.rect.has_point(event.position): return false
		for area in g.ui_regions:
			if area.has_point(event.position): return false
		var p: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
		if not g.character_touch.hit(g,p).is_empty(): return false
		for visitor in g.state.ink_visits.guests:
			if not Rect2(visitor.pos-Vector2(34,62),Vector2(68,66)).has_point(p): continue
			var target: Dictionary=g._find_object("day_ink_%d"%visitor.uid)
			if not target.is_empty(): g._go_to(target);return true
			return false
		for obj in g.objects:
			if obj.type!="day_target" or obj.kind=="floor": continue
			var on_prop: bool=p.distance_to(obj.pos+Vector2(0,-26))<35
			if obj.kind=="seat": on_prop=on_prop or Rect2(SEATS[obj.value]+Vector2(-38,-114),Vector2(108,48)).has_point(p)
			elif obj.kind=="cart": on_prop=on_prop or Rect2(CART+Vector2(-47,-94),Vector2(108,59)).has_point(p)
			if on_prop:
				g._go_to(obj);return true
		# Enlarged visible dirt must be clickable at its edge as well as its center.
		for obj in g.objects:
			if obj.type!="day_target" or obj.kind!="floor": continue
			var index: int=obj.value
			if CareArt.hit_stain(CareArt.FLOOR_POINTS[index],g.state.library_day.grime[index],index,p):
				g._go_to(obj);return true
	return false

func draw_actor(g, p: Vector2, walking: bool) -> bool:
	if not active(g): return false
	var s: Dictionary=g.state.library_day.direct
	var m: Dictionary=g.MEMBERS[g._mission_index_for(s.member)]
	var act: String="walk" if walking and g.mode=="day_promotion" else "idle"
	var seconds: float=distance/86.0
	var foot:=p
	if g.mode=="day_action":
		seconds=action_elapsed;act="stream"
		if action_kind=="present": act="read"
		if action_kind=="signoff" and reply==0: act="read"
		if action_kind=="perform":
			# Authored full-body walking and greeting frames, rigid footwork.
			foot+=Vector2(roundf(sin(action_elapsed*PI*2)*7),0)
			act="walk" if action_elapsed<1.6 else "stream"
			seconds=action_elapsed*1.25
	var actor_facing: String=facing if act in ["walk","idle"] else "down"
	if g.mode=="day_action" and action_kind=="perform": actor_facing="down"
	g.Yard.draw_actor(g,m,foot,act,seconds,actor_facing,action_elapsed*86 if action_kind=="perform" and g.mode=="day_action" else distance)
	g.draw_line(p+Vector2(-16,4),p+Vector2(16,4),Color("a3d3ae"),2)
	if g.mode=="day_action" and action_kind=="handoff":
		var hand: Vector2=(p+Vector2(16,-34)).lerp(prospect(g,int(s.stage)-1)+Vector2(-6,-25),smoothstep(.6,2.6,action_elapsed)).round()
		g.draw_rect(Rect2(hand,Vector2(13,18)),Color("f4dfb6"))
		g.draw_line(hand+Vector2(3,5),hand+Vector2(10,5),Color("66876b"),2)
	return true

func draw_player_prop(g, p: Vector2) -> void:
	if not enabled(g): return
	var d=g.state.library_day
	if not d.carried.is_empty():
		for i in range(d.carried.size()):
			var hand:=p+Vector2(1,-15-i*5)
			if g.mode=="day_action" and action_kind=="shelve":
				var target: Vector2=Data.BOOKS[d.carried[i]].shelf+Vector2(20,-72-i*5)
				hand=hand.lerp(target,smoothstep(.3+i*.4,1.6+i*.4,action_elapsed)).round()
			UI.carried_book(g,hand,int(d.carried[i]))
	if g.mode=="day_action" and action_kind=="clean":
		var hand:=p+Vector2(roundf(sin(action_elapsed*4)*9),-24)
		g.draw_rect(Rect2(hand,Vector2(14,7)),Color("b6c9ba"))
		g.draw_line(hand,hand+Vector2(14,0),Color("f2ebd2"),2)
	elif g.mode=="day_action" and action_kind=="mop":
		if d.grime[action_index]>=2 and action_elapsed<1.0:
			# Keep the original body/face intact. Lift a rigid book at hand height
			# before using the mop, so books are not treated as floor rubbish.
			if action_elapsed<.25: return
			var lift: float=smoothstep(.25,.9,action_elapsed)
			CareArt.draw_lifted_book(g,p+Vector2(9,1).lerp(Vector2(4,-23),lift),action_index%3)
			return
		var hand:=p+Vector2(12,-23)
		var tip:=p+Vector2(26+roundf(sin(action_elapsed*6)*10),1)
		g.draw_line(hand,tip,Color("66503b"),3)
		g.draw_rect(Rect2(tip-Vector2(10,2),Vector2(22,7)),Color("b7c8bc"))
		g.draw_line(tip-Vector2(8,0),tip+Vector2(10,0),Color("f1e5c8"),2)

func draw_floor(g) -> void:
	if not enabled(g) or Layout.private_point(g.player_pos): return
	for i in range(g.state.library_day.grime.size()):
		var collecting: bool=g.mode=="day_action" and action_kind=="mop" and action_index==i
		CareArt.draw_stain(g,CareArt.FLOOR_POINTS[i],g.state.library_day.grime[i],i,not collecting or action_elapsed<.25)

func draw_librarian(g,feet: Vector2) -> bool:
	if not enabled(g) or ete_elapsed<0 or g.character_touch.held=="ete" or not g.character_touch.ete_visit.is_empty() or g.ete_interactions.active!="": return false
	# Reuse intact authored whole-body frames: look up, firm fist, recover.
	# Only the foot anchor shifts by a single pixel; the face is never stretched.
	if ete_texture==null:
		ete_texture=CanvasTexture.new();ete_texture.diffuse_texture=g.ete_interactions.SHEET
		ete_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var time:=minf(ete_elapsed,2.6)
	var column: int=g.ete_interactions.SAMPLES.gesture([.45,.45,1.1,.35,.25],time)
	var tap:=Vector2(0,-1 if ete_elapsed>.8 and ete_elapsed<2.8 and int(ete_elapsed*8)%4==0 else 0)
	var p: Vector2=g.Field.origin(g,feet+tap,g.Field.STELLA_SCALE)
	g.draw_ellipse_shadow(feet+Vector2(0,3),Vector2(16,4)*g.Field.STELLA_ZOOM)
	g.draw_texture_rect_region(ete_texture,Rect2(p,Vector2(96,112)*g.Field.STELLA_SCALE),Rect2(column*96,10*112,96,112))
	return true

func draw_bubbles(g) -> void:
	Bubbles.draw(g,self)

func draw_world(g) -> void:
	if enabled(g): UI.draw_world(g,self)

func draw_ui(g) -> bool:
	if not enabled(g): return false
	if controls_mode(g): UI.draw(g,self);return true
	return false
