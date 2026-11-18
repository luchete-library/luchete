extends RefCounted

const VOLUMES := {
	"yato": preload("res://assets/encounters/yato.json"),
	"danming": preload("res://assets/encounters/danming.json"),
	"kubby": preload("res://assets/encounters/kubby.json"),
	"yune": preload("res://assets/encounters/yune.json"),
	"dori": preload("res://assets/encounters/dori.json"),
	"fuwa": preload("res://assets/encounters/fuwa.json"),
}

# Original pixel bookplates. Each depicts the motif of the book.
const PLATES := {
	"yato": ["    aa  aa    ","    aa  aa    ","    ap  ap    ","    ap  ap    ","    aa  aa    ","   waaaaaaw   ","  waaaaaaaaw  ","  waakaakaaw  ","   aaaapaa    ","   waaaaaw    ","  aaawwwaaa   "],
	"danming": ["     k  k     ","   ww kk ww   ","  waaw wwaaw  ","   wwwwwwww   ","   kaaakkaa   ","  kaaakkkaaak ","  kakkkaakaak ","   kkkaaakaa  ","    kaaaaka   ","      k k     "],
	"kubby": ["    aa   aa   ","   apaa aapa  ","   aaaaaaaa   ","  aaaaaaaawaa ","  aakaaaakaaa ","  aaappppaaaa ","   aapwwpaaa  ","    aaawaaa   ","     aaawa    ","      aaa     "],
	"yune": ["   k     k    ","   kp   pk    ","   kkkkkkk    ","  kkkkkkkkk   ","  kwpkkkpwk   ","  kkwkkkwkk   ","  kkkkpkkkk pp","   kkkkkkk pwp","   kkkkkkkppp ","    kk kk     "],
	"dori": ["   kkkkkkkk   ","  kpwwwwwwwk  ","  kawwaawwak  ","  kaaawwaaak  ","   kkkkkkkk k ","           kk ","      kkkkkk  ","     kk       ","    pkk       ","   ppk        ","  ppk         "],
	"fuwa": ["   ww  ww   w ","  waawwaaw waw","   ww  ww   w "," w            ","waw   www     "," w   waaaw    ","    waaaaaw   ","   waaaaaaaw  ","   waawwwaaw  ","    ww   ww   "],
}

static func stamp(g, id: String, center: Vector2, scale: int, accent: Color, faded: bool = false) -> void:
	var colors := {"a":accent,"w":Color("fff1cd"),"k":Color("493d4c"),"p":Color("c792ac")}
	if id == "yune":
		colors.k = Color("211e30")
		colors.p = Color("bc8de2")
	if id == "yato": colors.a = Color("ecdfca")
	if id == "danming": colors.a = Color("e4ad54")
	if id == "kubby": colors.a = Color("9cd1ad")
	if faded:
		for symbol in colors:
			var gray: float = colors[symbol].get_luminance()
			colors[symbol] = Color(gray,gray,gray)
	var rows: Array = PLATES[id]
	var top := center - Vector2(7*scale, floori(rows.size()*scale/2.0))
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if colors.has(row[x]):
				g.draw_rect(Rect2(top+Vector2(x,y)*scale,Vector2(scale,scale)),colors[row[x]])

# A sealed final page already has its name, even before the walk home.
static func titled(state, id: String) -> bool:
	return state.chapter_steps.get(id,0) == 3 or (state.page_complete and state.active_mission == id)

static func shelf_title(state, id: String) -> String:
	var book: Dictionary = VOLUMES[id].data
	return book.title if titled(state,id) else book.working_title

const FADED_CLOTH := Color("b4b4b4")

static func book_cloth(accent: Color, remembered: bool) -> Color:
	if not remembered: return FADED_CLOTH
	return Color.from_hsv(accent.h,clampf(accent.s*1.3+0.18,0.50,0.77),clampf(accent.v*0.80,0.54,0.72))

