extends RefCounted

# Inspection is local UI state. Previewing never equips, purchases or reserves a seat.
const Interactions = preload("res://scripts/stella_interactions.gd")
const Field = preload("res://scripts/field_sprites.gd")
const Pixels = preload("res://scripts/library_pixels.gd")
var selected := {}
var member_index := 0
var started := 0.0
var textures := {}

func action(g, id: String) -> bool:
	if id.begins_with("polish_item_"):
		selected[g.shop_tab]=id.trim_prefix("polish_item_")
		started=g.clock
		return true
	if id.begins_with("polish_member_"):
		member_index=clampi(int(id.trim_prefix("polish_member_")),0,5)
		started=g.clock
		return true
	if id.begins_with("growth_tab_"):
		if g.world_map_active() and ((g.world.vendor=="ete")!=(id=="growth_tab_upgrade")): return true
		g.shop_tab=id.trim_prefix("growth_tab_")
		started=g.clock
		return true
	return false

func draw(g) -> void:
	g._text(Vector2(165,193),("에테 · 도서관 능력 개선" if g.world.vendor=="ete" else "의문의 장인 · 제작 공방") if g.world_map_active() else "도서관 성장 상점",25)
	g._text(Vector2(165,225),"%d G  ·  기억의 빛 %d  ·  성장 %d단계" % [g.growth.gold,g.growth.memory_light,g.growth.rank()+1],18)
	var tabs := [["upgrade","도서관 능력"],["furniture","함께 쓰는 가구"],["costume","공개된 추가 의상"]]
	if g.world_map_active(): tabs=[tabs[0]] if g.world.vendor=="ete" else [tabs[1],tabs[2]]
	for i in range(tabs.size()): g._button(Rect2(165+i*310,244,294,39),tabs[i][1],"growth_tab_"+tabs[i][0],g.shop_tab==tabs[i][0])
	var catalogue: Dictionary=g.growth.catalogue(g.shop_tab)
	if catalogue.is_empty(): return
	var pick: String=selected.get(g.shop_tab,"")
	if not catalogue.has(pick): pick=catalogue.keys()[0]; selected[g.shop_tab]=pick
	var row := 0
	for id in catalogue:
		var item: Dictionary=catalogue[id]
		var y := 299+row*75
		g._panel(Rect2(158,y,510,68),Color("f5e4bd") if pick==id else Color("e5cea6"))
		if pick==id: g.draw_rect(Rect2(166,y+12,4,44),Color("a57743"))
		g._text(Vector2(182,y+27),item.label,18)
		g._text(Vector2(182,y+52),"%d G  ·  성장 %d단계" % [item.price,item.rank+1],16,g.MUTED)
		g.buttons.append({"rect":Rect2(172,y+4,326,60),"id":"polish_item_"+id})
		var owned: bool=(g.shop_tab=="furniture" and id in g.growth.owned_furniture) or (g.shop_tab=="costume" and id in g.growth.owned_costumes) or (g.shop_tab=="upgrade" and g.growth.has_upgrade(id))
		var error: String=g.growth.purchase_error(g.shop_tab,id,6)
		var label: String="배치하기" if owned and g.shop_tab=="furniture" else "착용하기" if owned and g.shop_tab=="costume" else "이용 중" if owned else "재개관 후" if g.growth.phase!="open" else "성장 %d단계" % (item.rank+1) if g.growth.rank()<item.rank else "골드 부족" if g.growth.gold<item.price else "구매하기"
		g._button(Rect2(510,y+16,140,37),label,"growth_buy_"+id,true,(owned and g.shop_tab=="upgrade") or (not owned and error!=""))
		row+=1
	_preview(g,catalogue[pick])
	g._text(Vector2(165,633),"목록을 눌러 먼저 살펴보세요. 다른 멤버의 공개 의상은 확인 중이에요." if g.shop_tab=="costume" else "목록에서 고르고, 오른쪽에서 실제 이용 모습을 먼저 살펴보세요." if g.shop_tab=="furniture" else "기억의 빛으로 단계를 열고 골드로 개선해요. 빛은 줄어들지 않아요.",17,g.MUTED)

func _preview(g,item: Dictionary) -> void:
	var box := Rect2(685,299,432,305)
	g._panel(box,Color("d6c5a2"))
	if g.shop_tab=="upgrade":
		g._text(Vector2(710,337),item.label,21)
		g._text_block(Vector2(710,386),item.get("description",""),370,19,g.CREAM)
		g._text_block(Vector2(710,485),"구매하면 도서관 전체에 적용돼요. 가구와 의상은 옆 탭에서 움직이는 모습을 확인할 수 있어요.",366,17,g.MUTED)
		return
	var member: String=item.get("member",g.MEMBERS[member_index].id)
	var costume: String=item.id if g.shop_tab=="costume" else g._costume_key(member)
	var animation: String=item.action if g.shop_tab=="furniture" else Interactions.click_actions(member)[0]
	var elapsed: float=fmod(maxf(0,g.clock-started),8.0)
	var action_data: Dictionary=Interactions.definition(member,animation)
	var column: int=Interactions.Samples.furniture(animation,elapsed,8.0) if g.shop_tab=="furniture" else Interactions.Samples.gesture(action_data.durations,fmod(elapsed,Interactions.duration(member,animation)+1.0),action_data.get("travel_seconds",[]))
	# The output window, rather than a fractional world zoom, sets the pixel grid.
	var screen_scale: float=g.get_window().size.x/1280.0
	var scale: float=2.0/screen_scale
	var feet := Vector2(907,566)
	var title: String=g.MEMBERS[g._mission_index_for(member)].short+" · "+(g.Furniture.ITEMS[item.kind].detail if g.shop_tab=="furniture" else "추가 의상 미리보기")
	g._text(Vector2(707,327),title,17)
	g.draw_rect(Rect2(704,552,394,28),Color("bca78a"))
	for x in range(708,1095,34): g.draw_line(Vector2(x,553),Vector2(x+14,579),Color("aa9277"),1)
	if g.shop_tab=="furniture": _furniture(g,item.kind,feet,scale,false)
	var tex := _texture(member,costume)
	var position := (feet-Field.FOOT*scale)*screen_scale
	position=position.round()/screen_scale
	g.draw_texture_rect_region(tex,Rect2(position,Vector2(Field.CELL)*scale),Rect2(column*96,int(action_data.row)*112,96,112))
	if g.shop_tab=="furniture": _furniture(g,item.kind,feet,scale,true)
	if g.shop_tab=="furniture":
		for i in range(6): g._button(Rect2(702+i*66,581,62,25),g.MEMBERS[i].short,"polish_member_%d"%i,member_index==i)
	else:
		g._text(Vector2(708,594),"공식 공개 · "+item.get("released","확인된 의상"),16,g.MUTED)

func _texture(member: String,costume: String) -> CanvasTexture:
	if not textures.has(costume):
		var tex := CanvasTexture.new()
		tex.diffuse_texture=Interactions.sheet_for(member,costume)
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[costume]=tex
	return textures[costume]

func _furniture(g,kind: String,feet: Vector2,scale: float,front: bool) -> void:
	if front and kind not in ["chair","tea"]: return
	var id := kind+("_front" if front else "_back")
	Pixels.sprite(g,id,feet,scale*2.0/Field.STELLA_SCALE)
