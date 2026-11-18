extends "res://scripts/ink_visitors.gd"

# Operating visits settle money and light only after visible actions. A
# completed broadcast also grants its one daily promotional memory reward.
const CARRY_SHEET_PATH := "res://assets/characters/visitors/ink_carry.png"
const DESK := Vector2(710,470)
const VISIT_PHASES := ["shelf","browse","to_exhibit","exhibit","to_record","record","to_read","read","to_desk","checkout","return_desk","checkin","leave"]
const Decor=preload("res://scripts/library_growth_decor.gd")
const Preferences=preload("res://scripts/ink_reading_preferences.gd")
const Outreach=preload("res://scripts/library_outreach.gd")
const WorldLayout=preload("res://scripts/library_world_layout.gd")
const EXHIBIT:=Decor.EXHIBIT_POINT
const RECORD:=Decor.RECORD_POINT
const PROMOTION_KINDS: Array=[ ["read","read","borrow"], ["read","borrow","read","borrow"], ["read","read","read","read","read"] ]
const READ_LIGHT := 2
const LOAN_LIGHT := 3
const BLOCK_TIMEOUT := 8.0
var growth: RefCounted
var batch_size := 0
var next_uid := 1
var current_day := 1
var spawn_retries := 0
var loans: Array[Dictionary] = []
var return_queue: Array[String] = []
var carry_texture: CanvasTexture
var appointments: Array[Dictionary]=[]
var next_appointment:=1
var planned_day:=0
var promotion_elapsed:=0.0
var campaign_rewarded:=false
var legacy_campaign:=false
var world_layout:=false
var direct_campaign:=false
var featured_book:=0
var outreach=Outreach.new()

func door_position() -> Vector2:
	return WorldLayout.VISITOR_DOOR if world_layout else DOOR

func shelf_position(slot: int) -> Vector2:
	return WorldLayout.VISITOR_SHELVES[slot] if world_layout else SHELF[slot]

func reading_position(slot: int) -> Vector2:
	return WorldLayout.VISITOR_READ[slot] if world_layout else READING[slot]

func desk_position() -> Vector2:
	return WorldLayout.VISITOR_DESK if world_layout else DESK

func exhibit_position() -> Vector2:
	return WorldLayout.VISITOR_EXHIBIT if world_layout else EXHIBIT

func record_position() -> Vector2:
	return WorldLayout.VISITOR_RECORD if world_layout else RECORD

func world_pose(v: Dictionary) -> Vector2:
	match v.phase:
		"read": return reading_position(v.slot)
		"checkout","checkin": return desk_position()
		"browse": return shelf_position(v.slot)
		"exhibit": return exhibit_position()
		"record": return record_position()
	return next_stop(v)

func _scheduled(state) -> bool:
	return state.has_method("library_calendar")

func _admissions_open(state) -> bool:
	return not _scheduled(state) or (state.minutes>=600 and state.minutes<1200 and not state.operating.closing)

func _book_appointment(state, kind: String, source: int, due_day: int, minute: int) -> void:
	var book: String=state.residents[(next_appointment-1)%state.residents.size()]
	appointments.append({"id":next_appointment,"kind":kind,"book":book,"source":source,"origin":"natural" if source==3 else "promotion","day":due_day,"minute":clampi(minute,600,1190),"retries":0})
	next_appointment+=1

func plan_day(state, rank_at_open: int) -> void:
	if planned_day==state.day or growth.phase!="open": return
	planned_day=state.day
	outreach.ensure(state.day)
	var count:=Outreach.natural_count(rank_at_open)
	count=mini(count,maxi(0,128-appointments.size()))
	for i in range(count): _book_appointment(state,"read" if i%2==0 else "borrow",3,state.day,660+i*80)

func reservations_for(day: int) -> int:
	var count:=0
	for item in appointments:
		if item.day==day: count+=1
	return count

func has_due_arrivals(state) -> bool:
	if not _admissions_open(state): return false
	if not return_queue.is_empty(): return true
	for item in appointments:
		if item.day<=state.day and item.minute<=state.minutes: return true
	return false

