extends "res://scripts/main.gd"

# Production entry point. The opt-in review runner sets preview_mode explicitly.
const GrowthState = preload("res://scripts/growth_state_adapter.gd")
const Growth = preload("res://scripts/library_growth.gd")
const Seasons = preload("res://scripts/library_seasons.gd")
const Work = preload("res://scripts/growth_work_sprites.gd")
const GrowthEditor = preload("res://scripts/growth_furniture_editor.gd")
const OperatingUI = preload("res://scripts/operating_ui.gd")
const ShopPreview = preload("res://scripts/polish_shop.gd")
const CharacterFocus = preload("res://scripts/character_focus.gd")
const ReconstructionTransition = preload("res://scripts/reconstruction_transition.gd")
const GrowthDecor = preload("res://scripts/library_growth_decor.gd")
const WorldLayout = preload("res://scripts/library_world_layout.gd")
const WorldView = preload("res://scripts/library_world.gd")
const WorldResidents = preload("res://scripts/library_world_residents.gd")
const LibraryDayFlow = preload("res://scripts/library_day.gd")
const FuwaAdventure = preload("res://scripts/fuwa_adventure/campaign.gd")
const StellaAdventure = preload("res://scripts/stella_adventure/game.gd")
var stella_book: Node2D
var fuwa_book: Node2D
var library_day_flow := LibraryDayFlow.new()
var world := WorldView.new()
const PREVIEW_SAVE := "res://artifacts/growth_20261116/preview_save.json"
const PRODUCTION_SAVE := "user://library_valley_v2.json"
const WORKS := {
	"corridor":{"title":"통로 정리","helpers":"야토 · 후와 · 플레이어","detail":"야토가 길을 확인하면 후와와 상자를 함께 옮겨요.","result":"쌓인 짐이 치워지고 서가와 열람 공간으로 가는 길이 열려요.","pos":Vector2(440,610),"seconds":16.0},
	"shelves":{"title":"서가 정돈","helpers":"도리 · 단밍","detail":"도리가 책을 살피고 단밍이 책과 소개 카드를 정리해요.","result":"비어 있던 서가가 채워지고 손님에게 보여 줄 책들이 준비돼요.","pos":Vector2(440,310),"seconds":12.0},
	"reading":{"title":"열람 공간 준비","helpers":"유네 · 쿠비","detail":"유네가 독서 자리를 살피고 쿠비가 독서등을 켜요.","result":"창을 열고 조명을 밝히면 계절 풍경이 보이고 독서 자리가 생겨요.","pos":Vector2(620,500),"seconds":12.0}
}
var growth: RefCounted
var persist := true
var preview_mode := false
var save_path := PRODUCTION_SAVE
var legacy_save_path := State.SAVE_PATH
var migrated_from_legacy := false
var shop_tab := "upgrade"
var work_task := ""
var work_elapsed := 0.0
var work_paused := false
var observed_gold := 0
var observed_light := 0
var season_override := -1
var background_paused := false
var summary_snoozed := false
var shop_preview := ShopPreview.new()
var character_focus := CharacterFocus.new()
var work_transition := ReconstructionTransition.new()
var world_mission_request := false

func _init() -> void:
	state=GrowthState.new()
	growth=state.growth
	furniture_editor=GrowthEditor.new()
	garden_residents=WorldResidents.new()

func world_map_active() -> bool:
	return state!=null and state.scene=="library" and mode not in ["chapter","rescue","fuwa_adventure","stella_adventure","title","new_confirm"]

func world_zoom() -> float:
	return 2.0 if library_day_flow.active(self) and state.library_day.direct.topic==0 else 1.0

func world_camera_offset() -> Vector2:
	if world_zoom()==2.0:
		var home: Vector2=WorldLayout.HOMES[_mission_index_for(state.library_day.direct.member)]
		return Vector2(clampf(640-home.x*2,-3840,-2560),clampf(420-home.y*2,-800,0))
	return super.world_camera_offset()

func append_world_layers(actors: Array) -> void:
	world.append_layers(self,actors)

func draw_world_layer(area: Rect2) -> void:
	world.draw_layer(self,area)

func _visit_ete(index: int=-1) -> void:
	world_mission_request=index>=0
	if world_map_active() and WorldLayout.private_point(player_pos): world.change_area(self,false)
	super._visit_ete(index)

func _walkable(point: Vector2) -> bool:
	if world_map_active(): return WorldLayout.walkable(point,obstacles)
	return super._walkable(point)

func _grid_at(point: Vector2) -> Vector2i:
	if world_map_active(): return WorldLayout.nearest(navigation,point)
	return super._grid_at(point)

func _go_to(obj: Dictionary) -> void:
	if world_map_active() and not obj.is_empty() and WorldLayout.private_point(obj.pos)!=WorldLayout.private_point(player_pos):
		_notify("그 친구는 다른 공간에 있어요. 연결 문으로 이동해 주세요.")
		return
	super._go_to(obj)

func _nearest() -> Dictionary:
	if not world_map_active(): return super._nearest()
	var best: Dictionary={}
	var distance:=78.0
	for obj in objects:
		if obj.get("promo_away",false) or WorldLayout.private_point(obj.pos)!=WorldLayout.private_point(player_pos): continue
		var d: float=player_pos.distance_to(obj.pos)
		if d<distance: distance=d;best=obj
	return best

func _studio_interact(obj: Dictionary) -> void:
	if not world_map_active(): super._studio_interact(obj);return
	if obj.is_empty() or mode!="play" or not obj.get("in_studio",false): return
	if not WorldLayout.private_point(player_pos): _notify("개인 공간에서 만날 수 있어요.");return
	var recommendation: bool=state.ink_visits.topic==0 and state.ink_visits.promoting(obj.id)
	if state.yard_host==obj.id or recommendation:
		life.open(self);life.member_index=obj.index;life.open_chat(self,recommendation)
	elif not character_touch.locked(self,obj.id): character_touch.react(self,obj.id)

func _ready() -> void:
	font=preload("res://scripts/game_font.gd").create()
	font.font_names=PackedStringArray(["Malgun Gothic","맑은 고딕","Noto Sans CJK KR"])
	font.allow_system_fallback=true
	chime=AudioStreamPlayer.new()
	chime.volume_db=-20
	add_child(chime)
	if preview_mode:
		audio_enabled=false
		save_path=PREVIEW_SAVE
		mode="play"
		if persist and _save_exists(save_path) and state.load_from(save_path):
			growth=state.growth
			player_pos=state.player
		else:
			for member in MEMBERS:
				state.residents.append(member.id)
				state.chapter_steps[member.id]=3
			state.intro_seen=true
			state.furniture.clear()
			state.scene="library"
			state.opening_pending=false
			growth.begin_rebuild(6)
	else:
		mode="title"
		save_available=_save_exists(save_path) or _save_exists(legacy_save_path)
	observed_gold=growth.gold
	observed_light=growth.memory_light
	_setup_map()
	get_window().min_size=Vector2i(960,600)
	get_window().title="루체테 · 재건과 사계절"+(" 플레이 시안" if preview_mode else "")
	get_tree().auto_accept_quit=false
	if preview_mode: _notify("여섯 스텔라가 모였어요. 에테의 운영 수첩에서 첫 재건을 시작해요.")

func _save_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")

