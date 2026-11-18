extends RefCounted

const Pose = preload("res://scripts/activity_pose.gd")
const Sprite = preload("res://scripts/activity_sprite.gd")
const INK := Color("493849")
const PAPER := Color("fff0cf")
var actor := Sprite.new()

func broadcast(g, box: Rect2, member: Dictionary, elapsed: float, reply: int, finished: bool) -> void:
	var pose := Pose.new()
	pose.build("signoff" if finished else "stream",elapsed,3,actor.shoulder_height(g._costume_key(member.id)),member.id,reply)
	var zoom := minf(5.0,(box.size.y-84)/82.0)
	var desk_y := box.end.y-73
	var studio_desk: bool=g.studios_open
	if studio_desk:
		var interior:=box.grow(-4)
		desk_y=interior.end.y-23*maxf(interior.size.x,interior.size.y)/g.Studios.CELL
	var feet := Vector2(box.get_center().x-9,desk_y-pose.hip.y*zoom+2)
	actor.draw(g,member.id,pose,feet,zoom,true)
	var hand: Vector2 = feet+pose.hands[1]*zoom
	var left: Vector2 = feet+pose.hands[0]*zoom
	var accent := Color(member.color)
	if studio_desk:
		g.Studios.paint(g,g._mission_index_for(member.id),box.grow(-4),true)
	else:
		g.draw_rect(Rect2(box.position.x+5,desk_y,box.size.x-10,68),Color("855a4a"))
		g.draw_rect(Rect2(box.position.x+5,desk_y,box.size.x-10,9),Color("d7a779"))
		g.draw_rect(Rect2(box.position.x+5,desk_y+13,box.size.x-10,3),Color("664739"))
		# The monitor faces the host. A short VU meter moves while they're on air.
		var monitor := Vector2(box.position.x+42,desk_y-40)
		g.draw_rect(Rect2(monitor,Vector2(62,34)),Color("272f38"))
		g.draw_rect(Rect2(monitor+Vector2(3,3),Vector2(56,26)),Color("416361"))
		for i in range(6):
			var h := 4 if finished else 6+int(9*absf(sin(elapsed*4+i)))
			g.draw_rect(Rect2(monitor+Vector2(7+i*8,25-h),Vector2(5,h)),accent.lightened(0.24))
		g.draw_rect(Rect2(monitor+Vector2(26,33),Vector2(10,7)),INK)
		var mic := Vector2(box.end.x-72,desk_y-100)
		g.draw_polyline(PackedVector2Array([mic,mic+Vector2(29,26),mic+Vector2(21,93)]),Color("c4b295"),6)
		g.draw_rect(Rect2(mic-Vector2(8,17),Vector2(16,30)),Color("232d34"))
		for i in range(3): g.draw_line(mic+Vector2(-5,-9+i*5),mic+Vector2(5,-9+i*5),Color("b5c7bf"),2)
	if finished or reply < 0: return
	match pose.gesture:
		"draw","write","draw_moon","stamp","match":
			# Map, envelope, or case file, braced against the left palm.
			var page := left-Vector2(5,9)
			g.draw_rect(Rect2(page,Vector2(43,30)),INK)
			g.draw_rect(Rect2(page+Vector2(2,2),Vector2(39,26)),PAPER)
			if member.id == "yato":
				g.draw_polyline(PackedVector2Array([page+Vector2(4,20),page+Vector2(15,13),page+Vector2(23,17),page+Vector2(36,6)]),Color("7ca294"),2)
			elif member.id == "danming":
				g.draw_polyline(PackedVector2Array([page+Vector2(2,3),page+Vector2(21,16),page+Vector2(40,3)]),Color("c58f85"),2)
			else:
				for y in [7,14,21]: g.draw_rect(Rect2(page+Vector2(6,y),Vector2(21,2)),Color("b29a72"))
			if pose.gesture == "stamp":
				g.draw_rect(Rect2(hand+Vector2(-3,-7),Vector2(6,13)),Color("ac7957"))
				g.draw_rect(Rect2(hand+Vector2(-7,5),Vector2(14,5)),INK)
			elif pose.gesture == "match":
				g.draw_rect(Rect2(hand-Vector2(3,15),Vector2(7,23)),accent)
				g.draw_rect(Rect2(hand-Vector2(1,13),Vector2(3,10)),PAPER)
			else:
				g.draw_line(hand+Vector2(-6,9),hand+Vector2(7,-12),Color("735968"),4)
		"fold":
			var paper := (hand+left)*0.5+Vector2(0,-4)
			g.draw_colored_polygon(PackedVector2Array([paper+Vector2(-15,-6),paper+Vector2(-5,5),paper+Vector2(7,5),paper+Vector2(16,-6),paper+Vector2(4,-2),paper+Vector2(0,-10),paper+Vector2(-5,-3)]),PAPER)
		"ring","chime":
			var bell := hand+Vector2(0,16)
			g.draw_line(hand,bell,Color("efdfbd"),2)
			g.draw_colored_polygon(PackedVector2Array([bell+Vector2(-4,-4),bell+Vector2(3,-4),bell+Vector2(7,4),bell+Vector2(-7,4)]),Color("e9c07e"))
			g.draw_circle(bell+Vector2(0,6),2,accent)
		"clap","sing":
			var sound := (left+hand)*0.5 if pose.gesture == "clap" else hand
			for i in range(2):
				var note := sound+Vector2(18+i*11,-9-i*8-3*sin(elapsed*5))
				g.draw_circle(note,3,accent)
				g.draw_line(note+Vector2(2,0),note+Vector2(2,-8),accent,2)
		"snow":
			for i in range(4):
				g._star(left.lerp(hand,i/3.0)+Vector2(0,11+3*sin(elapsed*5+i)),3,Color("cce5ee"))
