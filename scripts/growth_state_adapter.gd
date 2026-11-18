extends "res://scripts/game_state.gd"

# Growth state used by the main game and the isolated review scene. Legacy
# saves are decoded in memory; callers decide where to write the new slot.
const Growth = preload("res://scripts/library_growth.gd")
const Visitors = preload("res://scripts/growth_visitors.gd")
const Catalogue = preload("res://assets/records/growth_costumes.json")
const OperatingDay = preload("res://scripts/operating_day.gd")
const WorldLayout = preload("res://scripts/library_world_layout.gd")
const LibraryDay = preload("res://scripts/library_day_state.gd")
var library_day := LibraryDay.new()
var growth := Growth.new()
var operating := OperatingDay.new()
var migrated_from_legacy := false
var world_enabled := false
var world_player := WorldLayout.ENTRY

func enable_world_layout() -> void:
	if world_enabled: return
	world_enabled=true
	world_player=WorldLayout.ENTRY
	player=world_player
	for item in furniture:
		var point: Vector2=WorldLayout.FURNITURE[item.kind]
		item.x=point.x;item.y=point.y
	ink_visits.world_layout=true
	for guest in ink_visits.guests:
		guest.pos=ink_visits.world_pose(guest)
	ink_visits.paths.clear()

func _init() -> void:
	growth.set_costume_catalog(Catalogue.data)
	ink_visits=Visitors.new()
	ink_visits.bind_growth(growth)

func rebuild_stage() -> int:
	if growth.phase=="open": return 6
	return mini(5,growth.completed_tasks.size()*2)

func library_rank() -> String:
	if growth.phase=="recruiting": return "스텔라를 기다리는 도서관"
	if growth.phase=="rebuilding": return "함께 다시 짓는 도서관"
	if growth.phase=="ready": return "첫 손님을 맞을 준비 완료"
	return growth.rank_name()

func record_chapter_step(id: String, step: int) -> bool:
	var changed:=super.record_chapter_step(id,step)
	if changed and residents.size()==6:
		opening_pending=false
		growth.begin_rebuild(residents.size())
	return changed

func place_furniture(kind: String, point: Vector2) -> String:
	if kind not in growth.owned_furniture: return "의문의 장인에게 이 가구를 먼저 구매해 주세요."
	if world_enabled:
		var p:=point.snapped(Vector2(16,16))
		var error:=WorldLayout.placement_error(furniture,kind,p)
		if error!="": return error
		var old:=Furniture.find(furniture,kind)
		var enabled: bool=old.get("enabled",true)
		furniture=furniture.filter(func(item): return item.kind!=kind)
		furniture.append({"kind":kind,"x":p.x,"y":p.y,"enabled":enabled})
		return ""
	return super.place_furniture(kind,point)

func complete_reconstruction_task(id: String) -> bool:
	if not growth.complete_task(id): return false
	if id=="shelves": _register_completed_books(self)
	return true

func finish_activity(id: String, kind: String, reply: int=-1, routine: String="rope") -> int:
	# Personal chat still records fan memories. Global light is settled once by
	# an accepted promotional broadcast, sharing the same two daily slots.
	return super.finish_activity(id,kind,reply,routine)

func talk(id: String) -> bool:
	var before:=minutes
	var changed:=super.talk(id)
	if growth.phase=="open": minutes=before
	return changed

func library_calendar(day_override: int=-1) -> Dictionary:
	return Growth.calendar((day if day_override<0 else day_override)+operating.calendar_offset)

func advance_operating_time(seconds: float) -> bool:
	if growth.phase!="open": return false
	return operating.advance(self,seconds)

func request_day_close() -> String:
	if growth.phase!="open": return "재개관한 뒤 영업을 마감할 수 있어요."
	operating.ensure(self)
	operating.closing=true
	ink_visits.defer_waiting(day+1)
	return "신규 입장을 마쳤어요. 이용 중인 손님과 홍보가 끝나면 오늘을 결산해요."

func day_close_ready() -> bool:
	return growth.phase=="open" and operating.closing and ink_visits.topic<0 and ink_visits.guests.is_empty()

func finish_operating_day() -> bool:
	if not day_close_ready() or day>=9999: return false
	ink_visits.defer_waiting(day+1)
	operating.last_summary=operating.summary(self)
	super.sleep()
	if world_enabled: player=WorldLayout.ENTRY;world_player=player
	ink_visits.on_new_day(day)
	operating.begin(self)
	library_day.ensure(day)
	return true

