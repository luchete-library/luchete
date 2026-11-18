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

func run() -> void:
	var g := TestGame.new()
	root.add_child(g)
	g.set_process(false)
	g.audio_enabled=false
	g.state=g.State.new()
	g.state.residents=["yato","danming","kubby","yune","dori","fuwa"]
	g.mode="play"
	g._setup_map()
	var sprites = g.StellaInteractions
	var defaults: Dictionary={"yato":"yato_hood","danming":"danming_origin","kubby":"kubby_origin","yune":"amiha_yune_idle"}
	for id in defaults: check(g._costume_key(id)==defaults[id],"new default costume: "+id)
	check(g.Wardrobe.COSTUMES.yune.keys()==["amiha_yune_idle"],"Yune's wardrobe only offers her veiled dress")
	var legacy: Dictionary=g.state.to_data().duplicate(true)
	legacy.costumes={"yune":"yune_unveiled","yato":"yato_track"}
	var restored=g.State.new()
	check(restored.apply_data(legacy) and restored.costumes.yune==defaults.yune and restored.costumes.yato=="yato_track","retired dress loads as the veil; chosen outfits survive")
	var before: Dictionary = g.state.to_data().duplicate(true)
	for id in g.state.residents:
		var data: Dictionary = sprites.DATA[id].data
		check(sprites.supports(g,id),"default costume supports authored sprites: "+id)
		check(data.actions.size()==8 and sprites.click_actions(id).size()==4,"four personal reactions and four furniture actions: "+id)
		var equipped: String=g._costume_key(id)
		var atlas: Image = sprites.sheet_for(id,equipped).get_image()
		check(atlas.get_size()==Vector2i(3936,896),"complete eight-row atlas: "+id)
		var idle_row: int = g.Field.COSTUMES.find(equipped)
		var neutral: Image = g.Field.IDLE.get_image().get_region(Rect2i(0,idle_row*112,96,112))
		for action in data.actions:
			var unique := {}
			for col in range(5):
				var cel := atlas.get_region(Rect2i((col+1)*8*96,int(action.row)*112,96,112))
				var bounds := cel.get_used_rect()
				check(bounds.has_area() and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<96 and bounds.end.y==104,"pose fits common frame and floor: %s/%s/%d" % [id,action.id,col])
				unique[hash(cel.get_data())]=true
				if col==4: check(cel.get_data()==neutral.get_data(),"identical original idle return: "+id+"/"+action.id)
			check(unique.size()>=3,"action has distinct whole poses: "+id+"/"+action.id)
			if action.kind=="social":
				var elapsed := 0.0
				check(action.travel_seconds.size()==5,"five timed reaches: "+id+"/"+action.id)
				for col in range(5):
					var travel: float=action.travel_seconds[col]
					check(travel>0 and travel<=float(action.durations[col]),"travel fits pose duration: "+id+"/"+action.id)
					check(sprites.Samples.gesture(action.durations,elapsed+.001,action.travel_seconds)==col*8,"preparation to recovery timing: "+id+"/"+action.id)
					check(sprites.Samples.gesture(action.durations,elapsed+travel,action.travel_seconds)==(col+1)*8,"reach ends on key: "+id+"/"+action.id)
					elapsed+=float(action.durations[col])
				check(sprites.Samples.gesture(action.durations,elapsed+.001,action.travel_seconds)==40,"ended action rests without looping")
		var previous := ""
		for i in range(12):
			g.character_touch.react(g,id)
			check(g.character_touch.reactions[id].authored and g.character_touch.reactions[id].id!=previous,"random click uses personal art with no immediate repeat: "+id)
			previous=g.character_touch.reactions[id].id
			g.character_touch.update(g,4.0)
			g.character_touch.update(g,1.0)
		for costume in g.Wardrobe.COSTUMES[id]:
			g.state.costumes[id]=costume
			check(sprites.supports(g,id),"personal interactions in equipped costume: "+costume)
			var dressed: Image = sprites.sheet_for(id,costume).get_image()
			var rest: Image = g.Field.IDLE.get_image().get_region(Rect2i(0,g.Field.COSTUMES.find(costume)*112,96,112))
			for action in data.actions:
				check(dressed.get_region(Rect2i(40*96,int(action.row)*112,96,112)).get_data()==rest.get_data(),"gesture returns to equipped lobby sprite: "+costume+"/"+action.id)
		g.state.costumes.erase(id)
	check(before==g.state.to_data(),"art and transient reactions preserve saved state")
	var startled: Dictionary=sprites.definition("kubby","startled")
	var listen: Dictionary=sprites.definition("yune","listen")
	check(sprites.Samples.gesture(startled.durations,.45,startled.travel_seconds)==24,"Kubby shows and holds the full flinch within half a second")
	check(sprites.Samples.gesture(startled.durations,1.20,startled.travel_seconds)==32,"Kubby settles into visible relief before returning")
	check(sprites.Samples.gesture(listen.durations,.45,listen.travel_seconds)<16,"Yune is still easing into the head tilt")
	check(sprites.Samples.gesture(listen.durations,1.12,listen.travel_seconds)==24,"Yune holds her listening pose")
	g.character_touch.react(g,"yato")
	g.state.costumes.yato="yato_idle"
	g.character_touch.update(g,.01)
	check(not g.character_touch.reactions.has("yato"),"changing outfit during a reaction clears the old costume pose")
	for act in ["read","tea","yoga","stream"]:
		check(sprites.Samples.furniture(act,.23,8.0) in range(1,8),"furniture prepares first: "+act)
		check(sprites.Samples.furniture(act,.7,8.0) in range(9,16),"furniture enters its pose: "+act)
		check(sprites.Samples.furniture(act,7.3,8.0) in range(25,32),"furniture recovers before departing: "+act)
		check(sprites.Samples.furniture(act,8.0,8.0)==40,"furniture returns to standing: "+act)
	for t in [1.35,2.0,3.0,4.0,5.0,6.0]:
		check(sprites.Samples.furniture("yoga",t,8.0)==24,"yoga holds its seated pose instead of repeated squats")
	g.free()
	print("Stella interaction checks: ",checks,"; failures: ",failures,". Player save untouched.")
	quit(1 if failures else 0)
