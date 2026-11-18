extends SceneTree

const Motion = preload("res://scripts/fan_motion.gd")
const Game = preload("res://scripts/main.gd")
const Forms = preload("res://scripts/fan_forms.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for id in ["yato","danming","kubby","yune","dori","fuwa"]:
		var m = Motion.new()
		m.advance(id,"library",0.016,0.0,false)
		check(m.phase=="idle",id+" begins idle")
		m.advance(id,"library",0.016,2.0,false)
		check(m.phase=="start" and m.frame_for(id) in [24,25],id+" anticipation")
		for tick in range(10): m.advance(id,"library",0.016,2.0,false)
		check(m.phase=="walk" and m.frame_for(id) in PackedInt32Array(Forms.DATA.data.animations.walk),id+" walking")
		m.advance(id,"library",0.016,3.84,true)
		check(m.phase=="run" and m.frame_for(id) in PackedInt32Array(Forms.DATA.data.animations.run),id+" running")
		var travelled: float = m.distance
		m.advance(id,"library",0.016,0.0,true)
		check(m.phase=="stop" and m.frame_for(id)==26,id+" blocked motion stops")
		m.advance(id,"library",0.09,0.0,false)
		check(m.frame_for(id)==27,id+" settles")
		m.advance(id,"library",0.09,0.0,false)
		check(m.phase=="idle" and is_equal_approx(m.distance,travelled),id+" idle does not advance feet")
		m.advance(id,"garden",0.016,0.0,false)
		check(m.phase=="idle" and m.distance==0.0,id+" teleport resets travel")
		for tick in range(10): m.advance(id,"garden",0.016,2.0,false)
		m.advance(id,"garden",0.016,0.0,false,false)
		check(m.phase=="idle",id+" menus stop locomotion")
		var valid := true
		for tick in range(120):
			m.advance(id,"garden",0.1,0.0,false)
			valid = valid and m.frame_for(id)>=0 and m.frame_for(id)<28
		check(valid,id+" idle and blink stay inside atlas")
		for direction in {"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP}:
			var vector: Vector2 = {"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP}[direction]
			m.advance(id,"garden",0.001,0.17,false,true,vector*0.17)
			check(m.facing_for(id)==direction,id+" faces "+direction+" at small frame deltas")
			m.advance(id,"garden",0.05,0.0,false,true,Vector2.ZERO)
			m.advance(id,"garden",0.3,0.0,false,true,Vector2.ZERO)
			check(m.phase=="idle" and m.facing_for(id)==direction,id+" keeps "+direction+" after stopping")
			var region: Rect2 = Forms.region_for(m.frame_for(id),m.facing_for(id))
			check(region.position.y==["down","left","right","up"].find(direction)*64,id+" selects "+direction+" atlas row")
		m.advance(id,"garden",0.01,1.0,false,true,Vector2.RIGHT)
		m.advance(id,"garden",0.01,1.0,false,true,Vector2(1,1.05))
		check(m.direction=="right",id+" diagonal jitter keeps previous axis")
		m.advance(id,"garden",0.01,1.0,false,true,Vector2(1,-2))
		check(m.direction=="up",id+" decisive vertical move turns up")
		m.advance(id,"garden",0.01,0.0,false,true,Vector2.DOWN)
		check(m.direction=="up",id+" blocked input cannot turn the fan")
		m.advance(id,"garden",0.01,2.0,false,false,Vector2.LEFT)
		check(m.direction=="up",id+" menu cannot change facing")
		m.advance(id,"book:"+id,0.01,0.0,false)
		check(m.direction=="down",id+" book entry resets facing")
	for id in ["yato","yune","dori","fuwa"]:
		var a = Motion.new()
		var b = Motion.new()
		for tick in range(60): a.advance(id,"library",1.0/60.0,170.0/60.0,false)
		for tick in range(30): b.advance(id,"library",1.0/30.0,170.0/30.0,false)
		check(is_equal_approx(a.cycle,b.cycle),id+" gait independent of frame rate")
	# A real mouse route against a fully blocked map must leave the fan planted.
	var g = Game.new()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.mode="chapter"
	g.story_member=0
	g.chapter_question=false
	g.player_pos=Vector2(400,400)
	g.obstacles.clear()
	g.obstacles.append(Rect2(0,0,2000,2000))
	g.state.fan_form="yato"
	g.route=PackedVector2Array([g.player_pos+Vector2(90,0)])
	g._process(0.016)
	check(not g.moving and g.player_pos==Vector2(400,400),"blocked input does not set moving")
	check(g.fan_motion.phase=="idle","blocked input keeps the fan planted")
	g.obstacles.clear()
	g._process(0.016)
	check(g.moving and g.fan_motion.phase=="start","real free movement begins anticipation")
	for tick in range(12): g._process(0.016)
	check(g.fan_motion.phase=="walk","real input reaches walking")
	g.route=PackedVector2Array([g.player_pos+Vector2(90,0)])
	g._process(0.016)
	check(g.moving and g.fan_motion.phase=="walk","mouse route uses the same gait")
	g.route.clear()
	g._process(0.016)
	check(g.fan_motion.phase=="stop","route completion settles feet")
	for entry in [[Vector2.LEFT,"left"],[Vector2.UP,"up"],[Vector2.RIGHT,"right"],[Vector2.DOWN,"down"]]:
		g.player_pos=Vector2(400,400)
		g.route=PackedVector2Array([g.player_pos+entry[0]*90])
		g._process(0.016)
		check(g.fan_motion.direction==entry[1],"actual book mouse route faces "+entry[1])
	g.player_pos=Vector2(400,400)
	g.obstacles.append(Rect2(414,350,40,100))
	g.route=PackedVector2Array([g.player_pos+Vector2(90,90)])
	g._process(0.04)
	check(g.player_pos.x==400 and g.player_pos.y>400,"diagonal route slides along blocked x axis")
	check(g.fan_motion.direction=="down","wall sliding faces the resolved direction")
	g.obstacles.clear()
	g.mode="play"
	g.state.scene="library"
	g.state.yard_session={}
	g.route=PackedVector2Array([g.player_pos+Vector2(0,-90)])
	g._process(0.016)
	check(g.fan_motion.member=="yato" and g.fan_motion.direction=="up","library form uses directional movement")
	g.queue_free()
	await process_frame
	print("FAN MOTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