func _continue_game() -> void:
	var candidate:=GrowthState.new()
	# A corrupt newer save must never silently roll the player back to v1.
	var from_legacy:=not _save_exists(save_path)
	var source:=legacy_save_path if from_legacy else save_path
	if not candidate.load_from(source):
		_notify("저장 파일과 백업을 읽지 못했어요. 기존 진행은 덮어쓰지 않았어요.")
		return
	state=candidate
	growth=state.growth
	migrated_from_legacy=from_legacy
	_reset_session()
	player_pos=state.player
	mode="play"
	_setup_map()
	library_day_flow.resume(self)
	if from_legacy:
		_save()
		if save_failed: return
	_notify("기존 이야기를 이어왔어요. 원래 저장은 그대로 보관돼 있어요." if from_legacy else "루체테로 돌아왔어요. 오늘의 이야기를 이어가요.")

func _reset_session() -> void:
	_drop_fuwa_book()
	_drop_stella_book()
	world=WorldView.new()
	library_day_flow=LibraryDayFlow.new()
	world_mission_request=false
	replay_progress=null
	comic_started=-1.0
	comic_player.reset()
	chapter_question=false
	book_activity=null
	book_discovery.reset()
	work_task=""
	work_elapsed=0
	work_paused=false
	save_failed=false
	season_override=-1
	summary_snoozed=false
	background_paused=false
	shop_preview=ShopPreview.new()
	character_focus=CharacterFocus.new()
	work_transition.reset()
	observed_gold=growth.gold
	observed_light=growth.memory_light
	after_dialogue="play"
	life=StellaLife.new()
	shared=SharedActivity.new()

func _new_game() -> void:
	state=GrowthState.new()
	growth=state.growth
	_reset_session()
	migrated_from_legacy=false
	mission_index=0
	mode="play"
	player_pos=state.player
	_setup_map()
	state.intro_seen=true
	_save()
	_show_dialogue(AETHE_SPEAKER,[
		"어서 와요. 나는 루체테의 사서 에테예요. 저기 나란히 꽂힌 여섯 권이 보이나요? 예전에는 멀리서도 책등 색만 보고 어느 책인지 알았어요.",
		"루체테는 누군가 이야기를 기억해 주는 동안 여기에 있어요. 기억하는 이가 하나둘 떠나면, 책 속 친구들도 이 도서관도 조금씩 희미해져요.",
		"책 속에서는 각 스텔라가 되어 직접 행동하게 돼요. 도리의 잠복, 유네의 꿈, 단밍의 일터, 쿠비의 여행, 야토의 숲, 후와의 눈산에서 이야기가 이어져요. 마지막 장면을 마치면 도서관에서 다시 만나게 될 거예요.",
		"먼저 여섯 친구를 모두 이곳으로 데려와 줄래요? 모두 모이면 함께 통로를 정리하고 서가와 열람 공간을 준비해서 도서관을 다시 열 거예요.",
		"어느 책이든 마음이 가는 것부터 골라요. 마지막 문장을 되찾으면 그 책부터 다시 빛날 거예요. 준비되면 왼쪽 안내 데스크로 와요. 내가 돌아올 길을 지키고 있을게요."],GOLD)

func _save() -> void:
	if is_instance_valid(fuwa_book) and mode=="fuwa_adventure" and replay_progress==null and not fuwa_book.completed:
		state.fuwa_adventure=fuwa_book.snapshot()
	if is_instance_valid(stella_book) and mode=="stella_adventure" and replay_progress==null and not stella_book.completed:
		state.stella_adventures[stella_book.member]=stella_book.snapshot()
	library_day_flow.snapshot(self)
	if not persist: return
	if world_map_active(): state.world_player=player_pos
	state.player=player_pos
	save_failed=state.save_to(save_path)!=OK
	if save_failed: _notify("저장에 실패했어요. 현재 창을 닫기 전에 다시 저장해 주세요.")
	else: save_available=true

func _setup_map() -> void:
	if world_map_active():
		world.setup(self)
		library_day_flow.sync_targets(self)
		return
	world.entered=false
	super._setup_map()
	if state.scene!="library" or mode in ["chapter","rescue"]: return
	studios_open=state.residents.size()==6 and growth.phase!="recruiting"
	garden_residents.reset(self)
	if growth.phase!="open" and "shelves" not in growth.completed_tasks:
		objects=objects.filter(func(obj): return obj.type!="keepsake")
	for obj in objects:
		match obj.type:
			"librarian","board": obj.label="사서 에테 · 영입 의뢰와 팬 변신" if growth.phase=="recruiting" else "에테의 운영 수첩 · 재건과 성장"
			"table": obj.label="도서관 상점 · 능력·가구·의상"
			"desk": obj.label="방문·대출 기록"
			"sleep": obj.label="오늘의 일정 · 마감" if growth.phase=="open" else "휴식 의자 · 다음 날"
	if growth.phase=="rebuilding":
		for id in Growth.TASKS:
			if id in growth.completed_tasks: continue
			objects.append({"id":"work_"+id,"type":"growth_work","task":id,"pos":WORKS[id].pos,"label":WORKS[id].title+" · 함께 준비하기"})

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: background_paused=true
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN: background_paused=false
	super._notification(what)

func _process(delta: float) -> void:
	if mode=="stella_adventure" and is_instance_valid(stella_book):
		if not background_paused:
			clock+=delta;stella_book.advance(minf(delta,.05))
		stella_book.queue_redraw();queue_redraw()
		return
	if mode=="fuwa_adventure" and is_instance_valid(fuwa_book):
		if not background_paused:
			clock+=delta;fuwa_book.advance(minf(delta,.05))
		fuwa_book.queue_redraw();queue_redraw()
		return
	var previous_notice:=notice_revision
	if world_map_active(): state.world_player=player_pos
	if background_paused:
		queue_redraw()
		return
	if mode=="growth_work":
		clock+=delta
		toast_time=maxf(0,toast_time-delta)
		if not work_paused:
			work_transition.advance(self,delta)
			if work_transition.phase=="work":
				work_elapsed+=delta
				if work_elapsed>=float(WORKS[work_task].seconds): work_transition.begin_return(self)
			if work_transition.phase=="done":
				var finished:=work_task
				state.complete_reconstruction_task(finished)
				work_task=""
				mode="play"
				if "chair" in growth.owned_furniture and Furniture.find(state.furniture,"chair").is_empty():
					state.place_furniture("chair",WorldLayout.FURNITURE.chair if state.world_enabled else Furniture.DEFAULTS[0])
				_setup_map()
				work_transition.reset()
				_save()
				_notify(WORKS[finished].result)
		queue_redraw()
		return
	var live: bool=comic_started<0 and state.scene=="library" and (mode in ["play","together","day_promotion","day_action"] or (mode=="stella_life" and life.phase=="promo_chat"))
	var clock_changed:=false
	if live and growth.phase=="open": clock_changed=state.advance_operating_time(minf(delta,1.0))
	super._process(delta)
	if live: library_day_flow.update(self,delta)
	if clock_changed: _save()
	if comic_started<0 and growth.phase=="open" and mode=="play" and state.day_close_ready() and not summary_snoozed:
		mode="growth_summary"
		route.clear()
		_save()
	if growth.gold!=observed_gold or growth.memory_light!=observed_light:
		var money: int=growth.gold-observed_gold
		var light: int=growth.memory_light-observed_light
		observed_gold=growth.gold
		observed_light=growth.memory_light
		if mode=="play" and (money>0 or light>0) and notice_revision==previous_notice:
			_notify("도서관의 오늘  ·  골드 +%d  ·  기억의 빛 +%d" % [maxi(0,money),maxi(0,light)])
		_save()

