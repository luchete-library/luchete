extends Node2D

const State = preload("res://scripts/game_state.gd")
const Wardrobe = preload("res://scripts/wardrobe.gd")
const Faces = preload("res://scripts/affinity_faces.gd")
var faces := Faces.new()
const Stories = preload("res://scripts/stellar_stories.gd")
const Chapters = preload("res://scripts/debut_chapters.gd")
const IllustratedPage = preload("res://scripts/book_activities/illustrated_page.gd")
var book_activity: IllustratedPage
const DoriCase = preload("res://scripts/dori_investigation.gd")
const StoryTrail = preload("res://scripts/story_trail.gd")
const BookDiscovery = preload("res://scripts/book_discovery.gd")
var book_discovery := BookDiscovery.new()
var dori_rubbing := DoriCase.Rubbing.new()
const YuneDream = preload("res://scripts/yune_dream.gd")
var yune_dream := YuneDream.new()
const DanmingWorkshop = preload("res://scripts/danming_workshop.gd")
var danming_workshop := DanmingWorkshop.new()
const KubbyEmbers = preload("res://scripts/kubby_embers.gd")
var kubby_embers := KubbyEmbers.new()
const YatoForest = preload("res://scripts/yato_forest.gd")
var yato_forest := YatoForest.new()
const FuwaSnow = preload("res://scripts/fuwa_snow.gd")
var fuwa_snow := FuwaSnow.new()
const Comics = preload("res://scripts/debut_comics.gd")
const ComicPlayer = preload("res://scripts/comic_player.gd")
var comic_player := ComicPlayer.new()
const EncounterBooks = preload("res://scripts/encounter_books.gd")
const ActivityArchive = preload("res://scripts/activity_archive.gd")
var activity_archive := ActivityArchive.new()
const StellaLife = preload("res://scripts/stella_life.gd")
const Yard = preload("res://scripts/yard_sprites.gd")
const Field = preload("res://scripts/field_sprites.gd")
const EteInteractions = preload("res://scripts/ete_interactions.gd")
var ete_interactions := EteInteractions.new()
const StellaInteractions = preload("res://scripts/stella_interactions.gd")
const CharacterTouch = preload("res://scripts/character_touch.gd")
var character_touch := CharacterTouch.new()
const Furniture = preload("res://scripts/garden_furniture.gd")
const GardenResidents = preload("res://scripts/garden_residents.gd")
const FurnitureEditor = preload("res://scripts/furniture_editor.gd")
var garden_residents := GardenResidents.new()
var furniture_editor := FurnitureEditor.new()
var life := StellaLife.new()
const BookRole = preload("res://scripts/book_role.gd")
const FanForms = preload("res://scripts/fan_forms.gd")
const WorldPixels = preload("res://scripts/world_pixels.gd")
const Dressing = preload("res://scripts/world_dressing.gd")
const Rebuild = preload("res://scripts/library_rebuild.gd")
const Pixels = preload("res://scripts/library_pixels.gd")
const Studios = preload("res://scripts/stella_studios.gd")
const FanRecognition = preload("res://scripts/fan_recognition.gd")
var recognition := FanRecognition.new()
const SharedActivity = preload("res://scripts/shared_activity.gd")
var shared := SharedActivity.new()
var replay_progress: State
const AETHE := preload("res://assets/characters/aethe.png")
const AETHE_POS := Vector2(335,465)
const AETHE_SPEAKER := "루체테의 사서 에테"
var ete_facing := "down"
var mission_index := 0
var chapter_question := false
var chapter_home := Vector2.ZERO
var chapter_note := ""
var chapter_observation := ""
var scene_started := 0.0
var story_member := 0
var story_page := 0
var story_return := "play"
var story_sources := false
var encounter_member := 0
var encounter_page := 0
var encounter_return := "encounter_shelf"
var encounter_turn_at := -1.0
var ink_returned_at := -1.0
var encounter_turn_forward := true
var comic_started := -1.0
const CREAM := Color("513520")
const GOLD := Color("a35b27")
const MUTED := Color("806047")
const INK := Color("142a2b")
const PAPER := Color("f0dfb6")
var studios_open := false
var WORLD_SCALE: float:
	get:
		if world_map_active(): return world_zoom()
		if mode=="chapter":
			var review:=_story_camera_override()
			if review.z>0: return review.z
		if mode=="chapter" and dori_rubbing.camera>0:
			return lerpf(1.2,DoriCase.Rubbing.CLOSE_SCALE,dori_rubbing.camera)
		if mode=="chapter" and fuwa_snow.practice.camera>0:
			return lerpf(1.2,FuwaSnow.WardPractice.ZOOM,fuwa_snow.practice.camera)
		if mode=="chapter" and yato_forest.storehouse.camera>0:
			return lerpf(1.2,YatoForest.Storehouse.SCALE,yato_forest.storehouse.camera)
		if mode=="chapter" and kubby_embers.village.camera>0:
			return lerpf(1.2,KubbyEmbers.Village.ZOOM,kubby_embers.village.camera)
		if mode=="chapter" and yune_dream.nights.camera>0:
			return lerpf(1.2,YuneDream.Nights.CLOSE_SCALE,yune_dream.nights.camera)
		if mode=="chapter" and danming_workshop.lens.camera>0:
			return lerpf(1.2,DanmingWorkshop.MemoryLens.CLOSE_SCALE,danming_workshop.lens.camera)
		return Studios.SCALE if split_view() else 1.2
var WORLD_OFFSET: Vector2:
	get:
		if world_map_active(): return world_camera_offset()
		if mode=="chapter":
			var review:=_story_camera_override()
			if review.z>0: return Vector2(review.x,review.y)
		if mode=="chapter" and dori_rubbing.camera>0:
			return Vector2(64,-106).lerp(dori_rubbing.camera_offset(),dori_rubbing.camera)
		if mode=="chapter" and fuwa_snow.practice.camera>0:
			return Vector2(64,-106).lerp(FuwaSnow.WardPractice.OFFSET,fuwa_snow.practice.camera)
		if mode=="chapter" and yato_forest.storehouse.camera>0:
			return Vector2(64,-106).lerp(yato_forest.storehouse.camera_offset(),yato_forest.storehouse.camera)
		if mode=="chapter" and kubby_embers.village.camera>0:
			return Vector2(64,-106).lerp(KubbyEmbers.Village.OFFSET,kubby_embers.village.camera)
		if mode=="chapter" and yune_dream.nights.camera>0:
			return Vector2(64,-106).lerp(YuneDream.Nights.CLOSE_OFFSET,yune_dream.nights.camera)
		if mode in ["chapter","rescue"]:
			return Vector2(64,-106).lerp(DanmingWorkshop.MemoryLens.CLOSE_OFFSET,danming_workshop.lens.camera)
		return Studios.OFFSET if split_view() else Vector2(64,-145)

func _story_camera_override() -> Vector3:
	# Preview subclasses may evaluate composition without changing campaign UI.
	return Vector3.ZERO

func split_view() -> bool:
	if world_map_active(): return false
	return studios_open and mode not in ["chapter","rescue","title","new_confirm"]

func world_map_active() -> bool:
	return false

func world_zoom() -> float:
	return 1.0

func world_camera_offset() -> Vector2:
	return Vector2(-1280,0) if player_pos.x>=1280 else Vector2.ZERO

func append_world_layers(_actors: Array) -> void:
	pass

func draw_world_layer(_area: Rect2) -> void:
	pass
var in_world: bool = false
var ui_regions: Array[Rect2] = []
var chapter_signs: Array[Dictionary] = []
const MEMBERS := [
	{"id":"yato","name":"야토","short":"야토","role":"토끼 숲의 안내자","color":"e7a251","hair":"d6a077","pos":Vector2(175,350),
	 "lines":["여기서는 길을 잃어도 괜찮아. 책을 펼치면 또 다른 길이 나오니까.","토끼 귀만 보고 헷갈리면 안 돼. 나는 토끼에게 길러진 인간이야!", "지도 끝에 당근을 그려 뒀더니 다들 밭인 줄 알아. 우리 집 표시였는데!"],
	 "after":"숲의 길이 다시 이어졌네. 이번에는 나랑 같이 걸어 볼래?"},
	{"id":"danming","name":"오단밍","short":"단밍","role":"마음을 잇는 편지","color":"df92a4","hair":"edbdd0","pos":Vector2(365,300),
	 "lines":["도서관에 온 걸 환영해! 오늘은 어떤 손님이 편지를 기다리는지 같이 알아볼래?","편지 한 장에도 누군가의 마음이 있잖아. 찢어진 페이지도 그냥 버리지 말아 줘.","편지 접을 때 마지막 귀퉁이는 살짝 남겨 둬. 뜯을 사람이 손톱으로 고생하면 안 되잖아."],
	 "after":"이제 이 편지가 누군가에게 닿을 수 있겠네. 네가 연결해 준 거야. 고마워!"},
	{"id":"kubby","name":"햄쿠비","short":"쿠비","role":"도깨비불의 온기","color":"99b58d","hair":"b7cdb5","pos":Vector2(800,370),
	 "lines":["하우우우… 여긴 왜 이렇게 조용해? 책들이 다 잠들어 있는 거야?", "나는 얼음 도깨비지만, 이 도서관에서는 따뜻한 감정도 많이 알아 가고 싶어.","도서관에선 작은 소리로 노래하랬는데… 도깨비불이 박자 맞춰서 자꾸 커져!"],
	 "after":"이 반짝이는 기분도 책에 적어 둘 수 있을까? 오늘은 정말 신나는 날이야!"},
	{"id":"yune","name":"아미하 유네","short":"유네","role":"꿈의 페이지 수집가","color":"aa96d6","hair":"b9a0d6","pos":Vector2(720,565),
	 "lines":["안녕! 나는 드림캐처에서 태어난 꿈의 정령, 유네야. 이곳의 꿈은 어떤 색일까?", "책 속 정원에 떠다니는 별빛을 봤어? 잊힌 꿈이 조각조각 남아 있는 것 같아.","잠들기 전에 종이 한 장 놔둬 봐. 내일 딱 한 단어만 기억나도 적을 수 있게."],
	 "after":"잊어버린 줄 알았던 꿈이 돌아왔어. 오늘 밤은 좋은 꿈을 꿀 것 같아!"},
	{"id":"dori","name":"쇼코코 도리","short":"도리","role":"분실 문장 조사 중","color":"cda280","hair":"97745c","pos":Vector2(240,535),
	 "lines":["도서관에 문장 실종 사건이 발생했어! 탐정 지망생 쇼코코 도리, 조사 시작!", "방금 저 책을 덮었는데 책갈피가 두 장이야. 같이 살펴볼래?", "탐정 수첩 첫 줄은 일부러 비워 놨어. 증거 나오기 전에 결론부터 적으면 큰일 나거든."],
	 "after":"사라진 문장, 전부 발견! 이번 사건은 너랑 같이 해결한 걸로 기록할게."},
	{"id":"fuwa","name":"하쿠텐 후와","short":"후와","role":"책장을 지키는 음양사","color":"93c6df","hair":"dce6ec","pos":Vector2(540,600),
	 "lines":["곰방후와! 멋진 음양사 후와다. 도서관의 경계는 내가 살펴보고 있어!", "텐비와 함께 눈산을 지나왔는데, 이번에는 책 속으로 들어가는 문이네. 신기해!", "부적 끝에 눈송이 하나가 안 녹고 남았어. 텐비 발자국이랑 크기가 똑같네."],
	 "after":"책장 너머의 약속도 돌아왔어. 우리, 다음 이야기도 같이 지키자. 후와이팅!"}
]
var state = State.new()
var font: SystemFont
var mode: String = "title"
var clock: float = 0.0
var player_pos := Vector2(490,620)
var facing: int = 1
var moving: bool = false
var fan_motion = FanForms.Motion.new()
var traveler_cycle := 0.0
var buttons: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var chapter_floor := PackedVector2Array()
var chapter_trail := PackedVector2Array()
var objects: Array[Dictionary] = []
var navigation := AStarGrid2D.new()
var route := PackedVector2Array()
var pending_object: String = ""
var selected_book: int = 0
var toast: String = ""
var toast_time: float = 0.0
var notice_revision := 0
var dialogue_name: String = ""
var dialogue_lines: Array = []
var dialogue_index: int = 0
var dialogue_color := GOLD
var dialogue_member: int = -1
var after_dialogue: String = "play"
var save_available: bool = false
var sparkle_bursts: Array[Dictionary] = []
var audio_enabled: bool = true
var chime: AudioStreamPlayer
var save_failed: bool = false

func _ready() -> void:
	font = preload("res://scripts/game_font.gd").create()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR"])
	font.allow_system_fallback = true
	chime = AudioStreamPlayer.new()
	chime.volume_db = -20
	add_child(chime)
	save_available = FileAccess.file_exists(State.SAVE_PATH) or FileAccess.file_exists(State.SAVE_PATH + ".bak")
	_setup_map()
	get_window().min_size = Vector2i(960,600)
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		character_touch.cancel()
		if book_activity!=null: book_activity.dragging=false
		yune_dream.holding=false
		yune_dream.nights.playing=false
		danming_workshop.release()
		dori_rubbing.release()
		fuwa_snow.practice.release()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode != "title" and mode != "new_confirm":
			_save()
		get_tree().quit()

func _process(delta: float) -> void:
	if comic_started>=0:
		clock+=delta
		comic_player.update(self)
		queue_redraw()
		return
	if book_discovery.active(self) and book_discovery.paused:
		queue_redraw()
		return
	clock += delta
	if mode=="chapter" and yune_dream.view==1: yune_dream.advance(self,delta)
	if mode=="chapter":
		if MEMBERS[story_member].id=="dori": dori_rubbing.advance(self,delta)
		if MEMBERS[story_member].id=="yune" and _chapter_progress().debut_scene("yune")==2: yune_dream.nights.advance(self,delta)
		var lens=danming_workshop.lens
		lens.camera=move_toward(lens.camera,1.0 if danming_workshop.view==2 else 0.0,delta*2)
		if danming_workshop.view>=0: danming_workshop.advance(self,delta)
	var watching_recommendation:=mode=="stella_life" and life.phase=="promo_chat"
	var library_running: bool=state.scene=="library" and (mode in ["play","together","day_promotion","day_action"] or watching_recommendation)
	if library_running and not state.yard_session.is_empty():
		var session: Dictionary = state.yard_session
		var old_bond: int = state.friendship[session.member]
		if state.advance_yard_session(delta) > 0:
			var member: Dictionary = MEMBERS[_mission_index_for(session.member)]
			var bond := "친밀도 +1 · " if state.friendship[session.member] > old_bond else ""
			_notify("%s의 %s 마침 · %s팬의 기억 +1" % [member.short,State.Workout.ROUTINES[session.routine].name,bond])
			_play_chime(784)
			_save()
	if library_running:
		garden_residents.update(self,delta)
		state.ink_visits.advance(self,delta)
		if watching_recommendation and not state.ink_visits.promoting(MEMBERS[life.member_index].id):
			life.action(self,"back")
	toast_time = maxf(0, toast_time - delta)
	for burst in sparkle_bursts:
		burst.life -= delta
	sparkle_bursts = sparkle_bursts.filter(func(b): return b.life > 0)
	moving = false
	var travelled := 0.0
	var fan_displacement := Vector2.ZERO
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var awaiting_fuwa: bool=mode=="chapter" and MEMBERS[story_member].id=="fuwa" and fuwa_snow.approaching(_chapter_progress().debut_scene("fuwa"),_chapter_progress().fuwa_notes)
	if mode in ["play","day_promotion"] or (mode == "chapter" and not chapter_question and not awaiting_fuwa):
		var direction := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if direction.length() > 0:
			route.clear()
			pending_object = ""
			direction = direction.normalized()
		elif route.size() > 0:
			if player_pos.distance_to(route[0]) < 5:
				route.remove_at(0)
			if route.size() > 0:
				direction = (route[0] - player_pos).normalized()
		var speed := 240.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 170.0
		if direction != Vector2.ZERO:
			var previous_position := player_pos
			var step := direction * speed * minf(delta, 0.04)
			if route.size() > 0 and step.length() > player_pos.distance_to(route[0]):
				step = route[0] - player_pos
			if _walkable(player_pos + Vector2(step.x,0)):
				player_pos.x += step.x
			if _walkable(player_pos + Vector2(0,step.y)):
				player_pos.y += step.y
			fan_displacement = player_pos - previous_position
			travelled = fan_displacement.length()
			moving = travelled > 0.001
			if moving and mode=="chapter" and MEMBERS[story_member].id=="kubby" and _chapter_progress().debut_scene("kubby")==2:
				kubby_embers.walk(self,previous_position,player_pos)
			if direction.x != 0:
				facing = 1 if direction.x > 0 else -1
		if pending_object != "":
			var obj := _find_object(pending_object)
			if not obj.is_empty() and player_pos.distance_to(obj.pos) < obj.get("reach",78.0):
				route.clear()
				pending_object = ""
				_interact(obj)
	elif mode=="together":
		fan_displacement=shared.advance(self,delta)
		travelled=fan_displacement.length()
		moving=travelled>.001
	var fan_id: String = MEMBERS[story_member].id if mode in ["chapter","rescue"] else state.fan_form
	if mode=="chapter" and fan_id=="yato" and _chapter_progress().debut_scene("yato")==1:
		yato_forest.storehouse.advance(self,delta)
	if mode=="chapter" and fan_id=="yato" and not chapter_question and _chapter_progress().debut_scene("yato")==3:
		yato_forest.watch(self,delta)
	if mode=="chapter" and fan_id=="kubby" and _chapter_progress().debut_scene("kubby")==1:
		var village=kubby_embers.village
		# Walking up to Kubby is sufficient, with either manual movement or a mouse route.
		if not chapter_question and book_discovery.autostart_allowed(self) and village.elapsed<village.END and village.in_reach(player_pos):
			village.approach(self)
		village.advance(self,delta)
	if mode=="chapter" and fan_id=="fuwa":
		fuwa_snow.advance(self,_chapter_progress().debut_scene("fuwa"),_chapter_progress().fuwa_notes,delta)
	var fan_context: String = "book:"+fan_id if mode in ["chapter","rescue"] else state.scene
	fan_motion.advance(fan_id,fan_context,delta,travelled,running,mode in ["play","together"] or (mode=="chapter" and not chapter_question),fan_displacement)
	if fan_id=="" and moving:
		traveler_cycle=fposmod(traveler_cycle+travelled/76.0,1.0)
	elif not moving:
		traveler_cycle=0.0
	_update_ete_facing()
	ete_interactions.update(self,delta)
	character_touch.update(self,delta)
	recognition.update(self)
	book_discovery.advance(self,delta)
	queue_redraw()

