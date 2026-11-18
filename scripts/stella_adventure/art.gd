extends RefCounted

const World=preload("res://scripts/world_pixels.gd")
const Field=preload("res://scripts/field_sprites.gd")
const Dream=preload("res://scripts/yune_dream.gd")
const Shock=preload("res://assets/characters/interactions/motion/yato_storehouse_shock.png")
const GOLD=Color("ffe3a0")

static func star(g,p: Vector2,size: float,color: Color=GOLD) -> void:
	var q:=p.round();var s:=maxf(1,roundf(size))
	g.draw_rect(Rect2(q-Vector2(s,1),Vector2(s*2+1,3)),color)
	g.draw_rect(Rect2(q-Vector2(1,s),Vector2(3,s*2+1)),color)
static func stone(g,p: Vector2,carried: bool=false) -> void:
	if not carried: g.draw_ellipse_shadow(p,Vector2(16,4))
	World.sprite(g,"prop_stone",p,.75 if carried else .95)
static func rabbit(g,p: Vector2,row: int,speaking: bool=false) -> void:
	var data: Dictionary=World.MANIFEST.data.sprites.rabbit
	var size:=Vector2(data.size[0],data.size[1]);var native:=Vector2(data.native_size[0],data.native_size[1]);var anchor:=Vector2(data.anchor[0],data.anchor[1])
	g.draw_ellipse_shadow(p,Vector2(15,4))
	Field.Finish.cel(g,World.texture("yato_rabbit_family"),Rect2((p-anchor*1.45).round(),size*1.45),Rect2(Vector2(int(speaking),row)*native,native))
static func hamster(g,p: Vector2) -> void:
	# Ordinary brown, grounded animal; never the large mint fan avatar Hamnim.
	g.draw_ellipse_shadow(p,Vector2(10,3))
	g.draw_set_transform((g.WORLD_OFFSET+p*g.WORLD_SCALE).round(),0,Vector2.ONE*g.WORLD_SCALE)
	for x in [-8,5]: g.draw_rect(Rect2(x,-2,5,2),Color("e4b79a"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(-13,-3),Vector2(-15,-8),Vector2(-13,-13),Vector2(-9,-16),Vector2(-2,-17),Vector2(2,-16),Vector2(3,-19),Vector2(7,-19),Vector2(9,-16),Vector2(11,-13),Vector2(14,-10),Vector2(15,-8),Vector2(12,-6),Vector2(10,-3),Vector2(5,-2),Vector2(-8,-2)]),Color("71483d"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(-13,-8),Vector2(-11,-13),Vector2(-6,-15),Vector2(2,-15),Vector2(6,-16),Vector2(10,-12),Vector2(13,-9),Vector2(10,-5),Vector2(3,-3),Vector2(-7,-3),Vector2(-11,-4)]),Color("c78c52"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(-8,-6),Vector2(-2,-7),Vector2(2,-10),Vector2(10,-11),Vector2(13,-9),Vector2(10,-5),Vector2(4,-3),Vector2(-7,-3)]),Color("f3d8ad"))
	for tuft: Vector2 in [Vector2(-11,-11),Vector2(-8,-14),Vector2(-3,-14),Vector2(0,-12),Vector2(-9,-5)]: g.draw_rect(Rect2(tuft,Vector2(3,1)),Color("e7b576"))
	g.draw_rect(Rect2(4,-18,3,3),Color("e2ad99"));g.draw_rect(Rect2(4,-18,2,1),Color("f8d8ae"))
	g.draw_rect(Rect2(8,-13,2,2),Color("443638"));g.draw_rect(Rect2(8,-13,1,1),Color("fff3d7"))
	g.draw_rect(Rect2(14,-9,2,2),Color("b97974"));g.draw_line(Vector2(11,-8),Vector2(16,-10),Color("ead5bf"),1)
	g.draw_set_transform(g.WORLD_OFFSET,0,Vector2.ONE*g.WORLD_SCALE)
static func flame(g,p: Vector2,t: float) -> void:
	var q: Vector2=(p+Vector2(0,sin(t*2)*3)).round()
	World.sprite(g,"prop_ember",q,.9)
	star(g,q+Vector2(13,-25),2,Color("a9fbea"))
static func bubble(g,p: Vector2,line: String) -> void:
	var width: float=g.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+18
	var box:=Rect2(p-Vector2(width*.5,30),Vector2(width,27))
	g.draw_rect(box.grow(2),Color("574b58"));g.draw_rect(box,Color("f4e7c8"))
	g.text_at(box.position+Vector2(9,19),line,14,Color("513e48"))