static func memory_star(g, pos: Vector2, radius: float, accent: Color) -> void:
	var pulse := 0.5+0.5*sin(g.clock*1.6+pos.x*0.09)
	var light := accent.lightened(0.38)
	for ring in range(3,0,-1):
		g.draw_circle(pos,radius*(1.0+ring*0.48+pulse*0.15),Color(light,0.045))
	g._star(pos,radius*(0.86+0.14*pulse),Color("ffedb2"))
	g._star(pos+Vector2(radius*1.35,-radius*0.8),radius*0.30,Color("fff6df"))

const WOOD := Color("684631")
const DARK_WOOD := Color("382a28")
const BRASS := Color("dfbc7b")
const CREAM_INK := Color("f9e9bf")
const SPINE_HEIGHT := [323,304,337,318,299,331]
const SPINE_WIDTH := [113,121,106,122,111,119]

static func timber(g, rect: Rect2, tone: Color) -> void:
	g.draw_rect(rect,tone)
	g.draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),tone.lightened(0.23))
	g.draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-4),Vector2(rect.size.x,4)),tone.darkened(0.32))
	for i in range(1,4):
		var y := rect.position.y+floorf(rect.size.y*i/4.0)
		g.draw_line(Vector2(rect.position.x+5,y),Vector2(rect.end.x-5,y),tone.darkened(0.12),1)
	for x in range(int(rect.position.x+20),int(rect.end.x-42),73):
		var y := rect.position.y+6+posmod(x, maxi(2,int(rect.size.y)-13))
		g.draw_line(Vector2(x,y),Vector2(x+25,y),tone.lightened(0.09),1)

static func bookend(g, x: float, bottom: float, dir: int) -> void:
	var p := Vector2(x,bottom)
	g.draw_colored_polygon(PackedVector2Array([p,p+Vector2(0,-81),p+Vector2(10*dir,-81),
		p+Vector2(16*dir,-42),p+Vector2(46*dir,-13),p+Vector2(50*dir,-6),p+Vector2(50*dir,0)]),Color("977947"))
	g.draw_line(p+Vector2(6*dir,-73),p+Vector2(12*dir,-35),BRASS,2)
	g.draw_rect(Rect2(minf(x,x+dir*55),bottom-7,55,7),Color("c39a59"))

static func shelf_details(g) -> void:
	# An amber reading lamp and two returned books frame the catalogued volumes.
	var lamp := Vector2(184,511)
	for radius in [62,47,32]:
		g.draw_circle(lamp,radius,Color(0.98,0.73,0.35,0.035))
	g.draw_rect(Rect2(168,560,32,4),Color("947447"))
	g.draw_rect(Rect2(180,516,7,44),Color("967a4c"))
	g.draw_rect(Rect2(182,516,2,44),BRASS)
	g.draw_colored_polygon(PackedVector2Array([Vector2(169,480),Vector2(198,480),Vector2(211,509),Vector2(157,509)]),Color("aca06e"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(178,481),Vector2(190,481),Vector2(194,508),Vector2(173,508)]),Color("d9c48b"))
	g.draw_rect(Rect2(155,509,57,4),Color("e6c985"))
	for i in range(2):
		var x := 1043+i*7
		var y := 553-i*15
		g.draw_rect(Rect2(x,y-3,77-i*9,14),Color("734f46") if i == 0 else Color("596759"))
		g.draw_rect(Rect2(x+5,y,70-i*9,7),Color("c7b797"))
		g.draw_line(Vector2(x+11,y+4),Vector2(x+69-i*9,y+4),Color("afa183"))

