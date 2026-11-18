extends RefCounted

# Dressing sits on existing shelves/walls, so no new blocking floor tiles.
const EXHIBIT_POINT := Vector2(568,296)
const RECORD_POINT := Vector2(760,304)
const Furniture = preload("res://scripts/garden_furniture.gd")
const Pixels = preload("res://scripts/library_pixels.gd")

static func visitor_stop(rank: int, kind: String) -> Dictionary:
	if kind=="exhibit" and rank>=1: return {"pos":EXHIBIT_POINT,"label":"추천 카드 읽는 중","seconds":2.0}
	if kind=="record" and rank>=2: return {"pos":RECORD_POINT,"label":"기억 한 줄 남기는 중" if rank>=3 else "방문 기록 남기는 중","seconds":1.8}
	return {}

static func draw_visitor_memory(g, guest: Dictionary, rank: int) -> void:
	if guest.get("phase","")!="record" or rank<2: return
	var pos: Vector2=guest.pos.round()+Vector2(24,-62)
	var elapsed: float=guest.get("elapsed",0.0)
	# Paper and pen are props beside the visitor, never a deformation of its face.
	g.draw_rect(Rect2(pos-Vector2(2,2),Vector2(22,24)),Color("735840"))
	g.draw_rect(Rect2(pos,Vector2(18,20)),Color("f3e6bc"))
	var lines := clampi(floori(elapsed*4)+1,1,4)
	for i in range(lines): g.draw_rect(Rect2(pos+Vector2(3,4+i*3),Vector2(10-(i%2)*3,1)),Color("9b8163"))
	if elapsed<1.05:
		var pen := pos+Vector2(8+floori(elapsed*9)%5,2+lines*3)
		for i in range(7): g.draw_rect(Rect2(pen+Vector2(i,-i),Vector2(2,2)),Color("596f70"))
	else:
		g.draw_rect(Rect2(pos+Vector2(11,13),Vector2(5,5)),Color("b16e69"))
		g.draw_rect(Rect2(pos+Vector2(12,14),Vector2(2,2)),Color("f3d69c"))
		if rank>=3:
			var spread := 5+floori((elapsed-1.05)*9)
			var star := pos+Vector2(10,6)
			g.draw_rect(Rect2(star-Vector2(1,4),Vector2(3,9)),Color("fff0b5"))
			g.draw_rect(Rect2(star-Vector2(4,1),Vector2(9,3)),Color("fff0b5"))
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				g.draw_rect(Rect2((star+direction*spread).round(),Vector2(2,2)),Color("e7c876"))
	g._world_sign(guest.pos+Vector2(-16,-84),visitor_stop(rank,"record").label)

static func draw(g) -> void:
	if g.growth.phase!="open": return
	var rank: int=g.growth.rank()
	if rank>=1:
		# A six-book recommendation rail is fitted to the existing upper shelf.
		g.draw_rect(Rect2(522,162,110,43),Color("392d2a"))
		g.draw_rect(Rect2(526,165,102,35),Color("e6c690"))
		g._text(Vector2(535,178),"스텔라 추천 책",12,Color("5b412d"))
		for i in range(6):
			var x := 531+i*15
			var color := Color(g.MEMBERS[i].color)
			g.draw_rect(Rect2(x,182,11,18),color.darkened(.3))
			g.draw_rect(Rect2(x+2,183,7,15),color)
			g.draw_rect(Rect2(x+3,186,5,2),Color("ffedbb"))
			g.draw_rect(Rect2(x+3,196,5,1),Color("ffedbb"))
		g.draw_rect(Rect2(522,200,110,5),Color("b2854c"))
	if rank>=2:
		# The visitor ledger hangs at the window-side rail, away from the walkway.
		g.draw_rect(Rect2(728,239,66,43),Color("503d32"))
		g.draw_rect(Rect2(731,242,60,36),Color("cfb17e"))
		g.draw_rect(Rect2(735,245,51,27),Color("f7e9bd"))
		for i in range(4):
			g.draw_rect(Rect2(740,249+i*5,23+(i%2)*9,1),Color("a68d6d"))
		g.draw_rect(Rect2(776,260,6,6),Color("a56565"))
		g.draw_rect(Rect2(739,280,45,4),Color("af8450"))
		g.draw_rect(Rect2(728,220,66,16),Color("e5cb92"))
		g._text(Vector2(734,232),"잉크의 발자국",10,Color("533c2e"))
	if rank>=3:
		# A completed six-colour garland changes the whole shelf silhouette.
		for i in range(12):
			var x := 347+i*24
			var y := 144+absi(5-i)
			g.draw_rect(Rect2(x,y,24,2),Color("a88b57"))
			var color := Color(g.MEMBERS[i%6].color)
			g.draw_rect(Rect2(x+6,y+3,11,12),color)
			g.draw_rect(Rect2(x+8,y+15,7,3),color.darkened(.15))
		for p in [Vector2(340,267),Vector2(628,267)]:
			g.draw_rect(Rect2(p-Vector2(6,11),Vector2(12,11)),Color("a1724d"))
			g.draw_rect(Rect2(p-Vector2(7,13),Vector2(14,3)),Color("c6a470"))
			for leaf in [Vector2(-8,-19),Vector2(2,-25),Vector2(-3,-31)]:
				g.draw_rect(Rect2(p+leaf,Vector2(7,9)),Color("6c8c68"))
				g.draw_rect(Rect2(p+leaf+Vector2(1,1),Vector2(3,6)),Color("a3b77e"))
