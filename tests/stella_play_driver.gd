extends RefCounted

# Only production input and time stepping; no checkpoint injection or stage jumps.
static func key(g,code: int,pressed: bool=true) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=pressed;g._unhandled_input(e)
static func press(g,code: int=KEY_E) -> void: key(g,code);key(g,code,false)
static func step(g,seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		g.background_paused=false;g._process(1.0/60)
static func click(g,p: Vector2) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=g.stella_book.screen_world(p);g._unhandled_input(e)
static func walk(g,p: Vector2) -> bool:
	var book=g.stella_book;var stage: int=book.stage
	click(g,p)
	for i in range(1800):
		step(g,1.0/60)
		if book.stage!=stage or not book.action.is_empty(): return true
		if book.route.is_empty(): break
	return book.player_pos.distance_to(p)<60
static func play_stage(g) -> bool:
	var b=g.stella_book;var initial: int=b.stage
	if b.intro: press(g)
	match b.kind():
		"ending","carry","punishment": step(g,6.5)
		"called": press(g)
		"disguise": walk(g,b.target(0));press(g);step(g,2)
		"watch":
			for i in range(2):
				if b.has_mark(i): continue
				if b.stone: press(g)
				walk(g,b.target(i))
				if not b.stone: press(g)
				step(g,2.7);press(g)
			step(g,.1)
		"sleep":
			walk(g,b.target(0))
			if not b.stone: press(g)
			step(g,3)
		"dreams":
			for i in range(3):
				if b.stage!=initial: break
				walk(g,b.target(i));key(g,KEY_E);step(g,2.1);key(g,KEY_E,false)
		"arrows","weary":
			walk(g,b.target(0));key(g,KEY_E);step(g,5.4);key(g,KEY_E,false)
			if b.stage==initial and b.kind()=="weary": walk(g,b.target(1));step(g,.1)
		"follow","nightwalk","mountain":
			for i in range(3): walk(g,b.target(i));step(g,.1)
		"hamster": walk(g,b.target(0));step(g,2)
		"takehome": walk(g,b.target(0));press(g);walk(g,b.target(1));step(g,.1)
		"food": walk(g,b.target(0));press(g);step(g,2);walk(g,b.target(1));press(g);step(g,3.5)
		"cold":
			for i in range(2): walk(g,b.target(i));press(g);step(g,.1)
			step(g,3.2)
		"light": walk(g,b.target(0));key(g,KEY_E);step(g,3.5);key(g,KEY_E,false)
		_: walk(g,b.target(0));press(g);step(g,2.0 if b.kind()!="deduce" else 3.5)
	return b.stage!=initial or b.phase=="arrived"
static func complete(g) -> bool:
	for i in range(12):
		if g.stella_book.phase=="arrived": return true
		if not play_stage(g): return false
	return false