static func draw_spine(g, rect: Rect2, member: Dictionary, index: int, revealed: bool, title: String) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var center := rect.get_center().x
	var accent := Color(member.color)
	var cover := book_cloth(accent,revealed)
	var foil := Color("fff0bb") if revealed else Color("484848")
	var ink := Color("fff5d4") if revealed else Color("363636")
	if revealed:
		for margin in [7,4,2]:
			g.draw_rect(rect.grow(margin),Color(accent,0.10),false,2)
	g.draw_rect(Rect2(rect.position+Vector2(5,3),rect.size),Color("241e1c"))
	g.draw_rect(rect,cover.darkened(0.34))
	g.draw_rect(Rect2(x+4,y+2,w-10,h-3),cover)
	g.draw_rect(Rect2(x+7,y+3,6,h-5),cover.lightened(0.15))
	g.draw_rect(Rect2(rect.end.x-10,y+3,4,h-5),cover.darkened(0.22))
	for at in [y+10,y+37,rect.end.y-45,rect.end.y-11]:
		g.draw_rect(Rect2(x+3,at,w-7,4),cover.darkened(0.28))
		g.draw_rect(Rect2(x+4,at,w-9,1),foil)
	g._center(y+32,"L · %02d" % (index+1),14,foil,center)
	var gaps := title.count(" ")
	var letters := title.length()-gaps-title.count(",")
	var letter_size := mini(23,int((h-132-gaps*4)/float(letters)))
	var ty := y+57+(h-139-letter_size*letters-gaps*4)/2.0
	for letter in title:
		if letter == " ":
			ty += 4
			continue
		if letter == ",":
			g._text(Vector2(center+letter_size*0.42,ty),letter,14,ink)
			continue
		g._center(ty+letter_size,letter,letter_size,ink,center)
		ty += letter_size
	if revealed:
		memory_star(g,Vector2(center,rect.end.y-63),9,accent)
	else:
		g._center(rect.end.y-57,"◇",14,foil,center)
	g._center(rect.end.y-22,g.Chapters.BOOKS[member.id].fan,14,foil,center)

static func draw_shelf(g) -> void:
	# The rail carries the catalog labels; only the clothbound spines can be opened.
	g.draw_rect(Rect2(97,70,1086,645),DARK_WOOD)
	g.draw_rect(Rect2(128,167,1024,410),Color("383b34"))
	for i in range(10):
		var x := 132+i*103
		g.draw_line(Vector2(x,175),Vector2(x,567),Color("2d302b"),2)
		g.draw_line(Vector2(x+3,180),Vector2(x+3,561),Color("41433a"),1)
	timber(g,Rect2(86,61,1108,22),Color("876044"))
	timber(g,Rect2(97,82,1086,86),WOOD)
	timber(g,Rect2(101,166,29,404),WOOD)
	timber(g,Rect2(1150,166,29,404),WOOD)
	g.draw_rect(Rect2(130,168,1020,12),Color("292d28"))
	var plaque := Rect2(508,94,264,56)
	g.draw_rect(plaque,Color("302928"))
	g.draw_rect(plaque.grow(-2),BRASS)
	g.draw_rect(plaque.grow(-5),Color("614930"))
	g._center(132,"인연 책장",28,CREAM_INK,640)
	g._text(Vector2(153,127),"루체테   /   열람실",17,CREAM_INK)
	var count := 0
	for member in g.MEMBERS:
		if titled(g.state,member.id): count += 1
	g._text(Vector2(938,127),"제목 복원   %d / 6" % count,17,BRASS)
	shelf_details(g)
	var x := 273.0
	var hover_line := ""
	for i in range(g.MEMBERS.size()):
		var member: Dictionary = g.MEMBERS[i]
		var revealed := titled(g.state,member.id)
		var h: int = SPINE_HEIGHT[i]
		var w: int = SPINE_WIDTH[i]
		var rect := Rect2(x,564-h,w,h)
		var title := shelf_title(g.state,member.id)
		var hover := rect.has_point(g.get_global_mouse_position())
		var book_rect := rect
		if hover:
			book_rect.position.y -= 6
			hover_line = "%s   ·   『%s』   /   %s" % [member.name,title,"되찾은 제목" if revealed else "임시 제목"]
		draw_spine(g,book_rect,member,i,revealed,title)
		g.buttons.append({"rect":rect.merge(book_rect),"id":"encounter_%d" % i})
		x += w+5
	bookend(g,270,564,-1)
	bookend(g,x-2,564,1)
	timber(g,Rect2(90,565,1100,17),Color("a0754c"))
	timber(g,Rect2(97,582,1086,46),WOOD)
	x = 273
	for i in range(g.MEMBERS.size()):
		var w: int = SPINE_WIDTH[i]
		var label := Rect2(x+1,588,w-2,30)
		g.draw_rect(label,Color("a98c57"))
		g.draw_rect(label.grow(-2),Color("e5d4ad"))
		g._center(608,g.MEMBERS[i].name,15,g.CREAM,label.get_center().x)
		g.buttons.append({"rect":label,"id":"encounter_%d" % i})
		x += w+5
	timber(g,Rect2(97,628,1086,82),Color("584132"))
	g._text(Vector2(150,662),hover_line if hover_line else "1~6 또는 책등을 눌러 한 권을 꺼내세요.",18,CREAM_INK)
	g._text(Vector2(150,689),"마지막 문장을 완성한 책은 제 색과 제목을 되찾고, 책등에 별빛이 남아요.",15,BRASS)
	g._button(Rect2(919,650,222,45),"시작의 서가   Esc","encounter_back")