func defer_waiting(next_day: int) -> void:
	for item in appointments:
		if item.day<next_day:
			item.day=next_day
			item.minute=600+(int(item.id)%6)*10

func bind_growth(value: RefCounted) -> void:
	growth=value

func capacity() -> int:
	return clampi(int(growth.visitor_capacity()),2,READING.size()) if growth!=null else 2

func group_size() -> int:
	return batch_size if topic>=0 else capacity()

func start_error(state, choice: int, member: String="") -> String:
	if state.scene!="library": return "홍보는 공용 도서관에서 맡겨 주세요."
	if growth==null or growth.phase!="open" or state.residents.size()<6: return "여섯 스텔라와 도서관을 재개관한 뒤 홍보할 수 있어요."
	if topic!=-1: return "진행 중인 홍보를 먼저 마무리해 주세요."
	# Scheduled campaigns add appointments without replacing active visits or
	# returns. Legacy campaigns still use a single batch of visitor slots.
	if not _scheduled(state) and (not return_queue.is_empty() or not guests.is_empty()):
		return "진행 중인 방문을 먼저 마무리해 주세요."
	if choice<0 or choice>=TOPICS.size(): return "홍보 주제를 다시 골라 주세요."
	if appointments.size()+PROMOTION_KINDS[choice].size()>124: return "예약된 손님을 먼저 맞이해 주세요. 새 예약을 받을 공간이 부족해요."
	if _scheduled(state):
		state.operating.ensure(state)
		var schedule_error: String=state.operating.promotion_error(state,choice)
		if schedule_error!="": return schedule_error
	if _resolve_host(state,member) not in state.residents: return "방송이나 운동을 마친 스텔라에게 홍보를 맡길 수 있어요."
	return ""

func start(state, choice: int, member: String="", direct_play: bool=false, book: int=0) -> bool:
	if start_error(state,choice,member)!="": return false
	if _scheduled(state) and not state.operating.reserve(state,choice): return false
	var assigned_show:=choice==0 and member==""
	member=_resolve_host(state,member)
	campaigns+=1
	topic=choice
	host=member
	live_recommendation=assigned_show or direct_play or (choice==0 and int(state.activity_record(member).stream_day)!=state.day)
	batch_size=PROMOTION_KINDS[choice].size() if _scheduled(state) else capacity()
	pending=batch_size
	delay=2.4
	spawn_retries=0
	current_day=state.day
	promotion_elapsed=0.0
	campaign_rewarded=false
	legacy_campaign=not _scheduled(state)
	direct_campaign=direct_play
	featured_book=clampi(book,0,1)
	# A completed personal broadcast can invite guests through this same slot.
	if not direct_play and _scheduled(state) and choice==0 and not assigned_show and int(state.activity_record(member).stream_day)==state.day:
		_complete_promotion(state)
	return true

func _complete_promotion(state) -> void:
	if topic<0 or legacy_campaign: return
	var completed_topic:=topic
	outreach.ensure(state.day)
	outreach.completed_campaigns+=1
	if completed_topic==0 and not campaign_rewarded:
		if growth.reward("promotion:%d:broadcast"%campaigns,0,3): outreach.paid(state.day,{"origin":"promotion"},0,3)
		campaign_rewarded=true
	var tomorrow: bool=completed_topic==1 or not _admissions_open(state)
	var due_day: int=state.day+1 if tomorrow else state.day
	for i in range(PROMOTION_KINDS[completed_topic].size()):
		_book_appointment(state,PROMOTION_KINDS[completed_topic][i],completed_topic,due_day,600+i*20 if tomorrow else state.minutes+i*20)
		var appointment: Dictionary=appointments.back()
		appointment.feature=featured_book;appointment.source_host=host
		appointment.request=i==0;appointment.helped=false
	topic=-1;host="";pending=0;batch_size=0;live_recommendation=false
	promotion_elapsed=0.0
	direct_campaign=false

func next_stop(v: Dictionary) -> Vector2:
	match v.phase:
		"shelf": return shelf_position(v.slot)
		"to_read": return reading_position(v.slot)
		"to_desk","return_desk": return desk_position()
		"to_exhibit": return exhibit_position()
		"to_record": return record_position()
	return door_position()

