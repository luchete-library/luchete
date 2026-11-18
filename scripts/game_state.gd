class_name LibraryState
extends RefCounted

const Wardrobe = preload("res://scripts/wardrobe.gd")
const DoriCase = preload("res://scripts/dori_investigation.gd")
const YuneDream = preload("res://scripts/yune_dream.gd")
const DanmingWorkshop = preload("res://scripts/danming_workshop.gd")
const KubbyEmbers = preload("res://scripts/kubby_embers.gd")
const YatoForest = preload("res://scripts/yato_forest.gd")
const FuwaSnow = preload("res://scripts/fuwa_snow.gd")
const FuwaProgress = preload("res://scripts/fuwa_adventure/progress.gd")
const StellaProgress = preload("res://scripts/stella_adventure/chapters.gd")
const InkVisits = preload("res://scripts/ink_visitors.gd")
var ink_visits := InkVisits.new()
const SAVE_PATH := "user://library_valley_v1.json"
const REQUESTS := [
	{"id":"first_book","name":"첫 책에 불을 켜 주세요","description":"책 1권을 복원하기","reward":40,"daily":false},
	{"id":"all_books","name":"여섯 이야기의 서가","description":"책 6권을 모두 복원하기","reward":80,"daily":false},
	{"id":"daily_chat","name":"스텔라에게 안부를","description":"오늘 서로 다른 3명과 대화하기","reward":15,"daily":true}
]
const BOOKS := [
	{"id":"yato", "name":"토끼 숲의 길잡이", "owner":"야토", "color":"e9a65a"},
	{"id":"danming", "name":"마음을 잇는 편지", "owner":"오단밍", "color":"e69aa5"},
	{"id":"kubby", "name":"도깨비불의 온도", "owner":"햄쿠비", "color":"9ab99c"},
	{"id":"yune", "name":"잃어버린 꿈의 목록", "owner":"아미하 유네", "color":"b39bdf"},
	{"id":"dori", "name":"사라진 문장의 행방", "owner":"쇼코코 도리", "color":"d8a88a"},
	{"id":"fuwa", "name":"눈산 너머의 약속", "owner":"하쿠텐 후와", "color":"91cce3"}
]
var day: int = 1
var minutes: int = 540
var energy: int = 100
var restored: Array = []
var talked_today: Array = []
var friendship: Dictionary = {"yato":0,"danming":0,"kubby":0,"yune":0,"dori":0,"fuwa":0}
var scene: String = "library"
var player: Vector2 = Vector2(490, 620)
var intro_seen: bool = false
var costumes: Dictionary = {}
var story_choices: Dictionary = {}
var read_bonds: Dictionary = {}
var residents: Array = []
var fan_form := ""
const Workout = preload("res://scripts/workout.gd")
const EMPTY_ACTIVITY := {"memory":0,"stream_day":0,"workout_day":0,"prepared":false,"reply":-1,"last_workout":"rope"}
var activities: Dictionary = {}
var yard_session: Dictionary = {}
var yard_host := ""
const Furniture = preload("res://scripts/garden_furniture.gd")
var furniture: Array = []
# Four read-only memories; retain the earlier step encoding for save compatibility.
var chapter_steps: Dictionary = {}
var marked_actions: Array = []
var dori_notes: Array = []
var yune_notes: Array = []
var danming_notes: Array = []
var kubby_notes: Array = []
var yato_notes: Array = []
var fuwa_notes: Array = []
var fuwa_adventure: Dictionary = {}
var stella_adventures: Dictionary = {}
var chapter_routes: Dictionary = {}
var active_mission := ""
var page_complete := false
var opening_pending := false
var bookmarks: int = 0
var claimed_requests: Array = []
var active_loan: Dictionary = {}
var loan_today: bool = false
var total_loans: int = 0

const BOND_NAMES := ["알아가는 사이", "편한 친구", "가까운 친구"]

func wear_fan_form(id: String) -> bool:
	if id != "" and id not in residents: return false
	fan_form = id
	return true