func _calendar() -> Dictionary:
	var result: Dictionary=state.library_calendar()
	if preview_mode and season_override>=0:
		var day: int=(result.year-1)*Growth.DAYS_PER_SEASON*4+season_override*Growth.DAYS_PER_SEASON+4
		result=Growth.calendar(day)
	result.window_open="reading" in growth.completed_tasks
	return result

func _operating_status() -> String:
	if growth.phase!="open": return "개관 준비"
	if state.operating.closing: return "마감 중"
	if state.minutes<600: return "10시 개관 준비"
	if state.minutes>=1200: return "신규 입장 마감"
	return "영업 중"

func outstanding_loans() -> int:
	var count:=0
	for loan in state.ink_visits.loans:
		if not loan.returned: count+=1
	return count

func _draw_library() -> void:
	# Render each completed job independently, even when shelves/reading are
	# finished in the opposite order. Recruitment count no longer opens windows.
	var stage: int=6 if growth.phase in ["ready","open"] else 2 if "corridor" in growth.completed_tasks else 0
	Pixels.background(self,stage)
	if growth.phase!="open":
		_background_patch(Rect2(330,142,310,116),6 if "shelves" in growth.completed_tasks else 0)
		_background_patch(Rect2(675,140,116,104),6 if "reading" in growth.completed_tasks else 0)
	Pixels.story_books(self)
	if not state.residents.is_empty(): Furniture.draw_rooms(self)
	if "reading" in growth.completed_tasks: Pixels.window_light(self,6)
	for item in state.furniture: Pixels.contact_shadow(self,item.kind,Furniture.position(item))
	_world_sign(Vector2(476,260),"스토리 · 시작의 서가  J")
	ActivityArchive.draw_world(self)
	_world_sign(Vector2(490,485),"도서관 성장 상점")
	_world_sign(Vector2(128,672),"일정 · 마감" if growth.phase=="open" else "휴식 의자")
	_world_sign(Vector2(714,462),"대출 · 방문 기록")
	_world_sign(Vector2(834,287),"책 속 정원")
	if not state.yard_session.is_empty():
		var routine: String=state.yard_session.routine
		if Furniture.find(state.furniture,"mat").is_empty() or routine=="gym": Yard.draw_station(self,Furniture.activity_position(state,state.yard_session.member),routine)
	if studios_open: Studios.draw_passage(self)
	if growth.phase=="open":
		var door: Vector2=state.ink_visits.DOOR
		draw_rect(Rect2(door+Vector2(-22,-2),Vector2(44,36)),Color("594a41"))
		draw_rect(Rect2(door+Vector2(-20,0),Vector2(40,32)),Color("547069"))
		for y in [2,5,27,30]: draw_line(door+Vector2(-17,y),door+Vector2(17,y),Color("bcaa7b"))
	Pixels.atmosphere(self,6 if "reading" in growth.completed_tasks else 0)
	Seasons.draw(self,_calendar(),clock)
	if growth.phase=="rebuilding" and work_task!="corridor" and "corridor" not in growth.completed_tasks:
		Work._crate(self,Vector2(500,640))
	if growth.has_upgrade("reading_lamp"):
		draw_rect(Rect2(607,413,3,26),Color("725034"))
		draw_rect(Rect2(598,407,21,9),Color("f1dca4"))
		draw_rect(Rect2(600,407,17,2),Color("fff4c9"))
		draw_rect(Rect2(597,439,23,3),Color("8c6640"))
	if growth.has_upgrade("welcome_desk"):
		_panel(Rect2(775,560,55,28),Color("d8bd87"))
		_text(Vector2(780,579),"안내",13)
	if growth.has_upgrade("lending_desk"):
		draw_rect(Rect2(731,401,19,14),Color("516c6e"))
		_text(Vector2(733,412),"대출",9,Color("fff0cd"))
	GrowthDecor.draw(self)

func _background_patch(area: Rect2, stage: int) -> void:
	# These authored backgrounds have 2x native density: their texture pixels
	# already match world units at the default sprite scale of two.
	var source:=Rect2(area.position-Vector2(32,140),area.size)
	draw_texture_rect_region(Pixels.texture("library_stage_%d"%stage),area,source)

func _world_sign(pos: Vector2, label: String, chapter_target: String="") -> void:
	if state.scene=="library" and mode not in ["chapter","rescue"]:
		if label=="이야기 복원 작업대": label="도서관 성장 상점"
		elif label=="대출 데스크": label="대출 · 방문 기록"
	super._world_sign(pos,label,chapter_target)

func _draw() -> void:
	if mode=="stella_adventure" and is_instance_valid(stella_book):
		buttons.clear();ui_regions.clear();chapter_signs.clear()
		return
	if mode=="fuwa_adventure" and is_instance_valid(fuwa_book):
		buttons.clear();ui_regions.clear();chapter_signs.clear()
		return
	if world_map_active() and comic_started<0:
		_draw_world_frame()
		return
	# Keep notifications away from the toolbar and its live click targets.
	var remaining:=toast_time
	toast_time=0
	super._draw()
	toast_time=remaining
	if comic_started>=0: return
	if remaining>0 and mode!="growth_work":
		in_world=false
		_transform()
		var width:=minf(1170,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+44)
		# Keep the overview notice above both the normal hint (y=653) and
		# the nearby shared-activity button (y=648).
		var compact_notice:=mode=="play" and split_view()
		var y:=615 if compact_notice else 638 if mode=="play" else 723
		_panel(Rect2(640-width/2,y,width,32 if compact_notice else 39),PAPER)
		_center(y+(23 if compact_notice else 26),toast,16)
	character_focus.draw(self)
	if mode=="growth_work":
		in_world=false
		_transform()
		work_transition.draw_overlay(self)

func _draw_world_frame() -> void:
	buttons.clear();ui_regions.clear();chapter_signs.clear()
	in_world=true;_transform()
	world.draw_background(self)
	library_day_flow.draw_floor(self)
	_draw_objects()
	if mode=="play": character_touch.draw_drag(self)
	if mode=="furniture": furniture_editor.draw_world(self)
	in_world=false;_transform()
	world.draw_hud(self)
	library_day_flow.draw_bubbles(self)
	if library_day_flow.draw_ui(self): pass
	elif mode=="play":
		world.draw_hints(self)
	elif mode=="together": shared.draw_panel(self)
	elif mode=="furniture": furniture_editor.draw_ui(self)
	else: _draw_overlay()
	if toast_time>0:
		var width:=minf(1000,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+32)
		var notice_y:=764 if mode=="together" else 750
		_panel(Rect2(640-width*.5,notice_y,width,32),PAPER)
		_center(notice_y+22,toast,15)
	character_focus.draw(self)
	if mode=="growth_work": work_transition.draw_overlay(self)

func _draw_before_characters() -> void:
	library_day_flow.draw_world(self)

func _draw_librarian_override(feet: Vector2) -> bool:
	return library_day_flow.draw_librarian(self,feet)