func _route(g, from: Vector2, to: Vector2) -> PackedVector2Array:
	var start: Vector2i=g._grid_at(from)
	var finish: Vector2i=g._grid_at(to)
	if start.x<0 or finish.x<0: return PackedVector2Array()
	return g.navigation.get_point_path(start,finish)

func _can_visit(g, slot: int, kind: String) -> bool:
	var destination: Vector2=desk_position() if kind in ["borrow","return"] else reading_position(slot)
	if kind=="return":
		return not _route(g,door_position(),desk_position()).is_empty() and not _route(g,desk_position(),door_position()).is_empty()
	return not _route(g,door_position(),shelf_position(slot)).is_empty() and not _route(g,shelf_position(slot),destination).is_empty() and not _route(g,destination,door_position()).is_empty()

func walk(g, v: Dictionary, dt: float) -> bool:
	var uid: int=v.uid
	if not paths.has(uid):
		var path:=_route(g,v.pos,next_stop(v))
		if path.is_empty():
			v.blocked+=dt
			return false
		paths[uid]=path
	var route: PackedVector2Array=paths[uid]
	var budget:=SPEED*dt
	while budget>0 and not route.is_empty():
		var delta: Vector2=route[0]-v.pos
		var distance:=delta.length()
		var stride:=minf(budget,distance)
		if stride>.001:
			v.pos=v.pos.move_toward(route[0],stride)
			v.distance+=stride
			v.facing=Field.direction_for(delta.normalized()*8.0,v.facing)
			v.blocked=0.0
		budget-=stride
		if distance<=stride: route.remove_at(0)
		else: break
	paths[uid]=route
	if not route.is_empty(): return false
	paths.erase(uid)
	return true

func _guest(slot: int, kind: String, book: String, loan_id: String="") -> Dictionary:
	var result: Dictionary={"uid":next_uid,"slot":slot,"kind":kind,"book":book,"loan_id":loan_id,
		"phase":"return_desk" if kind=="return" else "shelf","pos":door_position(),"facing":"up",
		"distance":0.0,"elapsed":0.0,"blocked":0.0,"admitted":kind=="return","completed":false,"temperament":Preferences.for_uid(next_uid)}
	next_uid+=1
	return result

func _event(v: Dictionary, kind: String) -> String:
	return "ink:%d:%s" % [v.uid,kind]

func _pay_entry(g, v: Dictionary) -> void:
	if v.admitted or v.distance<24.0: return
	v.admitted=true
	total+=1
	if growth.reward(_event(v,"entry"),growth.entrance_fee(),0):
		outreach.entered(g.state.day,v)
		outreach.paid(g.state.day,v,growth.entrance_fee(),0)
		var from: String="추천 방송" if v.get("source",3)==0 else "잡지" if v.get("source",3)==1 else "공연" if v.get("source",3)==2 else "스텔라의 홍보"
		if Outreach.origin(v)=="promotion": g._notify(from+"을 보고 잉크가 찾아왔어요. 입장료 +%dG"%growth.entrance_fee())
		elif Outreach.origin(v)=="revisit": g._notify("마음에 든 도서관을 기억하고 다시 왔어요. 입장료 +%dG"%growth.entrance_fee())
	g._save()

func _change(v: Dictionary, phase: String) -> void:
	v.phase=phase
	v.elapsed=0.0
	v.blocked=0.0
	paths.erase(v.uid)

func _finish_reading(g, v: Dictionary) -> void:
	if v.completed: return
	v.completed=true
	if growth.reward(_event(v,"read"),0,READ_LIGHT): outreach.paid(g.state.day,v,0,READ_LIGHT)
	var again:=_remember_visit(g,v)
	if g.state.get("library_day")!=null: g.state.library_day.completed_reading(g.state,v)
	_change(v,"leave")
	g._notify("잉크가 이야기를 기억했어요. 기억의 빛 +%d" % READ_LIGHT+_recommendation_bonus(g,v)+again)
	g._save()

