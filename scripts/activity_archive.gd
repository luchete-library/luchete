extends RefCounted

# Read-only real-world activity records, kept apart from the playable debut books.
const CATALOG = preload("res://assets/records/library_events.json")
const POSITION := Vector2(195,279)
const HIT_RECT := Rect2(90,164,200,110)
const MODES := ["archive_shelf","archive_book"]
const PAPER := Color("f4e7c8")
const INK := Color("513c30")
const MUTED := Color("826b52")
const SPINES := [Rect2(329,193,86,392),Rect2(419,193,86,392),Rect2(507,193,86,392),Rect2(595,193,86,392),Rect2(683,193,86,392),Rect2(772,193,86,392),Rect2(860,193,88,392)]
const PLAQUES := [Rect2(264,611,101,34),Rect2(373,611,101,34),Rect2(481,611,101,34),Rect2(590,611,101,34),Rect2(697,611,101,34),Rect2(806,611,101,34),Rect2(914,611,112,34)]
const CONTENT_ROWS := 5
const SHELF_TEXTURE = preload("res://assets/ui/broadcast_bookshelf.png")
var volume := 0
var page := 0

func active(g) -> bool:
	return g.mode in MODES

func open(g) -> void:
	if g.mode!="play" or g.state.scene!="library": return
	g.route.clear()
	g.pending_object=""
	g.character_touch.cancel()
	g.buttons.clear()
	g.toast_time=0
	g.mode="archive_shelf"
	g.queue_redraw()

func back(g) -> void:
	g.mode="archive_shelf" if g.mode=="archive_book" else "play"
	g.buttons.clear()
	g.queue_redraw()

func book() -> Dictionary:
	return CATALOG.data.volumes[volume]

func entry() -> Dictionary:
	return book().entries[page]

func choose(g, index: int) -> void:
	volume=clampi(index,0,CATALOG.data.volumes.size()-1)
	page=0
	g.mode="archive_book"
	g.buttons.clear()
	g.queue_redraw()

func turn(g, direction: int) -> void:
	page=clampi(page+direction,0,book().entries.size()-1)
	g.queue_redraw()

