extends RefCounted

const Layout=preload("res://scripts/library_world_layout.gd")
const Pixels=preload("res://scripts/library_pixels.gd")
var textures: Dictionary={}
var entered:=false
var vendor:="artisan"
var last_rank:=-1

func texture(name: String) -> Texture2D:
	if not textures.has(name):
		var tex:=CanvasTexture.new()
		tex.diffuse_texture=load("res://assets/library_world/"+name+".png")
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[name]=tex
	return textures[name]

func region(g,name: String,r: Rect2,offset: Vector2=Vector2.ZERO) -> void:
	var tex:=texture(name)
	var factor:=tex.get_size()/Vector2(1280,800)
	g.draw_texture_rect_region(tex,Rect2(r.position+offset,r.size),Rect2(r.position*factor,r.size*factor))

func setup(g) -> void:
	var previous: Dictionary={}
	for obj in g.objects:
		if obj.type=="npc" and entered: previous[obj.id]=obj.duplicate(true)
	var was_enabled: bool=g.state.world_enabled
	g.state.enable_world_layout()
	if not entered or not was_enabled: g.player_pos=g.state.world_player
	entered=true
	g.studios_open=g.state.residents.size()==6 and g.growth.phase!="recruiting"
	g.character_touch.reset();g.ete_interactions.reset();g.ete_facing="down"
	g.objects.clear();g.route.clear();g.pending_object=""
	g.chapter_floor.clear();g.chapter_trail.clear();g.chapter_signs.clear()
	var services=[
		["ete","librarian",Layout.ETE,"에테 · 의뢰와 도서관 운영"],
		["shelf","shelf",Vector2(648,208),"시작의 서가 · 여섯 이야기"],
		["activity_archive","activity_archive",Vector2(136,288),"방송 기록 서가"],
		["board","promotion_board",Vector2(112,360),"홍보 게시판 · 주제 맡기기"],
		["table","artisan",Vector2(176,720),"의문의 장인 · 가구와 공개 의상"],
		["desk","desk",Layout.VISITOR_DESK,"대출 · 방문 기록"],
		["sleep","sleep",Vector2(1136,216),"오늘의 일정 · 마감"],
		["residence_door","world_door",Layout.PUBLIC_DOOR,"스텔라의 공간으로"],
		["library_door","world_door",Layout.HOME_DOOR,"공용 도서관으로"]]
	for service in services: g.objects.append({"id":service[0],"type":service[1],"pos":service[2],"label":service[3]})
	for i in range(g.MEMBERS.size()):
		var member: Dictionary=g.MEMBERS[i]
		if member.id not in g.state.residents: continue
		var obj: Dictionary=previous.get(member.id,{"id":member.id,"type":"npc","index":i,"slot":g.state.residents.find(member.id),"pos":Layout.HOMES[i] if g.studios_open else Layout.PUBLIC_SPOTS[i],"label":member.name+" · 대화"})
		obj.world_keep=previous.has(member.id)
		g.objects.append(obj)
	for item in g.state.furniture:
		g.objects.append({"id":"furniture_"+item.kind,"type":"furniture","index":-3,"kind":item.kind,"pos":Vector2(item.x,item.y),"label":g.Furniture.ITEMS[item.kind].name+" · 꾸미기"})
	if g.growth.phase=="rebuilding":
		var spots={"corridor":Vector2(560,704),"shelves":Vector2(552,344),"reading":Vector2(928,464)}
		for task in g.Growth.TASKS:
			if task not in g.growth.completed_tasks: g.objects.append({"id":"work_"+task,"type":"growth_work","task":task,"pos":spots[task],"label":g.WORKS[task].title+" · 함께 준비하기"})
	g.obstacles=Layout.obstacles(g.state.furniture)
	g.navigation=Layout.navigation(g.state.furniture)
	if not g._walkable(g.player_pos):
		var cell:=Layout.nearest(g.navigation,g.player_pos)
		g.player_pos=g.navigation.get_point_position(cell) if cell.x>=0 else Layout.ENTRY
	g.garden_residents.reset(g)
	g.state.ink_visits.refresh_map(g)
	last_rank=g.growth.rank()