func _lend(g, v: Dictionary) -> void:
	if v.completed: return
	v.completed=true
	var id:=_event(v,"loan")
	v.loan_id=id
	if growth.reward(id,growth.loan_fee(),LOAN_LIGHT): outreach.paid(g.state.day,v,growth.loan_fee(),LOAN_LIGHT)
	var again:=_remember_visit(g,v)
	var loan: Dictionary={"id":id,"book":v.book,"due_day":g.state.day+1,"queued":false,"returned":false}
	for key in ["feature","source_host","temperament","reading_goal"]:
		if v.has(key): loan[key]=v[key]
	loans.append(loan)
	_change(v,"leave")
	g._notify("책을 빌려 갔어요. 대여료 +%dG · 기억의 빛 +%d" % [growth.loan_fee(),LOAN_LIGHT]+_recommendation_bonus(g,v)+again)
	g._save()

func _recommendation_bonus(g, v: Dictionary) -> String:
	if not v.get("completed",false) or v.get("kind","") not in ["read","borrow"] or not Preferences.matched(v): return ""
	if not growth.reward(_event(v,"recommendation"),Preferences.BONUS_GOLD,Preferences.BONUS_LIGHT): return ""
	outreach.paid(g.state.day,v,Preferences.BONUS_GOLD,Preferences.BONUS_LIGHT)
	return " · 취향에 맞는 추천 +%dG / 빛 +%d"%[Preferences.BONUS_GOLD,Preferences.BONUS_LIGHT]

func _remember_visit(g, v: Dictionary) -> String:
	# Only a completed first visit earns one next-day appointment. Repeat
	# visitors and loan returns cannot recursively create more bookings.
	outreach.ensure(g.state.day)
	if Outreach.origin(v)=="revisit" or outreach.revisits_booked>=Outreach.REVISITS_PER_DAY or appointments.size()>=128: return ""
	var care=g.state.get("library_day")
	var tidy: bool=care!=null and care.tidied>=2 and care.unfiled()<=2 and care.grime.max()<=1
	if tidy and v.kind=="read": tidy=int(v.slot)%2 not in care.dirty
	var reason: String="recommendation" if Preferences.matched(v) else "care" if tidy else ""
	if reason=="": return ""
	_book_appointment(g.state,"read",3,g.state.day+1,720+outreach.revisits_booked*120)
	var item: Dictionary=appointments.back()
	item.origin="revisit";item.reason=reason;item.temperament=v.temperament
	item.feature=int(v.get("feature",0))
	if v.has("source_host"): item.source_host=v.source_host
	outreach.revisits_booked+=1
	return " · 좋은 추천을 기억하고 내일 다시 와요" if reason=="recommendation" else " · 정돈된 자리가 좋아 내일 다시 와요"

func _return_book(g, v: Dictionary) -> void:
	if v.completed: return
	for loan in loans:
		if loan.id==v.loan_id:
			loan.returned=true
			break
	v.completed=true
	if g.state.get("library_day")!=null: g.state.library_day.returned_loan(g.state,v)
	_change(v,"leave")
	g._notify("잉크가 빌린 책을 반납했어요.")
	# Returned records no longer generate future visits. Keep a short history.
	while loans.size()>32 and loans[0].returned: loans.remove_at(0)
	g._save()

func on_new_day(day: int) -> void:
	current_day=maxi(current_day,day)
	for loan in loans:
		if not loan.returned and not loan.queued and loan.due_day<=current_day:
			loan.queued=true
			return_queue.append(loan.id)

func _depart(g, index: int) -> void:
	var v:=guests[index]
	paths.erase(v.uid)
	guests.remove_at(index)
	if v.kind=="return" and not v.completed:
		# A moved/blocked desk must not strand a checked-out book forever.
		for loan in loans:
			if loan.id==v.loan_id: loan.queued=false
		on_new_day(g.state.day)
	g._save()

