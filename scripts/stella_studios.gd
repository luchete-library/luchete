extends RefCounted

# Screen-space rooms share the lobby's projection for actor drawing and hit testing.
const SCALE := 0.76
const OFFSET := Vector2(-6,70)
const CELL := 176
const ATLAS := preload("res://assets/studio_pixels/rooms.png")
const CLOSEUP := preload("res://assets/studio_pixels/rooms_closeup.png")
const DOOR := Vector2(896,364)
static var native_texture: CanvasTexture
static var closeup_texture: CanvasTexture
const GREETINGS := {
	"yato":{"welcome":"어, 여기야! 잘 찾아왔네!","cheer":"왔구나! 잠깐 숨 돌리고 가."},
	"danming":{"welcome":"똑똑! 내가 먼저 인사하려고 했는데.","heart":"손 펴 봐. 짠, 하트 하나!"},
	"kubby":{"rhythm":"짝, 짝! 이게 오늘의 인사야!","curious":"어라? 반가운 발소리가 들리더라!"},
	"yune":{"welcome":"안녕. 나도 방금 네 생각 했어.","listen":"응, 들려. 살짝 와 줬구나."},
	"dori":{"salute":"발소리로 맞혔어. 어서 와!","inspect":"잠깐, 그 발자국… 역시 너였어!"},
	"fuwa":{"welcome":"곰방후와! 여기까지 잘 왔어?","resolve":"후와이팅! 오늘도 얼굴 봐서 좋다!"}
}

static func room(index: int) -> Rect2:
	return Rect2(Vector2(723 + (index%3)*184,179 + floori(index/3.0)*218),Vector2(CELL,CELL))

static func feet(index: int, on_air:=false) -> Vector2:
	var anchor:=Vector2(87,145)
	if on_air:
		# Fuwa's set has a floor cushion. The other hosts stand behind their desks.
		anchor=Vector2(139,134) if index==5 else Vector2(87,170)
	return (room(index).position+anchor-OFFSET)/SCALE

static func draw_passage(g) -> void:
	var threshold:=DOOR+Vector2(-3,-19)
	g.draw_rect(Rect2(threshold,Vector2(33,38)),Color("443838"))
	g.draw_rect(Rect2(threshold+Vector2(0,4),Vector2(30,30)),Color("977351"))
	for x in [2,9,17,24]:
		g.draw_rect(Rect2(threshold+Vector2(x,4),Vector2(2,30)),Color("c59b6d"))
	for y in [0,34]:
		g.draw_rect(Rect2(threshold+Vector2(0,y),Vector2(33,4)),Color("78523d"))
		g.draw_line(threshold+Vector2(1,y),threshold+Vector2(31,y),Color("d1ae79"),1)

static func paint(g, index: int, dest: Rect2, front: bool) -> void:
	var span := maxf(dest.size.x,dest.size.y)
	var detailed := not front and span>CELL
	if native_texture==null:
		native_texture=CanvasTexture.new()
		native_texture.diffuse_texture=ATLAS
		native_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if detailed and closeup_texture==null:
		closeup_texture=CanvasTexture.new()
		closeup_texture.diffuse_texture=CLOSEUP
		closeup_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := CLOSEUP.get_width()/3.0 if detailed else float(CELL)
	var origin := Vector2(index%3,floori(index/3.0)+(2 if front else 0))*cell
	# Preserve prop proportions in both the square overview and the close-up.
	var visible := dest.size*(cell/span)
	origin+=Vector2((cell-visible.x)*.5,cell-visible.y)
	g.draw_texture_rect_region(closeup_texture if detailed else native_texture,dest,Rect2(origin,visible))

static func layer(g, front: bool) -> void:
	for i in range(g.MEMBERS.size()):
		# Fuwa sits on a floor cushion in the overview; her near desk is a camera prop.
		if front and g.MEMBERS[i].id=="fuwa": continue
		var dest := room(i)
		if not front:
			g.draw_rect(dest.grow(3),Color("302b2a"))
			g.draw_rect(dest.grow(2),Color("b79770"),false,1)
		paint(g,i,dest,front)

