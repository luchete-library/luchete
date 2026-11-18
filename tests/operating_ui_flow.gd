extends SceneTree

const OUT := "res://artifacts/polish_20261118/"
class AuditGame:
	extends "res://scripts/growth_game.gd"
	var labels: Array[String]=[]
	var saves:=0
	func _save() -> void: saves+=1
	func _draw() -> void:
		labels.clear()
		super._draw()
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
func capture(label: String) -> void:
	await frame()
	root.get_texture().get_image().save_png(OUT+label+".png")
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
func press(code: int) -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=code; e.pressed=true
	g._unhandled_input(e)
func tick(seconds: float) -> void:
	g.background_paused=false
	for step in range(roundi(seconds*10)): g._process(.1)
func no_due() -> bool:
	return g.state.ink_visits.topic<0 and g.state.ink_visits.guests.is_empty() and not g.state.ink_visits.has_due_arrivals(g.state)
func run() -> void:
	g=AuditGame.new()
	g.persist=false
	g.preview_mode=true
	root.add_child(g)
	await process_frame
	g.set_process(false); g.audio_enabled=false
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g.state.minutes=760 # Pre-opening conversation time must not shorten day one.
	g._action("growth_open"); g.toast_time=0
	check(g.mode=="play" and g.state.minutes==540,"production opening starts at 09:00")
	tick(8)
	check(g.state.minutes==550,"live world advances ten minutes in eight seconds")
	for modal in ["growth_ops","growth_shop","growth_ledger","growth_rest","promotion","pause","story","dialog","activity_archive"]:
		g.mode=modal
		var before: int=g.state.minutes
		tick(16)
		check(g.state.minutes==before,"menu or reading pauses operating clock: "+modal)
	g.mode="play"
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var before: int=g.state.minutes
	for i in range(80): g._process(.1)
	check(g.state.minutes==before,"background window pauses world")
	g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	g._action("growth_rest")
	check(await click("growth_wait") and g.state.minutes==600 and g.mode=="play","real wait button reaches opening without reward")
	check(g.growth.gold==0 and g.growth.memory_light==0,"waiting itself gives no rewards")
	root.size=Vector2i(960,600)
	g.toast_time=0
	await capture("operating_01_overview_960")
	g._action("promotion")
	await capture("operating_02_promotion_960")
	check(g.buttons.any(func(b): return b.id=="day_assign" and not b.get("disabled",false)),"morning promotion enabled in real menu")
	check(await click("day_assign"),"broadcast assigned with actual mouse event")
	check(g.state.operating.used_slots==[0],"broadcast consumes one global AM slot")
	for i in range(2000):
		tick(.1)
		if no_due() and g.state.ink_visits.appointments.is_empty(): break
	check(g.state.ink_visits.total==4 and g.growth.gold==55 and g.growth.memory_light==12,"broadcast books three real visits and single completion memory")
	var snapshot: Dictionary=g.state.to_data()
	var loaded=g.GrowthState.new()
	check(loaded.apply_data(snapshot),"active day state serializes")
	check(loaded.operating.used_slots==[0] and loaded.growth.gold==55,"save keeps spent AM slot and income")
	g._action("growth_rest")
	check(await click("growth_wait") and g.state.minutes==840,"next available slot reachable without idle waiting")
	g._action("promotion")
	check(await click("day_topic_1") and await click("day_assign"),"magazine can use PM slot")
	for i in range(1000):
		tick(.1)
		if g.state.ink_visits.topic<0: break
	check(g.state.operating.used_slots==[0,1] and g.state.ink_visits.reservations_for(g.state.day+1)==4,"magazine is four tomorrow reservations")
	check(g.growth.gold==55 and g.growth.memory_light==12,"magazine assignment does not award tomorrow usage early")
	g._action("growth_rest"); g.toast_time=0
	await capture("operating_03_daily_plan_960")
	check(await click("growth_close_request") and g.mode=="growth_close_confirm","close button opens explicit consequence view")
	await capture("operating_04_close_confirm_960")
	check(await click("growth_close_confirm") and g.state.operating.closing,"close confirmation returns to moving library")
	tick(.1)
	check(g.mode=="growth_summary" and g.state.day==1,"finished day waits for player to review summary")
	g.toast_time=0
	await capture("operating_05_summary_960")
	var sum: Dictionary=g.state.operating_summary()
	check(sum.income==55 and sum.light==12 and sum.visitors==4 and sum.next_reservations==4,"summary counts promotion, organic use and future reservation separately")
	check(await click("growth_summary_close") and g.mode=="play","summary can be closed to inspect library")
	tick(1)
	check(g.mode=="play","closing summary does not instantly reopen it")
	g._action("growth_rest")
	check(await click("growth_summary") and g.mode=="growth_summary","summary remains reachable after closing")
	check(await click("growth_next_day") and g.state.day==2 and g.state.minutes==540,"next day starts at 09:00 only after summary")
	check(g.state.operating.used_slots.is_empty() and g.state.ink_visits.reservations_for(2)==5,"new day resets quota and preserves magazine guests")
	check(g.growth.gold==55 and g.growth.memory_light==12,"settlement awards nothing twice")
	g.state.day=8
	g._action("life_open"); g.toast_time=0
	await capture("operating_06_summer_life_960")
	check(g.labels.any(func(label): return "여름 1일" in label),"life screen shares shortened calendar")
	g.mode="play"
	for id in ["yato","danming","kubby","yune","dori","fuwa"]:
		g.character_touch.reactions.clear()
		g.character_touch.react(g,id)
		g.character_touch.update(g,.7)
		await capture("expression_"+id+"_960")
		check(g.character_focus.last_sample.get("member","")==id,"live reaction enlargement uses "+id+" current sprite")
		check(g.character_focus.last_sample.get("physical_pixel_scale",0)>=1,"expression uses integer physical pixel scale")
		check(not g.buttons.any(func(b): return b.id=="growth_rest" and b.rect.position.y>600),"focus blocks covered footer targets")
		g.character_touch.update(g,10)
		await frame()
		check(g.character_focus.last_sample.is_empty(),"reaction focus disappears when reaction ends")
	for modal in ["growth_ops","growth_shop","growth_ledger","growth_rest","growth_close_confirm","growth_summary"]:
		g.mode=modal
		var saved: int=g.saves
		press(KEY_F5)
		check(g.saves==saved+1 and g.mode==modal,"F5 works without closing "+modal)
	print("OPERATING UI FLOW: ",checks," checks; ",failures," failures; mouse input, clock pauses, two slots, future guests, summary, six expressions.")
	g.free()
	quit(1 if failures else 0)