func _draw_objects() -> void:
	var saved: Array[Dictionary]=objects
	if library_day_flow.active(self):
		objects=objects.filter(func(obj): return not obj.get("direct_control",false))
	if mode=="growth_work" or growth.phase in ["rebuilding","ready"]:
		objects=[]
		for obj in saved:
			if obj.type=="keepsake" and growth.phase in ["rebuilding","ready"]: continue
			if mode=="growth_work" and obj.id in Work.participants(work_task): continue
			objects.append(obj)
	super._draw_objects()
	objects=saved
	if mode=="growth_work":
		if work_transition.phase=="work":
			Work.draw(self,work_task,work_elapsed,WorldLayout.WORK_OFFSET[work_task] if world_map_active() else Vector2.ZERO)
		else: work_transition.draw_world(self)

func _draw_traveler(pos: Vector2, walking: bool, form: String) -> void:
	if mode=="growth_work" and Work.hides_player(work_task): return
	if library_day_flow.draw_actor(self,pos,walking): return
	if mode=="day_action": pos+=Vector2(0,-roundf(sin(library_day_flow.action_elapsed*PI)*1.2))
	super._draw_traveler(pos,walking,form)
	library_day_flow.draw_player_prop(self,pos)

func _draw_hud() -> void:
	if world_map_active(): world.draw_hud(self);return
	if not split_view():
		_draw_compact_hud()
		return
	var banner:=Rect2(20,16,386,66)
	_panel(banner,PAPER)
	_text(Vector2(38,44),"루체테 도서관",23)
	_text(Vector2(38,67),state.library_rank(),14,MUTED)
	var currency:=Rect2(416,16,392,66)
	_panel(currency,PAPER)
	_text(Vector2(435,43),"골드  %d G" % growth.gold,20,GOLD)
	var threshold: int=growth.next_threshold()
	_text(Vector2(435,67),"기억의 빛  %d%s · 누적" % [growth.memory_light," / %d"%threshold if threshold>0 else ""],16)
	var calendar:=Rect2(818,16,442,66)
	_panel(calendar,PAPER)
	_text(Vector2(837,43),state.library_calendar().label,20)
	var today:=_calendar()
	var weather: String=Seasons.WEATHER_NAMES[Seasons.weather_for(today.absolute_day,today.season_index)]
	_text(Vector2(837,66),"%02d:%02d · %s · %s" % [state.minutes/60,state.minutes%60,weather,_operating_status()],14,MUTED)
	ui_regions.append_array([banner,currency,calendar])
	if mode=="together": return
	var controls: Array=[ ["운영 수첩 O","growth_ops"],["상점 G","growth_shop"],["스텔라의 하루 L","life_open"],["가구 배치 F","furniture_open"],["홍보 맡기기 P","promotion"],["일정 · 마감","growth_rest"],["메뉴","pause"] ]
	for i in range(controls.size()):
		var rect:=Rect2(20+i*178,98,170,38)
		_button(rect,controls[i][0],controls[i][1],i==0,i==4 and growth.phase!="open")
		ui_regions.append(rect)
	_panel(Rect2(20,688,1240,94),PAPER)
	ui_regions.append(Rect2(20,688,1240,94))
	if growth.phase=="open":
		OperatingUI.draw_footer(self)
		character_touch.draw_hint(self)
		return
	var hint: String="에테에게 재건 작업을 부탁받아 세 곳을 준비해 주세요." if growth.phase=="rebuilding" else "운영 수첩에서 문을 열면 잉크들이 찾아올 수 있어요." if growth.phase=="ready" else "홍보를 맡기고 방문객을 맞아요. 독서·대출·방송의 기억이 도서관을 키워요."
	_text(Vector2(39,716),hint,17)
	_text(Vector2(39,744),"이동 WASD / 방향키 · 상호작용 E · 스텔라 클릭으로 인사 · 가구로 드래그하면 이용",14,MUTED)
	_text(Vector2(39,769),"방문 %d명  ·  대출 중 %d권  ·  첫 재건 %d/3" % [state.ink_visits.total,outstanding_loans(),growth.completed_tasks.size()],14)
	_button(Rect2(1081,736,159,31),"방송 기록 서가","growth_archive")
	character_touch.draw_hint(self)

func _draw_compact_hud() -> void:
	# The initial full-size library fills the upper screen. Keep its archive
	# bookshelf unobscured, as in the previously approved pre-opening layout.
	var calendar: Dictionary=state.library_calendar()
	var almanac:=Rect2(1101,16,158,147)
	_panel(almanac,PAPER)
	_text(Vector2(1118,43),"재건 %d년차"%calendar.year,17)
	_text(Vector2(1118,67),"%s %d일  %02d:%02d"%[calendar.season_label,calendar.day_in_season,state.minutes/60,state.minutes%60],13,MUTED)
	_text(Vector2(1118,94),"골드 %d G"%growth.gold,17,GOLD)
	_text(Vector2(1118,119),"기억의 빛 %d"%growth.memory_light,14)
	_text(Vector2(1118,145),"누적 · 소비 없음",12,MUTED)
	ui_regions.append(almanac)
	var identity:=Rect2(22,688,266,95)
	_panel(identity,PAPER)
	_text(Vector2(39,718),"루체테 도서관" if state.scene=="library" else "책 속 정원",21)
	_text(Vector2(39,742),state.library_rank(),13,MUTED)
	_text(Vector2(39,767),"돌아온 스텔라  %d / 6"%state.residents.size(),15)
	ui_regions.append(identity)
	var footer:=Rect2(300,688,958,95)
	_panel(footer,PAPER)
	ui_regions.append(footer)
	if mode=="together": return
	var rows: Array=[["에테의 수첩 O","growth_ops"],["시작의 서가 J","journal"],["오늘의 활동 L","life_open"],["방송 기록 서가","growth_archive"],["휴식","growth_rest"],["메뉴","pause"]]
	for i in range(rows.size()): _button(Rect2(312+i*155,700,145,37),rows[i][0],rows[i][1],i==0,i==2 and state.residents.is_empty())
	var hint: String="에테에게 부탁을 받고, 여섯 책 중 마음이 가는 이야기를 골라 주세요."
	if not state.active_mission.is_empty(): hint="진행 중인 책은 에테의 수첩에서 이어 읽어요. · 이동 WASD / 방향키 · E 살펴보기"
	elif growth.phase!="recruiting": hint="홍보·구매·가구 배치는 공용 도서관에서 이어가요."
	_text(Vector2(317,765),hint,14,MUTED)

func _draw_growth_help() -> void:
	_panel(Rect2(246,133,788,544),PAPER)
	_text(Vector2(280,180),"루체테 도서관 안내서",28)
	var rows: Array=[
		"1. 에테에게 의뢰를 받고, 원하는 순서로 여섯 책을 완성해요.",
		"2. 모두 돌아오면 통로·서가·열람 공간을 함께 준비해요.",
		"3. 운영 수첩에서 재개관하고 스텔라에게 홍보를 맡겨요.",
		"4. 잉크의 입장·대여로 번 골드로 능력·가구·의상을 마련해요.",
		"5. 방송·독서·대출의 기억의 빛은 누적돼 다음 성장을 열어요.",
		"6. 한 계절은 7일. 09~22시 하루를 마치면 내일의 문을 열어요."
	]
	for i in range(rows.size()): _text(Vector2(280,225+i*39),rows[i],17)
	_text(Vector2(280,483),"WASD / 방향키 이동 · Shift 달리기 · E 상호작용 · J 이야기 서가",16,MUTED)
	_text(Vector2(280,515),"O 에테에게 · G 제작 공방 · L 활동 · F 가구 배치 · P 홍보",16,MUTED)
	_text(Vector2(280,547),"F5 저장 · F11 전체화면 · 클릭 인사 · 가구로 드래그해서 이용",16,MUTED)
	_text(Vector2(280,580),"오른쪽 위 문 / 5번 · 개인 공간 이동. 깊은 교류는 공용 도서관에서 해요.",14,MUTED)
	_button(Rect2(746,609,250,42),"돌아가기 Esc","close",true)