func place_furniture(kind: String, point: Vector2) -> String:
	if residents.is_empty(): return "스텔라를 한 명 맞이한 뒤 도서관을 꾸며요."
	var p := point.snapped(Vector2(16,16))
	var error := Furniture.placement_error(furniture,kind,p)
	if error!="": return error
	var old := Furniture.find(furniture,kind)
	var enabled: bool = old.get("enabled",true)
	furniture = furniture.filter(func(item): return item.kind!=kind)
	furniture.append({"kind":kind,"x":int(p.x),"y":int(p.y),"enabled":enabled})
	return ""

func store_furniture(kind: String) -> bool:
	var item := Furniture.find(furniture,kind)
	if item.is_empty(): return false
	furniture.erase(item)
	return true

func toggle_furniture(kind: String) -> bool:
	var item := Furniture.find(furniture,kind)
	if item.is_empty(): return false
	item.enabled = not item.enabled
	return true

func activity_record(id: String) -> Dictionary:
	return activities.get(id,EMPTY_ACTIVITY)

func begin_yard_session(id: String, routine: String) -> bool:
	if not yard_session.is_empty() or not can_do_activity(id,"workout") or not Workout.ROUTINES.has(routine): return false
	yard_session = {"member":id,"routine":routine,"elapsed":0.0}
	if yard_host == id: yard_host = ""
	return true

func advance_yard_session(delta: float) -> int:
	if yard_session.is_empty(): return 0
	yard_session.elapsed += delta
	if yard_session.elapsed < Workout.DURATION: return 0
	var completed := yard_session
	yard_session = {}
	return finish_activity(completed.member,"workout",-1,completed.routine)

func can_do_activity(id: String, kind: String) -> bool:
	return id in residents and not ink_visits.promoting(id) and kind in ["stream","workout"] and activity_record(id)[kind+"_day"] != day

func finish_activity(id: String, kind: String, reply: int = -1, routine: String = "rope") -> int:
	if not can_do_activity(id,kind) or (kind == "stream" and reply not in [0,1]): return 0
	if kind == "workout" and not Workout.ROUTINES.has(routine): return 0
	var record := activity_record(id).duplicate()
	var gain := 1
	if kind == "stream":
		gain = 3 if record.prepared else 2
		record.reply = reply
	else:
		record.last_workout = routine
		friendship[id] = mini(int(friendship[id])+1,10)
	record.prepared = kind == "workout"
	record[kind+"_day"] = day
	record.memory += gain
	activities[id] = record
	return gain

func bond_tier(id: String) -> int:
	var score := int(friendship[id])
	if score >= 8: return 2
	if score >= 4: return 1
	return 0

func request_claim_key(index: int) -> String:
	var request: Dictionary = REQUESTS[index]
	return request.id + ("_%d" % day if request.daily else "")

func request_ready(index: int) -> bool:
	match index:
		0: return restored.size() >= 1
		1: return restored.size() >= 6
		2: return talked_today.size() >= 3
	return false

func claim_request(index: int) -> String:
	if index < 0 or index >= REQUESTS.size(): return "존재하지 않는 의뢰예요."
	var key := request_claim_key(index)
	if key in claimed_requests: return "이미 보상을 받았어요."
	if not request_ready(index): return "아직 의뢰 조건을 채우지 못했어요."
	claimed_requests.append(key)
	bookmarks += REQUESTS[index].reward
	return ""

func requested_book_index() -> int:
	return (day - 1) % BOOKS.size()

func visitor_name() -> String:
	return ["숲길의 여행자","편지를 기다리는 독자","작은 등불 장인","꿈을 기록하는 아이","길 잃은 수습 탐정","눈산의 순례자"][requested_book_index()]

func lend_book(index: int) -> String:
	if index < 0 or index >= BOOKS.size(): return "책을 먼저 골라 주세요."
	if not active_loan.is_empty() or loan_today: return "오늘의 대출은 이미 접수했어요."
	if index != requested_book_index(): return "손님이 찾는 이야기는 다른 책이에요."
	if not BOOKS[index].id in restored: return "찾는 책을 먼저 작업대에서 복원해 주세요."
	if not spend_energy(2,20): return "기운이 부족해요. 차를 마시거나 쉬어 주세요."
	active_loan = {"book_id":BOOKS[index].id,"due_day":day+1,"visitor":visitor_name()}
	loan_today = true
	return ""

