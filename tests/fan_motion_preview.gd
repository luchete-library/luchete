extends SceneTree

const Motion = preload("res://scripts/fan_motion.gd")
const IDS = ["yato","danming","kubby","yune","dori","fuwa"]

class Preview:
	extends "res://scripts/main.gd"
	var samples := []
	var sample_x := 0.0
	var caption := ""
	func _save() -> void: pass
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,620),Color("293d39"))
		_text(Vector2(26,42),"팬 캐릭터 모션 · "+caption,26,Color("fff1ce"))
		for i in range(6):
			var origin := Vector2(24+420*(i%3),76+258*(i/3))
			draw_rect(Rect2(origin,Vector2(400,238)),Color("465a51"))
			_text(origin+Vector2(16,32),["마토","버리","햄님","몽치","돌돌이","텐비"][i],23,Color("fff1ce"))
			for mark in range(9):
				var px: float = origin.x+fposmod(mark*48.0-sample_x,396.0)
				draw_line(Vector2(px,origin.y+202),Vector2(px+12,origin.y+202),Color("7d8e7c"))
			if samples.size() != 6: continue
			fan_motion=samples[i]
			FanForms.draw(self,["yato","danming","kubby","yune","dori","fuwa"][i],origin+Vector2(200,200),moving,0.0,Vector2(2,2))
		_text(Vector2(26,610),"대기 → 걷기 → 달리기 → 정지 → 왼쪽 이동 · 실제 게임 렌더러",17,Color("d1d1bc"))

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
	DirAccess.make_dir_recursive_absolute("res://artifacts/fan_motion_capture")
	for tick in range(140):
		var walk: bool = (tick>=20 and tick<60) or tick>=115
		var run_fast: bool = tick>=60 and tick<95
		var speed := 240.0 if run_fast else 170.0 if walk else 0.0
		g.caption="달리기" if run_fast else "왼쪽 걷기" if tick>=115 else "걷기" if walk else "정지 · 대기" if tick>=95 else "대기"
		g.facing=-1 if tick>=115 else 1
		g.moving=speed>0
		g.clock=tick*0.05
		g.sample_x += speed*0.05*g.facing
		for i in range(6): g.samples[i].advance(IDS[i],"preview",0.05,speed*0.05,run_fast,true,Vector2.LEFT*speed*0.05 if tick>=115 else Vector2.DOWN*speed*0.05)
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/fan_motion_capture/%03d.png" % tick)
	print("FAN MOTION PREVIEW: 140 renderer frames captured; player save untouched.")
	quit()