func change_area(g,to_private: bool) -> void:
	if to_private and not g.studios_open:
		g._notify("여섯 스텔라가 모두 돌아오면 각자의 공간으로 이어져요.")
		return
	g.character_touch.cancel();g.route.clear();g.pending_object=""
	g.player_pos=Layout.HOME_DOOR if to_private else Layout.PUBLIC_DOOR+Vector2(-32,32)
	var cell:=Layout.nearest(g.navigation,g.player_pos)
	if cell.x>=0: g.player_pos=g.navigation.get_point_position(cell)
	g.state.world_player=g.player_pos
	g._save()
	g._notify("스텔라의 공간 · 방에서 인사하고 방송을 함께해요." if to_private else "공용 도서관 · 손님과 스텔라가 함께 머무는 곳이에요.")

func draw_background(g) -> void:
	if Layout.private_point(g.player_pos):
		region(g,"personal_spaces",Rect2(0,0,1280,800),Layout.HOME_OFFSET)
		return
	region(g,"library_abandoned",Rect2(0,0,1280,800))
	for patch in Layout.visible_patches(g.growth): region(g,"library_finished",patch)
	# A returned story regains its own color even before communal reconstruction.
	if "shelves" not in g.growth.completed_tasks:
		for i in range(6):
			if g.MEMBERS[i].id in g.state.residents: region(g,"library_finished",Rect2(524+i*44,86,39,60))
	if "corridor" not in g.growth.completed_tasks and g.mode!="growth_work":
		g.Work._crate(g,Vector2(495,695))
	if "reading" in g.growth.completed_tasks: draw_artisan(g,Vector2(176,720))
	if "reading" in g.growth.completed_tasks: g.Seasons.draw_world_windows(g,g._calendar(),g.clock)

func append_layers(g,actors: Array) -> void:
	if Layout.private_point(g.player_pos): return
	for r in Layout.STACKS:
		actors.append({"index":-8,"pos":Vector2(r.position.x+r.size.x*.5,r.end.y),"region":r})
	for r in [Rect2(20,380,242,135),Rect2(860,274,259,142),Rect2(858,506,265,124)]:
		actors.append({"index":-8,"pos":Vector2(r.position.x+r.size.x*.5,r.end.y),"region":r})

func draw_layer(g,area: Rect2) -> void:
	region(g,"library_abandoned",area)
	for patch in Layout.visible_patches(g.growth):
		if patch.intersects(area): region(g,"library_finished",patch.intersection(area))

func _hud_icon(g,id: String,p: Vector2) -> void:
	var rows: Array={"gold":["...oooo...","..oyyyyo..",".oyYyyYyo.","oyYyYYyYyo","oyYyyyyYyo","oyYyYYyYyo",".oyYyyYyo.","..oyyyyo..","...oooo..."],"light":["....w....","...wcw...","..wcCcw..",".wcCCCcw.","wcCCCCCcw",".wcCCCcw.","..wcCcw..","...wcw...","....w...."]}[id]
	var colors={"o":"795033","y":"e5ad45","Y":"fff0a1","w":"f5e8c5","c":"9bcac5","C":"ffffff"}
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key=rows[y][x]
			if colors.has(key): g.draw_rect(Rect2(p+Vector2(x*2,y*2),Vector2(2,2)),Color(colors[key]))

func draw_hud(g) -> void:
	var fill:=Color("f1ddb2")
	var dark:=Color("49372f")
	var day: Dictionary=g._calendar()
	var date:=Rect2(16,16,244,65)
	Pixels.panel(g,date,fill)
	Pixels.icon(g,"sun",Vector2(38,39),.9)
	g._text(Vector2(58,42),"%d년차 · %s %d일"%[day.year,day.season_label,day.day_in_season],18,dark)
	g._text(Vector2(34,66),"%02d:%02d · %s"%[g.state.minutes/60,g.state.minutes%60,g._operating_status()],15,dark)
	var money:=Rect2(16,86,119,38)
	var light:=Rect2(139,86,153,38)
	Pixels.panel(g,money,fill);Pixels.panel(g,light,fill)
	_hud_icon(g,"gold",Vector2(27,97));_hud_icon(g,"light",Vector2(149,95))
	g._text(Vector2(55,113),str(g.growth.gold),17,dark)
	var threshold: int=g.growth.next_threshold()
	g._text(Vector2(175,110),str(g.growth.memory_light)+(" / %d"%threshold if threshold>0 else " MAX"),15,dark)
	g.draw_rect(Rect2(176,116,97,3),Color("bcad86"))
	g.draw_rect(Rect2(176,116,97*(minf(1,float(g.growth.memory_light)/threshold) if threshold>0 else 1),3),Color("6f9e98"))
	g.ui_regions.append_array([date,money,light])
	var notebook:=Rect2(1224,744,42,43)
	Pixels.panel(g,notebook,fill);Pixels.icon(g,"journal",Vector2(1245,765),1.2)
	g.buttons.append({"rect":notebook,"id":"world_notebook"})
	g.ui_regions.append(notebook)

