extends SceneTree

const OUT="res://artifacts/polish_20261118/"
class AuditGame:
	extends "res://scripts/growth_game.gd"
	var saves:=0
	var panels: Array[Rect2]=[]
	var labels: Array[String]=[]
	func _save() -> void:
		saves+=1
		super._save()
	func _draw() -> void:
		panels.clear()
		labels.clear()
		super._draw()
	func _panel(rect: Rect2, fill: Color, border: Color=Color("b88752")) -> void:
		panels.append(rect)
		super._panel(rect,fill,border)
	func _text(pos: Vector2, value: String, size: int=18, color: Color=Color("513520")) -> void:
		labels.append(value)
		super._text(pos,value,size,color)

var g: Node2D
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func snap(label: String) -> void:
	await frame()
	root.get_texture().get_image().save_png(OUT+label+".png")
func press(code: int, echo:=false, pressed:=true) -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=code
	e.pressed=pressed
	e.echo=echo
	g._unhandled_input(e)
func click(id: String) -> bool:
	await frame()
	for b in g.buttons:
		if b.id==id:
			var e:=InputEventMouseButton.new()
			e.position=b.rect.get_center()
			e.button_index=MOUSE_BUTTON_LEFT
			e.pressed=true
			g._unhandled_input(e)
			return true
	return false
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	g=AuditGame.new()
	g.save_path=OUT+"ui_slot.json"
	g.legacy_save_path=OUT+"unused_legacy.json"
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.audio_enabled=false
	for member in g.MEMBERS:
		g.state.residents.append(member.id)
		g.state.chapter_steps[member.id]=3
	g.growth.begin_rebuild(6)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g.growth.open_library()
	g.mode="play"
	g._setup_map()
	for mode in ["play","growth_ops","growth_shop","growth_ledger","growth_rest","growth_work"]:
		g.mode=mode
		g.work_task="corridor" if mode=="growth_work" else ""
		var saves: int=g.saves
		press(KEY_F5)
		check(g.saves==saves+1 and not g.save_failed,"F5 saves in "+mode)
		var reloaded=g.GrowthState.new()
		check(reloaded.load_from(g.save_path) and reloaded.growth.phase=="open","F5 writes valid isolated save in "+mode)
		check(g.mode==mode,"F5 keeps current menu "+mode)
		press(KEY_F5,true)
		press(KEY_F5,false,false)
		check(g.saves==saves+1,"held/released F5 does not resave in "+mode)
		var before_mode:=root.mode
		press(KEY_F11)
		check(root.mode!=before_mode,"F11 reaches fullscreen in "+mode)
		press(KEY_F11)
		check(root.mode==before_mode,"F11 returns to previous window mode in "+mode)
	g.mode="growth_rest"
	g.work_task=""
	g.state.minutes=600
	g.state.ink_visits.start(g.state,1)
	await snap("rest_busy_after")
	check(g.labels.has("이 수첩에서는 시간이 멈춰요. 열람실로 돌아가면 다시 흘러요."),"operating notebook explains pause and resume")
	check(g.buttons.any(func(b): return b.id=="growth_close_request"),"busy day can request safe closing instead of skipping use")
	check(not g.buttons.any(func(b): return b.id=="sleep_confirm"),"busy rest cannot skip guests")
	check(await click("close") and g.mode=="play","rest return button uses actual pointer event")
	for tick in range(1500):
		g.background_paused=false
		g._process(.1)
		if g.state.ink_visits.topic<0 and g.state.ink_visits.guests.is_empty(): break
	check(g.state.ink_visits.topic<0 and g.state.ink_visits.guests.is_empty(),"closing rest really resumes and completes visits")
	g.mode="growth_rest"
	await frame()
	check(g.buttons.any(func(b): return b.id=="growth_wait"),"next schedule reachable after promotion finishes")
	g.state.day=8
	g.mode="play"
	g._action("life_open")
	g.toast_time=0
	await snap("summer_life_after")
	check(g.labels.any(func(t): return "여름 1일" in t),"life menu shares summer calendar")
	check(not g.labels.any(func(t): return "봄 29일" in t),"old absolute spring date removed")
	g.mode="play"
	g._notify("오늘의 이야기를 저장했어요.")
	await snap("notice_after_1280")
	var notice: Rect2=g.panels.back()
	check(Rect2(0,0,1280,800).encloses(notice),"notification stays inside the full library viewport")
	check(not g.buttons.any(func(button): return button.rect.intersects(notice)),"notification does not cover a current map action")
	root.size=Vector2i(960,600)
	await snap("notice_after_960")
	check(g.panels.back()==notice,"notice separation survives small window scaling")
	g.mode="together";g.shared.member="dori";g.shared.kind="tea";g.shared.path=PackedVector2Array();g.shared.activity_line="돌돌이, 네 잔은 여기야."
	await snap("notice_shared_after_960")
	check(not g.panels.back().intersects(Rect2(278,635,724,125)),"visitor notification does not cover shared reading or tea dialogue")
	check(Rect2(0,0,1280,800).encloses(g.panels.back()),"shared-activity notification stays on screen")
	root.size=Vector2i(1280,800)
	print("GROWTH UI REGRESSION: ",checks," checks; ",failures," failures; actual keys, isolated disk save, return button, live guests, dates, notification geometry.")
	g.free()
	quit(1 if failures else 0)
