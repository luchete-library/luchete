extends RefCounted

# Integer-grid PNGs authored in tools/draw_library_pixels.py. All sampling is nearest.
const MANIFEST = preload("res://assets/library_pixels/manifest.json")
static var textures := {}

static func texture(id: String) -> CanvasTexture:
	if not textures.has(id):
		var tex := CanvasTexture.new()
		tex.diffuse_texture=load("res://assets/library_pixels/"+id+".png")
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[id]=tex
	return textures[id]

static func sprite(g, id: String, position: Vector2, scale: float = 2.0, modulate: Color = Color.WHITE) -> void:
	var data: Dictionary=MANIFEST.data.sprites[id]
	var anchor := Vector2(data.anchor[0],data.anchor[1])
	var size := Vector2(data.size[0],data.size[1])
	g.draw_texture_rect(texture(id),Rect2((position-anchor*scale).round(),size*scale),false,modulate)

static func background(g, stage: int) -> void:
	sprite(g,"library_stage_"+str(clampi(stage,0,6)),Vector2(32,140))

static func window_light(g, stage: int) -> void:
	if stage<2: return
	var origin: Array=MANIFEST.data.sunlight_origin
	sprite(g,"window_light",Vector2(origin[0],origin[1]),2.0,Color(1,1,1,.57+.43*(stage-2)/4.0))

static func frame(g, rect: Rect2, style: String = "panel") -> void:
	# Corners and repeated edge strips preserve grain/rivet pixel size on long menus.
	var tex := texture("ui_"+style)
	var edge := minf(8.0,minf(rect.size.x,rect.size.y)/2.0)
	var xs := [rect.position.x,rect.position.x+edge,rect.end.x-edge,rect.end.x]
	var ys := [rect.position.y,rect.position.y+edge,rect.end.y-edge,rect.end.y]
	var source := [0.0,8.0,24.0,32.0]
	for y in [0,2]:
		for x in [0,2]:
			g.draw_texture_rect_region(tex,Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y]),Rect2(source[x],source[y],source[x+1]-source[x],source[y+1]-source[y]))
	var x: float=xs[1]
	while x<xs[2]:
		var width := minf(16,xs[2]-x)
		for y in [0,2]: g.draw_texture_rect_region(tex,Rect2(x,ys[y],width,edge),Rect2(8,source[y],width,8))
		x+=width
	var y: float=ys[1]
	while y<ys[2]:
		var height := minf(16,ys[2]-y)
		for side in [0,2]: g.draw_texture_rect_region(tex,Rect2(xs[side],y,edge,height),Rect2(source[side],8,8,height))
		y+=height

static func panel(g, rect: Rect2, fill: Color, style: String = "panel") -> void:
	g.draw_rect(Rect2(rect.position+Vector2(2,4),rect.size),Color("382d2dcc"))
	g.draw_rect(rect.grow(-4),fill)
	if rect.size.y>55:
		# Sparse paper fibers, kept away from the first text baseline.
		for y in range(int(rect.position.y)+18,int(rect.end.y)-10,37):
			for x in range(int(rect.position.x)+22,int(rect.end.x)-12,61):
				g.draw_rect(Rect2(x+(y%3)*3,y,2,1),Color("96754b12"))
	frame(g,rect,style)

static func icon(g, id: String, center: Vector2, scale: float = 1.6) -> void:
	if not MANIFEST.data.sprites.has("icon_"+id): return
	sprite(g,"icon_"+id,center-Vector2(10,10)*scale,scale)

static func book(g, position: Vector2, color: Color, opened: bool, scale: float) -> void:
	var id := "book_open" if opened else "book_closed"
	var size := Vector2(28,20) if opened else Vector2(17,25)
	var rect := Rect2(position.round(),size*scale)
	g.draw_texture_rect(texture(id+"_base"),rect,false,color)
	g.draw_texture_rect(texture(id+"_detail"),rect,false)