func _spawn_return(g) -> bool:
	if return_queue.is_empty() or guests.size()>=capacity() or not _admissions_open(g.state): return false
	var used: Array=[]
	for v in guests: used.append(v.slot)
	var slot:=0
	while slot in used: slot+=1
	if slot>=READING.size() or not _can_visit(g,slot,"return"): return false
	var id: String=return_queue.pop_front()
	for loan in loans:
		if loan.id==id:
			var visitor:=_guest(slot,"return",loan.book,id)
			for key in ["feature","source_host","temperament"]:
				if loan.has(key): visitor[key]=loan[key]
			guests.append(visitor)
			delay=2.0
			g._save()
			return true
	return false

func _free_slot() -> int:
	var used: Array=[]
	for visitor in guests: used.append(visitor.slot)
	for i in range(READING.size()):
		if i not in used: return i
	return -1

func _spawn_appointment(g) -> bool:
	if guests.size()>=capacity() or not _admissions_open(g.state): return false
	var slot:=_free_slot()
	if slot<0: return false
	for index in range(appointments.size()):
		var item:=appointments[index]
		if item.day>g.state.day or item.minute>g.state.minutes: continue
		if not _can_visit(g,slot,item.kind):
			item.retries+=1
			delay=2.0
			if item.retries>=4:
				item.day=g.state.day+1;item.minute=600;item.retries=0
				g._notify("통로가 막혀 예약 손님의 방문을 내일로 옮겼어요. 요금은 받지 않았어요.")
			g._save()
			return false
		appointments.remove_at(index)
		var visitor:=_guest(slot,item.kind,item.book)
		visitor.origin=item.get("origin","natural" if item.source==3 else "promotion")
		visitor.source=item.source
		for key in ["feature","source_host","request","helped","temperament","reason"]:
			if item.has(key): visitor[key]=item[key]
		if visitor.get("request",false): visitor.reading_goal=Preferences.goal_for(int(visitor.temperament),g.state.day,int(visitor.uid))
		if g.state.get("library_day")!=null:
			g.state.library_day.ensure(g.state.day)
			if not guests.is_empty() and not g.state.library_day.noise_used and not visitor.get("request",false):
				visitor.noisy=true;g.state.library_day.noise_used=true
		guests.append(visitor)
		delay=2.0
		g._save()
		return true
	return false

func _next_use(v: Dictionary) -> void:
	_change(v,"to_read" if v.kind=="read" else "to_desk")

func _can_stop(g, v: Dictionary, point: Vector2) -> bool:
	var cell:=Vector2i(floori(point.x/16),floori(point.y/16))
	if not g.navigation.is_in_boundsv(cell) or g.navigation.is_point_solid(cell): return false
	var destination: Vector2=reading_position(v.slot) if v.kind=="read" else desk_position()
	return not _route(g,v.pos,point).is_empty() and not _route(g,point,destination).is_empty()

