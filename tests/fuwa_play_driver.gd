extends RefCounted

static func key(g,code: int,pressed: bool=true) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=pressed;g._unhandled_input(e)
static func step(g,seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		g.background_paused=false;g._process(1.0/60)
static func click(g,point: Vector2) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	e.position=g.fuwa_book.screen_world(point);g._unhandled_input(e)
static func walk(g,point: Vector2) -> bool:
	click(g,point)
	for i in range(1800):
		step(g,1.0/60)
		if g.fuwa_book.route.is_empty(): break
	return g.fuwa_book.player_pos.distance_to(point)<8
static func find_tenbi(g) -> bool:
	for point in [Vector2(325,448),Vector2(390,425),Vector2(470,384),Vector2(540,350),Vector2(590,288),Vector2(615,205)]:
		var reached:=walk(g,point)
		if not reached and g.fuwa_book.zone==0: return false
		if point==Vector2(390,425): step(g,3)
	if g.fuwa_book.zone!=1: return false
	for point in [Vector2(330,450),Vector2(420,460),Vector2(620,465),Vector2(700,370)]:
		if not walk(g,point): return false
	for i in range(500):
		if g.fuwa_book.wind_strength()<=.3: break
		step(g,.05)
	key(g,KEY_E);step(g,.2);key(g,KEY_E,false)
	click(g,g.fuwa_book.tenbi-Vector2(0,28))
	for i in range(1800):
		step(g,1.0/60)
		if g.fuwa_book.phase=="return_ready": return true
	return false
