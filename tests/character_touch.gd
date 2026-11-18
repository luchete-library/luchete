extends SceneTree

class TestGame:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

var checks := 0
var failures := 0
var g: Node2D
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func prepare() -> void:
	g.state=g.State.new()
	g.state.residents=["yato","danming","kubby","yune","dori","fuwa"]
	g.state.fan_form="yune"
	for i in range(g.Furniture.ORDER.size()):
		g.state.place_furniture(g.Furniture.ORDER[i],g.Furniture.DEFAULTS[i])
	g.mode="play"
	g.player_pos=Vector2(490,620)
	g._setup_map()
	g.ui_regions.clear()
	g.buttons.clear()
	for a in g.garden_residents.agents.values(): a.timer=1000.0

func mouse(screen: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position=screen
	e.button_index=button
	e.pressed=pressed
	g._unhandled_input(e)

func motion(screen: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position=screen
	e.relative=screen-g.character_touch.pointer_screen
	g._unhandled_input(e)

func screen(p: Vector2) -> Vector2: return g.WORLD_OFFSET+p*g.WORLD_SCALE

func grab(id: String) -> void:
	mouse(screen(g._find_object(id).pos+Vector2(0,-44)),true)

func drop_at(p: Vector2) -> void:
	motion(screen(p))
	mouse(screen(p),false)

func click(id: String) -> void:
	var p: Vector2 = screen(g._find_object(id).pos+Vector2(0,-44))
	mouse(p,true)
	mouse(p+Vector2(2,0),false)

func tick(seconds: float) -> void:
	for i in range(ceili(seconds*60)): g._process(1.0/60.0)

func run() -> void:
	g=TestGame.new()
	root.add_child(g)
	g.set_process(false)
	g.audio_enabled=false
	prepare()
	var touch = g.character_touch
	var before: Dictionary = g.state.to_data().duplicate(true)
	var last := ""
	var seen := {}
	for i in range(25):
		click("ete")
		check(g.ete_interactions.active!="" and g.mode=="play","release click reacts without opening a menu")
		check(g.ete_interactions.active!=last,"Ete avoids immediate random repeats")
		last=g.ete_interactions.active
		seen[last]=true
		g.ete_interactions.update(g,10.0)
		click("ete")
		check(g.ete_interactions.active=="","cooldown blocks click spam")
		g.ete_interactions.update(g,1.1)
	check(seen.size()>1,"random choices produce different reactions")
	check(g.state.to_data()==before,"clicks do not grant affinity or alter progress")
	for id in g.state.residents:
		click(id)
		check(touch.reactions.has(id),"every unlocked Stella supports direct clicking: "+id)
		var previous: String = touch.reactions[id].id
		touch.update(g,4.0)
		touch.update(g,1.0)
		click(id)
		check(touch.reactions[id].id!=previous,"Stella click reaction avoids immediate repeat: "+id)
		touch.update(g,4.0)
	prepare()
	var original: Vector2 = g._find_object("ete").pos
	grab("ete")
	check(touch.held=="ete" and not touch.dragging and g.ete_interactions.active=="","press alone neither reacts nor walks player")
	var p: Vector2 = screen(g.Furniture.DEFAULTS[1])
	motion(p)
	check(touch.dragging and touch.target(g).kind=="tea","drag threshold selects furniture under pointer")
	check(g._find_object("ete").pos==original,"drag preview does not mutate original position")
	check(g.ete_interactions.active=="","dragging does not trigger click or pet reaction")
	mouse(p,false)
	check(touch.held=="" and not touch.dragging,"release ends pointer capture")
	check(g.ete_interactions.active=="tea" and g.garden_residents.reservations.tea=="ete","tea drop starts matching action and reserves furniture")
	check(g._find_object("ete").pos==g.Furniture.DEFAULTS[1]+Vector2(0,40),"standing Ete uses the safe space beside the furniture")
	var tea_pos: Vector2 = g._find_object("ete").pos
	grab("ete")
	motion(screen(Vector2(16,16)))
	tick(1.0)
	check(g.ete_interactions.elapsed==0.0,"held actor and action freeze during drag")
	mouse(screen(Vector2(16,16)),false)
	check(g._find_object("ete").pos==tea_pos and g.garden_residents.reservations.tea=="ete","invalid drop restores occupied furniture and the previous action")
	tick(12.0)
	check(touch.ete_visit.is_empty() and g._find_object("ete").pos.distance_to(original)<1,"Ete completes gesture and walks back")
	check(not g.garden_residents.reservations.has("tea"),"Ete releases furniture for other residents")
	for i in range(4):
		prepare()
		var kind: String = g.Furniture.ORDER[i]
		grab("ete")
		drop_at(g.Furniture.DEFAULTS[i])
		check(g.ete_interactions.active==touch.ETE_ACTIONS[kind],"contextual Ete action: "+kind)
		prepare()
		grab("yato")
		drop_at(g.Furniture.DEFAULTS[i])
		check(g.garden_residents.agents.yato.phase=="use" and g._find_object("yato").yard_action==g.Furniture.ITEMS[kind].action,"Stella drop starts matching furniture animation: "+kind)
		check(g.garden_residents.reservations[kind]=="yato","manual use and autonomous use share reservations")
		var source: Vector2 = g._find_object("ete").pos
		grab("ete")
		drop_at(g.Furniture.DEFAULTS[i])
		check(g._find_object("ete").pos==source and g.ete_interactions.active=="","occupied destination rejects another character")
		grab("yato")
		drop_at(Vector2(400,560)-Vector2(0,44))
		check(g._find_object("yato").pos.is_equal_approx(Vector2(400,560)) and not g.garden_residents.reservations.has(kind),"dragging out of furniture releases the slot: "+str(g._find_object("yato").pos)+" / "+g.toast)
	prepare()
	grab("ete")
	motion(screen(Vector2(400,520)))
	var esc := InputEventKey.new()
	esc.physical_keycode=KEY_ESCAPE
	esc.pressed=true
	g._unhandled_input(esc)
	check(touch.held=="" and g.mode=="play" and g._find_object("ete").pos==original,"Escape cancels without moving or opening pause")
	grab("ete")
	motion(screen(Vector2(400,520)))
	mouse(screen(Vector2(400,520)),true,MOUSE_BUTTON_RIGHT)
	check(touch.held=="" and g._find_object("ete").pos==original,"right click cancels drag")
	grab("ete")
	g._notification(g.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(touch.held=="","losing window focus releases capture")
	grab("ete")
	g.ui_regions.append(Rect2(700,300,120,120))
	drop_at(g.Furniture.DEFAULTS[3])
	# A real HUD region must reject a drop even over usable floor.
	prepare()
	grab("ete")
	g.ui_regions.append(Rect2(500,400,300,200))
	drop_at(Vector2(450,500))
	check(g._find_object("ete").pos==original,"dropping on UI leaves character in place")
	prepare()
	g.state.toggle_furniture("tea")
	grab("ete")
	drop_at(g.Furniture.DEFAULTS[1])
	check(g.ete_interactions.active=="" and g._find_object("ete").pos==original,"disabled furniture cannot be forced")
	g.state.yard_host="yato"
	grab("yato")
	check(touch.held=="","assigned broadcast cannot be accidentally interrupted")
	grab("ete")
	drop_at(g.Furniture.DEFAULTS[3])
	check(g._find_object("ete").pos==original,"assigned broadcast reserves its station")
	prepare()
	grab("ete")
	mouse(screen(Vector2(400,560)-Vector2(0,44)),false)
	check(g._find_object("ete").pos.is_equal_approx(Vector2(400,560)) and g.ete_interactions.active=="","coalesced drag release moves without a preceding motion event: "+str(g._find_object("ete").pos)+" / "+g.toast)
	g.player_pos=Vector2(400,620)
	check(g.ete_interactions.nearby(g),"mission proximity follows relocated Ete")
	g._interact(g._find_object("ete"))
	check(g.mode=="missions","E missions work at relocated position")
	prepare()
	before=g.state.to_data().duplicate(true)
	grab("yune")
	drop_at(g.Furniture.DEFAULTS[2])
	tick(18.0)
	check(g.state.to_data()==before,"manual furniture use adds no inventory, story or daily activity rewards")
	check(not g.garden_residents.reservations.has("mat"),"manual activity finishes and releases its station")
	grab("ete")
	g._setup_map()
	check(touch.held=="" and touch.ete_visit.is_empty(),"scene rebuild clears pointer state")
	g.free()
	print("Character touch checks: ",checks,"; failures: ",failures,". Player save untouched.")
	quit(1 if failures else 0)