func _update_ete_facing() -> void:
	if ete_interactions.active!="" or character_touch.held=="ete" or not character_touch.ete_visit.is_empty(): return
	if mode!="play" or state.scene!="library": return
	var offset := player_pos-ete_interactions.position(self)
	if offset.length()<=125.0:
		ete_facing=Field.direction_for(offset,ete_facing)

func _unhandled_input(event: InputEvent) -> void:
	if comic_player.input(self,event): return
	if activity_archive.input(self,event): return
	if book_discovery.input(self,event): return
	if mode=="chapter" and yato_forest.storehouse.input(self,event): return
	if mode=="chapter" and kubby_embers.village.input(self,event): return
	if mode=="chapter" and book_activity!=null and book_activity.input(self,event): return
	if mode=="chapter" and fuwa_snow.input(self,event): return
	if mode=="chapter" and yune_dream.input(self,event): return
	if mode=="chapter" and dori_rubbing.input(self,event): return
	if mode=="chapter" and danming_workshop.input(self,event): return
	if character_touch.input(self,event): return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_F11:
			var win := get_window()
			win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			return
		if mode == "title":
			if key == KEY_ENTER:
				_action("continue" if save_available else "new")
			return
		if key == KEY_F5 and mode != "new_confirm":
			_save()
			if not save_failed: _notify("오늘의 이야기를 저장했어요.")
			return
		if mode == "stella_life":
			life.handle_key(self,key)
			return
		if mode=="together":
			if key in [KEY_E,KEY_R,KEY_ESCAPE,KEY_ENTER,KEY_SPACE]: _action("shared_end")
			return
		if mode == "promotion":
			if key>=KEY_1 and key<=KEY_3: _action("promote_%d" % (key-KEY_1))
			elif key in [KEY_ESCAPE,KEY_P]: _action("close")
			return
		if mode == "furniture":
			furniture_editor.key(self,key)
			return
		if mode == "encounter_shelf":
			if key >= KEY_1 and key <= KEY_6: _open_encounter(key-KEY_1)
			elif key in [KEY_ESCAPE,KEY_B]: _action("encounter_back")
			return
		if mode == "encounter_book":
			if key == KEY_ESCAPE: _action("encounter_back")
			elif key == KEY_LEFT: _action("encounter_prev")
			elif key in [KEY_E,KEY_ENTER,KEY_SPACE,KEY_RIGHT]: _action("encounter_next")
			return
		if mode == "journal" and key == KEY_B:
			_action("encounter_shelf")
			return
		if mode == "story":
			_story_key(key)
			return
		if mode == "rescue":
			if key in [KEY_E,KEY_SPACE,KEY_ENTER]: _return_with_stella()
			elif key == KEY_ESCAPE: _leave_chapter()
			elif key == KEY_V: _action("comic_play")
			return
		if mode == "missions":
			if key >= KEY_1 and key <= KEY_6: mission_index = key-KEY_1
			elif key in [KEY_UP,KEY_W]: mission_index = posmod(mission_index-1,MEMBERS.size())
			elif key in [KEY_DOWN,KEY_S]: mission_index = (mission_index+1)%MEMBERS.size()
			elif key in [KEY_E,KEY_ENTER]: _take_mission()
			elif key == KEY_F: _action("fan_forms")
			elif key == KEY_ESCAPE: mode = "play"
			return
		if mode == "fan_forms":
			if key >= KEY_1 and key <= KEY_6: _change_form(MEMBERS[key-KEY_1].id)
			elif key == KEY_0: _change_form("")
			elif key == KEY_ESCAPE: _action("forms_back")
			return
		if mode == "chapter":
			if key == KEY_ESCAPE:
				if chapter_question: chapter_question = false
				else: _leave_chapter()
			elif chapter_question:
				if _dori_notebook_open():
					if key>=KEY_1 and key<=KEY_3: DoriCase.choose_card(self,key-KEY_1)
				elif key in [KEY_E,KEY_ENTER,KEY_SPACE,KEY_1]: _remember_chapter()
			elif key in [KEY_E,KEY_ENTER,KEY_SPACE]:
				var nearby := _nearest()
				if not nearby.is_empty(): _interact(nearby)
			return
		if mode == "journal" and key >= KEY_1 and key <= KEY_6:
			_open_story(key - KEY_1,"journal")
			return
		if mode == "dialog":
			if key == KEY_R and dialogue_member >= 0 and not _is_ete_line():
				_open_story(dialogue_member,"dialog")
				return
			if key in [KEY_E,KEY_SPACE,KEY_ENTER]:
				_advance_dialogue()
			elif key == KEY_ESCAPE:
				mode = after_dialogue
			return
		if key == KEY_ESCAPE:
			if mode == "ending":
				_action("close")
			elif mode == "new_confirm":
				mode = "title"
			else:
				mode = "pause" if mode == "play" else "play"
			route.clear()
			pending_object = ""
			return
		if mode == "restore":
			if key in [KEY_UP,KEY_W]: selected_book = posmod(selected_book - 1, 6)
			if key in [KEY_DOWN,KEY_S]: selected_book = (selected_book + 1) % 6
			if key in [KEY_ENTER,KEY_E]: _restore()
			return
		if mode == "loans" and key in [KEY_ENTER,KEY_E]:
			_action("lend")
			return
		if mode == "bag" and key == KEY_ENTER:
			_action("tea")
			return
		if mode == "requests" and key >= KEY_1 and key < KEY_1 + State.REQUESTS.size():
			_action("claim_%d" % (key - KEY_1))
			return
		if mode == "sleep" and key == KEY_ENTER:
			_action("sleep_confirm")
			return
		if mode == "play":
			if key==KEY_R: shared.begin(self)
			if key in [KEY_E,KEY_ENTER,KEY_SPACE]:
				var nearby := _nearest()
				if not nearby.is_empty(): _interact(nearby)
				else: _notify("서가나 스텔라 가까이에서 E를 눌러요.")
			if key == KEY_J: mode = "journal"
			if key == KEY_L: _action("life_open")
			if key == KEY_P: _action("promotion")
			if key == KEY_F and state.scene == "library": _action("furniture_open")
			if key == KEY_H: mode = "help"
			if key == KEY_M: _action("audio")
			if key == KEY_I or key == KEY_1: _action("bag")
			if key == KEY_2: _action("journal")
			if key == KEY_Q or key == KEY_3: _action("requests")
			if key == KEY_4: _action("goto_table")
			if key == KEY_5: _action("goto_portal")
			if key == KEY_6: _action("goto_desk")
			if key == KEY_7: _action("goto_sleep")
	if event is InputEventMouseMotion and ete_interactions.pointer_motion(self,event): return
	if event is InputEventMouseMotion and mode == "furniture":
		var over_ui := false
		for region in ui_regions:
			if region.has_point(event.position): over_ui = true
		if split_view() and event.position.x>=Studios.room(0).position.x: over_ui=true
		if not over_ui: furniture_editor.pointer = ((event.position-WORLD_OFFSET)/WORLD_SCALE).snapped(Vector2(16,16))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = event.position
		for i in range(buttons.size() - 1, -1, -1):
			if mode=="together" and buttons[i].id!="shared_end": continue
			if buttons[i].rect.has_point(point):
				_action(buttons[i].id)
				return
		if mode=="together": return
		if mode == "dialog":
			_advance_dialogue()
			return
		for region in ui_regions:
			if region.has_point(point): return
		if mode=="play" and split_view():
			for i in range(MEMBERS.size()):
				if Studios.room(i).has_point(point):
					_studio_interact(_find_object(MEMBERS[i].id))
					return
		point = (point-WORLD_OFFSET)/WORLD_SCALE
		if mode=="chapter" and not chapter_question:
			for sign in chapter_signs:
				if sign.rect.has_point(point):
					var target:=_find_object(sign.id)
					if not target.is_empty():
						_go_to(target)
						return
		if mode=="chapter" and not chapter_question and MEMBERS[story_member].id=="dori" and _chapter_progress().debut_scene("dori")==2:
			var target:=dori_rubbing.clicked_site(self,point)
			if not target.is_empty():
				_go_to(target)
				return
		if mode=="chapter" and not chapter_question and MEMBERS[story_member].id=="fuwa":
			var progress:=_chapter_progress()
			if fuwa_snow.approaching(progress.debut_scene("fuwa"),progress.fuwa_notes): return
			var painted:=fuwa_snow.painted_target(self,progress.debut_scene("fuwa"),progress.fuwa_notes,point)
			if not painted.is_empty():
				_go_to(painted)
				return
		if mode=="chapter" and not chapter_question and MEMBERS[story_member].id=="yato":
			var progress:=_chapter_progress()
			var yato_target:=yato_forest.painted_target(self,progress.debut_scene("yato"),progress.yato_notes,point)
			if not yato_target.is_empty():
				_go_to(yato_target)
				return
		if mode=="chapter" and not chapter_question and MEMBERS[story_member].id=="kubby":
			var kubby_target:=kubby_embers.painted_target(self,point)
			if not kubby_target.is_empty():
				_go_to(kubby_target)
				return
		if mode=="chapter" and not chapter_question and MEMBERS[story_member].id=="danming":
			var painted:=DanmingWorkshop.painted_target(self,point)
			if not painted.is_empty():
				_go_to(painted)
				return
		if mode=="chapter" and not chapter_question and MEMBERS[story_member].id=="yune":
			if _chapter_progress().debut_scene("yune")==2 and YuneDream.Nights.hits_catcher(point):
				_go_to(objects[0])
				return
			var loom:=_find_object("dream_loom")
			if not loom.is_empty() and Rect2(334,143,276,152).has_point(point):
				_go_to(loom)
				return
		if mode == "furniture":
			if split_view() and point.x>(Studios.room(0).position.x-WORLD_OFFSET.x)/WORLD_SCALE: return
			furniture_editor.click(self,point)
			return
		if mode == "chapter" and not chapter_question and not objects.is_empty() and objects[0].type=="leaf":
			var site: Dictionary = objects[0]
			if MEMBERS[story_member].id == "dori" and site.index == 2 and Rect2(_ete_walk_pos()-Vector2(32,77),Vector2(64,81)).has_point(point):
				_go_to(site)
				return
			var member_id: String=MEMBERS[story_member].id
			var actor_feet: Vector2=site.pos+Vector2(-55,-20)
			if member_id=="yune": actor_feet=yune_dream.feet(self,site.index,actor_feet)
			if member_id=="danming": actor_feet=DanmingWorkshop.ACTOR_FEET[site.index]
			if member_id=="kubby": actor_feet=kubby_embers.feet(self,site.index,_chapter_progress().kubby_notes)
			if member_id=="yato": actor_feet=YatoForest.feet(self,site.index,_chapter_progress().yato_notes)
			if member_id=="fuwa": actor_feet=fuwa_snow.feet(site.index,_chapter_progress().fuwa_notes)
			if (member_id!="fuwa" or FuwaSnow.visible_fuwa(site.index,_chapter_progress().fuwa_notes)) and Field.stella_hit_rect(_field_costume_key(member_id),actor_feet).has_point(point):
				_go_to(site)
				return
		if mode == "play":
			if state.scene == "library" and Rect2(330,164,310,110).has_point(point):
				_go_to(_find_object("shelf"))
				return
			if state.scene == "library" and ActivityArchive.HIT_RECT.has_point(point):
				_go_to(_find_object("activity_archive"))
				return
			var resident := character_touch.hit(self,point)
			if not resident.is_empty():
				_go_to(resident)
				return
			for obj in objects:
				if obj.type == "keepsake" and Rect2(obj.pos-Vector2(32,80),Vector2(64,82)).has_point(point):
					_go_to(obj)
					return
		if (mode == "play" or (mode == "chapter" and not chapter_question)) and Rect2(48,230,880,475).has_point(point):
			for obj in objects:
				if obj.get("promo_away",false): continue
				if obj.pos.distance_to(point + Vector2(0,15)) < 42:
					_go_to(obj)
					return
			pending_object = ""
			_path_to(point)

func _action(id: String) -> void:
	if comic_started>=0 and comic_player.action(self,id): return
	if activity_archive.action(self,id): return
	match id:
		"shared_end":
			if mode=="together": mode="play"
		"new":
			if save_available: mode = "new_confirm"
			else: _new_game()
		"new_confirm": _new_game()
		"cancel_new": mode = "title"
		"continue":
			if state.load_from():
				player_pos = state.player
				_setup_map()
				mode = "ending" if state.opening_pending else "play"
				_notify("루체테로 돌아왔어요. 에테의 의뢰를 이어가세요.")
			else: _notify("저장 파일을 읽지 못했어요. 새 이야기를 시작할 수 있어요.")
		"close":
			if mode == "ending" and state.opening_pending:
				state.opening_pending = false
				_setup_map()
				_save()
			mode = "play"
		"help": mode = "help"
		"journal": mode = "journal"
		"promotion":
			if mode=="play" and state.scene=="library" and state.rebuild_stage()==6 and not state.opening_pending:
				mode="promotion"
		"promote_0","promote_1","promote_2":
			if mode!="promotion": return
			var visits=state.ink_visits
			var error: String=visits.start_error(state,int(id.right(1)))
			if error!="":
				_notify(error)
				return
			if visits.start(state,int(id.right(1))):
				var member: Dictionary=MEMBERS[_mission_index_for(visits.host)]
				mode="play"
				_save()
				_notify("%s에게 ‘%s’ 홍보를 맡겼어요." % [member.short,visits.TOPICS[visits.topic].title])
		"furniture_open":
			if mode == "play": furniture_editor.open(self)
		"life_open":
			if mode == "play" and not state.residents.is_empty():
				life.open(self)
		"yard_cancel":
			if mode == "play" and state.scene == "library" and not state.yard_session.is_empty():
				state.yard_session = {}
				_save()
				_notify("운동 약속을 취소했어요. 오늘 다른 종목을 골라도 돼요.")
		"encounter_shelf":
			if mode == "journal": mode = "encounter_shelf"
		"encounter_read": _open_encounter(story_member)
		"encounter_back":
			if mode == "encounter_book": mode = encounter_return
			elif mode == "encounter_shelf": mode = "journal"
		"encounter_prev":
			if mode == "encounter_book" and encounter_page > 0:
				_turn_encounter(-1)
		"encounter_next":
			if mode == "encounter_book":
				var book: Dictionary = EncounterBooks.VOLUMES[MEMBERS[encounter_member].id].data
				if encounter_page == book.pages.size(): mode = encounter_return
				else: _turn_encounter(1)
		"goto_ete": _visit_ete()
		"fan_forms":
			if mode == "missions" and not state.residents.is_empty(): mode = "fan_forms"
		"forms_back":
			if mode == "fan_forms": mode = "missions"
		"form_traveler": _change_form("")
		"take_mission": _take_mission()
		"rescue_return": _return_with_stella()
		"ongoing_mission":
			if mode == "play" and state.active_mission != "":
				_open_story(_mission_index_for(state.active_mission),"play")
		"story_dialog": _open_story(dialogue_member,"dialog")
		"story_close": _close_story()
		"story_next": _turn_story()
		"story_replay": _replay_debut()
		"comic_play":
			if comic_started>=0 or mode == "rescue" or (mode == "story" and story_page == 0 and not story_sources and state.chapter_steps.get(MEMBERS[story_member].id,0) == 3):
				comic_player.reset()
				comic_started = clock
				buttons.clear()
		"comic_close":
			comic_started = -1.0
			comic_player.reset()
			buttons.clear()
		"comic_source":
			if comic_started >= 0: OS.shell_open(Comics.PROFILES.data[MEMBERS[story_member].id].source)
		"costume_next": _cycle_costume()
		"story_back": story_page = maxi(0,story_page-1)
		"story_sources": story_sources = not story_sources
		"story_choice_0": _choose_story(0)
		"story_choice_1": _choose_story(1)
		"chapter_leave": _leave_chapter()
		"fuwa_turn": fuwa_snow.turn(self)
		"fuwa_close": fuwa_snow.close_view(self)
		"chapter_remember": _remember_chapter()
		"chapter_source":
			if mode=="chapter" and chapter_question: OS.shell_open(Chapters.BOOKS[MEMBERS[story_member].id].source)
		"chapter_look": chapter_question = false
		"story_extra":
			if mode == "story" and MEMBERS[story_member].id in state.residents: story_page = 1
		"story_source_0","story_source_1","story_source_2","story_source_3":
			if mode == "story" and story_sources:
				var refs := _story_references()
				OS.shell_open(refs[int(id.right(1))][1])
		"bag": mode = "bag"
		"requests": mode = "requests"
		"tea":
			var error: String = state.buy_tea()
			_notify(error if error != "" else "따뜻한 차 한 잔. 현재 기운 %d / 100" % state.energy)
			if error == "": _save()
		"lend":
			var error: String = state.lend_book(state.requested_book_index())
			_notify(error if error != "" else "책을 빌려줬어요! 다음 날 반납되면 책갈피 +20")
			if error == "":
				_save()
				_play_chime(660)
		"pause": mode = "pause"
		"next": _advance_dialogue()
		"restore": _restore()
		"audio":
			audio_enabled = not audio_enabled
			if audio_enabled: _play_chime(523)
		"save":
			_save()
			if not save_failed: _notify("오늘의 이야기를 저장했어요.")
		"title":
			_save()
			mode = "title"
		"sleep_confirm":
			var returns: bool = not state.active_loan.is_empty()
			state.sleep()
			player_pos = state.player
			_setup_map()
			mode = "play"
			_save()
			_notify("봄 %d일. %s" % [state.day,"책이 반납됐어요. 책갈피 +20!" if returns else "기운이 돌아오고 정원이 새로 피어났어요."])
			_play_chime(440)
		"goto_table": _go_to(_find_object("table"))
		"goto_portal": _go_to(_find_object("portal"))
		"goto_sleep": _go_to(_find_object("sleep"))
		"goto_desk":
			if state.scene == "garden": _notify("대출 데스크는 도서관 안에 있어요. 먼저 문으로 돌아가요.")
			else: _go_to(_find_object("desk"))
		_:
			if id in ["dori_card_0","dori_card_1","dori_card_2"]:
				DoriCase.choose_card(self,id.right(1).to_int())
			if id.begins_with("join_") and mode=="play": shared.begin(self,id.trim_prefix("join_"))
			if id.begins_with("studio_") and mode=="play" and split_view():
				_studio_interact(_find_object(id.trim_prefix("studio_")))
			if id.begins_with("furn_") and mode == "furniture": furniture_editor.action(self,id.trim_prefix("furn_"))
			if id.begins_with("form_"): _change_form(id.trim_prefix("form_"))
			if id.begins_with("life_") and mode == "stella_life": life.action(self,id.trim_prefix("life_"))
			if id.begins_with("encounter_") and mode == "encounter_shelf":
				var number := id.trim_prefix("encounter_")
				if number.is_valid_int(): _open_encounter(int(number))
			elif id.begins_with("encounter_source_") and mode == "encounter_book":
				var book: Dictionary = EncounterBooks.VOLUMES[MEMBERS[encounter_member].id].data
				var ref := int(id.trim_prefix("encounter_source_"))
				if encounter_page == book.pages.size() and ref >= 0 and ref < book.refs.size():
					OS.shell_open(book.refs[ref][1])
			if id.begins_with("offer_") and mode == "missions":
				mission_index = int(id.trim_prefix("offer_"))
			if id.begins_with("memory_") and mode == "journal":
				_open_story(int(id.trim_prefix("memory_")),"journal")
			if id.begins_with("claim_"):
				var index := int(id.trim_prefix("claim_"))
				var error: String = state.claim_request(index)
				_notify(error if error != "" else "의뢰 완료! 책갈피 +%d" % State.REQUESTS[index].reward)
				if error == "":
					_save()
					_play_chime(880)
			if id.begins_with("book_"): selected_book = int(id.trim_prefix("book_"))
			if id.begins_with("npc_"): _go_to(_find_object(id.trim_prefix("npc_")))
	route = PackedVector2Array() if mode != "play" else route
	if mode != "play": pending_object = ""
	queue_redraw()

