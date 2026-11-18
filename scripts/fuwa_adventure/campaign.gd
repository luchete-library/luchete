extends "res://scripts/fuwa_adventure/game.gd"

signal arrived
signal checkpoint_changed
signal exit_requested
signal save_requested
const Progress=preload("res://scripts/fuwa_adventure/progress.gd")
var replay:=false
var completed:=false
var announced:=false

func _ready() -> void:
	var title:=get_window().title
	super._ready()
	get_window().title=title
	set_process(false);set_process_unhandled_input(false)

func snapshot() -> Dictionary:
	var stage: String="arrived" if phase=="arrived" else "reunion" if phase=="reunion" or phase in ReturnFlow.STAGES else "clearing" if zone==1 else "trail"
	return {"version":1,"stage":stage,"x":player_pos.x,"y":player_pos.y,"clock":clock,"spot":encounter%3,"assist":assist}

func restore_snapshot(raw: Dictionary) -> void:
	var data:=Progress.clean(raw)
	reset();completed=false;announced=false
	if data.is_empty():
		say("텐비와 신사에서 함께 수련하던 후와. 사라진 텐비를 찾아 눈산에 들어섰다.",7)
		return
	encounter=data.spot;reset();assist=data.assist;clock=data.clock
	if data.stage!="trail": enter_clearing();clock=data.clock;transition=0
	if data.stage in ["reunion","arrived"]:
		discovered=true;player_pos=tenbi+Vector2(-52,8)
		return_flow.enter(self,"awakening" if data.stage=="arrived" else "return_ready")
	else:
		var saved:=Vector2(data.x,data.y)
		if walkable(saved): player_pos=saved
		checkpoint=player_pos;protection=2

func advance(dt: float) -> void:
	var old_zone:=zone;var old_phase:=phase
	super.advance(dt)
	if phase=="arrived" and not announced:
		announced=true;arrived.emit()
	elif zone!=old_zone or (phase!=old_phase and phase=="return_ready"):
		checkpoint_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if key==KEY_R: return # A campaign book never resets with the preview shortcut.
		if key==KEY_F5: save_requested.emit();return
		if key==KEY_Q: exit_requested.emit();return
		if key==KEY_E and phase=="arrived" and not paused:
			exit_requested.emit();return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if RESTART.has_point(event.position): exit_requested.emit();return
		if phase=="arrived" and not paused and ReturnFlow.ACTION.has_point(event.position): exit_requested.emit();return
	super._unhandled_input(event)

func draw_hud() -> void:
	super.draw_hud()
	draw_rect(Rect2(452,18,433,31),Color("172c42"))
	text_at(Vector2(470,40),"후와 직접 조작"+(" · 다시 펼친 이야기" if replay else " · 텐비 찾기와 귀환"),16,Color("b5d3e5"))
	button(RESTART,"책 덮기   Q")
	if phase=="arrived":
		Pixels.panel(self,Rect2(170,635,940,136),Color("f0dfb6"))
		text_at(Vector2(201,674),"후와의 이야기를 다시 마쳤다" if replay else "후와가 루체테에 합류했다",26,Color("513520"))
		text_at(Vector2(201,710),"도서관으로 돌아가 다음 이야기를 이어가자." if replay else "후와 해금 · 에테에게서 텐비 모습으로 변신할 수 있어.",20,Color("513520"))
		text_at(Vector2(201,745),"E 또는 버튼: 도서관 생활로 돌아가기",17,Color("806047"))
		button(ReturnFlow.ACTION,"도서관으로   E")

func draw_pause() -> void:
	super.draw_pause()
	draw_rect(Rect2(382,326,518,112),Color("f0dfb6"))
	text_at(Vector2(392,352),"후와로 텐비를 찾아 함께 돌아가는 이야기야.",19,Color("513520"))
	text_at(Vector2(392,386),"F5: 저장   ·   Q: 책을 덮고 도서관으로",19,Color("513520"))
	text_at(Vector2(392,420),"진행한 구간은 다시 책을 펼치면 이어갈 수 있어.",18,Color("806047"))