func _return_with_stella() -> void:
	# A stale old return action must not bypass the new Fuwa adventure.
	if MEMBERS[story_member].id=="fuwa" or StellaAdventure.Chapters.CHAPTERS.has(MEMBERS[story_member].id): return
	var returning: bool=mode=="rescue" and replay_progress==null
	var previous: int=state.residents.size()
	super._return_with_stella()
	if not returning or state.residents.size()<=previous: return
	var chapter: Dictionary=Chapters.BOOKS[MEMBERS[story_member].id]
	var report: String=chapter.home
	if growth.phase=="rebuilding":
		report+=" 여섯 친구가 모두 모였어요. 이제 야토와 후와가 길을 정리하고, 모두 함께 서가와 열람 공간을 준비해요. 내 운영 수첩을 펼쳐 볼까요?"
		after_dialogue="growth_ops"
	else:
		report+=" 에테에게서 팬 모습으로 변신하고, 돌아온 친구와 이야기를 나눌 수 있어요. 남은 친구들도 모두 데려온 뒤 함께 도서관을 다시 세워요."
		after_dialogue="play"
	if dialogue_lines.size()>1: dialogue_lines[1]={"ete":true,"text":report}
	_notify("스텔라 귀환 %d / 6  ·  에테에게서 %s 변신 해금"%[state.residents.size(),chapter.fan])

func _enter_chapter(id: String) -> void:
	if id!="fuwa": _enter_stella_book(id);return
	var progress:=_chapter_progress()
	if progress.active_mission!="fuwa": return
	_drop_fuwa_book()
	chapter_home=player_pos;story_member=_mission_index_for("fuwa")
	route.clear();pending_object="";chapter_question=false;comic_started=-1
	book_discovery.reset();book_activity=null;character_touch.cancel()
	mode="fuwa_adventure";toast_time=0
	fuwa_book=FuwaAdventure.new();fuwa_book.replay=replay_progress!=null
	add_child(fuwa_book)
	var saved: Dictionary=progress.fuwa_adventure.duplicate(true)
	# Old unfinished books resume at the equivalent exploration/reunion;
	# even an old sealed page still plays the return and arrival before unlock.
	if saved.is_empty() and progress.debut_scene("fuwa")>=2:
		saved={"version":1,"stage":"reunion" if progress.debut_scene("fuwa")>=3 or "reunited" in progress.fuwa_notes else "clearing","x":210.0,"y":476.0,"clock":0.0,"spot":0,"assist":false}
	fuwa_book.restore_snapshot(saved)
	fuwa_book.arrived.connect(_fuwa_arrived)
	fuwa_book.checkpoint_changed.connect(_save_fuwa_checkpoint)
	fuwa_book.save_requested.connect(_save_fuwa_checkpoint)
	fuwa_book.exit_requested.connect(_close_fuwa_book)
	if replay_progress==null: _save_fuwa_checkpoint()
	queue_redraw()

func _save_fuwa_checkpoint() -> void:
	if replay_progress!=null or not is_instance_valid(fuwa_book): return
	_save()
	if save_failed: fuwa_book.say("저장하지 못했어요. F5로 다시 저장해 주세요.",6)

func _fuwa_arrived() -> void:
	if not is_instance_valid(fuwa_book) or mode!="fuwa_adventure" or fuwa_book.phase!="arrived": return
	if fuwa_book.completed: return
	if replay_progress!=null: fuwa_book.completed=true;return
	state.fuwa_adventure=fuwa_book.snapshot()
	if not state.complete_fuwa_adventure(): return
	fuwa_book.completed=true
	state.scene="library";state.yard_session={};state.yard_host=""
	_save_fuwa_checkpoint();_play_chime(880)

func _close_fuwa_book() -> void:
	if not is_instance_valid(fuwa_book) or mode!="fuwa_adventure": return
	var replaying:=replay_progress!=null
	var finished: bool=fuwa_book.completed
	if not replaying: _save_fuwa_checkpoint()
	_drop_fuwa_book();replay_progress=null
	player_pos=chapter_home;state.scene="library"
	mode="story" if replaying else "play" if finished else "journal"
	_setup_map()
	if not replaying: _save()
	if finished and not replaying:
		var line:="후와가 돌아왔어요. 이제 에테에게서 텐비 모습으로 변신하고, 후와와 이야기를 나눌 수 있어요."
		if growth.phase=="rebuilding": line+=" 여섯 친구가 모두 모였으니 함께 통로부터 정리해 볼까요?"
		_show_dialogue(AETHE_SPEAKER,[line],GOLD)
		after_dialogue="growth_ops" if growth.phase=="rebuilding" else "play"
	queue_redraw()

func _drop_fuwa_book() -> void:
	if not is_instance_valid(fuwa_book): return
	fuwa_book.hide();remove_child(fuwa_book);fuwa_book.queue_free();fuwa_book=null

func _enter_stella_book(id: String) -> void:
	if not StellaAdventure.Chapters.CHAPTERS.has(id): return
	var progress:=_chapter_progress()
	if progress.active_mission!=id: return
	_drop_stella_book();_drop_fuwa_book()
	chapter_home=player_pos;story_member=_mission_index_for(id)
	route.clear();pending_object="";chapter_question=false;comic_started=-1
	book_discovery.reset();book_activity=null;character_touch.cancel()
	mode="stella_adventure";toast_time=0
	stella_book=StellaAdventure.new();stella_book.member=id;stella_book.replay=replay_progress!=null
	add_child(stella_book)
	var saved: Dictionary=progress.stella_adventures.get(id,{}).duplicate(true)
	if saved.is_empty() and progress.debut_scene(id)>0:
		var old_scene: int=progress.debut_scene(id)
		var stages: Array=StellaAdventure.Chapters.CHAPTERS[id]
		var equivalent:=0
		for i in range(stages.size()):
			if stages[i][1]<=mini(old_scene,3): equivalent=i
			if stages[i][1]>=old_scene: break
		saved={"version":1,"stage":equivalent,"done":0,"x":230.0,"y":460.0,"clock":0.0,"phase":"play","intro":true}
	stella_book.restore_snapshot(saved)
	stella_book.arrived.connect(_stella_arrived)
	stella_book.checkpoint_changed.connect(_save_stella_checkpoint)
	stella_book.save_requested.connect(_save_stella_checkpoint)
	stella_book.exit_requested.connect(_close_stella_book)
	if replay_progress==null: _save_stella_checkpoint()
	queue_redraw()

func _save_stella_checkpoint() -> void:
	if replay_progress!=null or not is_instance_valid(stella_book): return
	_save()
	if save_failed: stella_book.say("저장하지 못했어요. F5로 다시 저장해 주세요.",6)