func _new_game() -> void:
	state = State.new()
	mission_index = 0
	player_pos = state.player
	_setup_map()
	state.intro_seen = true
	_save()
	_show_dialogue(AETHE_SPEAKER, [
		"어서 와요. 나는 루체테의 사서 에테예요. 저기 나란히 꽂힌 여섯 권이 보이나요? 예전에는 멀리서도 책등 색만 보고 어느 책인지 알았어요.",
		"루체테는 누군가 이야기를 기억해 주는 동안 여기에 있어요. 기억하는 이가 하나둘 떠나면, 책 속 친구들도 이 도서관도 조금씩 희미해져요.",
		"이제 여섯 권 모두 마지막 문장이 비어 있어요. 이 책갈피를 받아요. 책 안에서는 그 스텔라의 팬 모습을 빌려, 지나온 기록을 따라 걸을 수 있어요.",
		"책 속의 일은 이미 지나간 이야기예요. 당신이 과거를 바꿀 필요는 없어요. 그 아이가 걸어온 시간을 끝까지 읽고, 여기 돌아올 자리를 함께 마련해 줘요.",
		"어느 책이든 마음이 가는 것부터 골라요. 마지막 문장을 되찾으면 그 책부터 다시 빛날 거예요. 준비되면 작업대 왼쪽으로 와요. 내가 돌아올 길을 지키고 있을게요."], GOLD)

func _setup_map() -> void:
	recognition.nearby_member=""
	studios_open = state.scene=="library" and state.rebuild_stage()==6 and not state.opening_pending
	character_touch.reset()
	ete_interactions.reset()
	ete_facing="down"
	objects.clear()
	obstacles.clear()
	chapter_floor.clear()
	chapter_trail.clear()
	chapter_signs.clear()
	route.clear()
	pending_object = ""
	if mode == "chapter":
		var id: String = MEMBERS[story_member].id
		var chapter: Dictionary = Chapters.BOOKS[id]
		var scene := _chapter_progress().debut_scene(id)
		chapter_floor=Chapters.floor_polygon(id,scene)
		if id=="fuwa": chapter_floor=FuwaSnow.floor_area(self,scene,_chapter_progress().fuwa_notes)
		if id=="yato" and YatoForest.on_mountain(scene,_chapter_progress().yato_notes): chapter_floor=YatoForest.mountain_floor()
		if id=="dori" and scene==2:
			DoriCase.Rubbing.add_site(objects,_chapter_progress().dori_notes)
		elif book_discovery.active(self) and _chapter_progress().chapter_ready(id,scene):
			pass # Read the discovered memory, then continue without a return waypoint.
		elif not book_discovery.active(self) and _chapter_progress().route_pending(id):
			StoryTrail.add_exit(self,id,scene)
		elif id=="dori" and scene<3 and not DoriCase.ready(scene,_chapter_progress().dori_notes):
			DoriCase.add_sites(objects,scene,_chapter_progress().dori_notes)
		elif id=="yune" and not YuneDream.ready(scene,_chapter_progress().yune_notes):
			YuneDream.add_sites(objects,scene,_chapter_progress().yune_notes)
		elif id=="danming" and not DanmingWorkshop.ready(scene,_chapter_progress().danming_notes):
			DanmingWorkshop.add_sites(objects,scene,_chapter_progress().danming_notes)
		elif id=="kubby" and not KubbyEmbers.ready(scene,_chapter_progress().kubby_notes):
			KubbyEmbers.add_sites(objects,scene,_chapter_progress().kubby_notes)
		elif id=="yato" and not YatoForest.ready(scene,_chapter_progress().yato_notes):
			YatoForest.add_sites(objects,scene,_chapter_progress().yato_notes)
		elif id=="fuwa" and not FuwaSnow.ready(scene,_chapter_progress().fuwa_notes):
			FuwaSnow.add_sites(objects,scene,_chapter_progress().fuwa_notes)
		else:
			var label: String="조사 수첩 펼치기" if id=="dori" and scene==3 and not DoriCase.ready(3,_chapter_progress().dori_notes) else chapter.labels[scene]
			var site: Vector2=chapter.points[scene]
			if id=="dori" and scene==2: site=DoriCase.Rubbing.ETE_SIDE
			if id=="yune": site=YuneDream.record_site(scene,site)
			if id=="danming": site=DanmingWorkshop.record_site(scene)
			if id=="kubby": site=KubbyEmbers.record_site(scene)
			if id=="yato": site=YatoForest.record_site(scene)
			if id=="fuwa": site=FuwaSnow.record_site(scene)
			objects.append({"id":"leaf_%d" % scene,"type":"leaf","index":scene,"pos":site,"label":label})
	elif state.scene == "library":
		objects.append({"id":"ete","type":"librarian","pos":AETHE_POS,"label":"사서 에테 · 의뢰와 변신" if not state.residents.is_empty() else "사서 에테 · 재건 의뢰"})
		obstacles = Furniture.obstacles(state.furniture)
		for i in range(MEMBERS.size()):
			var member: Dictionary = MEMBERS[i]
			if member.id in state.residents:
				var slot: int = state.residents.find(member.id)
				var pos: Vector2 = Furniture.activity_position(state,member.id) if state.yard_session.get("member","")==member.id or state.yard_host==member.id else Yard.SPOTS[slot]
				objects.append({"id":member.id,"type":"npc","index":i,"slot":slot,"pos":pos,"label":member.name + " · 대화"})
			if state.chapter_steps.get(member.id,0) == 3:
				var p: Vector2 = Rebuild.PLACES[member.id]
				objects.append({"id":"gift_"+str(member.id),"type":"keepsake","index":i,"pos":p+Vector2(0,18),"label":Chapters.BOOKS[member.id].gift})
		for item in state.furniture:
			objects.append({"id":"furniture_"+str(item.kind),"type":"furniture","index":-3,"kind":item.kind,"pos":Furniture.position(item),"label":Furniture.ITEMS[item.kind].name+" · 꾸미기"})
		objects.append({"id":"shelf","type":"shelf","pos":Vector2(476,275),"label":"시작의 서가 · 책 펼치기"})
		objects.append({"id":"activity_archive","type":"activity_archive","pos":ActivityArchive.POSITION,"label":"방송 기록 서가 · 실제 방송 꺼내보기"})
		objects.append({"id":"table","type":"table","pos":Vector2(490,450),"label":"복원 작업대"})
		objects.append({"id":"portal","type":"portal","pos":Vector2(833,277),"label":"책 속 정원으로"})
		objects.append({"id":"sleep","type":"sleep","pos":Vector2(132,649),"label":"휴식 의자 · 다음 날"})
		objects.append({"id":"desk","type":"desk","pos":Vector2(710,450),"label":"대출 데스크"})
		objects.append({"id":"board","type":"board","pos":Vector2(95,290),"label":"의뢰 게시판"})
	else:
		obstacles = [Rect2(410,326,172,100),Rect2(115,257,60,55),Rect2(700,240,70,55),Rect2(755,560,65,55),Rect2(250,440,55,45)]
		objects.append({"id":"portal","type":"portal","pos":Vector2(130,637),"label":"루체테로 돌아가기"})
	obstacles.append_array(Dressing.obstacles(self))
	navigation.region = Rect2i(0,0,58,44)
	navigation.cell_size = Vector2(16,16)
	navigation.offset = Vector2(8,8)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(58):
		for y in range(44):
			navigation.set_point_solid(Vector2i(x,y), not _walkable(Vector2(x*16+8,y*16+8)))
	if not _walkable(player_pos):
		var safe_cell := _grid_at(player_pos)
		if safe_cell.x>=0:
			player_pos=navigation.get_point_position(safe_cell)
		else:
			player_pos = Vector2(490,620) if state.scene == "library" else Vector2(180,630)
	if mode=="chapter": StoryTrail.fit_exit(self)
	if mode=="chapter" and not objects.is_empty() and objects[0].type in ["leaf","story_path"]:
		var site: Vector2=objects[0].pos
		var last_mark := player_pos
		for waypoint in navigation.get_point_path(_grid_at(player_pos),_grid_at(site)):
			if waypoint.distance_to(last_mark)>35 and waypoint.distance_to(site)>47:
				chapter_trail.append(waypoint.round())
				last_mark=waypoint
	garden_residents.reset(self)
	state.ink_visits.refresh_map(self)

func _walkable(point: Vector2) -> bool:
	if not Rect2(72,252,836,433).has_point(point): return false
	if not chapter_floor.is_empty() and not Geometry2D.is_point_in_polygon(point,chapter_floor): return false
	for rect in obstacles:
		if rect.grow(12).has_point(point): return false
	return true

func _grid_at(point: Vector2) -> Vector2i:
	var best := Vector2i(-1,-1)
	var distance: float = INF
	var cell := Vector2i(floori(point.x / 16), floori(point.y / 16))
	for dx in range(-6,7):
		for dy in range(-6,7):
			var p := cell + Vector2i(dx,dy)
			if navigation.is_in_boundsv(p) and not navigation.is_point_solid(p):
				var d := point.distance_squared_to(navigation.get_point_position(p))
				if d < distance:
					distance = d
					best = p
	return best

func _path_to(point: Vector2) -> void:
	var start := _grid_at(player_pos)
	var end := _grid_at(point)
	if start.x >= 0 and end.x >= 0:
		route = navigation.get_point_path(start,end)

func _go_to(obj: Dictionary) -> void:
	if obj.is_empty():
		_notify("이 시설은 도서관 안에 있어요. 5번 문으로 돌아가요.")
		return
	if obj.get("in_studio",false) or state.ink_visits.promoting(obj.id) or player_pos.distance_to(obj.pos) < obj.get("reach",78.0):
		_interact(obj)
	else:
		pending_object = obj.id
		_path_to(obj.pos)

func _find_object(id: String) -> Dictionary:
	for obj in objects:
		if obj.id == id: return obj
	return {}

func _nearest() -> Dictionary:
	if mode=="chapter" and MEMBERS[story_member].id=="fuwa" and fuwa_snow.approaching(_chapter_progress().debut_scene("fuwa"),_chapter_progress().fuwa_notes): return {}
	var result: Dictionary = {}
	var distance: float = 78.0
	for obj in objects:
		if obj.get("promo_away",false) or obj.get("in_studio",false): continue
		var d := player_pos.distance_to(obj.pos)
		if d < distance:
			result = obj
			distance = d
	return result

func _studio_interact(obj: Dictionary) -> void:
	if obj.is_empty() or not split_view() or mode!="play": return
	if not obj.get("in_studio",false):
		_notify("%s · %s" % [MEMBERS[obj.index].short,"지금은 홍보하러 나갔어요." if obj.get("promo_away",false) else "공용 도서관에서 만날 수 있어요."])
		return
	var recommendation: bool=state.ink_visits.topic==0 and state.ink_visits.promoting(obj.id)
	if state.yard_host==obj.id or recommendation:
		life.open(self)
		life.member_index=obj.index
		life.open_chat(self,recommendation)
	elif not character_touch.locked(self,obj.id):
		character_touch.react(self,obj.id)

func _interact(obj: Dictionary) -> void:
	if obj.is_empty(): return
	route.clear()
	pending_object = ""
	match obj.type:
		"story_path": _follow_chapter_route(obj)
		"dori_alley": dori_rubbing.begin(self,obj)
		"dori_clue": DoriCase.inspect(self,obj)
		"yune_dream": yune_dream.inspect(self,obj)
		"danming_site": danming_workshop.inspect(self,obj)
		"kubby_site": kubby_embers.inspect(self,obj)
		"yato_site": yato_forest.inspect(self,obj)
		"fuwa_site": fuwa_snow.inspect(self,obj)
		"furniture": furniture_editor.open(self,obj.kind)
		"keepsake":
			var chapter: Dictionary = Chapters.BOOKS[MEMBERS[obj.index].id]
			_show_dialogue(AETHE_SPEAKER,[chapter.home],GOLD)
		"librarian":
			character_touch.release_ete(self)
			ete_interactions.reset()
			mode = "missions"
		"shelf": mode = "journal"
		"activity_archive": activity_archive.open(self)
		"leaf": _inspect_chapter(obj.index)
		"npc":
			if obj.get("in_studio",false):
				_studio_interact(obj)
				return
			if state.scene!="library" or obj.get("promo_away",false): return
			if state.ink_visits.promoting(obj.id):
				_notify("%s · %s 중이에요." % [MEMBERS[obj.index].short,state.ink_visits.TOPICS[state.ink_visits.topic].method])
				return
			if state.yard_host==obj.id and state.can_do_activity(obj.id,"stream"):
				life.open(self)
				life.member_index=obj.index
				life.open_chat(self)
				return
			for i in range(MEMBERS.size()):
				if MEMBERS[i].id == obj.id:
					var previous_score := int(state.friendship[obj.id])
					state.talk(obj.id)
					var lines: Array = MEMBERS[i].lines.duplicate()
					if obj.id in state.restored: lines = [MEMBERS[i].after, "오늘도 도서관에서 함께해 줘서 고마워. 다음 이야기도 찾아보자!"]
					if int(state.friendship[obj.id]) > previous_score: _notify(MEMBERS[i].name + "와 가까워졌어요. 친밀도 +1")
					if state.story_choices.has(obj.id):
						var choice: int = state.story_choices[obj.id]
						var record: Dictionary = Stories.ENTRIES[obj.id]
						lines = [record.recalls[choice], MEMBERS[i].after if obj.id in state.restored else MEMBERS[i].lines[1]]
					var tier: int = state.bond_tier(obj.id)
					var read_count: int = state.read_bonds.get(obj.id,0)
					if read_count < tier:
						var exchange: Array = Stories.ENTRIES[obj.id].bond[read_count]
						lines = [exchange[0], {"text":exchange[1], "warm":true, "bond":read_count+1}]
					elif tier > 0 and not state.story_choices.has(obj.id) and not obj.id in state.restored:
						lines = [MEMBERS[i].lines[2]]
					if state.fan_form!="":
						lines.push_front(FanRecognition.line(obj.id,state.fan_form,"talk"))
					_show_dialogue(MEMBERS[i].name, lines, Color(MEMBERS[i].color), i)
					_save()
		"table": mode = "restore"
		"desk": mode = "loans"
		"board": mode = "requests"
		"portal":
			state.yard_session = {}
			state.yard_host = ""
			state.scene = "garden" if state.scene == "library" else "library"
			player_pos = Vector2(190,630) if state.scene == "garden" else Vector2(800,300)
			_setup_map()
			_save()
			_play_chime(660)
			_notify("책 속 정원 · 팬 모습으로 산책할 수 있어요." if state.scene == "garden" else "루체테에 돌아왔어요. F로 꾸미고 L로 함께할 활동을 골라요.")
		"sleep": mode = "sleep"

func _begin_yard_workout(index: int, routine: String) -> void:
	var id: String = MEMBERS[index].id
	if not state.begin_yard_session(id,routine): return
	_visit_yard_station(id)
	if not save_failed: _notify("%s · %s 시작. 도서관에서 자유롭게 지내요." % [MEMBERS[index].short,State.Workout.ROUTINES[routine].name])

func _begin_yard_stream(index: int) -> void:
	var id: String = MEMBERS[index].id
	if not state.can_do_activity(id,"stream") or state.yard_session.get("member","") == id: return
	state.yard_host = id
	_visit_yard_station(id)
	if not save_failed:
		var hint := "개인실 이름표를 누르면 채팅을 볼 수 있어요." if studios_open else "카메라 옆 스텔라에게 말을 걸면 채팅을 볼 수 있어요."
		_notify("%s의 도서관 방송 · %s" % [MEMBERS[index].short,hint])

func _visit_yard_station(id: String) -> void:
	var entering: bool = state.scene != "library"
	mode = "play"
	life.phase = "roster"
	state.scene = "library"
	if entering:
		player_pos = Furniture.ENTRANCE
	if entering or not studios_open:
		_setup_map()
	else:
		character_touch.reactions.erase(id)
		garden_residents.update(self,0.)
	_save()

