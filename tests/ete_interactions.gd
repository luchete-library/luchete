extends SceneTree

class TestGame:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func key(g, code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	g._unhandled_input(event)

func stroke(g, side: float, outside: bool = false) -> bool:
	var event := InputEventMouseMotion.new()
	event.position=g.WORLD_OFFSET+(g.Field.head_hit_rect("aethe",g.AETHE_POS).get_center()+Vector2(side*9+(100 if outside else 0),0))*g.WORLD_SCALE
	event.relative=Vector2(side*18*g.WORLD_SCALE,0)
	return g.ete_interactions.pointer_motion(g,event)

func run() -> void:
	var g := TestGame.new()
	root.add_child(g)
	g.set_process(false)
	g.audio_enabled=false
	g.state=g.State.new()
	g.mode="play"
	g.player_pos=g.AETHE_POS+Vector2(0,75)
	g._setup_map()
	var interaction = g.ete_interactions
	var atlas: Image = interaction.SHEET.get_image()
	check(atlas.get_size()==Vector2i(3936,1344),"twelve five-stage interaction rows")
	check(interaction.MANIFEST.data.actions.size()==12,"all twelve interactions have timing and descriptions")
	key(g,KEY_R)
	check(g.mode=="play","R no longer opens a reaction selection panel")
	check(not interaction.start(g,"unknown"),"invalid action is ignored")
	check(not interaction.start(g,"recognize"),"fan recognition requires an equipped fan form")
	g.state.residents=["dori"]
	g.state.chapter_steps.dori=3
	g.state.fan_form="dori"
	var before: Dictionary = g.state.to_data().duplicate(true)
	var neutral: Image = g.Field.DIRECTIONAL.aethe.get_image().get_region(Rect2i(0,0,96,112))
	for item in interaction.MANIFEST.data.actions:
		check(interaction.start(g,item.id),"start "+item.id)
		check(g.ete_facing=="down" and interaction.phase()==0,"interaction begins with the prepared pose")
		check(not interaction.start(g,"pet"),"another click cannot restart a busy animation")
		for column in range(5):
			var cel := atlas.get_region(Rect2i((column+1)*8*96,int(item.row)*112,96,112))
			var bounds := cel.get_used_rect()
			check(bounds.has_area() and bounds.end.y==104 and bounds.size.y<=90 and bounds.position.x>0 and bounds.end.x<96,"whole pose fits native frame: %s/%d" % [item.id,column])
			check(interaction.phase()==column,"ordered preparation / gesture / response / recovery / idle")
			interaction.update(g,float(item.durations[column])-.001)
			check(interaction.phase()==column,"hold lasts for its authored duration")
			interaction.update(g,.00101)
		check(interaction.active=="","one-shot action ends: "+item.id)
		check(neutral.get_data()==atlas.get_region(Rect2i(5*interaction.SAMPLES.STEPS*96,int(item.row)*112,96,112)).get_data(),"returns to identical neutral pixels: "+item.id)
	check(before==g.state.to_data(),"visual interactions do not change inventory, friendship, day or story progress")
	interaction.start(g,"pet")
	interaction.update(g,.9)
	var held: float = interaction.elapsed
	g.mode="pause"
	interaction.update(g,20.0)
	check(interaction.elapsed==held,"pause freezes reaction rather than skipping it")
	g.mode="play"
	check(interaction.active=="pet","returning from pause preserves current gesture")
	interaction.update(g,10.0)
	check(interaction.active=="","large frame delta cannot leave a stuck action")
	interaction.start(g,"read")
	g.player_pos=g.AETHE_POS+Vector2(220,0)
	interaction.update(g,.01)
	check(interaction.phase()==3,"walking away begins recovery")
	interaction.update(g,2.0)
	check(interaction.active=="" and not interaction.start(g,"pet"),"distant player cannot start interaction")
	g.player_pos=g.AETHE_POS+Vector2(0,75)
	interaction.reset()
	g.ui_regions.clear()
	check(not stroke(g,1),"one pass across head is not a pet")
	check(not stroke(g,-1,true),"leaving head resets gesture")
	check(interaction.stroke_turns==0,"outside-head movements do not accumulate")
	var triggered := false
	for side in [1,-1,1,-1]: triggered=stroke(g,side) or triggered
	check(triggered and interaction.active=="pet","deliberate back-and-forth cursor strokes start petting")
	interaction.update(g,10.0)
	for side in [1,-1,1,-1]: stroke(g,side)
	check(interaction.active=="","cooldown prevents repeated reactions from one long stroke")
	interaction.update(g,1.1)
	for side in [1,-1,1,-1]: stroke(g,side)
	check(interaction.active=="pet","fresh strokes work after cooldown")
	g.state.scene="garden"
	interaction.update(g,.1)
	check(interaction.active=="","scene change clears reaction")
	g.state.scene="library"
	g.mode="play"
	g._setup_map()
	interaction.start(g,"greet")
	g._interact(g._find_object("ete"))
	check(g.mode=="missions" and interaction.active=="","original Ete mission interaction remains available")
	g.mode="fan_forms"
	g._change_form("dori")
	check(g.mode=="play" and interaction.active=="transform","real fan-form change uses bookmark gesture")
	g._setup_map()
	check(interaction.active=="","map reset never retains stale activity")
	g.queue_free()
	await process_frame
	print("Ete interaction checks: ",checks,"; failures: ",failures,". Player save untouched.")
	quit(1 if failures else 0)