func _stella_arrived() -> void:
	if not is_instance_valid(stella_book) or mode!="stella_adventure" or stella_book.phase!="arrived" or stella_book.completed: return
	if replay_progress!=null: stella_book.completed=true;return
	var id: String=stella_book.member
	state.stella_adventures[id]=stella_book.snapshot()
	if not state.complete_stella_adventure(id): return
	stella_book.completed=true;state.scene="library";state.yard_session={};state.yard_host=""
	_save_stella_checkpoint();_play_chime(880)

func _close_stella_book() -> void:
	if not is_instance_valid(stella_book) or mode!="stella_adventure": return
	var replaying:=replay_progress!=null
	var finished: bool=stella_book.completed
	var id: String=stella_book.member
	if not replaying: _save_stella_checkpoint()
	_drop_stella_book();replay_progress=null
	player_pos=chapter_home;state.scene="library"
	mode="story" if replaying else "play" if finished else "journal"
	_setup_map()
	if not replaying: _save()
	if finished and not replaying:
		var line: String=StellaAdventure.Chapters.NAMES[id]+"가 합류했어요. 에테에게서 "+Chapters.BOOKS[id].fan+" 모습으로 변신하고, 함께 이야기를 나눌 수 있어요."
		if growth.phase=="rebuilding": line+=" 여섯 친구가 모두 모였으니 함께 통로부터 정리해 볼까요?"
		_show_dialogue(AETHE_SPEAKER,[line],GOLD)
		after_dialogue="growth_ops" if growth.phase=="rebuilding" else "play"
	queue_redraw()

func _drop_stella_book() -> void:
	if not is_instance_valid(stella_book): return
	stella_book.hide();remove_child(stella_book);stella_book.queue_free();stella_book=null

func _draw_overlay() -> void:
	if world_map_active() and world.draw_menu(self): return
	if mode=="growth_work":
		_draw_hud()
		buttons.clear()
		var top:=16 if world_map_active() else 607
		var left:=350 if world_map_active() else 238
		_panel(Rect2(left,top,804,70),PAPER)
		_text(Vector2(left+23,top+27),WORKS[work_task].title+"  ·  "+WORKS[work_task].helpers,19)
		var working_hint: String="짐은 잠시 여행자 모습으로 옮겨요." if work_transition.phase=="work" and work_task=="corridor" and not state.fan_form.is_empty() else work_transition.label()
		_text(Vector2(left+23,top+52),working_hint+"   Esc "+("계속" if work_paused else "잠시 멈추기"),14,MUTED)
		draw_rect(Rect2(left+457,top+42,316,8),Color("c5b28d"))
		draw_rect(Rect2(left+457,top+42,316*clampf(work_elapsed/WORKS[work_task].seconds,0,1),8),Color("78966c"))
		return
	if mode=="help":
		_draw_growth_help()
		return
	if mode=="pause" and preview_mode:
		_panel(Rect2(370,243,540,275),PAPER)
		_center(284,"재건과 사계절 · 플레이 시안",24)
		_center(318,"시안은 별도 슬롯에 저장돼요.",16,MUTED)
		_button(Rect2(414,345,452,44),"이어서 하기","close",true)
		_button(Rect2(414,397,452,44),"시안 저장","growth_save")
		_button(Rect2(414,449,452,44),"종료","growth_quit")
		return
	if mode not in ["growth_ops","growth_shop","growth_ledger","growth_rest","growth_close_confirm","growth_summary"]:
		super._draw_overlay()
		return
	_panel(Rect2(130,147,1020,522),PAPER)
	_button(Rect2(1035,165,91,34),"닫기 Esc","growth_summary_close" if mode=="growth_summary" else "close")
	if mode=="growth_ops": _draw_operations()
	elif mode=="growth_shop": _draw_shop()
	elif mode=="growth_ledger": _draw_ledger()
	elif mode=="growth_close_confirm": OperatingUI.draw_close_confirmation(self)
	elif mode=="growth_summary": OperatingUI.draw_summary(self)
	elif mode=="growth_rest" and growth.phase=="open": OperatingUI.draw_plan(self)
	else:
		_text(Vector2(165,193),"오늘을 마무리할까요?",25)
		_text(Vector2(165,248),"다음 날에는 대출한 잉크가 책을 돌려주러 와요.",18)
		var busy: bool=state.ink_visits.topic>=0 or not state.ink_visits.guests.is_empty() or not state.ink_visits.return_queue.is_empty()
		_text(Vector2(165,286),"이 창에서는 홍보와 손님의 이용이 잠시 멈춰요." if busy else "쉬면 다음 날 아침에 다시 만나요.",16,MUTED)
		_button(Rect2(165,336,410,47),"휴식하고 "+state.library_calendar(state.day+1).label,"sleep_confirm",true,busy)
		if busy:
			_text(Vector2(165,424),"열람실로 돌아가면 이어져요. 손님이 모두 마친 뒤 쉬어 주세요.",17)
			_button(Rect2(165,469,410,47),"열람실로 돌아가 손님 맞이하기","close",true)

func _draw_operations() -> void:
	_text(Vector2(165,193),"에테의 운영 수첩",25)
	_text(Vector2(165,226),"모두가 모였으니, 이제 함께 도서관을 다시 열 준비를 해요." if growth.phase!="open" else "잉크가 남긴 기억을 모으고, 다음에 마련할 것을 골라 봐요.",17)
	_button(Rect2(805,204,312,33),"에테에게 팬 변신 부탁하기","fan_forms")
	if growth.phase in ["rebuilding","ready"]:
		for i in range(Growth.TASKS.size()):
			var id: String=Growth.TASKS[i]
			var task: Dictionary=WORKS[id]
			var y:=246+i*98
			_panel(Rect2(158,y,961,88),Color("ead4ab"))
			_text(Vector2(175,y+26),task.title+"  ·  "+task.helpers,18)
			_text(Vector2(175,y+52),task.detail,15,MUTED)
			_text(Vector2(175,y+74),task.result,13,MUTED)
			var complete: bool=id in growth.completed_tasks
			var locked: bool=id!="corridor" and "corridor" not in growth.completed_tasks
			_button(Rect2(938,y+23,159,40),"준비 완료" if complete else "통로 정리 후" if locked else "함께 작업하기","growth_work_"+id,true,complete or locked)
		_button(Rect2(165,552,450,45),"재개관 · 첫 손님 맞이하기","growth_open",true,growth.phase!="ready")
		_text(Vector2(165,627),"첫 재건은 골드와 기억의 빛을 요구하지 않아요.",16,MUTED)
	else:
		_text(Vector2(165,273),"성장 %d단계 · %s" % [growth.rank()+1,growth.rank_name()],21)
		_text(Vector2(165,313),"기억의 빛은 줄어들지 않아요. 30 · 100 · 250에 새 개선 항목이 열려요.",17)
		_text(Vector2(165,354),"골드 → 도서관 능력 · 상호작용 가구 · 실제 공개된 추가 의상",17)
		_text(Vector2(165,393),"기억의 빛 → 독서 완료 +2 · 대출 +3 · 홍보 방송 완료 +3",17)
		_button(Rect2(165,423,290,45),"도서관 능력 개선","growth_shop",true)
		_button(Rect2(470,423,290,45),"방문·대출 기록 보기","growth_ledger")
		if preview_mode:
			_text(Vector2(165,507),"창밖 계절 미리보기 · 날짜와 저장 내용은 바뀌지 않아요",16,MUTED)
			for i in range(4): _button(Rect2(165+i*165,527,150,36),Growth.SEASONS[i],"growth_season_%d"%i,season_override==i)
			_button(Rect2(841,527,240,36),"현재 날짜의 계절로","growth_season_reset")
		else:
			_text(Vector2(165,514),"홍보로 새 손님을 초대하고, 좋은 추천과 정돈으로 다시 찾을 이유를 만들어요.",17,MUTED)
			_text(Vector2(165,551),"만족 재방문은 하루 최대 2명 · 한 계절 7일 · 홍보는 오전과 오후 한 번씩.",16,MUTED)
		_text(Vector2(165,618),"입장료 %d G · 대여료 %d G · 동시 방문 %d명" % [growth.entrance_fee(),growth.loan_fee(),growth.visitor_capacity()],17)