func _restore() -> void:
	if not State.BOOKS[selected_book].id in state.residents:
		_open_story(selected_book,"restore")
		return
	var error: String = state.restore_book(selected_book)
	if error != "":
		_notify(error)
		return
	var book: Dictionary = State.BOOKS[selected_book]
	_save()
	_play_chime(880)
	sparkle_bursts.append({"pos":Vector2(490,410),"life":1.0,"color":Color(book.color)})
	var lines: Array = ["『%s』의 낡은 책장을 고쳤어요.\n%s의 친밀도 +2 · 대출용 도서 %d / 6" % [book.name,book.owner,state.restored.size()]]
	if state.restored.size() == 1: lines.append("첫 대출용 책이 준비됐어요. 독자가 기다리는 대출 데스크에 들러 보세요.")
	if state.restored.size() == 6: lines.append("여섯 권의 수리를 마쳤어요. 이제 모든 책을 독자에게 빌려줄 수 있어요.")
	_show_dialogue("이야기 복원 완료",lines,Color(book.color))

func _show_dialogue(speaker: String, lines: Array, color: Color, member: int = -1) -> void:
	mode = "dialog"
	dialogue_name = speaker
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_color = color
	dialogue_member = member
	after_dialogue = "play"

func _advance_dialogue() -> void:
	if mode != "dialog" or dialogue_index >= dialogue_lines.size(): return
	var line = dialogue_lines[dialogue_index]
	if line is Dictionary and line.has("bond"):
		state.read_bonds[MEMBERS[dialogue_member].id] = line.bond
		_save()
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size(): mode = after_dialogue

func _save() -> void:
	state.player = chapter_home if mode in ["chapter","rescue"] else player_pos
	var result: Error = state.save_to()
	save_failed = result != OK
	if save_failed: _notify("저장하지 못했어요. 폴더 권한과 디스크 공간을 확인해 주세요.")
	else: save_available = true

func _open_archive_source(url: String) -> void:
	if OS.shell_open(url)!=OK:
		_notify("출처를 열지 못했어요. 브라우저 연결을 확인해 주세요.")

func _notify(message: String) -> void:
	notice_revision+=1
	toast = message
	toast_time = 4.5

func _play_chime(frequency: float) -> void:
	if not audio_enabled or DisplayServer.get_name() == "headless": return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var count := 6600
	samples.resize(count * 2)
	for i in range(count):
		var t := float(i) / 22050.0
		var envelope := minf(t*80.0,1.0) * exp(-t*14.0)
		var value := int((sin(TAU*frequency*t) + 0.25*sin(TAU*frequency*2*t)) * envelope * 18000)
		samples.encode_s16(i*2,clampi(value,-32768,32767))
	stream.data = samples
	chime.stream = stream
	chime.play()

# Library/UI pixel assets use original integer-grid art; character assets keep their existing pipeline.
func _draw() -> void:
	buttons.clear()
	ui_regions.clear()
	chapter_signs.clear()
	if comic_started >= 0:
		in_world=false
		_transform()
		draw_rect(Rect2(0,0,1280,800),Color("38473c"))
		Comics.draw(self,MEMBERS[story_member].id,comic_player.elapsed(self))
		return
	draw_rect(Rect2(0,0,1280,800), Color("38473c"))
	for y in range(0,800,24):
		for x in range(0,1280,32):
			if (x/32+y/24)%3 == 0:
				draw_rect(Rect2(x+4,y+7,3,6), Color("495c47"))
	if split_view(): Studios.layer(self,false)
	in_world = true
	_transform()
	if mode in ["chapter","rescue"]:
		var id: String = MEMBERS[story_member].id
		Chapters.landscape(self,id,_chapter_progress().debut_scene(id))
	elif state.scene == "library":
		_draw_library()
	else:
		_draw_garden()
	_draw_objects()
	if mode=="chapter": yato_forest.storehouse.draw_words(self)
	if mode=="chapter" and dori_rubbing.phase!=DoriCase.Rubbing.Phase.FIELD: dori_rubbing.draw_tools(self)
	if mode=="chapter" and MEMBERS[story_member].id=="yato" and _chapter_progress().debut_scene("yato")==3:
		yato_forest.draw_foreground_light(self)
	if split_view():
		in_world=false
		_transform()
		Studios.layer(self,true)
		Studios.labels(self)
		in_world=true
		_transform()
	if mode=="play": character_touch.draw_drag(self)
	if mode == "furniture": furniture_editor.draw_world(self)
	book_discovery.draw_focus(self)
	if (mode == "play" and not character_touch.dragging) or (mode == "chapter" and not chapter_question and not dori_rubbing.active(self) and not book_discovery.active(self)):
		var near := _nearest()
		if not near.is_empty():
			var width := font.get_string_size(near.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x + 66
			var x := clampf(near.pos.x-width/2,55,925-width)
			var prompt_y: float = near.pos.y - (112 if near.type in ["npc","librarian"] else 90)
			if Rect2(x,prompt_y,width,34).intersects(Rect2(player_pos-Vector2(34,77),Vector2(68,81))):
				prompt_y=player_pos.y-115 if player_pos.y-115>=230 else player_pos.y+27
			if mode=="chapter":
				var id: String=MEMBERS[story_member].id
				if id=="fuwa" or (id=="yato" and _chapter_progress().debut_scene(id) in [2,3]):
					prompt_y=maxf(near.pos.y,player_pos.y)+51
			if state.scene=="library" and mode=="play":
				for guest in state.ink_visits.guests:
					if Rect2(x,prompt_y,width,34).intersects(Rect2(guest.pos-Vector2(31,55),Vector2(63,58))):
						x=clampf(guest.pos.x+37 if guest.pos.x<510 else guest.pos.x-width-37,55,925-width)
			_panel(Rect2(x,prompt_y,width,34),PAPER,GOLD)
			_text(Vector2(x+13,prompt_y+23),"E  " + near.label,15,CREAM)
	in_world = false
	_transform()
	if mode == "chapter":
		_draw_chapter_hud()
	elif mode == "play":
		_draw_hud()
		recognition.draw(self)
	elif mode=="together":
		_draw_hud()
		shared.draw_panel(self)
	elif mode == "furniture":
		furniture_editor.draw_ui(self)
	else:
		_draw_overlay()
	if toast_time > 0:
		var width := minf(1100,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+44)
		var toast_y := 34 if mode == "story" else 92
		_panel(Rect2(640-width/2,toast_y,width,39),PAPER,GOLD)
		_center(toast_y+26,toast,16,CREAM)
	if mode=="chapter" and MEMBERS[story_member].id=="dori": dori_rubbing.draw_transition(self)
	if mode in ["chapter","rescue"]: book_discovery.draw_transition(self)

func _transform(pos: Vector2 = Vector2.ZERO, size: Vector2 = Vector2.ONE, angle: float = 0.0) -> void:
	if in_world:
		draw_set_transform(WORLD_OFFSET+pos*WORLD_SCALE,angle,size*WORLD_SCALE)
	else:
		draw_set_transform(pos,angle,size)

func _text(pos: Vector2, value: String, size: int = 18, color: Color = CREAM) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(y: float, value: String, size: int = 18, color: Color = CREAM, x: float = 640) -> void:
	_text(Vector2(x-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,y),value,size,color)

func _text_block(pos: Vector2, value: String, width: float, size: int = 18, color: Color = CREAM, line_height: int = 30) -> float:
	var y := pos.y
	for paragraph in value.split("\n"):
		var line := ""
		for word in paragraph.split(" ",false):
			var next_line: String = word if line.is_empty() else line + " " + word
			if not line.is_empty() and font.get_string_size(next_line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width:
				_text(Vector2(pos.x,y),line,size,color)
				y += line_height
				line = word
			else:
				line = next_line
		_text(Vector2(pos.x,y),line,size,color)
		y += line_height
	return y

func _panel(rect: Rect2, fill: Color, border: Color = Color("b88752")) -> void:
	var paper := PAPER if fill.get_luminance() < 0.38 else fill
	Pixels.panel(self,rect,paper,"panel")

func _button(rect: Rect2, label: String, id: String, accent: bool = false, disabled: bool = false) -> void:
	if OS.has_feature("web"): label=label.replace("↵","Enter")
	var hover := rect.has_point(get_global_mouse_position()) and not disabled
	var fill := Color("e8c58d") if accent else Color("e9d8b3")
	if hover: fill = fill.lightened(.12)
	if disabled: fill = Color("c8bda6")
	Pixels.panel(self,rect,fill,"accent" if accent and not disabled else "slot")
	var size := 14 if rect.size.y < 36 else 17
	_center(rect.get_center().y+size*.35,label,size,MUTED if disabled else CREAM,rect.get_center().x)
	if not disabled: buttons.append({"rect":rect,"id":id})

func _draw_library() -> void:
	var stage: int = state.rebuild_stage()
	Pixels.background(self,stage)
	Pixels.story_books(self)
	if not state.residents.is_empty(): Furniture.draw_rooms(self)
	Pixels.window_light(self,stage)
	for item in state.furniture:
		Pixels.contact_shadow(self,item.kind,Furniture.position(item))
	_world_sign(Vector2(476,260),"스토리 · 시작의 서가  J")
	ActivityArchive.draw_world(self)
	_world_sign(Vector2(490,485),"이야기 복원 작업대")
	_world_sign(Vector2(128,672),"휴식 의자")
	_world_sign(Vector2(714,462),"대출 데스크")
	_world_sign(Vector2(834,287),"책 속 정원")
	if not state.yard_session.is_empty():
		var routine: String = state.yard_session.routine
		if Furniture.find(state.furniture,"mat").is_empty() or routine=="gym":
			Yard.draw_station(self,Furniture.activity_position(state,state.yard_session.member),routine)
	if not studios_open and state.yard_host!="" and Furniture.find(state.furniture,"camera").is_empty():
		Yard.draw_station(self,Furniture.activity_position(state,state.yard_host),"stream")
	if stage==6:
		if studios_open: Studios.draw_passage(self)
		var door: Vector2=state.ink_visits.DOOR
		draw_rect(Rect2(door+Vector2(-22,-2),Vector2(44,36)),Color("594a41"))
		draw_rect(Rect2(door+Vector2(-20,0),Vector2(40,32)),Color("547069"))
		for y in [2,5,27,30]: draw_line(door+Vector2(-17,y),door+Vector2(17,y),Color("bcaa7b"))
	Pixels.atmosphere(self,stage)

func _draw_shelf(pos: Vector2, width: int, stage: int) -> void:
	Pixels.sprite(self,"shelf_"+("story_" if width>250 else "west_")+str(clampi(stage,0,6)),pos-Vector2(4,6))
	if width>250: Pixels.story_books(self)

func _draw_garden() -> void:
	WorldPixels.background(self,"garden")
	for i in range(7):
		var offset := roundf(sin(clock*0.8+i)*4)
		draw_line(Vector2(431+offset,342+i*10),Vector2(440+offset+(i%3)*12,342+i*10),Color("86afb0"),1)
	for p in [Vector2(144,298),Vector2(739,282),Vector2(792,607),Vector2(277,474)]: _draw_tree(p)
	_draw_portal(Vector2(130,586))
	_world_sign(Vector2(128,672),"도서관으로")
	_text(Vector2(675,181),"매일 새로 피어나는 이야기",14,Color("e1d9ad"))
	_draw_dust(true)

func _world_sign(pos: Vector2, label: String, chapter_target: String="") -> void:
	if book_discovery.active(self): return
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x + 18
	var rect := Rect2(pos-Vector2(width/2,11),Vector2(width,21))
	if not chapter_target.is_empty() and mode=="chapter" and not chapter_question:
		chapter_signs.append({"id":chapter_target,"rect":rect})
	draw_rect(Rect2(rect.position+Vector2(0,2),rect.size),Color("242c2b77"))
	draw_rect(rect,Color("3d5148ec"))
	draw_rect(Rect2(rect.position+Vector2(3,0),Vector2(width-6,1)),Color("9e926a"))
	for x in [rect.position.x+3,rect.end.x-4]: draw_rect(Rect2(x,pos.y-1,1,1),Color("d1bd87"))
	_center(pos.y+5,label,12,Color("f4e7c8"),pos.x)

func _draw_tree(pos: Vector2) -> void:
	WorldPixels.sprite(self,"tree",pos)

func _draw_plant(pos: Vector2, lush: bool) -> void:
	draw_rect(Rect2(pos+Vector2(-13,-15),Vector2(26,25)),Color("9f7355"))
	draw_rect(Rect2(pos+Vector2(-17,-18),Vector2(34,7)),Color("bd916c"))
	draw_line(pos+Vector2(0,-18),pos+Vector2(0,-60),Color("749278"),3)
	for i in range(3 if lush else 2):
		var color := Color("8eb292") if lush else Color("7f9675")
		draw_rect(Rect2(pos+Vector2(-22+i*6,-35-i*11),Vector2(20,10)),color)
		draw_rect(Rect2(pos+Vector2(2,-43-i*11),Vector2(20-i*3,10)),color.darkened(0.1))

func _draw_portal(pos: Vector2) -> void:
	draw_circle(pos+Vector2(0,24),55,Color(0.55,0.8,0.75,0.07))
	WorldPixels.sprite(self,"prop_library_door",pos+Vector2(0,37),2.1)
	_star(pos+Vector2(0,13+sin(clock*2)*3),13,Color("f0e7bd"))
	for i in range(4):
		_star(pos+Vector2(sin(clock+i*2)*40,cos(clock*0.7+i)*36+12),3,GOLD)

func _draw_book(pos: Vector2, color: Color, opened: bool = false, scale_factor: float = 1.0) -> void:
	Pixels.book(self,pos,color,opened,scale_factor)

func draw_ellipse_shadow(pos: Vector2, size: Vector2) -> void:
	if in_world and mode in ["chapter","rescue"]:
		Field.Finish.contact(self,pos,size)
		return
	_transform(pos,Vector2(1,size.y/size.x))
	draw_circle(Vector2.ZERO,size.x,Color(0,0,0,0.18))
	_transform()

func _star(pos: Vector2, size: float, color: Color) -> void:
	if size<0.5 or color.a<=0.0: return
	draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-size),pos+Vector2(size*0.28,-size*0.28),pos+Vector2(size,0),pos+Vector2(size*0.28,size*0.28),pos+Vector2(0,size),pos+Vector2(-size*0.28,size*0.28),pos+Vector2(-size,0),pos+Vector2(-size*0.28,-size*0.28)]),color)

func _draw_dust(garden: bool) -> void:
	for i in range(24):
		var x := 80+fmod(i*83.0+sin(clock*0.35+i)*15,810)
		var y := 260+fmod(i*57.0-clock*(3 if garden else 1),410)
		var alpha := 0.15+0.12*sin(clock+i)
		draw_rect(Rect2(x,y,2,2),Color(0.99,0.89,0.65,alpha))

func _draw_before_characters() -> void:
	pass

func _draw_librarian_override(_feet: Vector2) -> bool:
	return false

func _actor_is_character(actor: Dictionary) -> bool:
	return actor.index>=-2 or actor.index==-7

func _actor_less(a: Dictionary,b: Dictionary) -> bool:
	# In the library, characters stay above bookcases and furniture fronts.
	# Story scenes retain their authored depth and occlusion choreography.
	if world_map_active() and _actor_is_character(a)!=_actor_is_character(b):
		return not _actor_is_character(a)
	return a.pos.y+(1 if a.index==-3 else -1 if a.index==-4 else 0)<b.pos.y+(1 if b.index==-3 else -1 if b.index==-4 else 0)

