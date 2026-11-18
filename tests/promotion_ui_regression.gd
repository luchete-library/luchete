extends SceneTree

const Adapter=preload("res://scripts/growth_state_adapter.gd")
const Normal=preload("res://scripts/game_state.gd")
const Visits=preload("res://scripts/growth_visitors.gd")

class CaptureGame:
	extends "res://scripts/main.gd"
	var captured_buttons: Array=[]
	var captured_text: Array=[]
	var saves:=0
	func _save() -> void: saves+=1
	func _draw() -> void: pass
	func _panel(_rect: Rect2, _fill: Color, _border: Color=Color("b88752")) -> void: pass
	func _text(_pos: Vector2, value: String, _size: int=18, _color: Color=Color("513520")) -> void:
		captured_text.append(value)
	func _button(rect: Rect2, label: String, id: String, _accent: bool=false, disabled: bool=false) -> void:
		captured_buttons.append({"id":id,"rect":rect,"label":label,"disabled":disabled})
		if not disabled: buttons.append({"id":id,"rect":rect})

var g:=CaptureGame.new()
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func render_menu() -> void:
	g.captured_buttons.clear()
	g.captured_text.clear()
	g.buttons.clear()
	g._draw_promotion()
func open_state():
	var state:=Adapter.new()
	for member in state.BOOKS:
		state.residents.append(member.id)
		state.chapter_steps[member.id]=3
	state.growth.begin_rebuild(6)
	for task in ["corridor","shelves","reading"]: state.complete_reconstruction_task(task)
	state.growth.open_library()
	return state
func assert_disabled(reason: String) -> void:
	render_menu()
	check(g.captured_buttons.size()==4,"three topics and return button are rendered")
	for button in g.captured_buttons:
		if button.id.begins_with("promote_"): check(button.disabled,"blocked topic is visibly disabled: "+button.id)
	check(reason in g.captured_text,"the exact start rejection is visible before clicking")
	check(g.captured_text.any(func(t): return "잠시 멈춰요" in t and "돌아가면" in t),"paused visitor guidance says how to resume")
	var before: Dictionary=g.state.ink_visits.data().duplicate(true)
	for code in [KEY_1,KEY_2,KEY_3]:
		g.toast=""
		var event:=InputEventKey.new()
		event.pressed=true
		event.physical_keycode=code
		g._unhandled_input(event)
		check(g.toast==reason and g.mode=="promotion","keyboard topic rejection gives the same visible reason")
		check(g.state.ink_visits.data()==before,"blocked input does not mutate campaign or visitor state")
func run() -> void:
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.audio_enabled=false
	g.state=open_state()
	g.mode="promotion"
	g._setup_map()
	var visits=g.state.ink_visits
	# A real next-day loan creates the return queue that formerly left the
	# three topic buttons enabled while every click silently failed.
	visits.loans.append({"id":"ui-regression-return","book":"dori","due_day":2,"queued":false,"returned":false})
	g.state.day=2
	visits.on_new_day(2)
	check(visits.return_queue.size()==1,"due loan is waiting for its physical return")
	var reason: String=visits.start_error(g.state,0)
	check("반납" in reason,"queued return has a specific explanation")
	assert_disabled(reason)
	# Returning to the library is an actual mouse action, then the visitor
	# simulation runs through return/check-in/leave with no extra fees.
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=Vector2(900,605)
	g._unhandled_input(event)
	check(g.mode=="play","the return button actually closes the paused menu")
	for tick in range(1000):
		g._process(.1)
		if visits.return_queue.is_empty() and not visits.guests.is_empty(): break
	g.mode="promotion"
	reason=visits.start_error(g.state,0)
	check("이용 중" in reason,"already admitted return guest also blocks a new campaign")
	assert_disabled(reason)
	g._action("close")
	for tick in range(1800):
		g._process(.1)
		if visits.return_queue.is_empty() and visits.guests.is_empty(): break
	check(visits.loans[0].returned and visits.guests.is_empty(),"closing menu lets the return finish normally")
	check(g.state.growth.gold==0 and g.state.growth.memory_light==0,"return adds neither fee nor memory reward")
	g.mode="promotion"
	render_menu()
	for button in g.captured_buttons:
		if button.id.begins_with("promote_"): check(not button.disabled,"topics become enabled when return is over")
	event.position=Vector2(508,296)
	g._unhandled_input(event)
	check(g.mode=="play" and visits.topic==0,"enabled topic starts through its rendered mouse target")
	check(g.saves>0,"starting a campaign still saves through the ordinary action")
	# Check automatic/explicit host selection without changing its established
	# daily-broadcast behavior. Selection and the reason query must be pure.
	var state=open_state()
	state.yard_host=state.residents[0]
	state.yard_session={"member":state.residents[1]}
	var fresh=state.ink_visits
	var snapshot: Dictionary=fresh.data().duplicate(true)
	check(fresh.start_error(state,0)=="" and fresh.data()==snapshot,"eligibility query has no campaign side effects")
	check(fresh.start(state,0) and fresh.host==state.residents[2],"automatic assignment skips busy broadcast and workout hosts")
	state=open_state();fresh=state.ink_visits
	state.yard_host="dori"
	check(fresh.start_error(state,0,"dori")=="" and fresh.start(state,0,"dori"),"explicit finished-broadcast host remains supported")
	check(fresh.host=="dori" and not fresh.live_recommendation,"explicit broadcast retains original completion behavior")
	state=open_state();fresh=state.ink_visits
	check(fresh.start_error(state,0,"unknown")!="" and not fresh.start(state,0,"unknown"),"unknown explicit host has a reason and cannot start")
	check(fresh.start_error(state,-1)!="" and not fresh.start(state,-1),"invalid topic has a reason and cannot start")
	state.scene="garden"
	check(fresh.start_error(state,0)!="" and not fresh.start(state,0),"wrong location eligibility agrees with start")
	state.scene="library";state.growth.phase="rebuilding"
	check(fresh.start_error(state,0)!="" and not fresh.start(state,0),"pre-opening eligibility agrees with start")
	# The original main scene also uses this menu; it keeps its old visitor
	# rules while implementing the same eligibility interface.
	var legacy:=Normal.new()
	for member in legacy.BOOKS:
		legacy.residents.append(member.id)
		legacy.chapter_steps[member.id]=3
	legacy.opening_pending=false
	check(legacy.ink_visits.start_error(legacy,0)=="","legacy reopened library supports eligibility query")
	check(legacy.ink_visits.start(legacy,0,"dori"),"legacy explicit-host start still works")
	check(legacy.ink_visits.start_error(legacy,1)!="" and not legacy.ink_visits.start(legacy,1),"legacy active campaign rejection agrees")
	print("PROMOTION UI: ",checks," checks, ",failures," failures. User saves untouched.")
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