func _draw_shop() -> void:
	shop_preview.draw(self)

func _draw_promotion() -> void:
	if growth.phase=="open" and world_map_active(): library_day_flow.draw_ui(self)
	elif growth.phase=="open": OperatingUI.draw_promotion(self)
	else: super._draw_promotion()

func _draw_ledger() -> void:
	_text(Vector2(165,193),"방문·대출 기록",25)
	_text(Vector2(165,250),"누적 방문 %d명  ·  지금 도서관에 %d명" % [state.ink_visits.total,state.ink_visits.guests.size()],21)
	_text(Vector2(165,294),"총 수입 %d G   /   구매에 사용 %d G   /   보유 %d G" % [growth.income_total,growth.spent_total,growth.gold],18)
	_text(Vector2(165,335),"입장 %d G  ·  대여 %d G  ·  반납하러 온 잉크는 무료 입장" % [growth.entrance_fee(),growth.loan_fee()],16,MUTED)
	_text(Vector2(165,388),"대출 중 %d권 · 다음 날부터 자동으로 반납하러 와요." % outstanding_loans(),18)
	_text(Vector2(165,431),"책을 읽거나 빌린 기억은 계속 쌓이고, 구매해도 줄지 않아요.",17)
	_text(Vector2(165,476),"홍보를 맡기는 순간에는 보상이 없어요. 실제 이용을 지켜봐 주세요.",16,MUTED)
	_button(Rect2(165,555,330,44),"운영 수첩으로","growth_ops",true)

func _interact(obj: Dictionary) -> void:
	if obj.is_empty(): return
	if library_day_flow.interact(self,obj): return
	if library_day_flow.active(self): return
	if world_map_active() and mode=="play":
		match obj.type:
			"world_door": world.change_area(self,obj.id=="residence_door");return
			"librarian":
				mode="missions" if world_mission_request else "world_ete"
				world_mission_request=false
				route.clear();return
			"artisan":
				if "reading" not in growth.completed_tasks: _notify("열람 공간을 준비하면 이곳에 제작 공방도 열려요.");return
				mode="world_artisan";route.clear();return
			"promotion_board": mode="promotion";route.clear();return
	if state.scene=="library" and mode=="play":
		match obj.type:
			"growth_work": _start_work(obj.task); return
			"librarian","board":
				character_touch.release_ete(self)
				ete_interactions.reset()
				mode="missions" if growth.phase=="recruiting" else "growth_ops"
				route.clear()
				return
			"table": mode="growth_shop"; route.clear(); return
			"desk": mode="growth_ledger"; route.clear(); return
			"sleep": mode="growth_rest"; route.clear(); return
	super._interact(obj)

func _start_work(id: String) -> void:
	if growth.phase!="rebuilding" or not WORKS.has(id) or id in growth.completed_tasks: return
	if id!="corridor" and "corridor" not in growth.completed_tasks:
		_notify("야토·후와와 통로부터 정리해 주세요.")
		return
	if world_map_active() and WorldLayout.private_point(player_pos): world.change_area(self,false)
	route.clear()
	pending_object=""
	character_touch.cancel()
	work_task=id
	work_elapsed=0
	work_paused=false
	mode="growth_work"
	toast_time=0
	work_transition.begin(self,id)

func _action(id: String) -> void:
	if mode=="stella_adventure":
		if id=="close": _close_stella_book()
		return
	if mode=="fuwa_adventure":
		if id=="close": _close_fuwa_book()
		return
	if library_day_flow.action(self,id): return
	if library_day_flow.active(self):
		if id in ["world_notebook","close"]: mode="day_pause"
		return
	if world_map_active():
		match id:
			"goto_table": _go_to(_find_object("table"));return
			"goto_desk": _go_to(_find_object("desk"));return
			"goto_sleep": _go_to(_find_object("sleep"));return
			"goto_portal": _go_to(_find_object("library_door" if WorldLayout.private_point(player_pos) else "residence_door"));return
			"world_notebook": mode="world_notebook";return
			"world_upgrades": world.vendor="ete";shop_tab="upgrade";mode="growth_shop";return
			"world_furniture_shop": world.vendor="artisan";shop_tab="furniture";mode="growth_shop";return
			"world_costume_shop": world.vendor="artisan";shop_tab="costume";mode="growth_shop";return
			"mission_open": mode="missions";return
			"growth_shop": world.vendor="ete";shop_tab="upgrade"
			"furniture_open":
				if WorldLayout.private_point(player_pos): _notify("상호작용 가구는 공용 도서관에 배치해요.");return
	if shop_preview.action(self,id): return
	if id.begins_with("growth_work_"): _start_work(id.trim_prefix("growth_work_")); return
	if id.begins_with("growth_tab_"): shop_tab=id.trim_prefix("growth_tab_"); return
	if id.begins_with("growth_buy_"): _buy(id.trim_prefix("growth_buy_")); return
	if id.begins_with("growth_season_"):
		if not preview_mode: return
		season_override=-1 if id=="growth_season_reset" else int(id.right(1))
		mode="play"
		_notify("현재 날짜의 창밖으로 돌아왔어요." if season_override<0 else Growth.SEASONS[season_override]+" 창밖 미리보기 · 운영 수첩에서 되돌릴 수 있어요.")
		return
	match id:
		"close":
			if mode=="ending" and growth.phase=="open" and state.ink_visits.campaigns==0:
				_show_dialogue(AETHE_SPEAKER,[
					"문을 열었지만 아직 우리를 아는 잉크는 적어요. 처음엔 일반 손님이 하루 한 명 찾아와요. 스텔라와 홍보해서 더 많은 친구에게 알릴까요?",
					"방송은 오늘 세 명, 공연은 오늘 다섯 명을 초대해요. 잡지는 내일 네 명의 예약으로 이어져요. 오전과 오후에 한 번씩 고를 수 있어요.",
					"맞는 책을 추천하고 이용 자리를 정돈해 주면, 만족한 잉크가 내일 다시 찾아와요. 수입과 기억의 빛이 쌓이면 서가와 도서관도 자라나요. 먼저 홍보창을 펼쳐 볼게요."
				],Color("d9c6e8"))
				after_dialogue="promotion"
				return
		"growth_ops","requests","bag":
			if state.scene!="library": _notify("에테의 수첩은 도서관에서 살펴봐요."); return
			mode="missions" if growth.phase=="recruiting" else "growth_ops"
			return
		"goto_ete": _visit_ete(); return
		"growth_shop","goto_table": mode="growth_shop"; return
		"growth_ledger","goto_desk": mode="growth_ledger"; return
		"growth_rest","goto_sleep": mode="growth_rest"; return
		"growth_promotion_wait":
			if state.promotion_wait_target()<0:
				mode="promotion"
				_notify("현재 홍보 가능 여부를 확인해 주세요.")
				return
			var note: String=state.wait_until_next_event()
			mode="promotion"
			_save()
			_notify(note)
			return
		"growth_wait":
			var note: String=state.wait_until_next_event()
			mode="play"
			_save()
			_notify(note)
			return
		"growth_close_request": mode="growth_close_confirm"; return
		"growth_close_confirm":
			var note: String=state.request_day_close()
			summary_snoozed=false
			mode="play"
			_save()
			_notify(note)
			return
		"growth_summary":
			mode="growth_summary" if state.day_close_ready() else "growth_rest"
			return
		"growth_summary_close": summary_snoozed=true; mode="play"; return
		"growth_next_day":
			if not state.finish_operating_day():
				_notify("손님 이용과 진행 중인 홍보를 마친 뒤 내일로 넘어가요.")
				return
			player_pos=state.player
			season_override=-1
			summary_snoozed=false
			mode="play"
			_setup_map()
			_save()
			_notify(state.library_calendar().label+" · 새로운 하루가 시작됐어요.")
			return
		"growth_archive": activity_archive.open(self); return
		"growth_save":
			_save()
			if not save_failed: _notify("오늘의 이야기를 저장했어요.")
			return
		"growth_quit": _save(); get_tree().quit(); return
		"growth_open":
			if growth.open_library():
				# The opening ceremony starts a fresh operating morning even if
				# pre-opening personal conversations advanced the old clock.
				state.minutes=state.OperatingDay.START
				state.operating.begin(state)
				mode="play"; _setup_map(); _save()
				_notify("도서관 문을 열었어요. 스텔라에게 홍보 주제를 맡겨 첫 잉크를 맞아요.")
				if not preview_mode: mode="ending"
			return
		"sleep_confirm":
			if growth.phase=="open": _action("growth_close_confirm"); return
			if state.ink_visits.topic>=0 or not state.ink_visits.guests.is_empty() or not state.ink_visits.return_queue.is_empty():
				_notify("손님과 홍보가 마무리된 뒤 쉬어요."); return
			state.sleep(); player_pos=state.player; season_override=-1; mode="play"; _setup_map(); _save()
			_notify(state.library_calendar().label+" · 새로운 하루가 시작됐어요.")
			return
		"continue":
			if preview_mode: mode="play"
			else: _continue_game()
			return
		"new","new_confirm","title":
			if preview_mode: mode="play"; return
		"forms_back": mode="missions" if growth.phase=="recruiting" else "growth_ops"; return
		"fan_forms": mode="fan_forms"; return
		"restore","lend","tea": _notify("도서관 상점과 잉크 방문 기록에서 새 운영을 확인해 주세요."); return
	if id.begins_with("claim_"): return
	super._action(id)