func _draw_objects() -> void:
	var actors: Array = []
	if mode in ["chapter","rescue"]:
		var id: String = MEMBERS[story_member].id
		var chapter: Dictionary = Chapters.BOOKS[id]
		var scene := _chapter_progress().debut_scene(id)
		var site: Vector2 = chapter.points[scene]
		if id == "dori" and scene in [1,2]:
			if scene == 2: actors.append({"pos":_ete_walk_pos(),"index":-2})
		elif (id!="fuwa" or FuwaSnow.visible_fuwa(scene,_chapter_progress().fuwa_notes)) and (id!="yato" or scene>0 or "nest" in _chapter_progress().yato_notes):
			var feet: Vector2=site+Vector2(-55,-20)
			if id=="yune": feet=yune_dream.feet(self,scene,feet)
			if id=="danming": feet=DanmingWorkshop.ACTOR_FEET[scene]
			if id=="kubby": feet=kubby_embers.feet(self,scene,_chapter_progress().kubby_notes)
			if id=="yato": feet=YatoForest.feet(self,scene,_chapter_progress().yato_notes)
			if id=="fuwa": feet=fuwa_snow.feet(scene,_chapter_progress().fuwa_notes)
			actors.append({"pos":feet,"index":story_member})
		if id == "dori" and scene == 3: actors.append({"pos":site+Vector2(59,-32),"index":-2})
	for obj in objects:
		if obj.get("promo_away",false): continue
		if character_touch.dragging and obj.id==character_touch.held: continue
		if obj.type == "npc": actors.append(obj)
		elif obj.type == "keepsake": actors.append({"pos":Rebuild.PLACES[MEMBERS[obj.index].id],"index":-5,"member":MEMBERS[obj.index]})
		elif obj.type == "furniture":
			actors.append(obj)
			var back := obj.duplicate()
			back.index = -4
			actors.append(back)
		elif obj.type == "librarian": actors.append({"pos":obj.pos,"index":-2})
	actors.append({"pos":player_pos,"index":-1})
	if state.scene=="library" and mode not in ["chapter","rescue"]:
		for guest in state.ink_visits.guests:
			actors.append({"pos":guest.pos,"index":-7,"guest":guest})
	if world_map_active(): append_world_layers(actors)
	else: Dressing.append_actors(self,actors)
	actors.sort_custom(_actor_less)
	var before_characters:=false
	for actor in actors:
		if world_map_active() and not before_characters and _actor_is_character(actor):
			_draw_before_characters();before_characters=true
		if actor.index == -8:
			draw_world_layer(actor.region)
		elif actor.index == -1:
			var form: String = MEMBERS[story_member].id if mode in ["chapter","rescue"] else state.fan_form
			if mode=="chapter" and form=="dori" and _chapter_progress().debut_scene(form)==2:
				dori_rubbing.draw_fan(self,actor.pos)
			elif mode=="chapter" and form=="fuwa" and fuwa_snow.practice.phase!=FuwaSnow.WardPractice.Phase.FIELD:
				fuwa_snow.practice.draw_tenbi(self,actor.pos)
			elif mode=="chapter" and form=="yato" and yato_forest.storehouse.phase==YatoForest.Storehouse.Phase.INSPECT:
				yato_forest.storehouse.draw_mato(self,actor.pos)
			elif mode=="chapter" and danming_workshop.view==2:
				danming_workshop.lens.draw_beori(self,actor.pos)
			elif mode in ["chapter","rescue"]:
				BookRole.draw(self,form,actor.pos,moving,Color(MEMBERS[story_member].color))
			else:
				_draw_traveler(actor.pos,moving,form)
				if mode=="together": shared.draw_prop(self,actor.pos)
			# Free-roam characters use the nearby interaction prompt, not foot labels.
			if form != "" and mode in ["chapter","rescue"]:
				var label: String=Chapters.BOOKS[form].fan+" · 나"
				if mode=="chapter" and form=="fuwa" and (_chapter_progress().debut_scene(form)==1 or "awoke" in _chapter_progress().fuwa_notes):
					label="기억을 읽는 텐비"
				var label_pos: Vector2=actor.pos+Vector2(0,17)
				if mode=="chapter" and danming_workshop.view==2:
					label_pos.y-=danming_workshop.lens.raised*(danming_workshop.lens.anchor_y-293)
				if not dori_rubbing.active(self) and dori_rubbing.phase==DoriCase.Rubbing.Phase.FIELD and yune_dream.view!=2 and fuwa_snow.practice.phase==FuwaSnow.WardPractice.Phase.FIELD: _world_sign(label_pos,label)
		elif actor.index == -7:
			state.ink_visits.draw_guest(self,actor.guest)
		elif actor.index == -6:
			Dressing.draw(self,actor)
		elif actor.index == -5:
			Rebuild.furnishing(self,actor.member.id)
		elif actor.index == -4:
			Furniture.draw_back(self,actor.kind,actor.pos)
		elif actor.index == -3:
			Furniture.draw_front(self,actor.kind,actor.pos)
		elif actor.index == -2:
			var pose := _ete_field_pose()
			if not character_touch.ete_visit.is_empty() and character_touch.ete_visit.phase=="return":
				pose={"direction":ete_facing,"walking":true,"distance":character_touch.ete_visit.distance}
			if _draw_librarian_override(actor.pos): pass
			elif dori_rubbing.active(self):
				Field.draw_story_librarian(self,actor.pos,pose,dori_rubbing.held_by_ete(self))
			elif mode in ["chapter","rescue"] or not ete_interactions.draw_actor(self,actor.pos):
				Field.draw_facing(self,"aethe",actor.pos,pose.direction,pose.walking,pose.distance)
			if mode == "chapter" and MEMBERS[story_member].id == "dori" and _chapter_progress().debut_scene("dori") == 2:
				if dori_rubbing.held_by_ete(self): dori_rubbing.draw_carried(self)
			elif mode in ["chapter","rescue"]: _world_sign(actor.pos+Vector2(0,15),"사서 에테")
		elif actor.get("type","") == "npc":
			if character_touch.draw_reaction(self,actor): continue
			var member: Dictionary = MEMBERS[actor.index]
			var act := Yard.routine(state,actor.slot,actor.id)
			var seconds: float = clock+actor.slot*0.43
			if state.yard_session.get("member","") == actor.id: seconds = state.yard_session.elapsed
			if actor.get("yard_action","") != "":
				act = actor.yard_action
				seconds = actor.yard_seconds
			Yard.draw_actor(self,member,actor.pos,act,seconds,actor.facing,actor.walk_distance)
		else:
			var member: Dictionary = MEMBERS[actor.index]
			var tint := Color.WHITE
			var dream_walk := false
			if mode=="chapter" and member.id=="yune":
				var scene:=_chapter_progress().debut_scene("yune")
				var notes: Array=_chapter_progress().yune_notes
				if scene==0 and not YuneDream.ready(0,notes): tint.a=.22
				if scene==2: tint=yune_dream.nights.yune_tint()
				if scene==3:
					tint.a=.88 if "call" in notes else .36
					dream_walk="call" in notes and yune_dream.walk_fraction(self)<1.0
			if dream_walk:
				Field.draw_stella_turn(self,"yune",_field_costume_key("yune"),actor.pos,"right",true,YuneDream.WALK_START.distance_to(actor.pos))
			elif mode=="chapter" and member.id=="fuwa" and fuwa_snow.practice.phase!=FuwaSnow.WardPractice.Phase.FIELD:
				fuwa_snow.practice.draw_fuwa(self,actor.pos)
				continue
			elif mode=="chapter" and member.id=="fuwa" and _chapter_progress().debut_scene("fuwa")==2:
				Field.draw_stella_turn(self,"fuwa",_field_costume_key("fuwa"),actor.pos,"right",fuwa_snow.arrival<1.0,FuwaSnow.SEARCH_START.distance_to(actor.pos))
			elif mode=="chapter" and member.id=="yato" and _chapter_progress().debut_scene("yato")==1:
				yato_forest.storehouse.draw_yato(self,actor.pos)
			elif mode=="chapter" and member.id=="yato" and _chapter_progress().debut_scene("yato")==2:
				var mountain:=YatoForest.on_mountain(2,_chapter_progress().yato_notes)
				var origin:=YatoForest.TRAIL_START if mountain else YatoForest.TOWN_START
				var last_x:=790 if mountain else 613
				Field.draw_stella_turn(self,"yato",_field_costume_key("yato"),actor.pos,"right",moving and player_pos.x>origin.x and player_pos.x<last_x,actor.pos.distance_to(origin))
			elif mode=="chapter" and member.id=="danming" and _chapter_progress().debut_scene("danming") in [1,2]:
				Field.draw_stella_turn(self,"danming",_field_costume_key("danming"),actor.pos,"up",false,0.0)
			elif mode=="chapter" and member.id=="kubby":
				var progress:=_chapter_progress()
				var scene:=progress.debut_scene("kubby")
				if scene==1:
					kubby_embers.village.draw_kubby(self,actor.pos)
				elif scene==0 or (scene==2 and kubby_embers.flow<KubbyEmbers.STOPS[1]):
					# Her original silhouette is how the verified memory is illustrated in the comic.
					_draw_member(actor.pos,"kubby",Field.STELLA_HEIGHT,true,Color("50465b"))
				elif scene==3 and "night" in progress.kubby_notes:
					Field.draw_stella_turn(self,"kubby","kubby_origin",actor.pos,"right",clock-kubby_embers.left_at<2.2,Vector2(416,497).distance_to(actor.pos))
				else: _draw_member(actor.pos,"kubby",Field.STELLA_HEIGHT,true)
			else: _draw_member(actor.pos,member.id,Field.STELLA_HEIGHT,true,tint)
			if mode=="chapter" and member.id=="yune" and yune_dream.view==2: continue
			if mode=="chapter" and member.id=="yato" and yato_forest.storehouse.phase==YatoForest.Storehouse.Phase.FAMILY: continue
			if mode=="chapter" and member.id=="kubby" and kubby_embers.village.watching: continue
			var label: String = member.short
			if mode != "chapter" and member.id in state.talked_today: label += " ·"
			draw_rect(Rect2(actor.pos+Vector2(-24,6),Vector2(48,21)),Color("664e3c"))
			_center(actor.pos.y+22,label,13,Color("fff0c5"),actor.pos.x)
	if route.size() > 0:
		var end := route[route.size()-1]
		draw_arc(end,7,0,TAU,16,Color(GOLD,0.6),1)
	for burst in sparkle_bursts:
		for i in range(8):
			var angle: float = i*TAU/8
			_star(burst.pos+Vector2(cos(angle),sin(angle))*(1-burst.life)*75,burst.life*5,Color(burst.color,burst.life))

func _costume_key(id: String) -> String:
	return Wardrobe.equipped(id,state.costumes.get(id,""))

func _field_costume_key(id: String) -> String:
	var key := _costume_key(id)
	if mode in ["chapter","rescue"]:
		if id == "danming": key = "danming_origin"
		if id == "kubby": key = "kubby_origin"
	return key

func _draw_member(feet: Vector2, id: String, height: float, compact: bool = false, tint: Color = Color.WHITE) -> void:
	var key := _field_costume_key(id)
	if compact:
		Field.draw(self,key,feet,height,tint)
		return
	var costume: Array = Wardrobe.COSTUMES[id][key]
	var texture: Texture2D = costume[1]
	var size := texture.get_size() * (height / texture.get_height())
	if in_world:
		draw_ellipse_shadow(feet+Vector2(0,1),Vector2(13,4))
	draw_texture_rect(texture,Rect2((feet-Vector2(size.x/2,height)).round(),size),false,tint)

func _draw_member_face(rect: Rect2, id: String, warm: bool) -> void:
	var key := _costume_key(id)
	var base: Texture2D = Wardrobe.COSTUMES[id][key][1]
	var portrait := faces.warm_portrait(base,key) if warm else base
	draw_texture_rect_region(portrait,rect,Faces.portrait_region(base,key))

func _cycle_costume() -> void:
	var id: String = MEMBERS[story_member].id
	var keys: Array = Wardrobe.COSTUMES[id].keys()
	if not id in state.residents or keys.size() < 2: return
	state.costumes[id] = keys[(keys.find(_costume_key(id))+1) % keys.size()]
	_save()

func _draw_traveler(pos: Vector2, walking: bool, form: String) -> void:
	if form.is_empty(): _draw_player(pos,walking)
	else: FanForms.draw(self,form,pos,walking)

func _draw_player(pos: Vector2, walking: bool) -> void:
	const TRAVELER=preload("res://assets/characters/yard/traveler.png")
	var phase:=fposmod(clock+1.7,4.8)
	var blink:=1 if phase<.06 else 2 if phase<.14 else 1 if phase<.2 else 0
	var frame:=floori(traveler_cycle*72)%72 if walking else blink
	var row:=1+floori(frame/36.0) if walking else 0
	var region:=Rect2(frame%36*96,row*112,96,112)
	draw_ellipse_shadow(pos+Vector2(0,3),Vector2(16,4))
	if not Field.directional_textures.has("traveler"):
		var tex:=CanvasTexture.new()
		tex.diffuse_texture=TRAVELER
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		Field.directional_textures["traveler"]=tex
	draw_texture_rect_region(Field.directional_textures["traveler"],Rect2(Field.origin(self,pos,Field.PIXEL_SCALE),Vector2(Field.CELL)*Field.PIXEL_SCALE),region)


func _draw_hud() -> void:
	# Keep the pre-opening archive shelf clear; dock its status beside the toolbar.
	var library_footer: bool = state.scene == "library" and not split_view()
	if library_footer:
		var identity := Rect2(22,703,266,84)
		_panel(identity,PAPER)
		Pixels.icon(self,"journal",Vector2(48,736),1.8)
		_text(Vector2(73,732),"루체테 도서관",20)
		_text(Vector2(73,751),state.library_rank(),12,MUTED)
		_text(Vector2(38,776),"재건 %d/6" % state.rebuild_stage(),14)
		for i in range(6):
			var tint := Color("c6ae84")
			if state.chapter_steps.get(State.BOOKS[i].id,0) == 3: tint = Color(State.BOOKS[i].color).darkened(0.15)
			draw_rect(Rect2(153+i*18,763,12,14),tint)
		ui_regions.append(identity)
	else:
		var place := "루체테 도서관" if state.scene == "library" else "책 속 정원"
		var banner := Rect2(22,18,238,73)
		_panel(banner,PAPER)
		Pixels.icon(self,"journal",Vector2(52,53),1.8)
		_text(Vector2(76,51),place,22)
		_text(Vector2(76,74),state.library_rank(),13,MUTED)
		ui_regions.append(banner)
	# Calendar and clock occupy the unwalkable top edge of the room.
	var almanac := Rect2(1101,16,158,121)
	_panel(almanac,PAPER)
	Pixels.icon(self,"sun",Vector2(1131,52),2.0)
	_text(Vector2(1157,46),"봄 %02d일" % state.day,18)
	_text(Vector2(1157,70),"%02d:%02d" % [state.minutes/60,state.minutes%60],18,MUTED)
	draw_line(Vector2(1115,83),Vector2(1244,83),Color("c59b64"),2)
	_icon("bookmark",Vector2(1122,107))
	_text(Vector2(1135,113),str(state.bookmarks),16)
	if mode=="play": _button(Rect2(1187,94,55,30),"메뉴","pause")
	ui_regions.append(almanac)
	# Restore count remains visible while individual assignments live in the board.
	if not library_footer:
		var tag := Rect2(22,99,211,39)
		_panel(tag,PAPER)
		_text(Vector2(36,124),"재건 %d/6" % state.rebuild_stage(),14)
		for i in range(6):
			var tint := Color("c6ae84")
			if state.chapter_steps.get(State.BOOKS[i].id,0) == 3: tint = Color(State.BOOKS[i].color).darkened(0.15)
			draw_rect(Rect2(113+i*17,112,11,14),tint)
		ui_regions.append(tag)
	if mode=="together":
		var visitors=state.ink_visits
		if studios_open:
			_panel(Rect2(412,24,456,46),PAPER)
			_center(54,"공용 도서관   ·   방문 중 %d명   /   누적 %d명" % [visitors.guests.size(),visitors.total],17,CREAM)
		return
	character_touch.draw_hint(self)
	if not state.residents.is_empty():
		_button(Rect2(897,24,192,46),"스텔라의 하루   L","life_open",true)
		if state.scene == "library": _button(Rect2(897,79,192,38),"도서관 꾸미기   F","furniture_open")
	if state.scene == "library" and not state.yard_session.is_empty():
		var session: Dictionary = state.yard_session
		var member: Dictionary = MEMBERS[_mission_index_for(session.member)]
		var panel := Rect2(1061,594,198,67) if library_footer else Rect2(267,76,193,64)
		_panel(panel,PAPER)
		ui_regions.append(panel)
		_text(panel.position+Vector2(12,25),member.short+" · "+State.Workout.ROUTINES[session.routine].name,16)
		draw_rect(Rect2(panel.position+Vector2(13,40),Vector2(100,8)),Color("bfa782"))
		draw_rect(Rect2(panel.position+Vector2(13,40),Vector2(100*session.elapsed/State.Workout.DURATION,8)),Color("739883"))
		_button(Rect2(panel.position+Vector2(124,27),Vector2(56,28)),"취소","yard_cancel")
	var energy_panel := Rect2(1125,672,134,91)
	_panel(energy_panel,PAPER)
	_text(Vector2(1143,705),"기운  %d" % state.energy,17)
	draw_rect(Rect2(1142,719,100,13),Color("5b4b3c"))
	draw_rect(Rect2(1144,721,96,9),Color("b8aa89"))
	var energy_width := floorf(96*state.energy/100.0)
	draw_rect(Rect2(1144,721,energy_width,9),Color("6f9270") if state.energy > 20 else Color("ba7a5a"))
	draw_rect(Rect2(1144,721,energy_width,2),Color("b4c692") if state.energy > 20 else Color("e2b079"))
	for x in range(1163,1240,19): draw_rect(Rect2(x,722,1,7),Color("49624d55"))
	_text(Vector2(1143,751),"E  상호작용",12,MUTED)
	ui_regions.append(energy_panel)
	var bar := Rect2(300,703,680,84)
	_panel(bar,Color("d8aa71"))
	ui_regions.append(bar)
	if state.active_mission != "":
		var mission: Dictionary = State.BOOKS[_mission_index_for(state.active_mission)]
		var mission_rect := Rect2(432,24,453,46) if library_footer else Rect2(395,24,490,46)
		var mission_label: String = "에테의 의뢰   ·   %s 구출   ›   이야기 이어가기" % mission.owner if library_footer else "에테의 의뢰   ·   %s 구출   ›   %s" % [mission.owner,mission.name]
		_button(mission_rect,mission_label,"ongoing_mission",true)
	elif state.scene == "library" and state.rebuild_stage() < 6:
		_button(Rect2(432,24,453,46),"작업대 왼쪽   ·   사서 에테에게 재건 의뢰 받기","goto_ete",true)
	elif state.scene=="library":
		var visits=state.ink_visits
		var status: String="홍보 주제 맡기기" if visits.topic<0 else visits.TOPICS[visits.topic].method+" · 방문 중 %d명" % visits.guests.size()
		_button(Rect2(395,24,490,46),"도서관 홍보   P     %s   |   누적 %d명" % [status,visits.total],"promotion",true)
	var shortcuts := [["bookmark","책갈피","bag"],["journal","서가","journal"],["requests","의뢰","requests"],["table","복원","goto_table"],["portal","이동","goto_portal"],["loans","대출","goto_desk"],["sleep","휴식","goto_sleep"]]
	for i in range(shortcuts.size()):
		var item: Array = shortcuts[i]
		var slot := Rect2(313+i*94,714,89,60)
		var locked: bool = state.scene == "garden" and i in [3,5,6]
		var hover := slot.has_point(get_global_mouse_position())
		Pixels.panel(self,slot,Color("c8bda6") if locked else (Color("fff0cf") if hover else Color("efdfba")),"accent" if hover and not locked else "slot")
		_text(slot.position+Vector2(7,16),str(i+1),12,MUTED)
		_icon(item[0],slot.position+Vector2(47,21))
		_center(slot.position.y+51,"돌아가기" if i == 4 and state.scene == "garden" else item[1],14,MUTED if locked else CREAM,slot.get_center().x)
		if not locked: buttons.append({"rect":slot,"id":item[2]})
		if i == 2 and _unclaimed_count() > 0:
			draw_circle(slot.position+Vector2(74,13),8,Color("a65036"))
			_text(slot.position+Vector2(72,17),"!",12,Color.WHITE)
	var help_rect := Rect2(250,713,27,28) if library_footer else Rect2(22,727,105,35)
	_button(help_rect,"?" if library_footer else "?   도움말","help")
	ui_regions.append(help_rect)