static func scenery(g) -> void:
	var kind: String=g.kind()
	if kind=="fading":
		g.draw_rect(Rect2(Vector2.ZERO,g.MAP_SIZE),Color(.08,.06,.18,.55*smoothstep(0,7,g.age)))
	if kind=="follow": g.draw_rect(Rect2(Vector2.ZERO,g.MAP_SIZE),Color(.06,.05,.14,.48))
	if kind=="nightwalk": g.draw_rect(Rect2(Vector2.ZERO,g.MAP_SIZE),Color(.05,.08,.17,.23))
	if kind in ["arrows","weary"]: workbench(g)
	if kind=="birth":
		var p:=Vector2(450,232)
		g.draw_line(p-Vector2(0,55),p-Vector2(0,31),Color("debf91"),2)
		g.draw_arc(p,30,0,TAU,24,Color("c4a6e6"),3)
		for i in range(8):
			var a:=p+Vector2.from_angle(TAU*i/8)*29
			var b:=p+Vector2.from_angle(TAU*(i+3)/8)*29
			g.draw_line(a,b,Color("e9d4f8"),1)
		for i in range(3):
			var f:=p+Vector2((i-1)*15,45+abs(i-1)*6)
			g.draw_line(f-Vector2(0,18),f+Vector2(0,7),Color("ebd7ef"),2);star(g,f,5,Color("c3b0eb"))
	if kind in ["dreams","fading"]:
		for i in range(3):
			var p:=Vector2(320+i*125,370+(i%2)*40)
			var strength: float=1.0-smoothstep(0,7,g.age)*.83 if kind=="fading" else 1.0
			star(g,p+Vector2(0,sin(g.clock+i)*4),7*strength,Color("ffe5b4"))
		if kind=="dreams":
			for i in range(3):
				if g.has_mark(i): continue
				var p: Vector2=g.target(i)-Vector2(0,30)
				var eat: float=clampf(g.charge/1.8,0,1) if g.nearest()==i else 0.0
				Dream.shadow_wisp(g,p,1.2*(1.0-eat))
				if eat>0:
					for n in range(5):
						var t:=fposmod(g.clock*1.7+n*.2,1)
						star(g,p.lerp(g.player_pos-Vector2(0,64),t),2,Color("ac95d3"))
	if kind in ["family","food"]:
		var p:=Vector2(480,315) if kind=="family" else Vector2(590,310)
		rabbit(g,p+Vector2(-35,8),0,g.action=="confession");rabbit(g,p+Vector2(29,-8),1)
		if kind=="food":
			var base:=Vector2(380,280)
			g.draw_rect(Rect2(base-Vector2(24,13),Vector2(48,27)),Color("5d4032"))
			g.draw_rect(Rect2(base-Vector2(21,10),Vector2(42,23)),Color("ad7946"))
			for i in range(6): g.draw_line(base+Vector2(-20+i*7,-10),base+Vector2(-20+i*7,13),Color("754d36"),1)
			var opened: bool=g.has_mark(0) or (g.action=="uncover" and g.action_age>.65)
			if opened:
				g.draw_rect(Rect2(base-Vector2(19,11),Vector2(38,10)),Color("49392e"))
				for i in range(3): g.draw_rect(Rect2(base+Vector2(-12+i*8,-8),Vector2(5,4)),Color("e6bc69"))
			else: g.draw_rect(Rect2(base-Vector2(25,16),Vector2(50,11)),Color("c3a47b"))
	if kind=="cold":
		for i in range(2):
			var p: Vector2=g.points()[i]-Vector2(0,35)
			g.draw_rect(Rect2(p-Vector2(27,60),Vector2(54,60)),Color("443c3d"))
			g.draw_rect(Rect2(p-Vector2(24,57),Vector2(48,54)),Color("7a6656"))
			for x in range(4): g.draw_line(p+Vector2(-20+x*13,-55),p+Vector2(-20+x*13,-4),Color("544839"),2)
			if g.has_mark(i): bubble(g,p-Vector2(0,70),"…")
	if kind in ["workdoor","village","door","meeting"]:
		var p: Vector2=g.points()[0]
		for i in range(4): star(g,p+Vector2(-12+i*8,-15-i*9),2)
	if kind not in ["carry","punishment","ending"]:
		var next: int=g.nearest()
		for i in range(g.points().size()):
			if g.has_mark(i): continue
			if kind in ["follow","nightwalk","mountain","food","takehome","weary"] and i!=next: continue
			var p: Vector2=g.target(i)
			if kind in ["follow","nightwalk"]:
				star(g,p-Vector2(0,25),7,GOLD)
			g.draw_arc(p+Vector2(0,4),18,0,TAU,16,Color("f5dba47f"),1)
			g.draw_polyline(PackedVector2Array([p+Vector2(-5,0),p+Vector2(0,-5),p+Vector2(5,0)]),GOLD,2)
	if kind=="light":
		var p: Vector2=g.player_pos
		for i in range(int(g.charge*9)):
			var angle: float=i*2.4+g.clock*.3
			star(g,p+Vector2(cos(angle)*50,-35+sin(angle)*48),2,GOLD)
	if kind=="deduce": Field.draw_facing(g,"aethe",Vector2(570,335),"left")
	if kind=="carry":
		var walk_in:=smoothstep(0,2.4,g.age)
		var walk_out:=smoothstep(2.9,6,g.age)
		var p:=Vector2(300,410).lerp(g.player_pos+Vector2(-23,0),walk_in).lerp(Vector2(690,260),walk_out)
		Field.draw_story_librarian(g,p,{"walking":g.age<2.4 or g.age>2.9,"direction":"right","distance":g.age*64},g.age>2.5)
		if g.age>2.5: stone(g,p+Vector2(2,-32),true)