func _buy(id: String) -> void:
	var catalogue: Dictionary=growth.catalogue(shop_tab)
	if not catalogue.has(id): return
	var owned: bool=(shop_tab=="furniture" and id in growth.owned_furniture) or (shop_tab=="costume" and id in growth.owned_costumes)
	if not owned:
		var error: String=growth.purchase(shop_tab,id,6)
		if error!="": _notify(error); return
	if shop_tab=="furniture":
		mode="play"
		if Furniture.find(state.furniture,id).is_empty(): state.place_furniture(id,WorldLayout.FURNITURE[id] if state.world_enabled else Furniture.DEFAULTS[Furniture.ORDER.find(id)])
		_setup_map()
		furniture_editor.open(self,id)
	elif shop_tab=="costume":
		state.costumes[catalogue[id].member]=id
		_notify(catalogue[id].label+"을 입었어요.")
	else: _notify(catalogue[id].label+"을 개선했어요.")
	observed_gold=growth.gold
	_save()

func _cycle_costume() -> void:
	var id: String=MEMBERS[story_member].id
	var keys: Array=[Wardrobe.COSTUMES[id].keys()[0]]
	for key in Wardrobe.COSTUMES[id]:
		if key in growth.owned_costumes and key not in keys: keys.append(key)
	if keys.size()<2: _notify("상점에서 확인된 추가 의상을 구매하면 갈아입을 수 있어요."); return
	state.costumes[id]=keys[(keys.find(_costume_key(id))+1)%keys.size()]
	_save()

func _afterword_hint(_book_name: String) -> String:
	return "여섯 스텔라가 모두 돌아온 뒤 서가 정돈을 마치면 이 장면의 뒷장이 열려요."

func _unregistered_label() -> String:
	return "서가 정돈 대기"

func _journal_hint() -> String:
	return "1~6 책 선택 · 전원 귀환 후 서가를 정돈하면 창작 단편의 뒷장도 열려요."

func _unhandled_input(event: InputEvent) -> void:
	if mode=="stella_adventure" and is_instance_valid(stella_book):
		stella_book._unhandled_input(event)
		get_viewport().set_input_as_handled()
		return
	if mode=="fuwa_adventure" and is_instance_valid(fuwa_book):
		fuwa_book._unhandled_input(event)
		get_viewport().set_input_as_handled()
		return
	if library_day_flow.input(self,event): return
	if world_map_active() and mode=="play" and comic_started<0 and event is InputEventMouse:
		if character_touch.input(self,event): return
		if event is InputEventMouseMotion: ete_interactions.pointer_motion(self,event);return
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			for i in range(buttons.size()-1,-1,-1):
				if buttons[i].rect.has_point(event.position):
					if not buttons[i].get("disabled",false): _action(buttons[i].id)
					return
			for area in ui_regions:
				if area.has_point(event.position): return
			var point: Vector2=event.position-WORLD_OFFSET
			var target: Dictionary=world.hit(self,point)
			if not target.is_empty(): _go_to(target);return
			if WorldLayout.floor_contains(point): pending_object="";_path_to(point)
		return
	if world_map_active() and mode.begins_with("world_"):
		if event is InputEventKey and event.pressed:
			if event.physical_keycode==KEY_ESCAPE: mode="play"
			elif event.physical_keycode in [KEY_F5,KEY_F11]: super._unhandled_input(event)
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			for button in buttons:
				if button.rect.has_point(event.position) and not button.get("disabled",false): _action(button.id);break
		return
	if world_map_active() and mode=="play" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_G: _go_to(_find_object("table"));return
		if event.physical_keycode==KEY_O: _go_to(_find_object("ete"));return
	if comic_started>=0:
		super._unhandled_input(event)
		return
	# New growth overlays must preserve the shared save/fullscreen controls.
	if mode.begins_with("growth_") and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_F5,KEY_F11]:
		super._unhandled_input(event)
		return
	if mode=="growth_work":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE: work_paused=not work_paused
		return
	if mode.begins_with("growth_"):
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
			if mode=="growth_summary": summary_snoozed=true
			mode="play"
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			for button in buttons:
				if button.rect.has_point(event.position): _action(button.id); break
		return
	if mode=="play" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_O: _action("growth_ops"); return
		if event.physical_keycode==KEY_G: mode="growth_shop"; return
	super._unhandled_input(event)
