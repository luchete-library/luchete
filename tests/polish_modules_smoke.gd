extends SceneTree
const Furniture = preload("res://scripts/garden_furniture.gd")
const Decor = preload("res://scripts/library_growth_decor.gd")
const Transition = preload("res://scripts/reconstruction_transition.gd")
const Game = preload("res://scripts/growth_game.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	for mask in range(16):
		var layout: Array=[]
		for i in range(4):
			if mask&(1<<i): layout.append({"kind":Furniture.ORDER[i],"x":Furniture.DEFAULTS[i].x,"y":Furniture.DEFAULTS[i].y,"enabled":true})
		var nav := Furniture.navigation(layout)
		for p in [Decor.EXHIBIT_POINT,Decor.RECORD_POINT]:
			var cell := Furniture.nearby_cell(nav,p)
			var entrance := Furniture.nearby_cell(nav,Furniture.ENTRANCE)
			check(cell.x>=0,"growth stop is walkable in layout %d"%mask)
			check(not nav.get_point_path(entrance,cell).is_empty(),"growth stop reachable from entrance in layout %d"%mask)
	var g=Game.new()
	g.persist=false
	g.save_path="res://artifacts/polish_20261118/no_user_save.json"
	g.legacy_save_path="res://artifacts/polish_20261118/no_legacy_save.json"
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g._new_game()
	while g.mode=="dialog": g._action("next")
	for member in g.MEMBERS:
		g.state.residents.append(member.id)
		g.state.chapter_steps[member.id]=3
	g.growth.begin_rebuild(6)
	g._setup_map()
	g.state.fan_form="dori"
	for task in ["corridor","shelves","reading"]:
		var transition := Transition.new()
		transition.begin(g,task)
		var time := 0.0
		while transition.phase=="approach" and time<30:
			transition.advance(g,.025); time+=.025
		check(transition.phase=="work",task+" reached its real work feet")
		check(not transition.actors.any(func(actor):return actor.fallback),task+" has connected approach paths")
		var work_time := time
		transition.begin_return(g)
		while transition.phase in ["return","return_fade"] and time<60:
			transition.advance(g,.025); time+=.025
		check(transition.phase=="done",task+" returned to original positions")
		check(not transition.fallback,task+" has connected return paths")
		check(g.state.fan_form=="dori","reconstruction never changes selected fan form")
		print("TRANSITION ",task,": approach=",snappedf(work_time,.01)," return=",snappedf(time-work_time,.01))
	print("POLISH MODULES: ",checks," checks, ",failures," failures. 16 furniture layouts, three reconstruction paths, no player saves.")
	quit(1 if failures else 0)