func next_event_minutes() -> int:
	var next:=OperatingDay.END
	if minutes<OperatingDay.OPEN: next=OperatingDay.OPEN
	if minutes<840 and 1 not in operating.used_slots: next=mini(next,840)
	if minutes<OperatingDay.LAST_ENTRY: next=mini(next,OperatingDay.LAST_ENTRY)
	for appointment in ink_visits.appointments:
		if appointment.day<=day and appointment.minute>minutes: next=mini(next,appointment.minute)
	return next

func promotion_wait_target() -> int:
	# Only offer the shortcut between promotion windows. Never skip a window
	# that can be used now, an active visit, or an earlier booked arrival.
	if growth.phase!="open": return -1
	operating.ensure(self)
	if operating.closing or ink_visits.topic>=0 or not ink_visits.guests.is_empty() or ink_visits.has_due_arrivals(self): return -1
	if minutes<OperatingDay.OPEN and 0 not in operating.used_slots: return next_event_minutes()
	if minutes<840 and 1 not in operating.used_slots and (minutes>=780 or 0 in operating.used_slots): return next_event_minutes()
	return -1

func wait_until_next_event() -> String:
	if growth.phase!="open": return "재개관 후의 영업 일정을 기다릴 수 있어요."
	operating.ensure(self)
	if operating.closing: return "손님이 마무리되면 오늘 결산을 확인해 주세요."
	if ink_visits.topic>=0 or not ink_visits.guests.is_empty(): return "홍보와 이용 중인 손님을 먼저 지켜봐 주세요."
	if ink_visits.has_due_arrivals(self): return "도착한 손님을 먼저 맞이해 주세요."
	minutes=maxi(minutes,next_event_minutes())
	operating.fraction=0.0
	if minutes>=OperatingDay.LAST_ENTRY: ink_visits.defer_waiting(day+1)
	if minutes>=OperatingDay.END: operating.closing=true
	return "%02d:%02d · 다음 일정까지 기다렸어요."%[minutes/60,minutes%60]

func operating_summary() -> Dictionary:
	if growth.phase=="open": operating.ensure(self)
	var result:=operating.summary(self)
	result.closing=operating.closing
	result.ready=day_close_ready()
	result.remaining_slots=2-operating.used_slots.size()
	result.loans=ink_visits.loans.filter(func(loan): return not loan.returned).size()
	result.next_event_minutes=next_event_minutes()
	result.next_event_label="%02d:%02d"%[result.next_event_minutes/60,result.next_event_minutes%60]
	return result

func sleep() -> void:
	# Keep one already-promised legacy return settlement (bookmarks only).
	# super clears that loan, so subsequent nights cannot pay it again.
	if growth.phase=="open":
		request_day_close()
		finish_operating_day()
	else:
		super.sleep()
		if world_enabled: player=WorldLayout.ENTRY;world_player=player
		ink_visits.on_new_day(day)

func lend_book(_index: int) -> String:
	return "책 대출은 방문한 잉크가 대출 데스크에서 직접 진행해요."

func to_data() -> Dictionary:
	var result:=super.to_data()
	result.ink_visits=InkVisits.new().data()
	result.library_growth=growth.data()
	result.growth_visitors=ink_visits.data()
	result.operating_day=operating.data()
	result.library_day=library_day.data()
	if world_enabled:
		result.library_world={"version":WorldLayout.VERSION,"x":world_player.x,"y":world_player.y,"furniture":furniture.duplicate(true)}
		# Keep the legacy portion decodable without clamping or losing ownership.
		result.furniture=furniture.duplicate(true)
		for item in result.furniture:
			var p: Vector2=Furniture.DEFAULTS[Furniture.ORDER.find(item.kind)]
			item.x=p.x;item.y=p.y
		result.x=490;result.y=620
	return result

static func _valid_world(raw: Dictionary,owners: Array,resident_count: int) -> bool:
	if not raw.has("library_world"): return true
	var data=raw.library_world
	if not data is Dictionary or data.get("version")!=WorldLayout.VERSION: return false
	for key in ["x","y"]:
		if not data.get(key) is int and not data.get(key) is float: return false
		if not is_finite(float(data[key])): return false
	var p:=Vector2(data.x,data.y)
	if not Rect2(0,0,2560,800).has_point(p) or (WorldLayout.private_point(p) and resident_count<6): return false
	if not data.get("furniture") is Array or data.furniture.size()>4: return false
	if not raw.get("furniture") is Array or data.furniture.size()!=raw.furniture.size(): return false
	var checked: Array=[]
	for item in data.furniture:
		if not item is Dictionary or item.get("kind","") not in owners or not item.get("enabled") is bool: return false
		if not Furniture.find(checked,item.kind).is_empty(): return false
		var legacy:=Furniture.find(raw.furniture,item.kind)
		if legacy.is_empty() or legacy.enabled!=item.enabled: return false
		for key in ["x","y"]:
			if not item.get(key) is int and not item.get(key) is float: return false
			if not is_finite(float(item[key])): return false
		var at:=Vector2(item.x,item.y)
		if at!=at.snapped(Vector2(16,16)) or WorldLayout.placement_error(checked,item.kind,at)!="": return false
		checked.append(item)
	return true

