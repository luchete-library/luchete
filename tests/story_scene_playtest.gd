extends "res://scripts/main.gd"

# This entry point owns its state. All six activities still run in the campaign's chapter UI.
const SCENES := [
	["danming",2,"bee_album","같은 자리, 다른 날"],
	["dori",2,"clue_rubbing","돌돌이의 돌 탁본"],
	["yune",2,"dream_nights","꿈빛이 옅어지던 밤"],
	["kubby",1,"wisp_watch","햄스터를 보고 놀란 쿠비"],
	["yato",1,"mato_basket","토끼 가족의 곳간"],
	["fuwa",0,"tenbi_together","텐비와 후와의 결계 연습"],
]
const PICKER := "scene_picker"
const PICKER_BUTTON := Rect2(932,21,228,40)
var completed: Array[String] = []

func _ready() -> void:
	super._ready()
	get_window().title="루체테 도서관 · 여섯 장면 테스트"
	show_picker()
	if "--beori-workbench" in OS.get_cmdline_user_args():
		get_window().title="루체테 도서관 · 버리의 작업대 체험"
		start_scene(0)
	elif "--doldori-alley" in OS.get_cmdline_user_args():
		get_window().title="루체테 도서관 · 돌돌이의 골목 탁본"
		start_scene(1)
	elif "--mongchi-nights" in OS.get_cmdline_user_args():
		get_window().title="루체테 도서관 · 몽치가 지켜본 밤"
		start_scene(2)
	elif "--hamnim-village" in OS.get_cmdline_user_args():
		get_window().title="루체테 도서관 · 햄님이 찾아간 아랫마을"
		start_scene(3)
	elif "--mato-storehouse" in OS.get_cmdline_user_args():
		get_window().title="루체테 도서관 · 마토가 찾은 곳간"
		start_scene(4)
	elif "--tenbi-shrine" in OS.get_cmdline_user_args():
		get_window().title="루체테 도서관 · 텐비와 후와의 신사 수련"
		start_scene(5)

func _save() -> void:
	pass

func show_picker() -> void:
	mode=PICKER
	book_activity=null
	book_discovery.reset()
	danming_workshop.reset()
	dori_rubbing.reset()
	yune_dream.reset()
	kubby_embers.village.restore([])
	yato_forest.storehouse.restore([])
	fuwa_snow.practice.reset()
	chapter_question=false
	buttons.clear()
	route.clear()
	pending_object=""
	toast_time=0
	chime.stop()
	queue_redraw()

func start_scene(slot: int) -> void:
	var entry: Array=SCENES[slot]
	var member: String=entry[0]
	var scene_index: int=entry[1]
	state=State.new()
	state.accept_mission(member)
	if scene_index>=1: state.record_chapter_step(member,0)
	if scene_index>=2: state.mark_first_action(member)
	story_member=_mission_index_for(member)
	_enter_chapter(member)
	var site:=_find_object(entry[2])
	if site.is_empty():
		push_error("Missing story test entry: "+str(entry))
		show_picker()
		return
	buttons.clear()
	queue_redraw()

func _next_chapter_site(id: String,_finished: int) -> void:
	if id not in completed: completed.append(id)
	if id in BookDiscovery.MEMBERS or (id=="dori" and _finished==2):
		super._next_chapter_site(id,_finished)
		return
	show_picker()

func _leave_chapter() -> void:
	show_picker()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.physical_keycode
		if mode==PICKER and code>=KEY_1 and code<=KEY_6:
			start_scene(code-KEY_1)
			return
		if code==KEY_F2:
			show_picker()
			return
		if code==KEY_F5: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if mode=="chapter" and not dori_rubbing.active(self) and not book_discovery.active(self) and PICKER_BUTTON.has_point(event.position):
			show_picker()
			return
		if mode==PICKER:
			for i in range(SCENES.size()):
				if card_rect(i).has_point(event.position):
					start_scene(i)
					return
	if mode!=PICKER or (event is InputEventKey and event.physical_keycode==KEY_F11):
		super._unhandled_input(event)

func _button(rect: Rect2,label: String,id: String,accent: bool=false,disabled: bool=false) -> void:
	if id=="chapter_leave": return # A single persistent button also covers modal pages.
	if id=="chapter_remember": label="기억을 잇고 다음 길 걷기   E"
	super._button(rect,label,id,accent,disabled)

static func card_rect(i: int) -> Rect2:
	return Rect2(97+(i%2)*555,185+floori(i/2.0)*154,531,133)

func _draw() -> void:
	if mode!=PICKER:
		super._draw()
		if mode=="chapter" and not dori_rubbing.active(self) and not book_discovery.active(self): _button(PICKER_BUTTON,"장면 선택   F2","test_picker")
		return
	buttons.clear()
	draw_rect(Rect2(0,0,1280,800),Color("34463d"))
	_panel(Rect2(66,58,1148,680),PAPER)
	_text(Vector2(99,127),"체험할 장면 고르기",33,CREAM)
	_text(Vector2(99,160),"장면을 클릭하거나 숫자 1~6을 누르세요.",18,MUTED)
	_text(Vector2(979,126),"체험 완료   %d / 6"%completed.size(),20,GOLD)
	for i in range(SCENES.size()):
		var entry: Array=SCENES[i]
		var member: String=entry[0]
		var box:=card_rect(i)
		var color:=Color("f4e5c6") if box.has_point(get_global_mouse_position()) else Color("e9d8b3")
		Pixels.panel(self,box,color,"slot")
		var art:=Rect2(box.position+Vector2(13,17),Vector2(205,99))
		draw_texture_rect_region(Comics.sheet(member),art,Comics.key_region(entry[1],10))
		var origin:=box.position+Vector2(231,43)
		_text(origin,"%d   %s · %s장"%[i+1,MEMBERS[_mission_index_for(member)].short,entry[1]+1],19,GOLD)
		_text(origin+Vector2(0,35),entry[3],21,CREAM)
		var fan: String=Chapters.BOOKS[member].fan
		_text(origin+Vector2(0,67),fan+("   ·   완료" if member in completed else ""),16,MUTED)
	_text(Vector2(99,690),"F2  장면 선택으로 돌아가기     ·     같은 장면을 다시 고르면 처음부터 시작해요.",17,MUTED)