func input(g, event: InputEvent) -> bool:
	if not active(g): return false
	if event is InputEventMouseMotion and g.mode=="archive_shelf":
		for i in range(SPINES.size()):
			var slot: Rect2=SPINES[i]
			var plaque: Rect2=PLAQUES[i]
			if slot.grow(4).has_point(event.position) or plaque.has_point(event.position):
				volume=i
				g.queue_redraw()
				break
		return true
	if event is InputEventKey:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key in [KEY_F11,KEY_F5]: return false
		if not event.pressed or event.echo: return true
		if key==KEY_ESCAPE:
			back(g)
		elif g.mode=="archive_shelf":
			if key>=KEY_1 and key<KEY_1+CATALOG.data.volumes.size(): choose(g,key-KEY_1)
			elif key in [KEY_LEFT,KEY_A]: volume=posmod(volume-1,CATALOG.data.volumes.size())
			elif key in [KEY_RIGHT,KEY_D]: volume=(volume+1)%CATALOG.data.volumes.size()
			elif key in [KEY_E,KEY_ENTER,KEY_SPACE]: choose(g,volume)
		else:
			if key in [KEY_LEFT,KEY_UP,KEY_A,KEY_W]: turn(g,-1)
			elif key in [KEY_RIGHT,KEY_DOWN,KEY_D,KEY_S,KEY_E,KEY_ENTER,KEY_SPACE]: turn(g,1)
			elif key>=KEY_1 and key<=KEY_5 and contents_start()+key-KEY_1<book().entries.size(): page=contents_start()+key-KEY_1
		g.queue_redraw()
		return true
	if event is InputEventMouseButton:
		if not event.pressed: return true
		if event.button_index==MOUSE_BUTTON_RIGHT:
			back(g)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and g.mode=="archive_book":
			turn(g,-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			for button in g.buttons.duplicate():
				if button.id.begins_with("archive_") and button.rect.has_point(event.position):
					g._action(button.id)
					break
		return true
	return false

func action(g, id: String) -> bool:
	if not id.begins_with("archive_"): return false
	if not active(g): return true
	if id=="archive_back": back(g)
	elif id.begins_with("archive_volume_") and g.mode=="archive_shelf":
		var index:=id.trim_prefix("archive_volume_")
		if index.is_valid_int() and int(index)>=0 and int(index)<CATALOG.data.volumes.size(): choose(g,int(index))
	elif g.mode=="archive_book":
		if id=="archive_contents_prev": contents_turn(g,-1)
		elif id=="archive_contents_next": contents_turn(g,1)
		elif id=="archive_prev": turn(g,-1)
		elif id=="archive_next": turn(g,1)
		elif id.begins_with("archive_page_"):
			var index:=id.trim_prefix("archive_page_")
			if index.is_valid_int() and int(index)>=0 and int(index)<book().entries.size(): page=int(index)
		elif id.begins_with("archive_source_"):
			var index:=id.trim_prefix("archive_source_")
			if index.is_valid_int() and int(index)>=0 and int(index)<entry().sources.size():
				g._open_archive_source(entry().sources[int(index)].url)
	g.queue_redraw()
	return true

static func draw_world(g) -> void:
	g.Pixels.sprite(g,"shelf_west_0",Vector2(86,154))
	g.draw_texture_rect_region(g.Pixels.texture("shelf_west_6"),Rect2(94,162,200,35),Rect2(8,8,200,35))
	for i in range(CATALOG.data.volumes.size()):
		var tone:=Color(CATALOG.data.volumes[i].color)
		var x:=103+i*26
		g.Pixels.book(g,Vector2(x+2,216),tone,false,1.0)
		g.draw_rect(Rect2(x+4,220,13,1),Color("ead39d"))
		g.draw_rect(Rect2(x+4,237,13,1),Color("ead39d"))
		g.draw_rect(Rect2(x+10,226,2,6),Color("f3dfb3"))
		g.draw_rect(Rect2(x+8,228,6,2),Color("f3dfb3"))
		g.draw_rect(Rect2(x,245,21,3),tone)
		g.draw_rect(Rect2(x,245,21,1),tone.lightened(.2))
	var sign:=Rect2(125,249,140,21)
	g.draw_rect(Rect2(sign.position+Vector2(1,2),sign.size),Color("392c27"))
	g.draw_rect(sign,Color("a67b4a"))
	g.draw_rect(sign.grow(-1),Color("e7c487"))
	g.draw_line(sign.position+Vector2(2,2),sign.position+Vector2(138,2),Color("f8dfaa"),1)
	g._center(264,"방송 기록 전용 서가",12,Color("49382d"),195)


func draw(g) -> void:
	if g.mode=="archive_shelf": draw_shelf(g)
	else: draw_book(g)

func contents_start() -> int:
	return floori(page/float(CONTENT_ROWS))*CONTENT_ROWS

func contents_turn(g, direction: int) -> void:
	var last:=floori((book().entries.size()-1)/float(CONTENT_ROWS))*CONTENT_ROWS
	page=clampi(contents_start()+direction*CONTENT_ROWS,0,last)
	g.buttons.clear()
	g.queue_redraw()

func draw_shelf(g) -> void:
	g.draw_texture_rect(SHELF_TEXTURE,Rect2(0,0,1280,800),false)
	var foil:=Color("f9e2a7")
	g._center(112,"방송 기록 서가",28,foil)
	g._text(Vector2(156,111),"루체테  /  열람실",18,foil)
	g._center(113,"나가기  Esc",19,INK,1076)
	g.buttons.append({"rect":Rect2(1003,84,145,42),"id":"archive_back"})
	for i in range(SPINES.size()):
		var slot: Rect2=SPINES[i]
		var data: Dictionary=CATALOG.data.volumes[i]
		var cx:=slot.get_center().x
		g._center(244,"L · %02d"%(i+1),17,foil,cx)
		var title: String=data.title
		var step:=27
		var height: int=(title.length()-title.count(" "))*step+title.count(" ")*8
		var y:=378-height/2.0+22
		for letter in title:
			if letter==" ": y+=8
			else:
				g._center(y+1,letter,24,Color("482a24"),cx+1)
				g._center(y,letter,24,foil,cx)
				y+=step
		var plaque: Rect2=PLAQUES[i]
		g._center(634,data.title,16,INK,plaque.get_center().x)
		if i==volume:
			g.draw_rect(slot.grow(2),Color("f7d288"),false,2)
			g.draw_rect(plaque.grow(-3),Color("c88a39"),false,2)
		g.buttons.append({"rect":slot,"id":"archive_volume_%d"%i})
		g.buttons.append({"rect":plaque,"id":"archive_volume_%d"%i})
	var chosen: Dictionary=book()
	g._center(686,"『%s』 · 기록 %d편"%[chosen.title,chosen.entries.size()],18,foil)
	g._center(716,"책등 클릭 · 1~7 고르기 · E 펼치기 · Esc 닫기",16,foil)

func draw_book(g) -> void:
	var data:=book()
	var record:=entry()
	var accent:=Color(data.color)
	# Thick cloth cover, stepped page edges and a shadowed gutter form an open album.
	g.draw_rect(Rect2(73,102,1140,612),Color("201d1c"))
	g.Pixels.panel(g,Rect2(65,90,1150,612),accent.darkened(.25))
	for i in range(3):
		g.draw_rect(Rect2(87+i*3,112-i*3,1106-i*6,566),Color("c5af88").lightened(i*.07))
	g.draw_rect(Rect2(99,106,528,562),PAPER)
	g.draw_rect(Rect2(653,106,528,562),Color("f9edcf"))
	for i in range(6):
		g.draw_rect(Rect2(627+i*2,108,2,558),Color("c1a578").darkened(i*.04))
		g.draw_rect(Rect2(641+i*2,108,2,558),Color("c1a578").darkened((5-i)*.04))
	for i in range(15):
		g.draw_rect(Rect2(116+(i*61)%492,119+(i*37)%520,3,1),Color("ac865722"))
		g.draw_rect(Rect2(676+(i*73)%472,128+(i*43)%512,3,1),Color("ac865722"))
	g._text(Vector2(130,148),data.title,27,INK)
	g._text(Vector2(130,180),"루체테 활동 기록  ·  목차",15,MUTED)
	g._text_block(Vector2(130,213),data.intro,462,17,MUTED,25)
	for i in range(contents_start(),mini(contents_start()+CONTENT_ROWS,data.entries.size())):
		var row: Dictionary=data.entries[i]
		var rect:=Rect2(127,255+(i-contents_start())*65,466,58)
		var selected:=i==page
		if selected or rect.has_point(g.get_global_mouse_position()):
			g.draw_rect(rect,Color("e5d3ad") if selected else Color("eee0bf"))
		g.draw_rect(Rect2(rect.position,Vector2(4,rect.size.y)),accent if selected else Color("d5c19c"))
		g._text(rect.position+Vector2(14,24),"%d   %s"%[i-contents_start()+1,row.title],18,INK)
		g._text(rect.position+Vector2(48,47),row.date,14,MUTED)
		g.buttons.append({"rect":rect,"id":"archive_page_%d"%i})
	g._button(Rect2(129,589,102,33),"← 목차","archive_contents_prev",false,contents_start()==0)
	g._button(Rect2(490,589,102,33),"목차 →","archive_contents_next",false,contents_start()+CONTENT_ROWS>=data.entries.size())
	g._center(612,"목차 %d / %d"%[contents_start()/CONTENT_ROWS+1,ceili(data.entries.size()/float(CONTENT_ROWS))],15,MUTED,362)
	g._text(Vector2(130,649),"1~5 선택 · ← → 넘기기 · 휠 이동",13,MUTED)
	var announced: bool=record.status=="announced"
	g.draw_rect(Rect2(684,129,announced_size(announced),27),Color("b98546") if announced else accent)
	g._text(Vector2(695,148),"예정 공지 · 확인 당시" if announced else "공개 활동 기록",14,Color("fff3d2"))
	g._text(Vector2(684,196),record.title,24,INK)
	g._text(Vector2(684,233),record.date,21,accent.darkened(.18))
	g._text_block(Vector2(684,261),record.date_note,459,14,MUTED,22)
	g.draw_line(Vector2(684,298),Vector2(1149,298),Color("ccb690"),1)
	g._text_block(Vector2(684,332),record.body,459,19,INK,30)
	g._text_block(Vector2(684,497),record.note,459,15,MUTED,23)
	var source_width: float=(465.0-(record.sources.size()-1)*12.0)/record.sources.size()
	for i in range(record.sources.size()):
		g._button(Rect2(684+i*(source_width+12),577,source_width,42),record.sources[i].label+"  ↗","archive_source_%d"%i)
	g._text(Vector2(684,647),"출처를 누르면 외부 브라우저에서 열려요.",14,MUTED)
	g._button(Rect2(89,723,193,43),"책장에 돌려놓기  Esc","archive_back")
	g._button(Rect2(886,723,116,43),"← 이전","archive_prev",false,page==0)
	g._button(Rect2(1016,723,116,43),"다음 →","archive_next",false,page==data.entries.size()-1)
	g._center(750,"%02d / %02d"%[page+1,data.entries.size()],17,Color("eddfbc"))

func announced_size(announced: bool) -> int:
	return 174 if announced else 132