func apply_data(raw: Variant) -> bool:
	if not raw is Dictionary or not _valid_base_numbers(raw): return false
	var modern: bool=raw.has("library_growth")
	if raw.has("growth_visitors")!=modern: return false
	if modern and raw.library_growth is Dictionary and raw.library_growth.get("version")==Growth.VERSION and not raw.has("operating_day"): return false
	var clean: Dictionary=raw.duplicate(true)
	if modern: clean.ink_visits=InkVisits.new().data()
	var ordinary:=LibraryState.new()
	if not ordinary.apply_data(clean): return false
	if raw.get("version",0)<3:
		# The oldest format inferred unlocked residents without chapter_steps.
		# Preserve those unlocks when moving to the explicit chapter format.
		for id in ordinary.residents: ordinary.chapter_steps[id]=3
	for id in ordinary.residents:
		if ordinary.chapter_steps.get(id,0)!=3: return false
	if raw.get("version",0)>=3 and ordinary.residents.size()!=raw.residents.size(): return false
	var candidate:=Growth.new()
	candidate.set_costume_catalog(Catalogue.data)
	var visitors:=Visitors.new()
	visitors.world_layout=raw.has("library_world")
	visitors.bind_growth(candidate)
	var schedule:=OperatingDay.new()
	if raw.has("operating_day"):
		if not modern or not schedule.restore(raw.operating_day,ordinary.day): return false
	else:
		# Keep absolute days monotonic for loans, activity stamps and event IDs.
		# Only the displayed calendar is compressed from 28 to 7 days/season.
		var old_index:=ordinary.day-1
		var new_index:=floori(old_index/112.0)*28+floori((old_index%112)/28.0)*7+floori((old_index%28)/4.0)
		schedule.calendar_offset=new_index+1-ordinary.day
	if modern:
		if not candidate.restore(raw.library_growth): return false
		if (candidate.phase=="recruiting")== (ordinary.residents.size()==6): return false
		if candidate.gold+candidate.spent_total!=candidate.income_total: return false
		if candidate.phase!="open" and (candidate.income_total>0 or candidate.memory_light>0 or not candidate.upgrades.is_empty()): return false
		if raw.get("opening_pending",false): return false
		for item in ordinary.furniture:
			if item.kind not in candidate.owned_furniture: return false
		if not _valid_equipment(raw,ordinary,candidate): return false
		if not visitors.restore(raw.growth_visitors,ordinary.residents): return false
	else:
		# Keep an already-open legacy library open; six recruits still waiting
		# for their old opening scene now enter the first reconstruction.
		if ordinary.residents.size()==6:
			candidate.begin_rebuild(6)
			if not ordinary.opening_pending:
				for task in Growth.TASKS: candidate.complete_task(task)
				candidate.open_library()
		for item in ordinary.furniture:
			if item.kind not in candidate.owned_furniture: candidate.owned_furniture.append(item.kind)
		for id in ordinary.costumes:
			var key: String=ordinary.costumes[id]
			if key!=Wardrobe.COSTUMES[id].keys()[0] and key not in candidate.owned_costumes:
				candidate.owned_costumes.append(key)
		if not _migrate_visitors(ordinary,visitors): return false
	if candidate.phase!="open" and (visitors.topic>=0 or not visitors.guests.is_empty() or not visitors.loans.is_empty() or not visitors.return_queue.is_empty() or not visitors.appointments.is_empty()): return false
	if visitors.current_day>ordinary.day or visitors.planned_day>ordinary.day: return false
	if visitors.outreach.day>ordinary.day: return false
	if schedule.day>0 and (schedule.start_income>candidate.income_total or schedule.start_spent>candidate.spent_total or schedule.start_light>candidate.memory_light or schedule.start_visitors>visitors.total): return false
	if schedule.opening_rank>candidate.rank(): return false
	if visitors.topic>=0 and not visitors.legacy_campaign and visitors.topic not in schedule.used_topics: return false
	if candidate.phase!="open" and (schedule.closing or not schedule.used_slots.is_empty()): return false
	if visitors.promoting(ordinary.yard_host) or visitors.promoting(ordinary.yard_session.get("member","")): return false
	if "shelves" in candidate.completed_tasks: _register_completed_books(ordinary)
	if not _valid_world(raw,candidate.owned_furniture,ordinary.residents.size()): return false
	# Validate everything on detached objects before committing the base state.
	var activities:=LibraryDay.new()
	if raw.has("library_day") and not activities.restore(raw.library_day,ordinary.residents,ordinary.day): return false
	if visitors.direct_campaign!=(not activities.direct.is_empty()): return false
	if not activities.direct.is_empty():
		if candidate.phase!="open" or not raw.has("library_world"): return false
		if activities.direct.member!=visitors.host or activities.direct.topic!=visitors.topic or activities.direct.campaign!=visitors.campaigns: return false
	# Use the canonical decoded data so version 1/2 chapter inference survives.
	clean=ordinary.to_data()
	clean.ink_visits=InkVisits.new().data()
	clean.opening_pending=false
	if not super.apply_data(clean): return false
	growth=candidate
	ink_visits=visitors
	operating=schedule
	library_day=activities
	world_enabled=raw.has("library_world")
	ink_visits.world_layout=world_enabled
	if world_enabled:
		world_player=Vector2(raw.library_world.x,raw.library_world.y)
		player=world_player
		furniture=raw.library_world.furniture.duplicate(true)
	opening_pending=false
	migrated_from_legacy=not modern
	return true

