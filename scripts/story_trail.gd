extends RefCounted

# Progress comes from the real activity notes, never a separate click counter.
const DATA = preload("res://assets/story/exploration_trails.json")
const EXIT_ID := "story_path"
const HUD := Rect2(97,83,1086,52)

static func entry(id: String, scene: int) -> Dictionary:
	return DATA.data.books[id][scene]

static func status(progress, id: String, scene: int) -> Dictionary:
	var page := entry(id,scene)
	var notes: Array=progress.get(id+"_notes")
	var complete: bool=progress.chapter_ready(id,scene)
	var found:=0
	var active:=-1
	var result:=""
	for i in range(page.beats.size()):
		var beat: Array=page.beats[i]
		if complete or beat[0] in notes:
			found+=1
			result=beat[2]
		elif active<0: active=i
	return {"found":found,"total":page.beats.size(),"active":active,
		"goal":page.beats[active][1] if active>=0 else "살펴본 변화를 책갈피에 남기기",
		"result":result,"ready":complete}

static func add_exit(g, id: String, scene: int) -> void:
	var link: Dictionary=entry(id,scene).next
	g.objects.append({"id":EXIT_ID,"type":"story_path","index":scene,
		"pos":Vector2(link.exit[0],link.exit[1]),"reach":24.0,"label":link.label})

static func fit_exit(g) -> void:
	var obj: Dictionary=g._find_object(EXIT_ID)
	if obj.is_empty(): return
	var cell: Vector2i=g._grid_at(obj.pos)
	if cell.x>=0: obj.pos=g.navigation.get_point_position(cell)

static func resume_position(g, id: String, scene: int) -> Vector2:
	match id:
		"yato": return g.YatoForest.record_site(scene)+Vector2(0,32)
		"danming": return g.DanmingWorkshop.record_site(scene)+Vector2(0,32)
		"kubby": return g.KubbyEmbers.record_site(scene)+Vector2(0,32)
		"yune": return g.YuneDream.record_site(scene,g.Chapters.BOOKS[id].points[scene])+Vector2(0,32)
		"fuwa": return g.FuwaSnow.record_site(scene)+Vector2(0,32)
		"dori": return [Vector2(669,558),Vector2(586,396),g.DoriCase.Rubbing.ETE_SIDE+Vector2(0,32)][scene]
	return g.player_pos

static func draw_exit(g) -> void:
	var obj: Dictionary=g._find_object(EXIT_ID)
	if obj.is_empty(): return
	var p: Vector2=obj.pos.round()
	g.draw_ellipse_shadow(p,Vector2(29,8))
	# A ribbon in the memory, not an invented door in the official setting.
	g.draw_rect(Rect2(p+Vector2(-13,-41),Vector2(26,38)),Color("6c4e48"))
	g.draw_rect(Rect2(p+Vector2(-10,-39),Vector2(20,34)),Color("ead4a0"))
	g.draw_rect(Rect2(p+Vector2(-3,-39),Vector2(6,32)),Color("b66d61"))
	g.draw_colored_polygon(PackedVector2Array([p+Vector2(-10,-5),p+Vector2(0,-12),p+Vector2(10,-5)]),Color("6c4e48"))
	for i in range(3):
		g._star(p+Vector2(-24+i*22,-18-sin(g.clock*2+i)*7),2.5,Color("f9dfa2"))
	g._world_sign(p+Vector2(0,23),obj.label,EXIT_ID)

static func draw_hud(g, id: String, scene: int) -> void:
	var progress=g._chapter_progress()
	var page:=entry(id,scene)
	var step:=status(progress,id,scene)
	var linking: bool=progress.route_pending(id)
	g._panel(HUD,g.PAPER)
	g.ui_regions.append(HUD)
	g._text(Vector2(121,104),"이어지는 기억" if linking else "이번 장면의 물음",14,g.GOLD)
	g._text(Vector2(260,104),page.next.label if linking else page.question,17,g.CREAM)
	var goal: String="밝아진 책갈피까지 걸어가 다음 기록으로 이어 가자." if linking else step.goal
	g._text(Vector2(121,126),goal,17,g.CREAM)
	var total: int=step.total+2 # field observations, record, and travel/return
	var finished: int=step.found+int(linking)
	for i in range(total):
		var color: Color=g.GOLD if i<finished else Color("bca98d")
		var x:=1118-(total-1-i)*19
		g.draw_rect(Rect2(x,115,10,10),color)
		if i==finished: g.draw_rect(Rect2(x-2,113,14,14),g.CREAM,false,1)
	g._text(Vector2(1064,104),"%d / %d"%[mini(finished+1,total),total],14,g.MUTED)
