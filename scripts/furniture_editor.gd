extends RefCounted

const Furniture = preload("res://scripts/garden_furniture.gd")
const SUGGESTED = Furniture.DEFAULTS
var selected := "chair"
var pointer: Vector2 = SUGGESTED[0]
var cache_key := ""
var cached_error := ""

func open(g, kind: String = "chair") -> void:
	if g.state.scene!="library" or g.state.residents.is_empty():
		g._notify("스텔라를 한 명 맞이하면 도서관 안을 꾸밀 수 있어요.")
		return
	g.mode="furniture"
	g.route.clear()
	g.pending_object=""
	selected=kind
	var current := Furniture.find(g.state.furniture,kind)
	pointer=Furniture.position(current) if not current.is_empty() else SUGGESTED[Furniture.ORDER.find(kind)]
	cache_key=""

func error(g) -> String:
	var key := selected+str(pointer)+JSON.stringify(g.state.furniture)+str(g.player_pos)
	if cache_key!=key:
		cache_key=key
		cached_error=Furniture.placement_error(g.state.furniture,selected,pointer,g.player_pos)
	return cached_error

func changed(g) -> void:
	cache_key=""
	g._setup_map()
	g._save()

func action(g, id: String) -> void:
	if id.begins_with("pick_"):
		selected=id.trim_prefix("pick_")
		var current := Furniture.find(g.state.furniture,selected)
		pointer=Furniture.position(current) if not current.is_empty() else SUGGESTED[Furniture.ORDER.find(selected)]
		cache_key=""
	elif id=="done": g.mode="play"
	elif id=="store":
		if g.state.store_furniture(selected):
			changed(g)
			g._notify(Furniture.ITEMS[selected].name+"를 보관했어요. 언제든 다시 놓을 수 있어요.")
	elif id=="toggle":
		if g.state.toggle_furniture(selected): changed(g)
	elif id=="suggest":
		var count := 0
		for i in range(Furniture.ORDER.size()):
			var kind: String = Furniture.ORDER[i]
			if Furniture.find(g.state.furniture,kind).is_empty() and Furniture.placement_error(g.state.furniture,kind,SUGGESTED[i],g.player_pos)=="":
				if g.state.place_furniture(kind,SUGGESTED[i])=="": count+=1
		changed(g)
		g._notify("비어 있던 가구 %d개를 놓았어요. 완료를 누르면 스텔라가 찾아와요." % count)

func key(g, code: int) -> void:
	if code>=KEY_1 and code<=KEY_4: action(g,"pick_"+Furniture.ORDER[code-KEY_1])
	elif code in [KEY_ESCAPE,KEY_F]: action(g,"done")
	elif code in [KEY_DELETE,KEY_BACKSPACE]: action(g,"store")
	elif code==KEY_T: action(g,"toggle")

func click(g, point: Vector2) -> void:
	for item in g.state.furniture:
		if item.kind!=selected and Rect2(Furniture.position(item)-Vector2(36,58),Vector2(72,78)).has_point(point):
			selected=item.kind
			pointer=Furniture.position(item)
			cache_key=""
			return
	pointer=point.snapped(Vector2(16,16))
	var reason := error(g)
	if reason!="":
		g._notify(reason)
		return
	reason=g.state.place_furniture(selected,pointer)
	if reason!="":
		g._notify(reason)
		return
	changed(g)
	g._notify(Furniture.ITEMS[selected].name+" 배치 완료 · 다른 가구를 고르거나 Esc로 돌아가요.")

func draw_world(g) -> void:
	for x in range(112,865,16):
		for y in range(288,617,16): g.draw_rect(Rect2(x,y,1,1),Color(1,.94,.75,.22))
	var good := error(g)==""
	var color := Color("9cdbbb") if good else Color("e89989")
	var area := Furniture.zone(pointer)
	g.draw_rect(area,Color(color,.12))
	g.draw_rect(area,color,false,2)
	g.draw_line(pointer,pointer+Vector2(0,40),color,2)
	g.draw_rect(Rect2(pointer+Vector2(-4,36),Vector2(8,8)),color,false,2)
	Furniture.draw_back(g,selected,pointer)
	Furniture.draw_front(g,selected,pointer)
	g._world_sign(pointer+Vector2(0,60),"클릭해서 놓기" if good else "여기는 놓을 수 없어요")

func draw_ui(g) -> void:
	g._panel(Rect2(22,20,1236,63),g.PAPER)
	g._text(Vector2(43,47),"도서관 꾸미기",23)
	g._text(Vector2(43,69),"가구는 종류별 1개 · 자유롭게 배치하고 보관할 수 있어요",14,g.MUTED)
	g._button(Rect2(873,30,175,42),"추천 배치","furn_suggest")
	g._button(Rect2(1066,30,172,42),"완료   Esc","furn_done",true)
	g.ui_regions.append(Rect2(22,20,1236,63))
	var current := Furniture.find(g.state.furniture,selected)
	g._panel(Rect2(290,90,940,69),g.PAPER)
	g._text(Vector2(306,115),"1~4 선택  ·  바닥 클릭으로 배치/이동  ·  Delete 보관  ·  T 이용 켜기/끄기",14)
	g._text(Vector2(306,143),"도서관 안에서 함께 지내요. 에테·서가·업무 데스크 앞은 비워 두어요.",14,g.MUTED)
	g.ui_regions.append(Rect2(290,90,940,69))
	if not current.is_empty():
		g._button(Rect2(23,164,243,37),"자동 이용  "+("켜짐" if current.enabled else "꺼짐")+"   T","furn_toggle",current.enabled)
		g._button(Rect2(23,207,243,37),"선택 가구 보관  Delete","furn_store")
		g.ui_regions.append(Rect2(23,164,243,80))
	g._panel(Rect2(100,691,1080,98),g.PAPER)
	g.ui_regions.append(Rect2(100,691,1080,98))
	for i in range(Furniture.ORDER.size()):
		var kind: String = Furniture.ORDER[i]
		var rect := Rect2(111+i*267,702,256,75)
		g._panel(rect,Color("ffeab6") if selected==kind else Color("ead1a2"),g.GOLD)
		g._transform(rect.position+Vector2(33,49),Vector2(.58,.58))
		Furniture.draw_back(g,kind,Vector2.ZERO)
		Furniture.draw_front(g,kind,Vector2.ZERO)
		g._transform()
		g._text(rect.position+Vector2(66,25),str(i+1)+"  "+Furniture.ITEMS[kind].name,17)
		g._text(rect.position+Vector2(66,47),"보관 중 · 놓기" if Furniture.find(g.state.furniture,kind).is_empty() else "배치됨 · 옮기기",13,g.MUTED)
		g._text(rect.position+Vector2(66,65),Furniture.ITEMS[kind].detail,12,g.MUTED)
		g.buttons.append({"rect":rect,"id":"furn_pick_"+kind})