static func _register_completed_books(target: LibraryState) -> void:
	for id in target.residents:
		if target.chapter_steps.get(id,0)==3 and id not in target.restored: target.restored.append(id)

static func _valid_base_numbers(raw: Dictionary) -> bool:
	for key in ["day","minutes","energy","x","y"]:
		var value: Variant=raw.get(key)
		if (not value is int and not value is float) or not is_finite(float(value)): return false
	if raw.day!=floor(raw.day) or raw.day<1 or raw.day>9999: return false
	if raw.has("opening_pending") and not raw.opening_pending is bool: return false
	if not raw.get("friendship") is Dictionary: return false
	for value in raw.friendship.values():
		if (not value is int and not value is float) or not is_finite(float(value)): return false
	for key in ["bookmarks","total_loans"]:
		if raw.has(key):
			var value: Variant=raw[key]
			if not Growth._count(value,999999): return false
	if raw.get("active_loan") is Dictionary and not raw.active_loan.is_empty():
		if not Growth._count(raw.active_loan.get("due_day"),999999999) or raw.active_loan.due_day<1: return false
	return true

static func _valid_equipment(raw: Dictionary, ordinary: LibraryState, candidate: RefCounted) -> bool:
	if not raw.get("furniture") is Array or raw.furniture.size()!=ordinary.furniture.size(): return false
	if not raw.get("costumes") is Dictionary: return false
	var known: Array=[]
	for member in Wardrobe.COSTUMES: known.append_array(Wardrobe.COSTUMES[member].keys())
	for key in candidate.owned_costumes:
		if key not in known: return false
	for member in raw.costumes:
		if member not in Wardrobe.COSTUMES or raw.costumes[member] not in Wardrobe.COSTUMES[member]: return false
		if raw.costumes[member]!=Wardrobe.COSTUMES[member].keys()[0] and raw.costumes[member] not in candidate.owned_costumes: return false
	return true

static func _migrate_visitors(ordinary: LibraryState, target: RefCounted) -> bool:
	var old: RefCounted=ordinary.ink_visits
	var converted: Dictionary=target.data()
	converted.campaigns=old.campaigns
	converted.total=old.total
	converted.current_day=ordinary.day
	if old.topic>=0:
		converted.legacy_campaign=true
		converted.topic=old.topic
		converted.host=old.host
		converted.pending=old.pending
		converted.delay=old.delay
		converted.live_recommendation=old.live_recommendation
		converted.batch_size=old.group_size()
		for guest in old.guests:
			var id: int=converted.next_uid
			converted.next_uid=id+1
			converted.guests.append({"uid":id,"slot":guest.slot,"kind":"read","origin":"promotion","source":old.topic,
				"book":ordinary.residents[(old.campaigns+guest.slot-1)%ordinary.residents.size()],
				"loan_id":"","phase":guest.phase,"x":guest.pos.x,"y":guest.pos.y,
				"facing":guest.facing,"distance":guest.distance,"elapsed":guest.elapsed,
				"blocked":0.0,"admitted":true,"completed":guest.phase=="leave"})
	# Existing guests were already counted on their legacy arrival. Their
	# admitted flag prevents a retroactive entrance fee or duplicate total.
	return target.restore(converted,ordinary.residents)