func clear_hint_rect(g,preferred: Rect2) -> Rect2:
	var occupied: Array[Rect2]=[]
	occupied.append_array(g.ui_regions)
	for obj in g.objects:
		if obj.type not in ["npc","librarian"] or obj.get("promo_away",false): continue
		var key: String="aethe" if obj.type=="librarian" else g._costume_key(obj.id)
		var bounds: Rect2=g.Field.stella_hit_rect(key,obj.pos)
		occupied.append(Rect2(bounds.position*g.WORLD_SCALE+g.WORLD_OFFSET,bounds.size*g.WORLD_SCALE).grow(5))
	occupied.append(Rect2((g.player_pos-Vector2(32,74))*g.WORLD_SCALE+g.WORLD_OFFSET,Vector2(64,80)*g.WORLD_SCALE))
	# Keep transient hints off the actual character, without moving the HUD.
	for offset in [Vector2.ZERO,Vector2(0,-40),Vector2(0,-80),Vector2(0,-120),Vector2(0,40),Vector2(0,80),Vector2(-preferred.size.x-20,0),Vector2(preferred.size.x+20,0)]:
		var candidate:=Rect2(preferred.position+offset,preferred.size)
		candidate.position.x=clampf(candidate.position.x,10,1270-candidate.size.x)
		candidate.position.y=clampf(candidate.position.y,135,710)
		var blocked:=false
		for body in occupied:
			if body.intersects(candidate): blocked=true;break
		if not blocked: return candidate
	return Rect2() # Hide an optional hint rather than cover a crowded group.

func draw_hints(g) -> void:
	if g.mode!="play": return
	var seat: Dictionary=g.shared.nearby(g)
	if not seat.is_empty() and not Layout.private_point(g.player_pos):
		g._button(Rect2(416,700,448,38),"%s · %s  R"%[g.MEMBERS[g._mission_index_for(seat.id)].short,g.SharedActivity.NAMES[seat.kind]],"join_"+seat.id,true)
	var target: Dictionary=g._nearest()
	var mouse: Vector2=(g.get_global_mouse_position()-g.WORLD_OFFSET)/g.WORLD_SCALE
	if Layout.private_point(g.player_pos):
		var hit: Dictionary=g.character_touch.hit(g,mouse)
		if not hit.is_empty(): target=hit
	var has_request_bubble: bool=target.get("type","")=="day_target" and target.get("kind","") in ["request","quiet"]
	if not target.is_empty() and not has_request_bubble:
		var label: String=target.label
		if target.type=="npc": label=g.MEMBERS[target.index].name+(" · 방송 채팅" if target.get("yard_action","")=="stream" else " · 인사" if target.get("in_studio",false) else " · 대화")
		var p: Vector2=target.pos*g.WORLD_SCALE+g.WORLD_OFFSET
		var width:=minf(470,g.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+36)
		var rect:=clear_hint_rect(g,Rect2(clampf(p.x-width*.5,10,1270-width),clampf(p.y-138,135,710),width,30))
		if rect.has_area():
			g._panel(rect,g.PAPER)
			g._text(rect.position+Vector2(12,21),"E  "+label,15)
	for obj in g.objects:
		if not obj.get("in_studio",false): continue
		var line: String=g.character_touch.reactions.get(obj.id,{}).get("greeting","")
		if line.is_empty() or not Layout.private_point(g.player_pos): continue
		var p: Vector2=obj.pos+g.WORLD_OFFSET
		var r:=clear_hint_rect(g,Rect2(clampf(p.x-125,10,1010),maxf(136,p.y-158),260,49))
		if r.has_area(): g._panel(r,g.PAPER);g._text_block(r.position+Vector2(10,20),line,240,14,g.CREAM,18)