func advance(g, dt: float) -> void:
	if growth==null or growth.phase!="open" or g.state.scene!="library": return
	dt=clampf(dt,0.0,.15)
	if _scheduled(g.state): g.state.operating.ensure(g.state)
	if current_day!=g.state.day: on_new_day(g.state.day)
	delay=maxf(0.0,delay-dt)
	if topic>=0 and pending>0:
		var ready: bool=not promoting(host) or g._find_object(host).get("promo_ready",false)
		if legacy_campaign:
			if _scheduled(g.state) and (g.state.minutes>=1200 or g.state.operating.closing):
				# A migrated in-flight campaign may cross the new closing cutoff.
				# Preserve every promised guest without admitting them after hours.
				for index in range(pending):
					var old_slot:=batch_size-pending+index
					_book_appointment(g.state,"read" if old_slot%2==0 else "borrow",topic,g.state.day+1,600+index*20)
				pending=0
				g._save()
			elif ready and delay<=0 and _admissions_open(g.state):
				var slot:=batch_size-pending
				var kind: String="read" if slot%2==0 else "borrow"
				if not _can_visit(g,slot,kind):
					spawn_retries+=1;delay=2.0
					if spawn_retries>=4:
						pending=0
						g._notify("서가·열람석·대출 데스크로 가는 길을 비워 주세요. 입장료는 받지 않았어요.")
				else:
					var book: String=g.state.residents[(campaigns+slot-1)%g.state.residents.size()]
					var visitor:=_guest(slot,kind,book)
					visitor.origin="promotion";visitor.source=topic
					guests.append(visitor)
					pending-=1;spawn_retries=0;delay=3.2
					g._save()
		elif ready and not direct_campaign:
			promotion_elapsed+=dt
			if promotion_elapsed>=6.0:
				var completed_topic:=topic
				_complete_promotion(g.state)
				g._notify("잡지를 보고 내일 찾아올 손님이 예약했어요." if completed_topic==1 else "홍보가 끝났어요. 예약 시간에 잉크들이 찾아와요.")
				g._save()
	if delay<=0 and _admissions_open(g.state):
		if not _spawn_return(g): _spawn_appointment(g)
	for i in range(guests.size()-1,-1,-1):
		var v:=guests[i]
		v.elapsed+=dt
		match v.phase:
			"browse":
				# Requests are optional. A visitor resumes ordinary self-service
				# after a short wait, even while the player is promoting elsewhere.
				if v.get("request",false) or v.get("noisy",false):
					if v.elapsed<24.0: continue
					v.request=false;v.noisy=false
				if v.elapsed>=1.6:
					if growth.rank()>=1 and _can_stop(g,v,exhibit_position()): _change(v,"to_exhibit")
					else: _next_use(v)
			"exhibit":
				if v.elapsed>=2.0:
					if growth.rank()>=2 and _can_stop(g,v,record_position()): _change(v,"to_record")
					else: _next_use(v)
			"record":
				if v.elapsed>=1.8: _next_use(v)
			"read":
				if v.elapsed>=growth.reading_seconds()+v.slot*.5: _finish_reading(g,v)
			"checkout":
				if v.elapsed>=1.8: _lend(g,v)
			"checkin":
				if v.elapsed>=1.3: _return_book(g,v)
			_:
				var arrived:=walk(g,v,dt)
				_pay_entry(g,v)
				if v.blocked>=BLOCK_TIMEOUT:
					if v.phase=="leave": _depart(g,i)
					else: _change(v,"leave")
					continue
				if not arrived: continue
				match v.phase:
					"shelf": _change(v,"browse");v.facing="up"
					"to_exhibit": _change(v,"exhibit");v.facing="up"
					"to_record": _change(v,"record");v.facing="up"
					"to_read": _change(v,"read");v.facing="down"
					"to_desk": _change(v,"checkout");v.facing="up"
					"return_desk": _change(v,"checkin");v.facing="up"
					"leave": _depart(g,i)
	if legacy_campaign and topic>=0 and pending==0 and guests.is_empty():
		topic=-1;host="";live_recommendation=false;batch_size=0;legacy_campaign=false
		g._notify("잉크들이 돌아갔어요. 다음 운영 일정을 확인해 주세요.")
		g._save()

func carrying(v: Dictionary) -> bool:
	if v.kind=="return": return v.phase in ["return_desk","checkin"]
	return v.phase in ["to_exhibit","exhibit","to_record","record","to_read","to_desk","checkout"] or (v.kind=="borrow" and v.completed and v.phase=="leave")

func draw_guest(g, v: Dictionary) -> void:
	if not carrying(v):
		super.draw_guest(g,v)
		return
	if carry_texture==null:
		carry_texture=CanvasTexture.new()
		carry_texture.diffuse_texture=load(CARRY_SHEET_PATH)
		carry_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var row:=DIRECTIONS.find(v.facing)
	var frame:=floori(v.distance/4.5)%16 if v.phase in ["to_exhibit","to_record","to_read","to_desk","return_desk","leave"] else 0
	var p: Vector2=v.pos.round()
	var alpha:=smoothstep(0,23,p.distance_to(door_position())) if v.phase=="leave" else 1.0
	if v.phase=="return_desk": alpha=smoothstep(0,23,v.distance)
	g.draw_ellipse_shadow(p+Vector2(0,2),Vector2(13,3)*alpha)
	var anchor:=34 if v.facing in ["up","right"] else 29
	g.draw_texture_rect_region(carry_texture,Rect2(p-Vector2(anchor,57),Vector2(64,64)),Rect2(frame*64,row*64,64,64),Color(1,1,1,alpha))
	Decor.draw_visitor_memory(g,v,growth.rank())

