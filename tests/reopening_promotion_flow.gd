extends SceneTree

const OUT := "res://artifacts/reopening_ui_20261118/"
class AuditGame:
	extends "res://tests/reopening_first_day.gd"
	var labels: Array[String]=[]
	func _save() -> void: pass
	func _draw() -> void:
		labels.clear()
		super._draw()
	func _text(pos: Vector2, value: String, size: int=18, color: Color=Color("513520")) -> void:
		labels.append(value)
		super._text(pos,value,size,color)

var g: Node2D
var checks:=0
var failures:=0
var peak:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	g.toast_time=0
	await frame()
	root.get_texture().get_image().save_png(OUT+label+".png")
func click(id: String) -> bool:
	await frame()
	for button in g.buttons:
		if button.id==id:
			var event:=InputEventMouseButton.new()
			event.position=button.rect.get_center()
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=true
			g._unhandled_input(event)
			return true
	return false
func tick(seconds: float) -> void:
	for step in range(roundi(seconds*10)):
		g.background_paused=false
		g._process(.1)
		peak=maxi(peak,g.state.ink_visits.guests.size())
func drain() -> void:
	for step in range(5000):
		tick(.1)
		if g.state.ink_visits.topic<0 and g.state.ink_visits.guests.is_empty() and g.state.ink_visits.reservations_for(g.state.day)==0: return
	check(false,"all promised visits finish")

func run() -> void:
	g=AuditGame.new()
	g.isolated_save_enabled=false
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.audio_enabled=false
	await capture("01_promotion_before_open")
	check(g.buttons.any(func(b): return b.id=="growth_promotion_wait"),"opening wait is available inside promotion menu")
	check(not g.buttons.any(func(b): return b.id.begins_with("promote_")),"all topics remain disabled before 10")
	check(await click("growth_promotion_wait") and g.state.minutes==600 and g.mode=="promotion","wait reaches 10 and keeps topic selection open")
	check(g.growth.gold==0 and g.growth.memory_light==0 and g.state.operating.used_slots.is_empty(),"wait grants no money, light or promotion")
	check(g.state.promotion_wait_target()==-1,"no shortcut skips an available morning slot")
	await capture("02_promotion_ready")
	g.mode="play"
	await capture("03_current_goal_1280")
	check(g.labels.has("지금 오전 홍보 1회 가능") and g.labels.has("다음 성장까지 기억의 빛 30"),"footer shows current action and remaining light")
	check(g.buttons.any(func(b): return b.id=="growth_archive" and b.rect==Rect2(1081,736,159,31)),"archive button keeps approved location")
	root.size=Vector2i(960,600)
	await capture("04_current_goal_960")
	root.size=Vector2i(1280,800)

	# Start a normal scheduled visitor before assigning the AM campaign.
	var v=g.state.ink_visits
	v._book_appointment(g.state,"read",3,g.state.day,600)
	tick(4)
	check(not v.guests.is_empty(),"visitor is physically using library before promotion")
	var first_uid: int=v.guests[0].uid
	var before_money: int=g.growth.gold
	g._action("promotion")
	await capture("05_promotion_while_occupied")
	check(await click("promote_0"),"real promotion button works while visitor present")
	check(v.guests.any(func(guest): return guest.uid==first_uid),"assigning promotion preserves existing guest")
	check(g.growth.gold==before_money and g.growth.memory_light==0,"assignment pays no immediate reward")
	check(g.state.operating.used_slots==[0] and not v.start(g.state,1),"AM slot reserved and active promotion cannot duplicate")
	var reloaded=g.GrowthState.new()
	check(reloaded.apply_data(JSON.parse_string(JSON.stringify(g.state.to_data()))),"concurrent guest and campaign survive JSON round trip")
	check(reloaded.ink_visits.guests[0].uid==first_uid and reloaded.operating.used_slots==[0],"save preserves guest identity and used quota")
	drain()
	check(v.total==4 and g.growth.gold==55 and g.growth.memory_light==12,"original reader plus broadcast settle exactly once")
	check(peak<=2,"concurrent campaign never exceeds visitor capacity")
	check(not v.start(g.state,2),"second AM campaign remains blocked after first completes")
	check(g.state.promotion_wait_target()==840,"after AM use shortcut targets afternoon")
	g._action("promotion")
	check(await click("growth_promotion_wait") and g.state.minutes==840,"promotion menu waits for afternoon")
	check(not v.start(g.state,0),"same topic cannot repeat in afternoon")
	check(await click("promote_2"),"different PM topic accepted")
	drain()
	check(g.state.operating.used_slots==[0,1] and not v.start(g.state,1),"third daily promotion remains blocked")
	check(g.growth.gold==105 and g.growth.memory_light==22,"afternoon earnings remain unchanged")
	g.state.request_day_close()
	check(g.state.finish_operating_day(),"day closes normally")
	check(v.return_queue.size()==1,"borrowed book returns next morning")
	g.state.minutes=600
	g.mode="play"
	check(v.start_error(g.state,1)=="","return queue does not block new day promotion")
	check(v.start(g.state,1) and v.return_queue.size()==1,"new promotion preserves pending return")
	check(g.state.promotion_wait_target()==-1,"active campaign prevents time skip")
	drain()
	check(v.loans[0].returned and g.growth.gold==105 and g.growth.memory_light==22,"return still completes without duplicate payment")
	check(v.reservations_for(g.state.day+1)==4,"magazine still schedules next day visitors")
	# An earlier appointment must precede the next promotion window.
	g.state.minutes=790
	v._book_appointment(g.state,"read",3,g.state.day,810)
	check(g.state.promotion_wait_target()==810,"shortcut respects earlier booked arrival")
	g._action("promotion")
	check(await click("growth_promotion_wait") and g.state.minutes==810,"wait stops at earlier appointment")
	check(g.state.promotion_wait_target()==-1,"due arrival cannot be skipped repeatedly")
	g.mode="play"
	drain()
	g.state.minutes=840
	v._book_appointment(g.state,"borrow",3,g.state.day,840)
	tick(4)
	g._action("promotion")
	check(await click("promote_0"),"PM campaign can begin while borrower uses library")
	drain()
	check(g.state.operating.used_slots==[0,1] and peak<=2,"two-slot limit and capacity remain after concurrent borrower")
	g.growth.reward("test:rank",0,100)
	g.mode="play"
	await capture("06_later_growth_goal")
	check(g.labels.any(func(label): return "다음 성장까지 기억의 빛" in label),"growth goal advances with rank")
	g.state.minutes=1020
	g.state.operating.used_slots.clear()
	g.state.operating.used_topics.clear()
	check(v.start_error(g.state,0)!="","17:00 cutoff remains enforced")
	g.state.operating.closing=true
	check(v.start_error(g.state,0)!="" and g.state.promotion_wait_target()==-1,"closing blocks promotion and shortcut")
	print("REOPENING PROMOTION FLOW: ",checks," checks; ",failures," failures")
	g.free()
	quit(1 if failures else 0)
