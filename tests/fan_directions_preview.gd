extends SceneTree

const Motion = preload("res://scripts/fan_motion.gd")
const IDS = ["yato","danming","kubby","yune","dori","fuwa"]

class Preview:
	extends "res://scripts/main.gd"
	var samples := []
	var floor_offset := Vector2.ZERO
	var caption := ""
	func _save() -> void: pass
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,620),Color("293d39"))
		_text(Vector2(26,42),"팬 캐릭터 4방향 이동 · "+caption,26,Color("fff1ce"))
		for i in range(6):
			var origin := Vector2(24+420*(i%3),76+258*(i/3))
			draw_rect(Rect2(origin,Vector2(400,238)),Color("465a51"))
			for row in range(4):
				for col in range(8):
					var p := origin+Vector2(fposmod(col*48.0-floor_offset.x,384.0)+8,fposmod(row*40.0-floor_offset.y,160.0)+56)
					draw_line(p,p+Vector2(6,0),Color("5e7362"))
			_text(origin+Vector2(16,32),["마토","버리","햄님","몽치","돌돌이","텐비"][i],23,Color("fff1ce"))
			if samples.size() != 6: continue
			fan_motion=samples[i]
			FanForms.draw(self,["yato","danming","kubby","yune","dori","fuwa"][i],origin+Vector2(200,200),moving,0.0,Vector2(2,2))
		_text(Vector2(26,610),"각 방향: 출발 → 걷기 → 달리기 → 멈춤 · 정면 기본 그림 유지 · 실제 게임 렌더러",17,Color("d1d1bc"))

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,620)
	root.content_scale_size=Vector2i(1280,620)
	var g=Preview.new()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.mode="play"
	g.audio_enabled=false
	for id in IDS:
		var m=Motion.new()
		m.advance(id,"preview",0,0,false)
		g.samples.append(m)
	DirAccess.make_dir_recursive_absolute("res://artifacts/fan_direction_capture")
	for tick in range(160):
		var segment := tick/40
		var beat := tick%40
		var run_fast := beat>=24 and beat<32
		var speed := 240.0 if run_fast else 170.0 if beat<32 else 0.0
		var vector: Vector2 = [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][segment]
		g.caption=["앞 / 아래","왼쪽","오른쪽","뒤 / 위"][segment]+(" · 달리기" if run_fast else " · 걷기" if speed>0 else " · 멈춤")
		g.moving=speed>0
		g.clock=tick*0.06
		g.floor_offset+=vector*speed*0.06
		for i in range(6): g.samples[i].advance(IDS[i],"preview",0.06,speed*0.06,run_fast,true,vector*speed*0.06)
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/fan_direction_capture/%03d.png" % tick)
	print("FAN DIRECTIONS PREVIEW: 160 renderer frames captured; player save untouched.")
	quit()