static func hovered_resident(g, pointer: Vector2) -> Dictionary:
	if not g.split_view() or g.mode!="play" or g.character_touch.held!="" or g.character_touch.dragging: return {}
	for npc in g.objects:
		if npc.get("type","")!="npc" or not npc.get("in_studio",false) or npc.get("promo_away",false): continue
		if not room(npc.index).has_point(pointer): continue
		var world_pointer: Vector2=(pointer-g.WORLD_OFFSET)/g.WORLD_SCALE
		if g.Field.stella_hit_rect(g._costume_key(npc.id),npc.pos).has_point(world_pointer): return npc
	return {}

static func draw_hover_name(g, pointer: Vector2) -> void:
	var npc:=hovered_resident(g,pointer)
	if npc.is_empty(): return
	var member: Dictionary=g.MEMBERS[npc.index]
	var area:=room(npc.index)
	var bounds: Rect2=g.Field.stella_hit_rect(g._costume_key(npc.id),npc.pos)
	var feet: Vector2=npc.pos*g.WORLD_SCALE+g.WORLD_OFFSET
	var top: float=bounds.position.y*g.WORLD_SCALE+g.WORLD_OFFSET.y
	var width: float=g.font.get_string_size(member.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+26
	var x:=clampf(feet.x-width*.5,area.position.x+4,area.end.x-width-4)
	var y:=maxf(area.position.y+4,top-32)
	# Keep the name clear of a greeting bubble and the character's face.
	if g.character_touch.reactions.get(npc.id,{}).get("greeting","")!="": y=area.end.y-31
	var plaque:=Rect2(x,y,width,27)
	g._panel(plaque,g.PAPER)
	g.draw_rect(Rect2(plaque.position+Vector2(4,5),Vector2(2,17)),Color(member.color))
	g._text(plaque.position+Vector2(14,19),member.name,15,g.CREAM)
	# Display only: no hit region, so clicks and dragging still reach the resident.

static func labels(g) -> void:
	g._text(Vector2(23,165),"공용 도서관",18,Color("f1dfb7"))
	g._text(Vector2(723,165),"스텔라 개인실",18,Color("f1dfb7"))
	for i in range(g.MEMBERS.size()):
		var member: Dictionary=g.MEMBERS[i]
		var npc: Dictionary=g._find_object(member.id)
		var area := room(i)
		var plaque := Rect2(Vector2(area.position.x,area.end.y+2),Vector2(CELL,28))
		var at_home: bool=npc.get("in_studio",false)
		var status := "개인실" if at_home else "도서관"
		if g.state.ink_visits.promoting(member.id):
			status="방송 중" if g.state.ink_visits.topic==0 else ("외출 중" if npc.get("promo_away",false) else "외출 준비")
		elif g.state.yard_host==member.id: status="방송 중"
		elif g.state.yard_session.get("member","")==member.id: status="운동 중"
		var hover: bool=g.mode=="play" and plaque.has_point(g.get_global_mouse_position())
		if hover and at_home: status="채팅 열기" if status=="방송 중" else "인사하기"
		g.draw_rect(plaque,Color("584b40") if hover else Color("3e3733"))
		g.draw_rect(Rect2(plaque.position,Vector2(3,28)),Color(member.color))
		g._text(plaque.position+Vector2(11,19),member.short,15,Color("f6e8cb"))
		var width: float=g.font.get_string_size(status,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		g._text(plaque.position+Vector2(CELL-width-10,19),status,13,Color("ffe0a3") if status=="방송 중" else Color("d5c6ac"))
		if g.mode=="play": g.buttons.append({"rect":plaque,"id":"studio_"+member.id})
		var greeting: String=g.character_touch.reactions.get(member.id,{}).get("greeting","")
		if at_home and greeting!="" and g.mode=="play":
			var bubble:=Rect2(area.position+Vector2(4,5),Vector2(CELL-8,51))
			g._panel(bubble,g.PAPER)
			g._text_block(bubble.position+Vector2(9,20),greeting,bubble.size.x-18,14,g.CREAM,18)
	draw_hover_name(g,g.get_global_mouse_position())
