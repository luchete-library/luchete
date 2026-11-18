extends "res://scripts/furniture_editor.gd"

const Layout=preload("res://scripts/library_world_layout.gd")

func open(g,kind: String="chair") -> void:
	super.open(g,kind)
	if g.world_map_active() and Furniture.find(g.state.furniture,kind).is_empty(): pointer=Layout.FURNITURE[kind]

func action(g,id: String) -> void:
	if not g.world_map_active(): super.action(g,id);return
	if id=="suggest":
		var count:=0
		for kind in g.growth.owned_furniture:
			if Furniture.find(g.state.furniture,kind).is_empty() and Layout.placement_error(g.state.furniture,kind,Layout.FURNITURE[kind],g.player_pos)=="":
				if g.state.place_furniture(kind,Layout.FURNITURE[kind])=="": count+=1
		changed(g);g._notify("보유한 가구 %d개를 추천 위치에 놓았어요."%count)
		return
	super.action(g,id)
	if id.begins_with("pick_") and Furniture.find(g.state.furniture,selected).is_empty(): pointer=Layout.FURNITURE[selected]

func error(g) -> String:
	if selected not in g.growth.owned_furniture: return "의문의 장인에게 구매하면 배치할 수 있어요."
	if g.world_map_active():
		var key:=selected+str(pointer)+JSON.stringify(g.state.furniture)+str(g.player_pos)
		if cache_key!=key:
			cache_key=key;cached_error=Layout.placement_error(g.state.furniture,selected,pointer,g.player_pos)
		return cached_error
	return super.error(g)

func draw_world(g) -> void:
	if not g.world_map_active(): super.draw_world(g);return
	for x in range(320,1201,16):
		for y in range(592,728,16):
			if g._walkable(Vector2(x,y)): g.draw_rect(Rect2(x,y,1,1),Color(1,.94,.75,.3))
	var good:=error(g)==""
	var color:=Color("9cdbbb") if good else Color("e89989")
	g.draw_rect(Furniture.zone(pointer),Color(color,.15))
	g.draw_rect(Furniture.zone(pointer),color,false,2)
	Furniture.draw_back(g,selected,pointer);Furniture.draw_front(g,selected,pointer)
	g._world_sign(pointer+Vector2(0,60),"클릭해서 놓기" if good else "여기는 놓을 수 없어요")

func draw_ui(g) -> void:
	super.draw_ui(g)
	for i in range(Furniture.ORDER.size()):
		var kind: String=Furniture.ORDER[i]
		if kind in g.growth.owned_furniture: continue
		var pos:=Vector2(111+i*267,702)
		g.draw_rect(Rect2(pos+Vector2(64,31),Vector2(185,42)),Color("ead1a2"))
		g._text(pos+Vector2(66,49),"구매 전 · 의문의 장인에게 구입",12,g.MUTED)
		g._text(pos+Vector2(66,66),"모든 스텔라가 이용 가능",12,g.MUTED)