func _unclaimed_count() -> int:
	var count := 0
	for i in range(State.REQUESTS.size()):
		if state.request_ready(i) and not state.request_claim_key(i) in state.claimed_requests:
			count += 1
	return count

func _draw_promotion() -> void:
	var visits=state.ink_visits
	_panel(Rect2(222,128,836,534),PAPER)
	_text(Vector2(264,191),"도서관 홍보",29)
	_text(Vector2(264,230),"스텔라에게 주제를 맡기고, 도서관에서 잉크를 맞이해요.",18,MUTED)
	for i in range(visits.TOPICS.size()):
		var theme: Dictionary=visits.TOPICS[i]
		var y:=266+i*81
		_button(Rect2(260,y,496,60),"%d    %s" % [i+1,theme.title],"promote_%d" % i,true,visits.start_error(state,i)!="")
		_text(Vector2(784,y+36),theme.method,18,GOLD)
	var status: String="지금까지 루체테를 찾아온 잉크  %d명" % visits.total
	if visits.topic>=0:
		status="%s의 %s  ·  방문 중 %d명  ·  오는 중 %d명" % [MEMBERS[_mission_index_for(visits.host)].short,visits.TOPICS[visits.topic].method,visits.guests.size(),visits.pending]
	var error: String=visits.start_error(state,0)
	if error!="" and visits.topic<0: status=error
	_text(Vector2(266,526),status,16)
	_text(Vector2(266,556),"이 창에서는 방문이 잠시 멈춰요. 열람실로 돌아가면 이어져요.",14,MUTED)
	_button(Rect2(792,583,219,44),"열람실로   Esc","close")

func _icon(id: String, p: Vector2) -> void:
	Pixels.icon(self,id,p)

func _draw_bag() -> void:
	_panel(Rect2(330,230,620,334),PAPER)
	_icon("bookmark",Vector2(381,276))
	_text(Vector2(412,285),"내 책갈피  ·  %d개" % state.bookmarks,25)
	_text(Vector2(373,333),"여행자의 찻잔",20)
	_text(Vector2(373,370),"차 한 잔  ·  책갈피 15개로 기운 30 회복",16,MUTED)
	_text(Vector2(373,404),"현재 기운  %d / 100" % state.energy,16)
	_button(Rect2(373,457,170,45),"닫기  Esc","close")
	_button(Rect2(630,457,271,45),"차 마시기  ·  15개  ↵","tea",true,state.bookmarks < 15 or state.energy == 100)

func _draw_requests() -> void:
	_panel(Rect2(225,106,830,591),PAPER)
	_text(Vector2(269,165),"도서관 의뢰 게시판",28)
	_text(Vector2(269,200),"조건을 채우면 도장을 찍고 책갈피를 받아요.",16,MUTED)
	var counts: Array = [state.restored.size(),state.restored.size(),state.talked_today.size()]
	var goals := [1,6,3]
	for i in range(State.REQUESTS.size()):
		var request: Dictionary = State.REQUESTS[i]
		var y := 226+i*96
		var claimed: bool = state.request_claim_key(i) in state.claimed_requests
		_panel(Rect2(265,y,746,83),Color("f9e8bd"))
		_text(Vector2(284,y+31),("오늘  ·  " if request.daily else "서가  ·  ")+request.name,18)
		_text(Vector2(284,y+59),"%s   %d/%d" % [request.description,mini(counts[i],goals[i]),goals[i]],15,MUTED)
		_button(Rect2(790,y+19,198,43),"수령 완료" if claimed else "책갈피 +%d  받기" % request.reward,"claim_%d" % i,true,claimed or not state.request_ready(i))
	_text(Vector2(269,655),"1~3 보상 받기   ·   일일 의뢰는 아침에 새로 열려요.",14,MUTED)
	_button(Rect2(811,622,199,41),"닫기  Esc","close")

func _draw_loans() -> void:
	_panel(Rect2(278,137,724,511),PAPER)
	_text(Vector2(320,195),"루체테 대출 데스크",28)
	var index: int = state.requested_book_index()
	var book: Dictionary = State.BOOKS[index]
	var borrowed: bool = not state.active_loan.is_empty()
	_text(Vector2(320,231),"봄 %d일   ·   오늘의 독자" % state.day,15,GOLD)
	_text(Vector2(320,278),state.visitor_name(),23)
	var wishes := ["낯선 숲을 걸을 때 길잡이가 되어 줄 책을 찾고 있어요.","친구에게 하고 싶은 말을 편지로 쓰고 싶어요.","손에 쥔 등불이 어떤 마음으로 타는지 궁금해요.","아침마다 잊어버리는 꿈을 기록해 보고 싶어요.","읽던 책에서 한 문장이 사라졌어요. 단서를 찾고 있어요.","눈 오는 날 멀어진 친구와 한 약속을 기억하고 싶어요."]
	_text_block(Vector2(320,312),wishes[index],635,17,MUTED,26)
	_panel(Rect2(317,360,646,112),Color("f7e7bf"))
	_draw_book(Vector2(342,384),Color(book.color),false,2.4)
	_text(Vector2(404,402),"『%s』" % book.name,23)
	var status := "대출 가능" if book.id in state.restored else "작업대에서 먼저 복원해 주세요."
	if borrowed: status = "대출 중  ·  봄 %d일 아침 반납 예정" % state.active_loan.due_day
	_text(Vector2(407,440),status,16,MUTED)
	_text(Vector2(320,509),"대출  기운 2 / 20분   ·   반납 보상  책갈피 20개",15)
	_text(Vector2(320,537),"누적 반납 %d권" % state.total_loans,15,GOLD)
	_button(Rect2(324,574,228,47),"데스크 떠나기","close")
	_button(Rect2(658,574,295,47),"접수 완료" if borrowed else "오늘의 책 빌려주기  ↵","lend",true,borrowed or not book.id in state.restored or state.energy < 2)

func _mission_index_for(id: String) -> int:
	for i in range(MEMBERS.size()):
		if MEMBERS[i].id == id: return i
	return 0

func _visit_ete(index: int = -1) -> void:
	if state.scene != "library":
		_notify("도서관으로 돌아가 작업대 왼쪽의 에테에게 말을 걸어요.")
		return
	if index >= 0: mission_index = index
	mode = "play"
	_go_to(_find_object("ete"))

func _take_mission() -> void:
	if mode != "missions": return
	var id: String = MEMBERS[mission_index].id
	if state.chapter_steps.get(id,0) == 3:
		_open_story(mission_index,"missions")
		return
	if not state.accept_mission(id):
		_notify("먼저 마지막 문장을 완성한 책으로 돌아가 스텔라를 데려와 주세요.")
		return
	_save()
	_open_story(mission_index,"missions")

func _is_ete_line() -> bool:
	var line = dialogue_lines[dialogue_index]
	return dialogue_name == AETHE_SPEAKER or (line is Dictionary and line.get("ete",false))

func _draw_missions() -> void:
	var id: String = MEMBERS[mission_index].id
	var book: Dictionary = State.BOOKS[mission_index]
	var chapter: Dictionary = Chapters.BOOKS[id]
	_panel(Rect2(104,77,1072,651),PAPER)
	_text(Vector2(145,133),"에테의 도서관 재건 의뢰",32)
	_text(Vector2(148,166),"여섯 책의 친구들을 한 명씩 데려와, 비어 있는 루체테를 함께 꾸며 주세요.",16,MUTED)
	draw_line(Vector2(145,184),Vector2(1133,184),Color("bfa273"),2)
	var ete_size:=AETHE.get_size()*(271.0/AETHE.get_height())
	draw_texture_rect(AETHE,Rect2(Vector2(260.5-ete_size.x/2.0,214),ete_size),false)
	_center(512,"사서 에테",21,CREAM,259)
	_center(538,"루체테 · 귀환 담당",14,MUTED,259)
	for i in range(MEMBERS.size()):
		var target: Dictionary = MEMBERS[i]
		var mark := "완료" if state.chapter_steps.get(target.id,0) == 3 else ("진행" if state.active_mission == target.id else "의뢰")
		_button(Rect2(393+i%2*369,207+int(i/2)*57,353,46),"%d   %s   ·   %s" % [i+1,target.name,mark],"offer_%d" % i,i==mission_index)
	_text(Vector2(397,434),"『%s』" % book.name,23)
	var request: String="후와가 되어 눈산에서 텐비를 찾아 주세요. 귀환술과 뜻밖의 균열을 거쳐 도서관에 도착하면 후와가 합류해요." if id=="fuwa" else MEMBERS[mission_index].name+"가 되어 이야기 속에서 직접 행동해 주세요. 마지막 장면을 마치고 도서관에 도착하면 합류해요."
	_text_block(Vector2(399,477),request if state.chapter_steps.get(id,0) != 3 else "이 책의 마지막 문장은 안전해요. 기록과 함께한 이야기를 다시 펼쳐 볼까요?",700,18,CREAM,30)
	var label := "임무 수락 · 데뷔 기록 읽기"
	if state.chapter_steps.get(id,0) == 3: label = "완성한 기록 읽기"
	elif state.active_mission == id: label = "맡은 임무 이어가기"
	elif state.active_mission != "": label = "임무 바꾸기 · 찾은 단서 보관"
	_button(Rect2(141,635,223,48),"돌아가기   Esc","close")
	_button(Rect2(380,635,288,48),"팬 모습으로 변신   F","fan_forms",false,state.residents.is_empty())
	_button(Rect2(704,625,421,58),label+"   E","take_mission",true,state.page_complete and state.active_mission != id and state.chapter_steps.get(id,0) < 3)
	_text(Vector2(397,577),"책 속의 나   %s      ·      귀환 후   %s" % [MEMBERS[mission_index].name,chapter.gift],16,GOLD)

func _change_form(id: String) -> void:
	if mode != "fan_forms" or not state.wear_fan_form(id): return
	recognition.nearby_member=""
	character_touch.clear_room_greetings(self)
	mode = "play"
	ete_interactions.reset()
	ete_interactions.start(self,"transform")
	_save()
	_play_chime(740)
	var name_text: String = "여행자" if id.is_empty() else Chapters.BOOKS[id].fan
	_notify("에테가 책갈피를 건넸어요. 지금 내 모습 · "+name_text)
	queue_redraw()

func _draw_fan_forms() -> void:
	_panel(Rect2(108,77,1064,651),PAPER)
	_text(Vector2(154,134),"에테의 변신 책갈피",32)
	_text(Vector2(156,175),"“어떤 모습으로 지내고 싶나요? 함께 돌아온 친구의 책갈피를 골라 보세요.”",17,MUTED)
	draw_line(Vector2(154,198),Vector2(1125,198),Color("bfa273"),2)
	for i in range(MEMBERS.size()):
		var m: Dictionary = MEMBERS[i]
		var pos := Vector2(153+327*(i%3),224+166*floori(i/3.0))
		var open: bool = m.id in state.residents
		var wearing: bool = state.fan_form == m.id
		var accent := Color(m.color) if open else Color("a49b88")
		draw_rect(Rect2(pos,Vector2(310,147)),Color("927659"))
		draw_rect(Rect2(pos+Vector2(2,2),Vector2(306,143)),Color("f8e8c3") if open else Color("ddcfb0"))
		draw_rect(Rect2(pos+Vector2(2,2),Vector2(306,5)),accent)
		if open: _draw_traveler(pos+Vector2(58,100),false,m.id)
		else: _draw_book(pos+Vector2(35,52),accent,false,2.1)
		_text(pos+Vector2(112,44),m.name,15,MUTED)
		_text(pos+Vector2(111,82),Chapters.BOOKS[m.id].fan,24)
		var label := "현재 모습" if wearing else ("이 모습으로 변신" if open else "귀환 후 해금")
		_button(Rect2(pos+Vector2(10,104),Vector2(290,36)),"%d   %s" % [i+1,label],"form_"+m.id,wearing,not open)
	var current: String = "여행자" if state.fan_form.is_empty() else Chapters.BOOKS[state.fan_form].fan
	_text(Vector2(156,607),"내 모습   ·   "+current,18,GOLD)
	_button(Rect2(155,635,259,46),"에테에게 돌아가기   Esc","forms_back")
	_button(Rect2(827,635,294,46),"여행자 모습으로   0","form_traveler")

func _draw_overlay() -> void:
	if mode == "dialog":
		draw_rect(Rect2(0,0,1280,800),Color(0.04,0.08,0.1,0.35))
		_panel(Rect2(140,540,1000,208),Color("20352f"),dialogue_color)
		_panel(Rect2(160,561,172,161),Color("293c35"),Color(dialogue_color,0.5))
		var line = dialogue_lines[dialogue_index]
		var ete_line := _is_ete_line()
		if ete_line:
			draw_texture_rect_region(AETHE,Rect2(168,569,156,145),Faces.portrait_region(AETHE,"aethe"))
			_text(Vector2(350,724),"루체테의 사서  ·  팬게임 창작 대사",12,MUTED)
		elif dialogue_member >= 0:
			var member: Dictionary = MEMBERS[dialogue_member]
			_draw_member_face(Rect2(168,569,156,145),member.id,line is Dictionary and line.get("warm",false))
			_text(Vector2(350,724),State.BOND_NAMES[state.bond_tier(member.id)]+"  ·  팬게임 창작 대사",12,MUTED)
		else:
			_draw_book(Vector2(209,599),dialogue_color,true,2.6)
			_text(Vector2(350,724),"팬게임 창작 대사",11,MUTED)
		_text(Vector2(350,578),AETHE_SPEAKER if ete_line else dialogue_name,20,CREAM)
		_text_block(Vector2(350,615),line.text if line is Dictionary else str(line),755,18,CREAM,31)
		if dialogue_member >= 0 and not ete_line:
			_button(Rect2(737,695,211,34),"시작의 책 다시 읽기  R","story_dialog")
		_button(Rect2(965,695,150,34),"다음  E  ·  %d/%d" % [dialogue_index+1,dialogue_lines.size()],"next")
		return
	draw_rect(Rect2(0,0,1280,800),Color(0.03,0.07,0.08,0.78))
	match mode:
		"archive_shelf","archive_book": activity_archive.draw(self)
		"promotion": _draw_promotion()
		"stella_life": life.draw(self)
		"fan_forms": _draw_fan_forms()
		"missions": _draw_missions()
		"rescue":
			var member: Dictionary = MEMBERS[story_member]
			_panel(Rect2(176,166,928,464),PAPER)
			_text(Vector2(223,225),"되찾은 마지막 장   /   "+State.BOOKS[story_member].name,18,GOLD)
			_draw_member(Vector2(330,518),member.id,210,true)
			_text(Vector2(465,292),"이야기가 완성되었다",30)
			_text_block(Vector2(466,349),Chapters.BOOKS[member.id].last_line,575,21,CREAM,37)
			_text_block(Vector2(466,461),"기록을 끝까지 읽었다. 이제 함께 루체테로 돌아가자.",557,16,MUTED,26)
			_text(Vector2(466,485),"도서관 재건과 귀환은 팬게임의 연결 이야기입니다.",12,MUTED)
			if replay_progress == null:
				var accent := Color(member.color)
				var lit := 1.0 if ink_returned_at < 0 else smoothstep(0.0,1.1,clock-ink_returned_at)
				var cover := EncounterBooks.FADED_CLOTH.lerp(EncounterBooks.book_cloth(accent,true),lit)
				_draw_book(Vector2(467,493),cover,false,1.1)
				if lit > 0: EncounterBooks.memory_star(self,Vector2(484,496),6*lit,accent)
				_text(Vector2(501,515),"빛을 되찾은 책   『%s』" % EncounterBooks.shelf_title(state,member.id),18,GOLD)
			_button(Rect2(223,538,296,53),"데뷔 네 컷 보기   V","comic_play")
			_button(Rect2(605,538,448,53),"회상 마치기   E" if replay_progress else member.name+"와 함께 열람실로   E","rescue_return",true)
		"title":
			_panel(Rect2(300,144,680,505),PAPER,GOLD)
			for x in [443,837]:
				draw_rect(Rect2(x,121,6,72),Color("876341"))
				draw_rect(Rect2(x+1,122,2,66),Color("c8a36c"))
			draw_rect(Rect2(354,187,572,175),Color("62452f"))
			for i in range(3):
				var plank := Rect2(360,191+i*55,560,53)
				draw_rect(plank,Color("aa713e").lightened(0.045*i))
				draw_rect(Rect2(plank.position,Vector2(560,3)),Color("c99656"))
				for grain in range(8):
					var g := plank.position+Vector2(18+grain*68,13+(grain*7+i*9)%31)
					draw_rect(Rect2(g,Vector2(21+grain%4*5,2)),Color(0.31,0.18,0.09,0.14))
			for nail in [Vector2(371,201),Vector2(904,201),Vector2(371,345),Vector2(904,345)]:
				draw_rect(Rect2(nail,Vector2(5,5)),Color("614833"))
			_center(232,"L U C E T E    L I B R A R Y",15,Color("ffe7ac"))
			_center(303,"도서관 밸리",58,Color("61442f"),642)
			_center(299,"도서관 밸리",58,Color("ffebbc"))
			_center(345,"루체테의 첫 페이지",23,Color("ffdc98"))
			_center(420,"책 속에서는 스텔라의 팬으로, 루체테에서는 도서관을 재건하는 여행자로.",17,MUTED)
			if save_available:
				_button(Rect2(435,452,410,48),"이야기 이어 하기  ↵","continue",true)
				_button(Rect2(435,511,410,42),"새로운 이야기","new")
			else:
				_button(Rect2(435,465,410,52),"루체테로 들어가기  ↵","new",true)
			_center(590,"리스텔라 비공식 팬게임 · 플레이 가능한 시제품",13,MUTED)
			_center(617,"여섯째 판  ·  우리가 다시 세우는 루체테",13,MUTED)
		"bag": _draw_bag()
		"requests": _draw_requests()
		"loans": _draw_loans()
		"restore": _draw_restoration()
		"journal": _draw_journal()
		"encounter_shelf": EncounterBooks.draw_shelf(self)
		"encounter_book": EncounterBooks.draw_book(self,MEMBERS[encounter_member],encounter_page)
		"story": _draw_story()
		"help":
			_panel(Rect2(280,149,720,512),Color("20352f"),GOLD)
			_text(Vector2(320,201),"작은 도서관 안내서",28,CREAM)
			var rows := ["01   작업대 왼쪽의 에테에게 도서관 재건 의뢰를 받아요.","02   데뷔 기록을 읽고 그 스텔라의 팬으로 책 속을 걸어요.","03   빛나는 곳을 살피고, 네 장면의 기록을 차례로 책갈피에 남겨요.","04   둘이 귀환할 때마다 루체테에 새로운 자리가 생겨요.","05   귀환한 스텔라는 L로 직접 선택해 방송하거나 운동할 수 있어요.","06   왼쪽 활동 기록 서가에서 기념 방송과 행사 기록을 꺼내 읽어요."]
			if world_map_active() and state.get("growth")!=null and state.growth.phase=="open":
				rows=["01   에테의 의뢰를 받아 여섯 스텔라의 이야기를 완성해요.","02   모두 돌아오면 함께 재건하고 도서관을 다시 열어요.","03   홍보는 오전·오후 한 번씩, 직접 하거나 맡길 수 있어요.","04   잉크의 말에서 취향을 읽어요. 잘 맞는 추천은 이용 후 보너스!","05   반납 책·다 쓴 자리·바닥 얼룩은 다음 날에도 남아요.","06   책은 같은 표시 서가에, 자리와 얼룩은 가까이서 E로 정돈해요."]
			for i in range(rows.size()): _text(Vector2(320,253+i*43),rows[i],17,MUTED)
			_text(Vector2(320,501),"WASD / 방향키 이동 · Shift 달리기 · E / Enter 상호작용",16,CREAM)
			_text(Vector2(320,532),"1~7 하단 단축칸 · Q 의뢰 · I 책갈피 · F5 저장 · F11 전체화면",16,CREAM)
			_text(Vector2(320,564),"도서관에서 F · 가구 배치/이동, Delete 보관, T 자동 이용 켜기/끄기",15,GOLD)
			_button(Rect2(710,591,245,42),"도서관으로  Esc","close",true)
		"sleep":
			_panel(Rect2(350,240,580,310),Color("20352f"),GOLD)
			_center(295,"오늘의 책갈피를 끼울까요?",26,CREAM)
			_center(342,"봄 %d일  ·  복원 %d권  ·  오늘 인사 %d명" % [state.day,state.restored.size(),state.talked_today.size()],17,MUTED)
			_center(382,"다음 날 아침에는 기운이 100으로 회복돼요.",17,CREAM)
			_button(Rect2(395,448,230,48),"조금 더 둘러보기","close")
			_button(Rect2(645,448,240,48),"다음 날 아침  ↵","sleep_confirm",true)
		"pause":
			_panel(Rect2(420,185,440,440),Color("20352f"),GOLD)
			_center(239,"잠시 책갈피",28,CREAM)
			_button(Rect2(470,275,340,44),"계속하기  Esc","close",true)
			_button(Rect2(470,332,340,44),"지금 저장하기  F5","save")
			_button(Rect2(470,389,340,44),"효과음  " + ("켜짐" if audio_enabled else "꺼짐"),"audio")
			_button(Rect2(470,446,340,44),"안내서 보기","help")
			_button(Rect2(470,503,340,44),"저장하고 제목 화면으로","title")
			_center(593,"진행은 자동 저장됩니다.",13,MUTED)
		"new_confirm":
			_panel(Rect2(350,250,580,290),Color("20352f"),GOLD)
			_center(308,"새로운 이야기를 시작할까요?",25,CREAM)
			_center(356,"현재 저장된 진행을 새 이야기로 바꿉니다.",17,MUTED)
			_button(Rect2(395,436,230,48),"돌아가기","cancel_new")
			_button(Rect2(645,436,240,48),"새 이야기 시작","new_confirm",true)
		"ending":
			_panel(Rect2(280,145,720,520),Color("203831"),GOLD)
			for i in range(6): _star(Vector2(490+i*60,205),10,Color(State.BOOKS[i].color))
			_center(280,"루체테가 다시 문을 엽니다",34,CREAM)
			_center(328,"여섯 권의 마지막 장에, 여섯 스텔라의 이름이 돌아왔습니다.",18,GOLD)
			_center(372,"사서 에테가 장부를 덮고 문을 엽니다. 여섯 스텔라와 여행자가 그 곁에 섭니다.",17,MUTED)
			_center(414,"당신이 함께한 %d일이 루체테의 첫 번째 장이 되었어요." % state.day,18,CREAM)
			_center(465,"오른쪽 위 문 너머 각자의 공간에 여섯 스텔라가 자리를 잡았어요.",16,MUTED)
			_center(495,"도서관에서 P를 눌러 홍보 주제를 맡기고, 찾아오는 잉크를 맞아 주세요.",16,MUTED)
			_button(Rect2(435,548,410,50),"우리의 도서관으로","close",true)
			_center(636,"THE FIRST CHAPTER IS YOURS",12,GOLD)

