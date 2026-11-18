extends RefCounted

const CareArt=preload("res://scripts/library_care_art.gd")
const PAPER:=Color("fff0cc")
const BORDER:=Color("805a36")
const TEXT:=Color("4b352c")

static func visible(g,flow) -> bool:
	return flow.enabled(g) and g.mode=="play" and not flow.active(g) and g.player_pos.x<1280 and g.comic_started<0

static func screen_rect(g,world: Rect2) -> Rect2:
	return Rect2(world.position*g.WORLD_SCALE+g.WORLD_OFFSET,world.size*g.WORLD_SCALE)

static func bodies(g) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for obj in g.objects:
		if obj.get("promo_away",false) or obj.type not in ["npc","librarian","artisan"]: continue
		if obj.type=="artisan":
			result.append(screen_rect(g,Rect2(obj.pos-Vector2(30,92),Vector2(60,96))).grow(5));continue
		var key: String="aethe" if obj.type=="librarian" else g._costume_key(obj.id)
		result.append(screen_rect(g,g.Field.stella_hit_rect(key,obj.pos)).grow(5))
	for guest in g.state.ink_visits.guests:
		result.append(screen_rect(g,Rect2(guest.pos-Vector2(34,60),Vector2(68,66))).grow(4))
	result.append(screen_rect(g,Rect2(g.player_pos-Vector2(34,82),Vector2(68,88))).grow(5))
	return result

static func place(anchor: Vector2,size: Vector2,occupied: Array[Rect2]) -> Rect2:
	var preferred:=anchor-Vector2(size.x*.5,size.y+12)
	for offset in [Vector2.ZERO,Vector2(-size.x*.5-16,0),Vector2(size.x*.5+16,0),Vector2(0,-size.y-16),Vector2(-size.x-24,-32),Vector2(size.x+24,-32)]:
		var rect:=Rect2((preferred+offset).round(),size)
		rect.position.x=clampf(rect.position.x,10,1270-size.x)
		rect.position.y=clampf(rect.position.y,134,730-size.y)
		var blocked:=false
		for region in occupied:
			if rect.grow(5).intersects(region): blocked=true;break
		if not blocked: return rect
	return Rect2()

static func layout(g,flow) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not visible(g,flow): return result
	var occupied:=bodies(g)
	occupied.append_array([Rect2(10,10,288,120),Rect2(1216,738,58,56)])
	if flow.ete_elapsed>=0 and g.state.library_day.unfiled()>0 and g.character_touch.held!="ete" and g.character_touch.ete_visit.is_empty() and g.ete_interactions.active=="":
		var feet: Vector2=g.ete_interactions.position(g)
		var body: Rect2=screen_rect(g,g.Field.stella_hit_rect("aethe",feet))
		var anchor:=Vector2(body.get_center().x,body.position.y-2)
		var rect:=place(anchor,Vector2(302,74),occupied)
		if rect.has_area():
			result.append({"kind":"ete","target":"","rect":rect,"anchor":anchor,"expanded":true})
			occupied.append(rect.grow(10))
	for visitor in g.state.ink_visits.guests:
		if visitor.phase!="browse" or (not visitor.get("request",false) and not visitor.get("noisy",false)): continue
		var target: String="day_ink_%d"%visitor.uid
		if g._find_object(target).is_empty(): continue
		var nearby: bool=g.player_pos.distance_to(visitor.pos)<=130
		var kind: String="request" if visitor.get("request",false) else "quiet"
		var anchor: Vector2=(visitor.pos-Vector2(0,62))*g.WORLD_SCALE+g.WORLD_OFFSET
		var rect:=place(anchor,Vector2(204,42) if nearby else Vector2(40,38),occupied)
		if not rect.has_area() and nearby:
			nearby=false;rect=place(anchor,Vector2(40,38),occupied)
		if rect.has_area():
			result.append({"kind":kind,"target":target,"rect":rect,"anchor":anchor,"expanded":nearby})
			occupied.append(rect.grow(8))
	return result

static func bubble(g,rect: Rect2,anchor: Vector2,angry: bool) -> void:
	var border:=Color("a15b48") if angry else BORDER
	# A stepped pixel outline and short speaker tail, never a modal window.
	g.draw_rect(Rect2(rect.position+Vector2(3,7),rect.size-Vector2(0,4)),Color(0.12,0.08,0.06,.28))
	g.draw_rect(Rect2(rect.position+Vector2(4,0),rect.size-Vector2(8,0)),border)
	g.draw_rect(Rect2(rect.position+Vector2(0,4),rect.size-Vector2(0,8)),border)
	g.draw_rect(Rect2(rect.position+Vector2(4,2),rect.size-Vector2(8,4)),PAPER)
	g.draw_rect(Rect2(rect.position+Vector2(2,4),rect.size-Vector2(4,8)),PAPER)
	var x:=roundf(clampf(anchor.x,rect.position.x+12,rect.end.x-12))
	var y:=rect.end.y-2
	g.draw_rect(Rect2(x-7,y,14,4),border)
	g.draw_rect(Rect2(x-5,y+4,10,3),border)
	g.draw_rect(Rect2(x-3,y+7,6,3),border)
	g.draw_rect(Rect2(x-5,y,10,3),PAPER)
	g.draw_rect(Rect2(x-3,y+3,6,3),PAPER)

static func draw(g,flow) -> void:
	for entry in layout(g,flow):
		var rect: Rect2=entry.rect
		bubble(g,rect,entry.anchor,entry.kind=="ete")
		if entry.kind=="ete":
			CareArt.draw_warning(g,rect.position+Vector2(10,20),flow.ete_elapsed)
			var first: String="들고 있는 책도" if not g.state.library_day.carried.is_empty() else "책이 쌓였잖아요!"
			g._text(rect.position+Vector2(52,29),first,17,TEXT)
			g._text(rect.position+Vector2(52,55),"서가에 정리해 주세요.",17,TEXT)
		else:
			var center:=rect.position+Vector2(20,18)
			if entry.kind=="request":
				g.draw_rect(Rect2(center-Vector2(4,10),Vector2(8,16)),BORDER)
				g.draw_rect(Rect2(center-Vector2(2,10),Vector2(4,14)),Color("e3a63d"))
				g.draw_rect(Rect2(center+Vector2(-3,9),Vector2(6,5)),BORDER)
				g.draw_rect(Rect2(center+Vector2(-2,9),Vector2(4,3)),Color("e3a63d"))
			else:
				for x in [-7,0,7]: g.draw_rect(Rect2(center+Vector2(x-2,0),Vector2(4,4)),BORDER)
			if entry.expanded: g._text(rect.position+Vector2(39,27),"책 추천해 주세요!" if entry.kind=="request" else "조금 시끄러워요…",16,TEXT)
		g.ui_regions.append(rect)

static func click(g,flow,screen: Vector2) -> bool:
	for entry in layout(g,flow):
		if not entry.rect.has_point(screen): continue
		if entry.target!="":
			var target: Dictionary=g._find_object(entry.target)
			if not target.is_empty(): g._go_to(target)
		return true
	return false
