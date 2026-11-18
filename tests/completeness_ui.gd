extends "res://tests/library_day_flow.gd"
const DEST:="res://artifacts/completeness_20261118/"
class Probe:
	extends "res://scripts/growth_game.gd"
	var label_issues: Array=[]
	func _draw() -> void:
		label_issues.clear();super._draw()
	func _button(r: Rect2,label: String,id: String,accent: bool=false,disabled: bool=false) -> void:
		var size: int=14 if r.size.y<36 else 17
		var width: float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		if width>r.size.x-12: label_issues.append({"id":id,"label":label,"text_width":width,"button_width":r.size.x,"mode":mode})
		super._button(r,label,id,accent,disabled)
var panels: Array=[]

func fresh() -> void:
	if is_instance_valid(g): g.free()
	g=Probe.new();g.persist=false;g.save_path=DEST+"ui_unused.json";g.legacy_save_path=DEST+"missing.json"
	root.add_child(g);g.set_process(false);g.audio_enabled=false;g.background_paused=false
	g.state.intro_seen=true
	for m in g.MEMBERS:
		g.state.active_mission=m.id;g.state.chapter_steps[m.id]=2;g.state.page_complete=true;g.state.record_chapter_step(m.id,2)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g._action("growth_open");g._action("close");g._setup_map()
	g.state.library_day.ensure(g.state.day);g.state.minutes=600;g.state.operating.begin(g.state)

func snap(name: String) -> void:
	g.toast_time=0;g.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	var outside: Array=[]
	for b in g.buttons:
		if not Rect2(0,0,1280,800).encloses(b.rect): outside.append(b.id)
	panels.append({"name":name,"mode":g.mode,"size":[root.size.x,root.size.y],"button_count":g.buttons.size(),"overflow":g.label_issues.duplicate(true),"outside":outside})
	check(outside.is_empty(),"all buttons on screen: "+name)
	root.get_texture().get_image().save_png(DEST+"ui_"+name+".png")

func run() -> void:
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=size;fresh()
		var suffix: String="_%d"%size.x
		await snap("first_day"+suffix)
		for id in ["world_notebook","help","growth_ops","growth_rest","growth_ledger","promotion","world_upgrades","world_furniture_shop","world_costume_shop","fan_forms","life_open","growth_archive","journal"]:
			g.mode="play";g._action(id);await snap(id+suffix)
		g.mode="play";g.world.change_area(g,true);await snap("private_spaces"+suffix)
		g.world.change_area(g,false);g.growth.reward("late_audit",500,250)
		g.state.library_day.returned.assign([0,0,0,1,1,1]);g.state.library_day.dirty.assign([0,1]);g.state.library_day.grime.fill(3)
		for i in range(6):
			var npc: Dictionary=g._find_object(g.MEMBERS[i].id)
			npc.in_studio=false;npc.pos=[Vector2(552,352),Vector2(824,480),Vector2(312,592),Vector2(880,216),Vector2(1152,544),Vector2(1120,688)][i]
			npc.yard_action="idle";npc.facing="down"
		g.player_pos=Vector2(560,648);g.library_day_flow.sync_targets(g)
		await snap("crowded_dirty"+suffix)
		g.mode="play";g._action("world_costume_shop");await snap("late_costumes"+suffix)
		g.mode="play";g._action("world_furniture_shop");await snap("late_furniture"+suffix)
	var f:=FileAccess.open(DEST+"ui_layout.json",FileAccess.WRITE);f.store_string(JSON.stringify(panels,"\t"));f.close()
	print("COMPLETENESS UI: ",count," checks; failures=",failures,"; panels=",panels.size())
	g.free();quit(1 if failures else 0)