func _draw_restoration() -> void:
	_panel(Rect2(180,145,920,535),Color("20352f"),GOLD)
	_text(Vector2(215,194),"이야기 복원 작업대",28,CREAM)
	_text(Vector2(215,224),"잊힌 문장들을 엮어, 책에 다시 빛을 불어넣어요.",15,MUTED)
	for i in range(6):
		var book: Dictionary = State.BOOKS[i]
		var rect := Rect2(215,251+i*57,390,47)
		var complete: bool = book.id in state.restored
		_button(rect,("✓  " if complete else "")+book.name,"book_%d" % i,selected_book == i)
	var book: Dictionary = State.BOOKS[selected_book]
	_draw_book(Vector2(790,273),Color(book.color),false,3.2)
	_center(399,book.name,24,CREAM,843)
	_center(433,book.owner + "의 이야기",16,Color(book.color).darkened(0.5),843)
	_center(478,"대출용 도서 수리  ·  기운 12 / 40분",17,MUTED,843)
	_center(510,"현재 기운 %d / 100" % state.energy,15,MUTED,843)
	var label := "이 책 복원하기  E"
	if book.id in state.restored: label = "이미 복원한 이야기"
	elif state.energy < 12: label = "기운을 회복해 주세요"
	var awaits_member: bool = not book.id in state.residents
	_button(Rect2(663,543,365,49),"시작의 책 펼치기   E" if awaits_member else label,"restore",true,not awaits_member and (book.id in state.restored or state.energy < 12))
	_text(Vector2(215,640),"↑ ↓ 선택   ·   E 복원   ·   Esc 닫기",14,MUTED)
	_button(Rect2(871,620,192,34),"작업대 떠나기","close")

func _chapter_progress() -> State:
	return replay_progress if replay_progress != null else state

func _dori_notebook_open() -> bool:
	return mode=="chapter" and chapter_question and MEMBERS[story_member].id=="dori" and _chapter_progress().debut_scene("dori")==3 and not DoriCase.ready(3,_chapter_progress().dori_notes)

func _ete_walk_pos() -> Vector2:
	return dori_rubbing.ete_feet(self)

func _ete_field_pose() -> Dictionary:
	if mode in ["chapter","rescue"] and MEMBERS[story_member].id=="dori" and _chapter_progress().debut_scene("dori")==2:
		return dori_rubbing.ete_pose(self)
	return {"direction":ete_facing if mode not in ["chapter","rescue"] else "down","walking":false,"distance":0.0}

func _inspect_chapter(index: int, observation: String="") -> void:
	if mode=="chapter" and MEMBERS[story_member].id=="dori" and index==3 and not DoriCase.ready(3,_chapter_progress().dori_notes):
		chapter_question=true
		chapter_note="먼저 일어난 일부터 그림을 하나씩 골라 끼워 보자.   1 · 2 · 3 또는 클릭"
		return
	if book_discovery.active(self):
		book_discovery.begin_result(self)
		return
	if mode != "chapter" or chapter_question: return
	var id: String = MEMBERS[story_member].id
	var progress := _chapter_progress()
	if progress.route_pending(id): return
	if index != progress.debut_scene(id): return
	if id=="dori" and index==2: return # This memory is discovered and recorded in the field.
	if id=="dori" and index<3 and not DoriCase.ready(index,progress.dori_notes): return
	if id=="yune" and not YuneDream.ready(index,progress.yune_notes): return
	if id=="danming" and not DanmingWorkshop.ready(index,progress.danming_notes): return
	if id=="kubby" and not KubbyEmbers.ready(index,progress.kubby_notes): return
	if id=="yato" and not YatoForest.ready(index,progress.yato_notes): return
	if id=="fuwa" and not FuwaSnow.ready(index,progress.fuwa_notes): return
	chapter_question = true
	if not observation.is_empty(): chapter_observation=observation
	if _dori_notebook_open(): chapter_note="먼저 일어난 일부터 그림을 하나씩 골라 끼워 보자.   1 · 2 · 3 또는 클릭"

func _next_chapter_site(id: String, finished: int) -> void:
	book_discovery.reset()
	chapter_question = false
	chapter_observation=""
	scene_started = clock
	chapter_note = "%d번째 기록을 책갈피에 남겼다. 다음 표시로 걸어가자." % (finished+1)
	if id=="dori":
		dori_rubbing.reset()
		if finished==1: player_pos=DoriCase.Rubbing.ENTRANCE
		chapter_note="가까이 가서 E를 누르거나 살펴볼 곳을 클릭해."
	if id=="yune":
		yune_dream.reset()
		if finished==1: player_pos=yune_dream.nights.spawn(_chapter_progress().yune_notes)
		chapter_note="몽치로 걸어가서 E를 누르거나 살펴볼 곳을 클릭해."
	if id=="danming":
		if finished+1==2: player_pos=DanmingWorkshop.MemoryLens.ENTRANCE
		chapter_note="버리로 걸어가서 E를 누르거나 살펴볼 곳을 클릭해."
	if id=="kubby":
		kubby_embers.village.restore(_chapter_progress().kubby_notes)
		if finished==0: player_pos=KubbyEmbers.Village.ENTRANCE
		chapter_note="햄님으로 걸어가서 E를 누르거나 궁금한 곳을 클릭해."
	if id=="yato":
		yato_forest.storehouse.restore(_chapter_progress().yato_notes)
		player_pos=YatoForest.spawn(finished+1,_chapter_progress().yato_notes)
		chapter_note="마토로 직접 걷거나 궁금한 곳을 클릭해 봐. 가까이에서는 E로 살펴볼 수 있어."
	if id=="fuwa":
		player_pos=FuwaSnow.spawn(finished+1,_chapter_progress().fuwa_notes)
		fuwa_snow.resume(finished+1,_chapter_progress().fuwa_notes,player_pos)
		chapter_note="방향키로 걸어서 E를 누르거나, 가 보고 싶은 곳을 클릭해."
	chapter_note=StoryTrail.entry(id,finished).next.lead
	_setup_map()
	if id=="dori" and finished==1: dori_rubbing.resume(self)
	_play_chime(600+finished*85)
	if replay_progress == null: _save()

func _leave_chapter() -> void:
	if mode not in ["chapter","rescue"]: return
	book_discovery.reset()
	book_activity=null
	fuwa_snow.viewing=false
	fuwa_snow.practice.reset()
	yune_dream.reset()
	danming_workshop.reset()
	dori_rubbing.reset()
	kubby_embers.village.restore([])
	yato_forest.storehouse.restore([])
	mode = "story" if replay_progress else "journal"
	replay_progress = null
	player_pos = chapter_home
	chapter_question = false
	_setup_map()
	_save()

func _remember_chapter() -> void:
	if book_discovery.active(self):
		book_discovery.request_next(self)
		return
	if mode != "chapter" or not chapter_question or book_activity!=null: return
	var id: String = MEMBERS[story_member].id
	var progress := _chapter_progress()
	var scene := progress.debut_scene(id)
	if id=="dori" and scene==2: return
	if id=="dori" and (dori_rubbing.phase!=DoriCase.Rubbing.Phase.FIELD or not DoriCase.ready(scene,progress.dori_notes)): return
	if id=="yune" and (yune_dream.view>=0 or not YuneDream.ready(scene,progress.yune_notes)): return
	if id=="danming" and (danming_workshop.view>=0 or not DanmingWorkshop.ready(scene,progress.danming_notes)): return
	if id=="kubby" and (kubby_embers.village.watching or not KubbyEmbers.ready(scene,progress.kubby_notes)): return
	if id=="yato" and (yato_forest.storehouse.phase!=YatoForest.Storehouse.Phase.FIELD or not YatoForest.ready(scene,progress.yato_notes)): return
	if id=="fuwa" and (fuwa_snow.practice.phase!=FuwaSnow.WardPractice.Phase.FIELD or not FuwaSnow.ready(scene,progress.fuwa_notes)): return
	if scene < 3:
		if not progress.open_chapter_route(id): return
		chapter_question=false
		chapter_note=StoryTrail.entry(id,scene).next.reason
		_setup_map()
		_play_chime(690)
		if replay_progress==null: _save()
		return
	if not progress.seal_page(id): return
	if replay_progress == null: ink_returned_at = clock
	chapter_question = false
	mode = "rescue"
	if replay_progress == null: _save()
	_play_chime(740)

func _follow_chapter_route(obj: Dictionary) -> void:
	if mode!="chapter" or chapter_question: return
	var id: String=MEMBERS[story_member].id
	var progress:=_chapter_progress()
	var scene:=progress.debut_scene(id)
	if obj.index!=scene or not progress.route_pending(id): return
	if player_pos.distance_to(obj.pos)>float(obj.reach):
		_go_to(obj)
		return
	var advanced: bool
	if scene==0: advanced=progress.record_chapter_step(id,0)
	elif scene==1: advanced=progress.mark_first_action(id)
	else: advanced=progress.record_chapter_step(id,1)
	if advanced: _next_chapter_site(id,scene)

func _return_with_stella() -> void:
	if mode != "rescue": return
	if replay_progress:
		_leave_chapter()
		return
	var member: Dictionary = MEMBERS[story_member]
	var chapter: Dictionary = Chapters.BOOKS[member.id]
	if not state.record_chapter_step(member.id,2): return
	chapter_question = false
	mode = "play"
	state.scene = "library"
	state.yard_session = {}
	state.yard_host = ""
	player_pos = AETHE_POS+Vector2(49,30)
	_setup_map()
	_save()
	_play_chime(880)
	sparkle_bursts.append({"pos":_find_object(member.id).pos,"life":1.0,"color":Color(member.color)})
	var report: String = chapter.home
	if state.residents.size() == 1: report += " 이제 도서관 안에서 함께 지내요. F로 독서·차·운동·방송 가구를 놓고, L로 오늘의 활동을 골라 보세요."
	if state.opening_pending: report += " 여섯 자리가 다 찼어요. 이제 문을 열까요?"
	_show_dialogue(member.name,[chapter.arrival,{"ete":true,"text":report}],Color(member.color),story_member)
	_notify("루체테 재건 %d / 6   ·   %s   ·   에테에게서 %s 변신 해금" % [state.rebuild_stage(),chapter.gift,chapter.fan])
	for i in range(MEMBERS.size()):
		if state.chapter_steps.get(MEMBERS[i].id,0) < 3:
			mission_index = i
			break
	if state.opening_pending: after_dialogue = "ending"