# Stepped paper edges, a curved upper and lower edge, and the shadow of the sewing fold.
static func open_binding(g, rect: Rect2, fold: float, cloth: Color) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	g.draw_rect(Rect2(rect.position+Vector2(5,9),rect.size),Color("302622"))
	g.draw_rect(rect,cloth.darkened(0.54))
	g.draw_rect(rect.grow(-4),cloth.darkened(0.32))
	var left_leaf := PackedVector2Array([Vector2(x+15,y+24),Vector2(x+66,y+15),Vector2(fold-62,y+12),Vector2(fold-19,y+16),Vector2(fold,y+22),Vector2(fold,bottom-18),Vector2(fold-32,bottom-24),Vector2(fold-70,bottom-26),Vector2(x+74,bottom-25),Vector2(x+15,bottom-15)])
	var right_leaf := PackedVector2Array([Vector2(fold,y+22),Vector2(fold+22,y+15),Vector2(fold+64,y+11),Vector2(right-74,y+14),Vector2(right-15,y+22),Vector2(right-15,bottom-15),Vector2(right-74,bottom-24),Vector2(fold+71,bottom-26),Vector2(fold+33,bottom-24),Vector2(fold,bottom-18)])
	for leaves in [left_leaf,right_leaf]:
		for offset in [8,5,2]:
			var edge := PackedVector2Array()
			for point: Vector2 in leaves: edge.append(point+Vector2(0,offset))
			g.draw_colored_polygon(edge,Color("bba17c") if offset != 5 else Color("dfcca8"))
	g.draw_colored_polygon(left_leaf,Color("f2e0b9"))
	g.draw_colored_polygon(right_leaf,Color("f8ebcd"))
	for i in range(5):
		g.draw_rect(Rect2(fold-(5-i)*4,y+23,4,rect.size.y-49),Color(0.31,0.21,0.12,0.018+i*0.022))
		g.draw_rect(Rect2(fold+i*4,y+23,4,rect.size.y-49),Color(0.31,0.21,0.12,0.12-i*0.022))
	g.draw_line(Vector2(fold,y+22),Vector2(fold,bottom-18),Color("aa8c65"),2)
	var rx := right-67
	g.draw_colored_polygon(PackedVector2Array([Vector2(rx,y+14),Vector2(rx+14,y+16),Vector2(rx+14,y+70),Vector2(rx+7,y+64),Vector2(rx,y+70)]),cloth.darkened(0.31))

