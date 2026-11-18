extends "res://scripts/growth_game.gd"

# A fresh day-one session with production rules and an isolated save. Normal
# launch through main.tscn still starts/continues the player's ordinary game.
const TEST_OUT := "res://artifacts/reopening_ui_20261118/"
var isolated_save_enabled := true

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_OUT)
	FileAccess.open(TEST_OUT+".gdignore",FileAccess.WRITE).store_string("")
	persist=false
	preview_mode=false
	save_path=TEST_OUT+"first_day_%d.json"%int(Time.get_unix_time_from_system()*1000)
	legacy_save_path=TEST_OUT+"no_legacy_save.json"
	super._ready()
	for member in MEMBERS:
		state.active_mission=member.id
		state.chapter_steps[member.id]=2
		state.page_complete=true
		assert(state.record_chapter_step(member.id,2))
	for task in ["corridor","shelves","reading"]:
		assert(state.complete_reconstruction_task(task))
	assert(state.place_furniture("chair",Furniture.DEFAULTS[0])=="")
	assert(growth.open_library())
	state.intro_seen=true
	state.opening_pending=false
	state.minutes=540
	state.day=1
	state.operating.begin(state)
	player_pos=state.player
	mode="promotion"
	observed_gold=0
	observed_light=0
	_setup_map()
	persist=isolated_save_enabled
	_save()
	get_window().title="루체테 · 재개관 첫날 테스트 · 별도 저장"
	get_window().size=Vector2i(1280,800)
	get_window().position=Vector2i(100,60)
	if "--capture-initial" in OS.get_cmdline_user_args(): call_deferred("capture_initial")

func capture_initial() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TEST_OUT+"launched_first_day.png")
	print("FIRST_DAY_READY day=",state.day," minutes=",state.minutes," mode=",mode," save=",save_path)