func _draw_chapter_hud() -> void:
	if book_discovery.active(self):
		book_discovery.draw_hud(self)
		return
	if dori_rubbing.active(self):
		dori_rubbing.draw_hud(self)
		return
	var member: Dictionary = MEMBERS[story_member]
	var chapter: Dictionary = Chapters.BOOKS[member.id]
	var scene := _chapter_progress().debut_scene(member.id)
	var top := Rect2(97,9,1086,64)
	_panel(top,PAPER)
	ui_regions.append(top)
	_text(Vector2(122,34),"%s의 책   /   %s의 모습으로 읽는 기억" % [member.name,chapter.fan],14,GOLD)
	var place: String=chapter.places[scene]
	if member.id=="yato" and scene==1: place="토끼 가족의 곳간"
	if member.id=="yato" and YatoForest.on_mountain(scene,_chapter_progress().yato_notes): place="숲을 나와 산 아래로"
	if member.id=="fuwa":
		var current_place:=FuwaSnow.place(scene,_chapter_progress().fuwa_notes)
		if not current_place.is_empty(): place=current_place
	_text(Vector2(121,60),place,23,CREAM)
	_text(Vector2(818,48),"장면   %d / 4" % (scene+1),16,MUTED)
	_button(Rect2(932,21,228,40),"회상 나가기  Esc" if replay_progress else "책갈피 꽂고 나가기  Esc","chapter_leave")
	if member.id=="fuwa" and scene==1 and "overlook" in _chapter_progress().fuwa_notes and not chapter_question:
		fuwa_snow.draw_overlook(self)
	if member.id=="kubby" and scene==2 and "ice" in _chapter_progress().kubby_notes and not chapter_question:
		kubby_embers.draw_reflection(self)
		ui_regions.append(KubbyEmbers.FRAME.grow(4))
	if fuwa_snow.practice.phase!=FuwaSnow.WardPractice.Phase.FIELD:
		fuwa_snow.practice.draw_hud(self)
		return
	if yato_forest.storehouse.phase!=YatoForest.Storehouse.Phase.FIELD:
		yato_forest.storehouse.draw_hud(self)
		return
	if kubby_embers.village.watching:
		kubby_embers.village.draw_hud(self)
		return
	if yune_dream.view==2:
		yune_dream.nights.draw_hud(self)
		return
	if dori_rubbing.phase!=DoriCase.Rubbing.Phase.FIELD:
		dori_rubbing.draw_hud(self)
		return
	if danming_workshop.view==2:
		danming_workshop.lens.draw_hud(self)
		return
	if not chapter_question: StoryTrail.draw_hud(self,member.id,scene)
	var bottom := Rect2(97,714,1086,77) if not chapter_note.is_empty() else Rect2(97,732,1086,59)
	_panel(bottom,PAPER)
	ui_regions.append(bottom)
	var hint: String=chapter.hints[scene]
	if member.id=="dori" and not DoriCase.ready(scene,_chapter_progress().dori_notes):
		hint=DoriCase.TASK[scene]
		if scene==2 and dori_rubbing.has_print(self): hint="탁본을 들고 에테를 따라가, 품에 안은 돌의 윤곽을 맞춰 보자."
		if scene==0: hint+="   %d / %d"%[DoriCase.count(scene,_chapter_progress().dori_notes),DoriCase.REQUIRED[scene].size()]
	if member.id=="yune" and not YuneDream.ready(scene,_chapter_progress().yune_notes):
		hint=YuneDream.hint(scene,_chapter_progress().yune_notes)
	if member.id=="danming" and not DanmingWorkshop.ready(scene,_chapter_progress().danming_notes):
		hint=DanmingWorkshop.hint(scene,_chapter_progress().danming_notes)
	if member.id=="kubby" and not KubbyEmbers.ready(scene,_chapter_progress().kubby_notes):
		hint=KubbyEmbers.hint(scene,_chapter_progress().kubby_notes)
	if member.id=="yato" and not YatoForest.ready(scene,_chapter_progress().yato_notes):
		hint=YatoForest.hint(scene,_chapter_progress().yato_notes)
	if member.id=="fuwa" and not FuwaSnow.ready(scene,_chapter_progress().fuwa_notes):
		hint=FuwaSnow.hint(scene,_chapter_progress().fuwa_notes)
	if _chapter_progress().route_pending(member.id): hint=StoryTrail.entry(member.id,scene).next.label+" · 밝아진 책갈피까지 걸어가자."
	_text(Vector2(124,bottom.position.y+34),chapter.fan+"  ·  "+hint,19,CREAM)
	if not chapter_note.is_empty(): _text(Vector2(124,776),chapter_note,16,MUTED)
	if not chapter_question: return
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color(0.07,0.11,0.13,0.67))
	if book_activity!=null:
		book_activity.draw(self)
		return
	if member.id=="fuwa" and fuwa_snow.viewing:
		fuwa_snow.draw_view(self)
		return
	if member.id=="yune" and yune_dream.view>=0:
		yune_dream.draw_closeup(self)
		return
	if member.id=="danming" and danming_workshop.view>=0:
		danming_workshop.draw_closeup(self)
		return
	if _dori_notebook_open():
		_panel(Rect2(202,170,876,470),PAPER)
		DoriCase.draw_notebook(self,_chapter_progress().dori_notes)
		return
	_panel(Rect2(202,172,876,454),PAPER)
	_text(Vector2(244,222),"기억 %d / 4   ·   내가 따라온 이야기" % (scene+1),16,GOLD)
	_text(Vector2(244,265),chapter.places[scene],23,CREAM)
	draw_line(Vector2(244,285),Vector2(1034,285),Color("c19d6d"),1)
	_text_block(Vector2(244,326),chapter.records[scene],778,21,CREAM,34)
	if scene<3:
		_text_block(Vector2(244,443),StoryTrail.entry(member.id,scene).next.reason,778,16,MUTED,21)
	elif not chapter_observation.is_empty():
		_text_block(Vector2(244,449),chapter.fan+"  ·  "+chapter_observation,778,15,MUTED,20)
	else:
		_text(Vector2(244,465),chapter_note if member.id=="dori" else "과거의 사건을 바꾸지 않고, 읽은 기억을 책갈피에 남깁니다.",15,MUTED)
	_button(Rect2(244,500,790,45),("마지막 기록을 완성하기" if scene==3 else "기억을 잇고 현장에서 계속 걷기")+"   E","chapter_remember",true)
	_button(Rect2(244,568,247,40),"공식 기록 열기 ↗","chapter_source")
	_button(Rect2(797,568,237,40),"현장 더 보기   Esc","chapter_look")

func _open_story(member_index: int, return_mode: String) -> void:
	if member_index < 0 or member_index >= MEMBERS.size(): return
	story_member = member_index
	story_page = 0
	story_sources = false
	story_return = return_mode
	route.clear()
	pending_object = ""
	mode = "story"

func _open_encounter(index: int) -> void:
	if index < 0 or index >= MEMBERS.size(): return
	if mode != "encounter_shelf" and not (mode == "story" and story_page == 0 and not story_sources): return
	encounter_return = mode
	encounter_member = index
	encounter_page = 0
	encounter_turn_at = -1.0
	mode = "encounter_book"

func _turn_encounter(direction: int) -> void:
	encounter_page += direction
	encounter_turn_at = clock
	encounter_turn_forward = direction > 0

func _close_story() -> void:
	if story_sources:
		story_sources = false
	else:
		mode = story_return

func _replay_debut() -> void:
	var id: String = MEMBERS[story_member].id
	if mode != "story" or story_page != 0 or story_sources or state.chapter_steps.get(id,0) != 3: return
	replay_progress = State.new()
	replay_progress.accept_mission(id)
	_enter_chapter(id)

func _enter_chapter(id: String) -> void:
	book_discovery.reset()
	danming_workshop.lens.camera=0.0
	book_activity=null
	chapter_observation=""
	yune_dream.reset()
	danming_workshop.reset()
	dori_rubbing.reset()
	ink_returned_at = -1.0
	var chapter: Dictionary = Chapters.BOOKS[id]
	var progress := _chapter_progress()
	var scene := progress.debut_scene(id)
	chapter_home = player_pos
	scene_started = clock
	chapter_question = false
	chapter_note = chapter.welcome if scene == 0 else "남겨 둔 책갈피부터 이어 읽는다. 표시된 기록으로 걸어가자."
	if id=="dori": chapter_note="가까이 가서 E를 누르거나 살펴볼 곳을 클릭해. 찾은 단서는 책갈피에 남아."
	if id=="yune": chapter_note="몽치로 걸어가서 E를 누르거나 꿈속의 사물을 클릭해."
	if id=="danming": chapter_note="버리로 걸어가서 E를 누르거나 궁금한 곳을 클릭해. 살펴본 자리는 책갈피에 남아."
	if id=="kubby": chapter_note="햄님으로 걸어가서 E를 누르거나 살펴볼 곳을 클릭해. 발자국이 작은 단서가 될 거야."
	player_pos = Vector2(155,605) if scene == 0 else chapter.points[scene-1]+Vector2(0,40)
	if id=="yune" and scene==2: player_pos=yune_dream.nights.spawn(progress.yune_notes)
	if id=="dori" and scene==2:
		player_pos=DoriCase.Rubbing.ENTRANCE
		if "print1" in progress.dori_notes: player_pos=DoriCase.Rubbing.STONE_SIDE
		if "print3" in progress.dori_notes: player_pos=DoriCase.Rubbing.ETE_SIDE
	if id=="danming" and scene==2: player_pos=DanmingWorkshop.MemoryLens.ENTRANCE
	if id=="kubby":
		kubby_embers.resume(progress.kubby_notes)
		if scene==1:
			player_pos=KubbyEmbers.Village.STATION if "found" in progress.kubby_notes else KubbyEmbers.Village.ENTRANCE
		if scene==2 and "ice" in progress.kubby_notes: player_pos=KubbyEmbers.trail_point(kubby_embers.flow)
	if id=="yato":
		yato_forest.resume(progress.yato_notes)
		player_pos=YatoForest.spawn(scene,progress.yato_notes)
		chapter_note="마토로 걸어가서 E를 누르거나 궁금한 곳을 클릭해. 발견한 기억은 책갈피에 남아."
	if id=="fuwa":
		player_pos=FuwaSnow.spawn(scene,progress.fuwa_notes)
		fuwa_snow.resume(scene,progress.fuwa_notes,player_pos)
		chapter_note="텐비로 걸어가서 E를 누르거나 살펴볼 곳을 클릭해. 읽은 장면은 책갈피에 남아."
	mode = "chapter"
	if scene>0: chapter_note=StoryTrail.entry(id,scene-1).next.lead
	if progress.route_pending(id):
		chapter_note=StoryTrail.entry(id,scene).next.reason
		player_pos=StoryTrail.resume_position(self,id,scene)
	_setup_map()
	if id=="dori" and scene==2: dori_rubbing.resume(self)
	if progress.page_complete: mode = "rescue"
	toast_time = 0

func _turn_story() -> void:
	if mode != "story" or story_sources: return
	var id: String = MEMBERS[story_member].id
	match story_page:
		0:
			if state.chapter_steps.get(id,0) < 3:
				if state.active_mission != id:
					_visit_ete(story_member)
					return
				_enter_chapter(id)
			else: story_page = 1
		1:
			if state.story_choices.has(id): story_page = 2
		2:
			if id in state.restored: story_page = 3
			else: _close_story()
		3: _close_story()

func _choose_story(choice: int) -> void:
	if mode != "story" or story_page != 1 or story_sources: return
	if state.remember_choice(MEMBERS[story_member].id,choice):
		_save()
		story_page = 2

func _story_key(key: int) -> void:
	if key == KEY_C:
		_cycle_costume()
		return
	if key == KEY_ESCAPE:
		_close_story()
	elif not story_sources:
		if key == KEY_B and story_page == 0: _open_encounter(story_member)
		if key == KEY_T and story_page == 0: _action("story_extra")
		if key == KEY_R and story_page == 0: _replay_debut()
		if key == KEY_V and story_page == 0: _action("comic_play")
		if key in [KEY_E,KEY_SPACE,KEY_ENTER,KEY_RIGHT]: _turn_story()
		if key == KEY_LEFT: story_page = maxi(0,story_page-1)
		if key in [KEY_1,KEY_2]: _choose_story(key - KEY_1)

func _story_references() -> Array:
	var refs: Array = Stories.ENTRIES[MEMBERS[story_member].id].sources.duplicate()
	refs.append(["리스텔라 데뷔 연혁 · 활동 기록 재수록","https://www.namu.moe/w/리스텔라"])
	refs.append(Stories.ENTRIES[MEMBERS[story_member].id].broadcast_reference)
	return refs

func _draw_story() -> void:
	var member: Dictionary = MEMBERS[story_member]
	var entry: Dictionary = Stories.ENTRIES[member.id]
	var choice: int = state.story_choices.get(member.id,-1)
	var tint := Color(member.color)
	EncounterBooks.open_binding(self,Rect2(116,77,1048,639),400,EncounterBooks.book_cloth(tint,EncounterBooks.titled(state,member.id)))
	_text(Vector2(188,147),"루체테 인물 서가",16,MUTED)
	_panel(Rect2(165,185,197,205),Color("f5e4ba"),tint)
	_draw_member(Vector2(263,382),member.id,190.0)
	_center(436,member.name,25,CREAM,265)
	_center(475,"리스텔라 데뷔  ·  "+entry.date,15,MUTED,265)
	_center(529,"이야기 책",14,GOLD,265)
	_center(564,State.BOOKS[story_member].name,17,CREAM,265)
	if member.id in state.residents and Wardrobe.COSTUMES[member.id].size() > 1:
		var outfit: String = Wardrobe.COSTUMES[member.id][_costume_key(member.id)][0]
		_button(Rect2(154,580,223,40),"의상  ·  " + outfit + "   C ›","costume_next")
	_button(Rect2(154,634,223,42),"책으로 돌아가기" if story_sources else "책 덮기  Esc","story_close")
	if story_sources:
		_text(Vector2(440,162),"첫 장의 참고 자료",25)
		_text(Vector2(440,210),"캐릭터 배경과 데뷔 음반, 방송에서의 모습을 더 살펴볼 수 있어요.",16,MUTED)
		var refs := _story_references()
		for i in range(refs.size()):
			_button(Rect2(440,250+66*i,665,48),refs[i][0]+"   ↗","story_source_%d" % i)
		_text(Vector2(440,525),"버튼을 누르면 기본 브라우저로 자료가 열려요.",14,MUTED)
		return
	var headings := ["시작의 기록","함께 쓰는 첫 장","여행자의 책갈피","복원된 책의 뒷장"]
	_text(Vector2(440,146),"제 %d 장    /    %s" % [story_page+1,"공개 설정·데뷔 기록" if story_page == 0 else "팬게임 오리지널"],15,GOLD)
	_text(Vector2(440,202),headings[story_page] if story_page != 1 else entry.title,30)
	draw_line(Vector2(440,224),Vector2(1112,224),Color("c19d6d"),2)
	match story_page:
		0:
			_text_block(Vector2(440,275),entry.origin,657,20,CREAM,34)
			_text(Vector2(440,433),"첫 싱글   〈%s〉" % entry.song,20,GOLD)
			_text_block(Vector2(440,473),entry.debut,657,17,MUTED,28)
			_button(Rect2(866,117,246,41),"팬과의 인연책   B","encounter_read")
			_button(Rect2(439,625,201,49),"참고 자료","story_sources")
			var step: int = state.chapter_steps.get(member.id,0)
			var label := "책 속으로 들어가기" if step == 0 else "책갈피부터 이어가기"
			if member.id=="fuwa" and not state.fuwa_adventure.is_empty(): label="책갈피부터 이어가기"
			if not state.stella_adventures.get(member.id,{}).is_empty(): label="책갈피부터 이어가기"
			if state.active_mission != member.id: label = "에테에게 의뢰 받기"
			elif state.page_complete: label = "스텔라와 귀환하기"
			_button(Rect2(835,625,277,49),("우리의 이야기 펼치기" if step == 3 else label)+"  E","story_next",true)
			if step == 3:
				_button(Rect2(439,543,273,45),"데뷔 네 컷 보기   V","comic_play")
				_button(Rect2(649,625,177,49),"데뷔 재체험  R","story_replay")
			else:
				_text(Vector2(440,567),"책 속의 나   %s    ·    %s" % [member.name,Chapters.BOOKS[member.id].place],17,GOLD)
				if member.id in state.residents: _button(Rect2(650,625,172,49),"합류 후 단편  T","story_extra")
		1:
			_text_block(Vector2(440,267),entry.scene,663,19,CREAM,28)
			if choice < 0:
				for i in range(2):
					_button(Rect2(441,480+59*i,670,47),"%d   %s" % [i+1,entry.choices[i]],"story_choice_%d" % i)
				_text(Vector2(740,652),"고른 행동이 이 책의 여백에 남아요.",16,MUTED)
			else:
				_text(Vector2(440,536),"그날의 선택  ·  "+entry.choices[choice],18,GOLD)
				_button(Rect2(858,625,254,49),"책갈피 다시 읽기  E","story_next",true)
			_button(Rect2(440,625,148,49),"앞장  ←","story_back")
		2,3:
			_text(Vector2(440,277),entry.choices[choice],20,GOLD)
			var passage: String = entry.replies[choice] if story_page == 2 else entry.ends[choice]
			_text_block(Vector2(440,340),passage,663,21,CREAM,35)
			var has_end: bool = member.id in state.restored
			if story_page == 2 and not has_end:
				_text_block(Vector2(440,533),_afterword_hint(State.BOOKS[story_member].name),663,16,MUTED,25)
			_button(Rect2(440,625,148,49),"앞장  ←","story_back")
			_button(Rect2(856,625,256,49),"뒷장 읽기  E" if has_end and story_page == 2 else "읽기 마치기  E","story_next",true)

func _afterword_hint(book_name: String) -> String:
	return "『%s』를 복원하면 이 장면의 뒷장이 열려요."%book_name

func _unregistered_label() -> String:
	return "복원 대기"

func _journal_hint() -> String:
	return "1~6  책 선택    ·    합류 뒤에는 대화와 책 복원이 열려요."

func _draw_journal() -> void:
	_panel(Rect2(200,130,880,560),Color("20352f"),GOLD)
	_text(Vector2(240,182),"시작의 서가",27,CREAM)
	_button(Rect2(574,148,250,45),"인연 책장   B","encounter_shelf")
	_text(Vector2(240,212),"책을 골라 데뷔 기록을 읽으세요. 책 속으로 떠나려면 먼저 사서 에테의 의뢰를 받으세요.",14,MUTED)
	_text(Vector2(855,178),"합류한 스텔라  %d / 6" % state.residents.size(),15,GOLD)
	for i in range(6):
		var member: Dictionary = MEMBERS[i]
		var x := 240+(i%2)*415
		var y := 249+(i/2)*121
		_panel(Rect2(x,y,390,105),Color("2a4037"),Color("4d6555"))
		if not member.id in state.residents:
			_draw_book(Vector2(x+19,y+28),EncounterBooks.book_cloth(Color(member.color),EncounterBooks.titled(state,member.id)),false,2.0)
			_text(Vector2(x+76,y+33),State.BOOKS[i].name,17,CREAM)
			_text(Vector2(x+76,y+57),member.name+"의 데뷔 기록",13,MUTED)
			var step: int = state.chapter_steps.get(member.id,0)
			_text(Vector2(x+76,y+83),"책갈피  ·  장면 %d/4" % (state.debut_scene(member.id)+1) if step > 0 else "서가에서 기다리는 책",13,GOLD)
			_button(Rect2(x+257,y+53,119,37),"%d  %s" % [i+1,"이어 읽기" if step else "책 펼치기"],"memory_%d" % i)
			continue
		_draw_member(Vector2(x+39,y+96),member.id,90.0,true)
		_text(Vector2(x+77,y+29),member.name,18,Color(member.color).darkened(0.54))
		_text(Vector2(x+77,y+53),member.role,13,MUTED)
		for heart in range(5):
			var filled: bool = int(state.friendship[member.id]) >= (heart+1)*2
			_text(Vector2(x+78+heart*21,y+80),"♥" if filled else "♡",17,Color("ae5341") if filled else MUTED)
		_text(Vector2(x+199,y+80),"친밀도 %d/10  ·  %s" % [state.friendship[member.id],State.BOND_NAMES[state.bond_tier(member.id)]],12,MUTED)
		var tab := "다시 읽기" if state.story_choices.has(member.id) else "첫 장 읽기"
		_button(Rect2(x+256,y+10,122,32),"%d  %s" % [i+1,tab],"memory_%d" % i)
		_text(Vector2(x+276,y+59),"뒷장 열림" if member.id in state.restored else _unregistered_label(),12,MUTED)
	_text(Vector2(240,650),_journal_hint(),14,MUTED)
	_button(Rect2(815,622,225,40),"도서관으로  Esc","close",true)