static func draw_turn(g, elapsed: float, forward: bool) -> void:
	if elapsed < 0 or elapsed >= 0.24: return
	var t := elapsed/0.24
	var direction := 1 if forward else -1
	var end_x := 640+direction*466*cos(PI*t)
	var lift := 30*sin(PI*t)
	var leaf := PackedVector2Array([Vector2(640,133),Vector2(end_x,126-lift),Vector2(end_x,610-lift),Vector2(640,621)])
	if absf(end_x-640) > 2:
		g.draw_colored_polygon(leaf,Color("ede0bd") if t<0.5 else Color("f7ebcf"))
		g.draw_line(leaf[1],leaf[2],Color("ba9f79"),2)

static func draw_book(g, member: Dictionary, page: int) -> void:
	var book: Dictionary = VOLUMES[member.id].data
	var fan: String = g.Chapters.BOOKS[member.id].fan
	var accent := Color(member.color)
	var revealed := titled(g.state,member.id)
	var is_note: bool = page == book.pages.size()
	var title := shelf_title(g.state,member.id)
	open_binding(g,Rect2(102,98,1076,551),640,book_cloth(accent,revealed))
	g._text(Vector2(166,172),"루체테 장서    /    "+member.name+" · "+fan,15,g.MUTED)
	g._text(Vector2(698,172),book.basis,15,g.MUTED)
	g.draw_line(Vector2(166,192),Vector2(575,192),Color("ceb68d"),1)
	g.draw_line(Vector2(698,192),Vector2(1110,192),Color("ceb68d"),1)
	g._text(Vector2(166,245),"되찾은 제목" if revealed else "임시 제목",15,g.GOLD)
	g._text(Vector2(164,290),title,31,g.CREAM)
	if is_note:
		g._text(Vector2(166,354),"책 뒤의 기록",22,g.GOLD)
		g._text_block(Vector2(166,402),book.note,403,18,g.CREAM,29)
		g._text(Vector2(698,272),"열람 자료",26,g.CREAM)
		if book.refs.is_empty():
			g._text_block(Vector2(699,340),"제공된 리스텔라 갤러리 댓글 캡처에 전해진 이야기를 실었습니다. 방송 원본은 미확인입니다.",390,19,g.MUTED,33)
		for i in range(book.refs.size()):
			g._button(Rect2(698,306+i*68,406,50),book.refs[i][0]+"  ↗","encounter_source_%d" % i)
	else:
		var leaf: Array = book.pages[page]
		var paragraphs := str(leaf[1]).split("\n\n",false,1)
		g._text(Vector2(166,346),"%02d    %s" % [page+1,leaf[0]],22,g.GOLD)
		g._text_block(Vector2(166,396),paragraphs[0],408,21,g.CREAM,34)
		if paragraphs.size() > 1:
			g._text_block(Vector2(698,266),paragraphs[1],406,21,g.CREAM,34)
		var medallion := Vector2(900,505)
		var cloth := book_cloth(accent,revealed)
		g.draw_arc(medallion,43,0,TAU,48,cloth.darkened(0.3),1)
		g.draw_circle(medallion,38,cloth.darkened(0.53))
		stamp(g,member.id,medallion,4,accent,not revealed)
		if revealed: memory_star(g,medallion+Vector2(37,-29),6,accent)
		g._center(573,book.kind,16,g.MUTED,900)
	g._text(Vector2(166,600),"%02d" % (page*2+1),15,g.MUTED)
	g._center(600,"%02d" % (page*2+2),15,g.MUTED,1103)
	if g.encounter_turn_at >= 0: draw_turn(g,g.clock-g.encounter_turn_at,g.encounter_turn_forward)
	g._button(Rect2(143,671,216,47),"책 덮기   Esc","encounter_back")
	g._button(Rect2(605,671,163,47),"앞장   ←","encounter_prev",false,page == 0)
	var next_label := "다음 장   E"
	if page == book.pages.size()-1: next_label = "책 뒤의 기록   E"
	if is_note: next_label = "읽기 마치기   E"
	g._button(Rect2(881,671,230,47),next_label,"encounter_next",true)