static func rooms(g) -> void:
	var rugs := ["rug_read","rug_tea","rug_exercise","rug_stream"]
	var places := [Vector2(136,290),Vector2(136,462),Vector2(630,490),Vector2(640,275)]
	for i in range(4): sprite(g,rugs[i],places[i])

static func furniture(g, kind: String, position: Vector2, front: bool) -> void:
	if front and kind not in ["chair","tea"]: return
	sprite(g,kind+("_front" if front else "_back"),position)

static func contact_shadow(g, kind: String, position: Vector2) -> void:
	# Project to the left of the upper-right window. All shadows precede the actors.
	var ends: Vector2 = {"chair":Vector2(-30,26),"tea":Vector2(-44,45),"camera":Vector2(7,42),"mat":Vector2(-43,33)}[kind]
	var y := position.y + (13 if kind=="mat" else 8 if kind=="camera" else 16)
	var x := position.x
	g.draw_colored_polygon(PackedVector2Array([Vector2(x+ends.x-5,y+1),Vector2(x+ends.x+2,y-4),Vector2(x+ends.y,y-4),Vector2(x+ends.y-2,y+1),Vector2(x+ends.y-10,y+4),Vector2(x+ends.x-5,y+4)]),Color("372d3430"))

static func story_books(g) -> void:
	for i in range(g.MEMBERS.size()):
		var member: Dictionary=g.MEMBERS[i]
		var remembered: bool=g.EncounterBooks.titled(g.state,member.id)
		var accent := Color(member.color)
		var cover: Color=g.EncounterBooks.book_cloth(accent,remembered)
		var p := Vector2(354+i*44,209)
		g.draw_texture_rect(texture("book_closed_base"),Rect2(p,Vector2(23,34)),false,cover)
		if remembered:
			g.draw_texture_rect(texture("book_closed_detail"),Rect2(p,Vector2(23,34)),false)
			g.EncounterBooks.stamp(g,member.id,p+Vector2(13,17),1,accent)
			g.EncounterBooks.memory_star(g,p+Vector2(19,6),2,accent)
			g.draw_rect(Rect2(p+Vector2(16,28),Vector2(3,6)),accent.darkened(.12))
		else:
			for y in [4,25]: g.draw_rect(Rect2(p+Vector2(6,y),Vector2(13,1)),Color("aaaDa6"))
			g.draw_rect(Rect2(p+Vector2(10,13),Vector2(6,7)),Color("b5b6ad"))

static func atmosphere(g, stage: int) -> void:
	if stage>=2:
		# Dust catches the light as it drifts through the projected window panes.
		for i in range(13):
			var depth:=fposmod(i*17.0-g.clock*(2.2+i%3),208.0)
			var u:=.12+fposmod(i*.137+g.clock*.008,.75)
			if absf(u-.5)<.055 or absf(depth-81)<6: continue
			var p:=Vector2(679+u*(73+.15*depth)-.71*depth,238+depth).round()
			var strength: float=(.24+.13*sin(g.clock*.68+i))*(1-depth/255)
			g.draw_rect(Rect2(p,Vector2(2,2)),Color(1.0,.90,.67,strength))
	for i in range(10 if stage else 17):
		var x := roundf((95+fmod(i*83+sin(g.clock*.3+i)*12,788))/2)*2
		var y := roundf((270+fmod(i*37-g.clock*2+420,390))/2)*2
		g.draw_rect(Rect2(x,y,2,2),Color(0.93,0.85,0.67,.13+.08*sin(g.clock+i)))
	# A few discrete portal motes keep the garden door recognizable as an entrance.
	for i in range(3):
		var p := Vector2(832+roundf(sin(g.clock*.65+i*2)*27/2)*2,218+roundf(cos(g.clock*.5+i*2)*30/2)*2)
		g.draw_rect(Rect2(p,Vector2(2,2)),Color("eddb9b"))