static func foreground(g) -> void:
	var kind: String=g.kind()
	if g.member=="kubby":
		if kind=="hamster": hamster(g,Vector2(540+sin(g.clock)*6,330))
		elif kind=="takehome": hamster(g,g.player_pos+Vector2(25,-37) if g.has_mark(0) else Vector2(540,330))
		elif kind=="punishment":
			var p: Vector2=g.player_pos+Vector2(45,-4)
			if g.age<3.2: hamster(g,p)
			else: flame(g,p-Vector2(0,15),g.clock)
			if g.age>2.6 and g.age<3.8:
				for i in range(14): star(g,p+Vector2.from_angle(i*.7+g.clock)*22-Vector2(0,18),2,Color("c7f5f9"))
		elif kind in ["nightwalk","meeting","ending"]: flame(g,g.player_pos+Vector2(45,-25),g.clock)
	if g.action=="confession":
		# Intact authored shock cel, with the same body scale and foot anchor.
		var frame:=roundi(smoothstep(.6,1.0,g.action_age)*8)
		g.draw_ellipse_shadow(g.player_pos+Vector2(0,3),Vector2(24,6))
		Field.Finish.cel(g,Shock,Rect2(Field.origin(g,g.player_pos,Field.STELLA_SCALE),Vector2(Field.CELL)*Field.STELLA_SCALE),Rect2(frame*96,Field.COSTUMES.find(g.costume())*112,96,112))
		bubble(g,Vector2(580,232),"야토야, 너는 사람이야.")
	elif g.action=="deduce": bubble(g,Vector2(570,222),"그 추리가 맞았어!")
	elif g.kind()=="carry" and g.age>1.5: bubble(g,Vector2(520,243),"내 애완돌이 여기 있었구나.")
	if g.working and kind in ["arrows","weary"]:
		var p:=Vector2(390+sin(g.clock*8)*9,290)
		g.draw_rect(Rect2(p,Vector2(17,8)),Color("f1dfb6"));g.draw_rect(Rect2(p+Vector2(1,6),Vector2(15,2)),Color("c4a681"))
	if g.charge>0 and kind in ["dreams","light","watch","sleep"]:
		var p: Vector2=g.player_pos+Vector2(-28,16)
		g.draw_rect(Rect2(p,Vector2(56,4)),Color("2f3043"))
		g.draw_rect(Rect2(p,Vector2(56*clampf(g.charge/(1.8 if kind=="dreams" else 3.2 if kind=="light" else 2.5),0,1),4)),GOLD)

static func workbench(g) -> void:
	var p:=Vector2(450,300)
	for x in [-79,70]:
		g.draw_rect(Rect2(p+Vector2(x,2),Vector2(10,30)),Color("503c35"));g.draw_rect(Rect2(p+Vector2(x+2,3),Vector2(4,26)),Color("966745"))
	g.draw_rect(Rect2(p-Vector2(90,41),Vector2(180,48)),Color("4b3836"))
	g.draw_rect(Rect2(p-Vector2(88,39),Vector2(176,41)),Color("a3724c"))
	for i in range(5):
		g.draw_line(p+Vector2(-86,-35+i*8),p+Vector2(85,-35+i*8),Color("77513c"),1)
		g.draw_line(p+Vector2(-75+i*19,-30+i*6),p+Vector2(-38+i*19,-30+i*6),Color("c39663"),1)
	var shaft_clean: bool=g.has_mark(0)
	g.draw_line(p+Vector2(-56,-15),p+Vector2(56,-15),Color("d9b473"),3)
	g.draw_colored_polygon(PackedVector2Array([p+Vector2(66,-15),p+Vector2(51,-23),p+Vector2(51,-7)]),Color("e9cb8e"))
	for i in range(2):
		var tidy: bool=g.has_mark(i+1) or (g.kind()=="weary" and shaft_clean)
		var y: int=-15+(-1 if i==0 else 1)*(9 if tidy else 14)
		g.draw_line(p+Vector2(-50,-15),p+Vector2(-65,y),Color("ddd2d9"),3)
		g.draw_line(p+Vector2(-44,-15),p+Vector2(-59,y),Color("afa1c1"),2)
	if not shaft_clean:
		for i in range(8): g.draw_rect(Rect2(p+Vector2(-34+i*9,-18+i%3),Vector2(3,3)),Color("745950"))