func data() -> Dictionary:
	var visible: Array=[]
	for v in guests:
		var item:=v.duplicate(true)
		item.erase("pos")
		item.x=v.pos.x;item.y=v.pos.y
		visible.append(item)
	return {"version":2,"campaigns":campaigns,"total":total,"topic":topic,"host":host,"pending":pending,"delay":delay,
		"guests":visible,"live_recommendation":live_recommendation,"batch_size":batch_size,"next_uid":next_uid,
		"current_day":current_day,"loans":loans.duplicate(true),"return_queue":return_queue.duplicate(),"spawn_retries":spawn_retries,
		"appointments":appointments.duplicate(true),"next_appointment":next_appointment,"planned_day":planned_day,
		"promotion_elapsed":promotion_elapsed,"campaign_rewarded":campaign_rewarded,"legacy_campaign":legacy_campaign,
		"direct_campaign":direct_campaign,"featured_book":featured_book,"outreach":outreach.data()}

func restore(raw: Variant, residents: Array) -> bool:
	# Decode into temporaries, so a rejected snapshot cannot partly mutate state.
	if not raw is Dictionary or (raw.get("version")!=1 and raw.get("version")!=2): return false
	var decoded_outreach=Outreach.new()
	if raw.has("outreach") and not decoded_outreach.restore(raw.outreach): return false
	if not raw.get("direct_campaign",false) is bool or not number(raw.get("featured_book",0),0,1,true): return false
	if raw.get("direct_campaign",false) and (raw.get("topic",-1)<0 or raw.get("legacy_campaign",false)): return false
	var old: bool=raw.version==1
	for key in ["campaigns","total","pending","batch_size","next_uid","current_day","spawn_retries"]:
		if not number(raw.get(key),0,1e9,true): return false
	if raw.next_uid<1 or raw.current_day<1 or raw.pending>5 or raw.batch_size>5 or raw.spawn_retries>4: return false
	if not number(raw.get("topic"),-1,TOPICS.size()-1,true) or not number(raw.get("delay"),0,3.2): return false
	if not raw.get("host") is String or not raw.get("live_recommendation") is bool: return false
	if raw.topic>=0 and (raw.host not in residents or raw.batch_size<2): return false
	if raw.topic==-1 and (raw.host!="" or raw.pending!=0): return false
	if raw.topic>=0 and raw.pending>raw.batch_size: return false
	if not raw.get("guests") is Array or raw.guests.size()>5 or not raw.get("loans") is Array or not raw.get("return_queue") is Array: return false
	var decoded: Array[Dictionary]=[]
	var used_ids: Array=[]
	var used_slots: Array=[]
	for item in raw.guests:
		if not item is Dictionary: return false
		if not number(item.get("uid"),1,raw.next_uid-1,true) or item.uid in used_ids: return false
		if not number(item.get("slot"),0,4,true) or item.slot in used_slots: return false
		if item.get("phase") not in VISIT_PHASES or item.get("kind") not in ["read","borrow","return"]: return false
		if item.get("facing") not in DIRECTIONS or item.get("book") not in residents or not item.get("loan_id") is String: return false
		if not item.get("admitted") is bool or not item.get("completed") is bool: return false
		if not number(item.get("x"),0 if world_layout else 72,1280 if world_layout else 908) or not number(item.get("y"),0 if world_layout else 252,800 if world_layout else 685): return false
		for key in ["distance","elapsed","blocked"]:
			if not number(item.get(key),0,1e9): return false
		var v: Dictionary=item.duplicate(true)
		if not _valid_activity_fields(item,residents): return false
		if not v.has("origin") and v.has("source_host"): v.origin="promotion"
		v.pos=Vector2(v.x,v.y);v.erase("x");v.erase("y")
		v.uid=int(v.uid);v.slot=int(v.slot)
		used_ids.append(v.uid);used_slots.append(v.slot);decoded.append(v)
	var decoded_loans: Array[Dictionary]=[]
	var ids: Array=[]
	for item in raw.loans:
		if not item is Dictionary or not item.get("id") is String or item.id=="" or item.id in ids: return false
		if not _valid_activity_fields(item,residents): return false
		if item.get("book") not in residents or not number(item.get("due_day"),1,1e9,true): return false
		if not item.get("queued") is bool or not item.get("returned") is bool: return false
		ids.append(item.id);decoded_loans.append(item.duplicate(true))
	var decoded_queue: Array[String]=[]
	for id in raw.return_queue:
		if not id is String or id not in ids or id in decoded_queue: return false
		decoded_queue.append(id)
	for v in decoded:
		if v.kind=="return" and v.loan_id not in ids: return false
		if old and raw.topic>=0 and (v.kind=="return" or v.slot>=raw.batch_size-raw.pending): return false
		if old and raw.topic==-1 and v.kind!="return": return false
	for loan in decoded_loans:
		var active_return:=false
		for v in decoded:
			if v.kind=="return" and v.loan_id==loan.id: active_return=true
		if loan.returned and loan.id in decoded_queue: return false
		if not loan.returned and loan.queued and loan.id not in decoded_queue and not active_return: return false
	var decoded_appointments: Array[Dictionary]=[]
	var appointment_ids: Array=[]
	if not old:
		if not raw.get("appointments") is Array or raw.appointments.size()>128: return false
		if not number(raw.get("next_appointment"),1,1e9,true) or not number(raw.get("planned_day"),0,1e9,true): return false
		if not number(raw.get("promotion_elapsed"),0,6.15): return false
		if not raw.get("campaign_rewarded") is bool or not raw.get("legacy_campaign") is bool: return false
		for item in raw.appointments:
			if not item is Dictionary: return false
			if not _valid_activity_fields(item,residents): return false
			if not number(item.get("id"),1,raw.next_appointment-1,true) or item.id in appointment_ids: return false
			if item.get("kind") not in ["read","borrow"] or item.get("book") not in residents: return false
			if not number(item.get("source"),0,3,true) or not number(item.get("day"),1,1e9,true): return false
			if not number(item.get("minute"),600,1190,true) or not number(item.get("retries"),0,3,true): return false
			appointment_ids.append(item.id);decoded_appointments.append(item.duplicate(true))
	campaigns=int(raw.campaigns);total=int(raw.total);topic=int(raw.topic);host=raw.host
	pending=int(raw.pending);delay=float(raw.delay);batch_size=int(raw.batch_size);next_uid=int(raw.next_uid)
	current_day=int(raw.current_day);spawn_retries=int(raw.spawn_retries);live_recommendation=raw.live_recommendation
	guests=decoded;loans=decoded_loans;return_queue=decoded_queue;paths.clear()
	appointments=decoded_appointments
	next_appointment=1 if old else int(raw.next_appointment)
	planned_day=0 if old else int(raw.planned_day)
	promotion_elapsed=0.0 if old else float(raw.promotion_elapsed)
	campaign_rewarded=false if old else raw.campaign_rewarded
	legacy_campaign=(topic>=0) if old else raw.legacy_campaign
	direct_campaign=raw.get("direct_campaign",false)
	featured_book=int(raw.get("featured_book",0))
	outreach=decoded_outreach
	return true

static func _valid_activity_fields(item: Dictionary, residents: Array) -> bool:
	if item.has("origin") and item.origin not in Outreach.ORIGINS: return false
	if item.has("source") and not number(item.source,0,3,true): return false
	if item.has("reading_goal") and not number(item.reading_goal,0,1,true): return false
	if item.has("reason") and item.reason not in ["care","recommendation"]: return false
	if item.has("temperament") and not number(item.temperament,0,Preferences.TEMPERAMENTS.size()-1,true): return false
	if item.has("feature") and not number(item.feature,0,1,true): return false
	if item.has("source_host") and item.source_host not in residents: return false
	for key in ["request","helped","noisy"]:
		if item.has(key) and not item[key] is bool: return false
	return true