func draw_menu(g) -> bool:
	if g.mode not in ["world_ete","world_artisan","world_notebook"]: return false
	var r:=Rect2(290,224,500,343)
	g._panel(r,g.PAPER)
	var title: String="에테 · 무엇을 도와드릴까요?" if g.mode=="world_ete" else "의문의 장인 · 제작 공방" if g.mode=="world_artisan" else "도서관 수첩"
	g._text(r.position+Vector2(24,40),title,23)
	var choices: Array
	if g.mode=="world_ete": choices=[["영입 의뢰 · 이야기 책","mission_open"],["도서관 재건 · 운영","growth_ops"],["도서관 능력 개선","world_upgrades"],["팬 모습으로 변신","fan_forms"]]
	elif g.mode=="world_artisan": choices=[["가구 제작 · 보유 가구","world_furniture_shop"],["공개 의상 제작 · 갈아입기","world_costume_shop"],["보유 가구 배치","furniture_open"]]
	else: choices=[["도서관 안내","help"],["오늘의 일정 · 마감","growth_rest"],["방문 · 대출 기록","growth_ledger"],["스텔라 활동","life_open"]]
	for i in range(choices.size()): g._button(Rect2(r.position+Vector2(24,61+i*52),Vector2(452,43)),choices[i][0],choices[i][1],i==0)
	g._button(Rect2(r.position+Vector2(338,290),Vector2(138,34)),"닫기 Esc","close")
	return true

func hit(g,p: Vector2) -> Dictionary:
	var zones={"shelf":Rect2(500,64,335,132),"activity_archive":Rect2(23,139,205,146),"board":Rect2(47,287,110,77),"table":Rect2(28,548,245,184),"desk":Rect2(27,381,239,136),"residence_door":Rect2(1135,38,110,181)}
	if not Layout.private_point(p):
		for id in zones:
			if zones[id].has_point(p): return g._find_object(id)
	for obj in g.objects:
		if obj.type in ["npc","librarian"] or obj.get("promo_away",false): continue
		if obj.pos.distance_to(p+Vector2(0,15))<43: return obj
	return {}
func draw_artisan(g,p: Vector2) -> void:
	# Tentative original supporting NPC, not an official character.
	g.draw_ellipse_shadow(p,Vector2(21,4))
	var outline=PackedVector2Array([Vector2(-4,-87),Vector2(9,-84),Vector2(15,-77),Vector2(18,-66),Vector2(16,-57),Vector2(24,-48),Vector2(26,-28),Vector2(20,-23),Vector2(19,-8),Vector2(15,-7),Vector2(15,0),Vector2(3,0),Vector2(2,-7),Vector2(-3,-7),Vector2(-4,0),Vector2(-18,0),Vector2(-18,-5),Vector2(-14,-9),Vector2(-20,-10),Vector2(-19,-26),Vector2(-26,-28),Vector2(-24,-47),Vector2(-17,-56),Vector2(-19,-65),Vector2(-15,-77),Vector2(-9,-83)])
	for j in range(outline.size()): outline[j]+=p
	g.draw_colored_polygon(outline,Color("30363d"))
	var hood=PackedVector2Array([Vector2(-4,-85),Vector2(8,-81),Vector2(13,-74),Vector2(15,-64),Vector2(12,-56),Vector2(-12,-56),Vector2(-16,-65),Vector2(-12,-75)])
	for j in range(hood.size()): hood[j]+=p
	g.draw_colored_polygon(hood,Color("547574"))
	var parts=[[-13,-74,25,17,"3d565c"],[-10,-69,20,14,"27363f"],[-8,-66,16,10,"1f2c35"],[-6,-62,3,2,"dbcba4"],[4,-62,3,2,"dbcba4"],[-5,-81,8,2,"8ba29a"],[-11,-76,3,5,"728f87"],[-14,-68,2,10,"91a59b"],[12,-66,2,8,"30484f"],[-10,-55,21,4,"87988a"],[-13,-50,27,10,"526d68"],[-19,-46,6,17,"486361"],[15,-46,7,17,"486361"],[-22,-39,4,11,"6a8176"],[-23,-29,6,5,"d5b698"],[19,-29,5,5,"d5b698"],[-14,-39,28,24,"ad8056"],[-10,-48,3,12,"dab88a"],[8,-48,3,12,"dab88a"],[-13,-39,25,2,"e1b888"],[-13,-15,28,2,"dab083"],[-14,-13,29,2,"445656"],[-10,-31,20,12,"805c45"],[-9,-30,18,2,"d4aa7a"],[-7,-27,3,5,"b39b70"],[3,-27,2,6,"a3b7ae"],[-12,-10,8,5,"57676a"],[5,-10,8,5,"57676a"],[-16,-3,10,1,"8a7a66"],[5,-3,8,1,"8a7a66"],[-3,-52,5,3,"bc9b65"],[20,-43,2,15,"bd9665"],[17,-46,9,4,"a8b3ad"]]
	for part in parts: g.draw_rect(Rect2(p+Vector2(part[0],part[1]),Vector2(part[2],part[3])),Color(part[4]))

