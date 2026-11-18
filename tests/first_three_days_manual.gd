extends SceneTree

# Manual UX session only. After the initial fixture, every action and every
# elapsed second comes from the normal game loop and manually selected input.
# Optional review-api transports viewport images and native InputEvent objects.
const OUT := "res://artifacts/first_three_days_20261117/"

class ManualGame:
	extends "res://scripts/growth_game.gd"
	const REVIEW_OUT := "res://artifacts/first_three_days_20261117/"
	const SLOT := REVIEW_OUT+"manual_save.json"
	var review_log: FileAccess
	var review_started_ms := 0
	var observing := false
	var observation_interval := 0.0
	var last_signature := ""
	var total_active_seconds := 0.0
	var mode_seconds: Dictionary = {}
	var day_seconds: Dictionary = {}
	var captured_saves: Dictionary = {}
	var event_number := 0
	var review_api_enabled := false
	var review_api_elapsed := 0.0
	var review_api_sequence := -1
	var review_capture_pending := false

	func _ready() -> void:
		# Set routes before parent _ready so even save-availability checks cannot
		# inspect the ordinary or old review save slots.
		persist=false
		preview_mode=false
		save_path=SLOT
		legacy_save_path=REVIEW_OUT+"no_legacy_slot.json"
		super._ready()
		for path in [State.SAVE_PATH,State.SAVE_PATH+".bak",PRODUCTION_SAVE,PRODUCTION_SAVE+".bak",PREVIEW_SAVE,PREVIEW_SAVE+".bak"]:
			captured_saves[path]=hash_file(path)
		FileAccess.open(REVIEW_OUT+"save_hashes_before.json",FileAccess.WRITE).store_string(JSON.stringify(captured_saves,"\t"))
		# This fixture replaces only the already-completed story/reconstruction.
		for member in MEMBERS:
			state.active_mission=member.id
			state.chapter_steps[member.id]=2
			state.page_complete=true
			assert(state.record_chapter_step(member.id,2))
		state.intro_seen=true
		state.opening_pending=false
		for task in ["corridor","shelves","reading"]:
			assert(state.complete_reconstruction_task(task))
		assert(growth.phase=="ready" and growth.gold==0 and growth.memory_light==0)
		assert(state.place_furniture("chair",Furniture.DEFAULTS[0])=="")
		state.minutes=540
		state.day=1
		player_pos=state.player
		observed_gold=0
		observed_light=0
		mode="growth_ops"
		_setup_map()
		get_window().title="루체테 · 첫 3일 수동 플레이 검토"
		get_window().size=Vector2i(1280,800)
		# An optional --resume flag uses ONLY this isolated slot.
		if "--resume" in OS.get_cmdline_user_args() and FileAccess.file_exists(SLOT):
			_continue_game()
		review_started_ms=Time.get_ticks_msec()
		review_log=FileAccess.open(REVIEW_OUT+"manual_events.jsonl",FileAccess.READ_WRITE if "--resume" in OS.get_cmdline_user_args() else FileAccess.WRITE)
		assert(review_log!=null)
		if "--resume" in OS.get_cmdline_user_args(): review_log.seek_end()
		persist=true
		observing=true
		review_api_enabled="--review-api" in OS.get_cmdline_user_args()
		if review_api_enabled:
			background_paused=false
			RenderingServer.frame_post_draw.connect(review_capture)
		record("session_start",{"fixture":"six rescued, three free works complete; player opens library manually","speed":"normal","resume":"--resume" in OS.get_cmdline_user_args()})
		if review_api_enabled: record("review_api_enabled",{"reason":"native Windows capture timed out; manual decisions use rendered viewport PNG and injected input events","focus_pause_override":true,"time_scale":Engine.time_scale})
		_save()
		queue_redraw()

	static func hash_file(path: String) -> Dictionary:
		return {"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}

	func snapshot() -> Dictionary:
		var visitors: RefCounted=state.ink_visits
		var guests: Array=[]
		for guest in visitors.guests:
			guests.append({"uid":guest.uid,"kind":guest.get("kind",""),"phase":guest.phase,"book":guest.get("book",""),"pos":[snappedf(guest.pos.x,.1),snappedf(guest.pos.y,.1)]})
		var next_loans: Array=[]
		for loan in visitors.loans:
			if not loan.returned: next_loans.append(loan.duplicate(true))
		return {"mode":mode,"day":state.day,"minutes":state.minutes,"phase":growth.phase,"rank":growth.rank()+1,
			"gold":growth.gold,"light":growth.memory_light,"total_income":growth.income_total,"total_spent":growth.spent_total,
			"total_visitors":visitors.total,"guests":guests,"promotion":visitors.topic,"promotion_host":visitors.host,
			"promotion_elapsed":snappedf(visitors.promotion_elapsed,.1),"appointments":visitors.appointments.duplicate(true),
			"return_queue":visitors.return_queue.duplicate(),"outstanding_loans":next_loans,"used_slots":state.operating.used_slots.duplicate(),
			"used_topics":state.operating.used_topics.duplicate(),"closing":state.operating.closing,"background_paused":background_paused,
			"furniture":state.furniture.duplicate(true),"upgrades":growth.upgrades.duplicate(true),"owned_costumes":growth.owned_costumes.duplicate(),
			"player":[snappedf(player_pos.x,.1),snappedf(player_pos.y,.1)],"toast":toast if toast_time>0 else "",
			"active_seconds":snappedf(total_active_seconds,.01)}

	func record(kind: String, detail: Dictionary={}) -> void:
		if not observing or review_log==null: return
		event_number+=1
		var entry: Dictionary={"event":event_number,"kind":kind,"wall_seconds":(Time.get_ticks_msec()-review_started_ms)/1000.0,
			"timestamp":Time.get_datetime_string_from_system(),"detail":detail,"state":snapshot()}
		review_log.store_line(JSON.stringify(entry))
		review_log.flush()

	func write_summary() -> void:
		if not observing: return
		var preserved: Dictionary={}
		for path in captured_saves:
			preserved[path]={"unchanged":captured_saves[path]==hash_file(path),"before":captured_saves[path],"after":hash_file(path)}
		FileAccess.open(REVIEW_OUT+"manual_summary.json",FileAccess.WRITE).store_string(JSON.stringify({
			"wall_seconds":(Time.get_ticks_msec()-review_started_ms)/1000.0,"active_seconds":total_active_seconds,
			"mode_seconds":mode_seconds,"day_seconds":day_seconds,"state":snapshot(),"preserved_saves":preserved,
			"review_api":review_api_enabled,
			"note":"Real-time manual decisions from viewport PNG; injected InputEvents with focus pause disabled, no time scaling or scripted actions." if review_api_enabled else "Real time manual window input; no time scaling or scripted play actions after initial ready fixture."},"\t"))

	func _process(delta: float) -> void:
		if review_api_enabled:
			# Inspection transport only: normal delta and production updates stay
			# intact. Input is chosen one command at a time from the captured UI.
			background_paused=false
			review_api_elapsed+=delta
			if review_api_elapsed>=0.35:
				review_api_elapsed=0.0
				review_capture_pending=true
				review_input()
		if observing and not background_paused:
			total_active_seconds+=delta
			mode_seconds[mode]=float(mode_seconds.get(mode,0.0))+delta
			var day_key:=str(state.day)
			day_seconds[day_key]=float(day_seconds.get(day_key,0.0))+delta
		super._process(delta)
		if not observing: return
		observation_interval+=delta
		if observation_interval>=1.0:
			observation_interval=0.0
			var info:=snapshot()
			# Position/pose samples are useful once a second. Background-paused
			# heartbeats are omitted unless a state change occurs.
			var signature:=JSON.stringify(info)
			if signature!=last_signature:
				last_signature=signature
				record("observation")
				write_summary()

	func _action(id: String) -> void:
		record("action_before",{"id":id})
		super._action(id)
		record("action_after",{"id":id})
		write_summary()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			record("key",{"physical_keycode":event.physical_keycode,"key":OS.get_keycode_string(event.physical_keycode)})
		elif event is InputEventMouseButton and event.pressed:
			record("mouse",{"button":event.button_index,"position":[event.position.x,event.position.y]})
		super._unhandled_input(event)

	func _save() -> void:
		assert(save_path==SLOT)
		super._save()

	func review_input() -> void:
		var path:=REVIEW_OUT+"input.json"
		if not FileAccess.file_exists(path): return
		var command: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not command is Dictionary or not command.has("seq"): return
		var sequence:=int(command.seq)
		if sequence<=review_api_sequence: return
		review_api_sequence=sequence
		record("review_api_input",command)
		match str(command.get("type","")):
			"click":
				var point:=Vector2(float(command.get("x",0)),float(command.get("y",0)))
				var motion:=InputEventMouseMotion.new()
				motion.position=point; motion.global_position=point
				Input.parse_input_event(motion)
				var down:=InputEventMouseButton.new()
				down.position=point; down.global_position=point
				down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
				Input.parse_input_event(down)
				await get_tree().process_frame
				var up:=InputEventMouseButton.new()
				up.position=point; up.global_position=point
				up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false
				Input.parse_input_event(up)
			"key":
				var code:=OS.find_keycode_from_string(str(command.get("code","")))
				if code==0: return
				var down:=InputEventKey.new()
				down.keycode=code; down.physical_keycode=code
				down.pressed=bool(command.get("pressed",true))
				Input.parse_input_event(down)
				if not command.has("pressed"):
					await get_tree().process_frame
					var up:=InputEventKey.new()
					up.keycode=code; up.physical_keycode=code; up.pressed=false
					Input.parse_input_event(up)
			"capture": review_capture_pending=true

	func review_capture() -> void:
		if not review_capture_pending or not is_inside_tree(): return
		review_capture_pending=false
		var image:=get_viewport().get_texture().get_image()
		if image==null or image.is_empty(): return
		var temp:=REVIEW_OUT+"live_frame.tmp.png"
		if image.save_png(temp)==OK:
			DirAccess.rename_absolute(temp,REVIEW_OUT+"live_frame.png")

	func _notification(what: int) -> void:
		if what==NOTIFICATION_WM_CLOSE_REQUEST:
			record("window_close")
			write_summary()
		super._notification(what)
		if review_api_enabled: background_paused=false
		if what in [NOTIFICATION_WM_WINDOW_FOCUS_IN,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
			record("focus",{"focused":what==NOTIFICATION_WM_WINDOW_FOCUS_IN})

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+".gdignore",FileAccess.WRITE).store_string("")
	call_deferred("run")

func run() -> void:
	var game:=ManualGame.new()
	root.add_child(game)
	# SceneTree --script runners do not always show the native root window.
	# This review is intentionally interactive, unlike the headless test suites.
	root.show()
	root.grab_focus()
	game.record("window_ready",{"visible":root.visible,"display_server":DisplayServer.get_name(),"size":[root.size.x,root.size.y]})