func buy_tea() -> String:
	if energy >= 100: return "이미 기운이 가득해요."
	if bookmarks < 15: return "차 한 잔에는 책갈피 15개가 필요해요."
	bookmarks -= 15
	energy = mini(100,energy+30)
	return ""

func rebuild_stage() -> int:
	return chapter_steps.values().count(3)

func library_rank() -> String:
	return ["먼지 쌓인 열람실","첫 등불이 켜진 서가","햇살이 드는 서가","온기가 도는 열람실","이야기가 모이는 서가","별빛 가득한 열람실","다시 문을 연 루체테"][rebuild_stage()]

func remember_choice(id: String, choice: int) -> bool:
	if not id in residents or story_choices.has(id) or choice < 0 or choice > 1:
		return false
	story_choices[id] = choice
	return true

func spend_energy(amount: int, time_cost: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	minutes = mini(minutes + time_cost, 1320)
	return true

func talk(id: String) -> bool:
	if not id in residents or id in talked_today:
		return false
	talked_today.append(id)
	friendship[id] = mini(int(friendship[id]) + 1, 10)
	minutes = mini(minutes + 10, 1320)
	return true

func accept_mission(id: String) -> bool:
	if not friendship.has(id) or chapter_steps.get(id,0) == 3 or (page_complete and active_mission != id):
		return false
	active_mission = id
	return true

func seal_page(id: String) -> bool:
	if active_mission != id or chapter_steps.get(id,0) != 2 or page_complete: return false
	page_complete = true
	return true

func debut_scene(id: String) -> int:
	var step := int(chapter_steps.get(id,0))
	if step == 0: return 0
	if step == 1: return 2 if id in marked_actions else 1
	return 3

func chapter_ready(id: String, index: int) -> bool:
	if index<0 or index>3: return false
	match id:
		"dori": return DoriCase.ready(index,dori_notes)
		"yune": return YuneDream.ready(index,yune_notes)
		"danming": return DanmingWorkshop.ready(index,danming_notes)
		"kubby": return KubbyEmbers.ready(index,kubby_notes)
		"yato": return YatoForest.ready(index,yato_notes)
		"fuwa": return FuwaSnow.ready(index,fuwa_notes)
	return false

func route_pending(id: String) -> bool:
	var index:=debut_scene(id)
	return index<3 and chapter_routes.get(id,-1)==index and chapter_ready(id,index)

func open_chapter_route(id: String) -> bool:
	if active_mission!=id or page_complete or debut_scene(id)>=3 or not chapter_ready(id,debut_scene(id)): return false
	chapter_routes[id]=debut_scene(id)
	return true

func mark_first_action(id: String) -> bool:
	if active_mission != id or chapter_steps.get(id,0) != 1 or id in marked_actions: return false
	marked_actions.append(id)
	chapter_routes.erase(id)
	return true

func record_chapter_step(id: String, step: int) -> bool:
	if active_mission != id or not friendship.has(id) or step < 0 or step >= 3 or chapter_steps.get(id,0) != step:
		return false
	if step == 1:
		if not id in marked_actions: return false
		marked_actions.erase(id)
	if step == 2:
		if not page_complete: return false
		active_mission = ""
		page_complete = false
	chapter_steps[id] = step + 1
	chapter_routes.erase(id)
	if step == 2 and not id in residents:
		residents.append(id)
	if step == 2 and rebuild_stage() == BOOKS.size():
		opening_pending = true
	return true

func complete_fuwa_adventure() -> bool:
	# Only the arrived checkpoint can finish the new route. Existing step
	# encoding is kept so shelves, transformations and growth share one unlock.
	if active_mission!="fuwa" or "fuwa" in residents or chapter_steps.get("fuwa",0)>=3: return false
	if FuwaProgress.clean(fuwa_adventure).get("stage","")!="arrived": return false
	if chapter_steps.get("fuwa",0)==0: record_chapter_step("fuwa",0)
	if chapter_steps.get("fuwa",0)==1:
		if "fuwa" not in marked_actions: mark_first_action("fuwa")
		record_chapter_step("fuwa",1)
	if not page_complete: seal_page("fuwa")
	return record_chapter_step("fuwa",2)

func complete_stella_adventure(id: String) -> bool:
	if not StellaProgress.CHAPTERS.has(id) or active_mission!=id or id in residents or chapter_steps.get(id,0)>=3: return false
	if StellaProgress.clean(id,stella_adventures.get(id,{})).get("phase","")!="arrived": return false
	if chapter_steps.get(id,0)==0: record_chapter_step(id,0)
	if chapter_steps.get(id,0)==1:
		if id not in marked_actions: mark_first_action(id)
		record_chapter_step(id,1)
	if not page_complete: seal_page(id)
	return record_chapter_step(id,2)

func restore_book(index: int) -> String:
	if index < 0 or index >= BOOKS.size():
		return "책을 선택해 주세요."
	var book: Dictionary = BOOKS[index]
	if not book.id in residents:
		return "시작의 서가에서 이 책을 체험하고 스텔라를 먼저 맞이해요."
	if book.id in restored:
		return "이미 복원한 책이에요."
	if not spend_energy(12, 40):
		return "기운이 부족해요. 휴식 의자에서 다음 날을 시작해요."
	restored.append(book.id)
	friendship[book.id] = mini(int(friendship[book.id]) + 2, 10)
	return ""

func sleep() -> void:
	yard_session = {}
	yard_host = ""
	day += 1
	if not active_loan.is_empty() and day >= int(active_loan.due_day):
		bookmarks += 20
		total_loans += 1
		active_loan.clear()
	loan_today = false
	claimed_requests = claimed_requests.filter(func(key): return not str(key).begins_with("daily_"))
	minutes = 540
	energy = 100
	talked_today.clear()
	scene = "library"
	player = Vector2(175, 625)

func to_data() -> Dictionary:
	return {"version":7,"chapter_routes":chapter_routes.duplicate(),"ink_visits":ink_visits.data(),"active_mission":active_mission,"page_complete":page_complete,"residents":residents.duplicate(),"chapter_steps":chapter_steps.duplicate(),"opening_pending":opening_pending,"day":day,"minutes":minutes,"energy":energy,
		"fan_form":fan_form,"activities":activities.duplicate(true),"yard_session":yard_session.duplicate(),"yard_host":yard_host,"furniture_room":"library","furniture":furniture.duplicate(true),"marked_actions":marked_actions.duplicate(),"restored":restored.duplicate(),
		"dori_notes":dori_notes.duplicate(),"yune_notes":yune_notes.duplicate(),"danming_notes":danming_notes.duplicate(),"talked_today":talked_today.duplicate(),
		"kubby_notes":kubby_notes.duplicate(),
		"yato_notes":yato_notes.duplicate(),
		"fuwa_notes":fuwa_notes.duplicate(),"fuwa_adventure":fuwa_adventure.duplicate(true),
		"stella_adventures":stella_adventures.duplicate(true),
		"friendship":friendship.duplicate(),"scene":scene,"x":player.x,"y":player.y,"intro_seen":intro_seen,"story_choices":story_choices.duplicate(),"costumes":costumes.duplicate(),"read_bonds":read_bonds.duplicate(),
		"bookmarks":bookmarks,"claimed_requests":claimed_requests.duplicate(),"active_loan":active_loan.duplicate(),"loan_today":loan_today,"total_loans":total_loans}

func apply_data(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0) not in [1,1.0,2,2.0,3,3.0,4,4.0,5,5.0,6,6.0,7,7.0]:
		return false
	if data.version >= 3:
		if not data.get("residents") is Array or not data.get("chapter_steps") is Dictionary: return false
		for id in data.residents:
			if not friendship.has(id): return false
		for id in data.chapter_steps:
			var step = data.chapter_steps[id]
			if not friendship.has(id) or (not step is int and not step is float): return false
			if step != int(step) or step < 0 or step > 3 or (step == 3 and not id in data.residents): return false
	if data.version >= 4:
		var mission = data.get("active_mission")
		if not mission is String or not data.get("page_complete") is bool: return false
		if mission != "" and (not friendship.has(mission) or data.chapter_steps.get(mission,0) == 3): return false
		if data.page_complete and (mission == "" or data.chapter_steps.get(mission,0) != 2): return false
	if data.version >= 2:
		for key in ["bookmarks","total_loans"]:
			if not data.get(key) is float and not data.get(key) is int: return false
		if not data.get("claimed_requests") is Array or not data.get("active_loan") is Dictionary or not data.get("loan_today") is bool: return false
		if not data.active_loan.is_empty():
			if not data.active_loan.get("book_id") is String or not friendship.has(data.active_loan.book_id): return false
			if not data.active_loan.get("due_day") is float and not data.active_loan.get("due_day") is int: return false
			if not data.active_loan.get("visitor") is String: return false
	for key in ["day", "minutes", "energy", "x", "y"]:
		if not data.get(key) is float and not data.get(key) is int:
			return false
	if not data.get("friendship") is Dictionary: return false
	for key in ["restored", "talked_today"]:
		if not data.get(key) is Array: return false
	for key in friendship:
		if not data.friendship.get(key) is float and not data.friendship.get(key) is int:
			return false
	var saved_choices: Variant = data.get("story_choices", {})
	if not saved_choices is Dictionary:
		return false
	var decoded_choices := {}
	for id in saved_choices:
		var choice: Variant = saved_choices[id]
		if not friendship.has(id) or (not choice is float and not choice is int):
			return false
		if choice != 0 and choice != 1: return false
		decoded_choices[id] = int(choice)
	var saved_activities: Variant = data.get("activities",{})
	if not saved_activities is Dictionary: return false
	var decoded_activities := {}
	for id in saved_activities:
		var record: Variant = saved_activities[id]
		if id not in data.get("residents",[]) or not record is Dictionary or not record.get("prepared") is bool: return false
		var decoded := {"prepared":record.prepared}
		var routine: Variant = record.get("last_workout","rope")
		if not routine is String or not Workout.ROUTINES.has(routine): return false
		decoded.last_workout = routine
		for key in ["memory","stream_day","workout_day","reply"]:
			var value: Variant = record.get(key)
			if (not value is int and not value is float) or value != int(value): return false
			decoded[key] = int(value)
		if decoded.memory < 0 or decoded.reply not in [-1,0,1]: return false
		for key in ["stream_day","workout_day"]:
			if decoded[key] < 0 or decoded[key] > data.day: return false
		decoded_activities[id] = decoded
	var loaded_visits:=InkVisits.new()
	if data.version>=6:
		if not loaded_visits.restore(data.get("ink_visits"),data.residents): return false
		if loaded_visits.campaigns>0:
			for book in BOOKS:
				if data.chapter_steps.get(book.id,0)!=3: return false
	ink_visits=loaded_visits
	activities = decoded_activities
	var from_garden: bool = data.get("furniture_room","")!="library"
	furniture = Furniture.decode(data.get("furniture",[]),from_garden)
	story_choices = decoded_choices
	costumes.clear()
	var saved_costumes: Variant = data.get("costumes", {})
	if saved_costumes is Dictionary:
		for id in friendship:
			if saved_costumes.get(id) is String:
				costumes[id] = Wardrobe.equipped(id,saved_costumes[id])
	day = clampi(int(data.day), 1, 9999)
	minutes = clampi(int(data.minutes), 540, 1320)
	energy = clampi(int(data.energy), 0, 100)
	for key in friendship:
		friendship[key] = clampi(int(data.friendship[key]), 0, 10)
	read_bonds.clear()
	var saved_bonds: Variant = data.get("read_bonds",{})
	if saved_bonds is Dictionary:
		for id in friendship:
			var read_count: Variant = saved_bonds.get(id,0)
			if (read_count is int or read_count is float) and (read_count == 1 or read_count == 2):
				read_bonds[id] = mini(int(read_count),bond_tier(id))
	restored.clear()
	talked_today.clear()
	for id in data.restored:
		if id is String and friendship.has(id) and not id in restored:
			restored.append(id)
	for id in data.talked_today:
		if id is String and friendship.has(id) and not id in talked_today:
			talked_today.append(id)
	residents.clear()
	chapter_steps.clear()
	if data.version >= 3:
		for id in data.residents:
			if not id in residents: residents.append(id)
	for id in friendship:
		if data.version >= 3:
			if data.chapter_steps.has(id): chapter_steps[id] = int(data.chapter_steps[id])
		elif friendship[id] > 0 or story_choices.has(id) or id in restored or id in talked_today or costumes.has(id):
			residents.append(id)
	var saved_form: Variant = data.get("fan_form","")
	fan_form = saved_form if saved_form is String and saved_form in residents else ""
	active_mission = data.active_mission if data.version >= 4 else ""
	marked_actions.clear()
	dori_notes=DoriCase.valid_notes(data.get("dori_notes",[]))
	yune_notes=YuneDream.restored_notes(data.get("yune_notes",[]))
	danming_notes=DanmingWorkshop.restored_notes(data.get("danming_notes",[]))
	kubby_notes=KubbyEmbers.restored_notes(data.get("kubby_notes",[]))
	yato_notes=YatoForest.restored_notes(data.get("yato_notes",[]))
	fuwa_notes=FuwaSnow.restored_notes(data.get("fuwa_notes",[]))
	fuwa_adventure=FuwaProgress.clean(data.get("fuwa_adventure",{}))
	stella_adventures={}
	if data.get("stella_adventures",{}) is Dictionary:
		for member in StellaProgress.CHAPTERS:
			var checkpoint:=StellaProgress.clean(member,data.get("stella_adventures",{}).get(member,{}))
			if not checkpoint.is_empty(): stella_adventures[member]=checkpoint
	if data.version<7:
		if "sleeper" in dori_notes and "stone_compare" not in dori_notes: dori_notes.append("stone_compare")
		if "eaten" in yune_notes and "gold" not in yune_notes: yune_notes.append("gold")
	if data.get("marked_actions") is Array:
		for id in data.marked_actions:
			if id is String and chapter_steps.get(id,0) == 1 and not id in marked_actions: marked_actions.append(id)
	page_complete = data.page_complete if data.version >= 4 else false
	chapter_routes.clear()
	var saved_routes: Variant=data.get("chapter_routes",{})
	if saved_routes is Dictionary:
		for id in friendship:
			var index: Variant=saved_routes.get(id,-1)
			if (index is int or index is float) and index==debut_scene(id) and index>=0 and index<3 and chapter_ready(id,int(index)):
				chapter_routes[id]=int(index)
	if not data.has("fuwa_notes") and ("fuwa" in residents or (page_complete and active_mission=="fuwa")):
		for step in FuwaSnow.STEPS: fuwa_notes.append_array(step)
	opening_pending = data.version >= 3 and data.get("opening_pending",false) == true and rebuild_stage() == BOOKS.size()
	scene = "garden" if data.get("scene") == "garden" else "library"
	var host: Variant = data.get("yard_host","")
	var old_activity: bool = from_garden and scene=="garden"
	yard_host = host if (scene == "library" or old_activity) and host is String and can_do_activity(host,"stream") else ""
	yard_session = {}
	var session: Variant = data.get("yard_session",{})
	if (scene == "library" or old_activity) and session is Dictionary and session.get("member") is String and session.get("routine") is String:
		var elapsed: Variant = session.get("elapsed")
		if (elapsed is int or elapsed is float) and elapsed >= 0 and elapsed < Workout.DURATION and begin_yard_session(session.member,session.routine):
			yard_session.elapsed = float(elapsed)
	player = Vector2(clampf(float(data.x), 90, 900), clampf(float(data.y), 245, 675))
	if old_activity and (yard_host!="" or not yard_session.is_empty()):
		scene="library"
		player=Furniture.ENTRANCE
	intro_seen = data.get("intro_seen", false) == true
	bookmarks = clampi(int(data.get("bookmarks",0)),0,999999)
	total_loans = clampi(int(data.get("total_loans",0)),0,999999)
	claimed_requests.clear()
	for key in data.get("claimed_requests",[]):
		if key is String and key.length() < 64 and not key.begins_with("daily_gather_") and not key in claimed_requests: claimed_requests.append(key)
	active_loan = data.get("active_loan",{}).duplicate()
	loan_today = data.get("loan_today",false)
	return true

func save_to(path: String = SAVE_PATH) -> Error:
	# Write a full temporary file first so a failed write never truncates a valid save.
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_data()))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(path, backup)
		if error != OK:
			return error
	return DirAccess.rename_absolute(temp, path)

func load_from(path: String = SAVE_PATH) -> bool:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var file := FileAccess.open(candidate, FileAccess.READ)
			if file != null:
				var parser := JSON.new()
				if parser.parse(file.get_as_text()) == OK and apply_data(parser.data):
					return true
	return false
