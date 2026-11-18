extends RefCounted

# Hand-painted code-native sprite proposal. The live game's asset cache is untouched.
const Base=preload("res://scripts/library_care_art.gd")
const CELL:=Vector2i(128,64)
const BOOK_CELL:=Vector2i(32,24)
static var textures: Dictionary={}
static var books: Dictionary={}
static var floors: Dictionary={}
static var placements: Dictionary={}

static func px(im: Image,x: int,y: int,c: String) -> void:
	Base.pixel(im,x,y,Color(c))

static func book_cell(frame: int) -> Image:
	if books.has(frame): return books[frame]
	var im:=Image.create(32,24,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	var palettes: Array=[ ["513333","7d4440","a86752","c78968"], ["304d4b","426965","608d7c","8fb09a"], ["3e4359","53617c","7b87a4","a5b2bc"] ]
	var c: Array=palettes[frame%3]
	if frame<3:
		# Foreshortened hardback: lower page block, rounded spine, cloth and tooling.
		for y in range(4):
			for x in range(19):
				px(im,7+x,13+y,"3d3028" if y==3 or x==0 or x==18 else "b69b73" if y==2 or x%4==0 else "e0cda4")
		for y in range(9):
			var left:=5+y/3
			for x in range(20):
				var color: String=c[0] if x==0 or y==8 or x==19 else c[1] if x<4 else c[2]
				if x>4 and x<18 and y>0 and y<7 and (x+y*3)%11==0: color=c[3]
				if y==0 and x>1: color=c[3]
				px(im,left+x,5+y,color)
			px(im,left+3,5+y,c[0])
			if y in [2,6]:
				for x in range(5,18): px(im,left+x,5+y,"bd9c60")
			elif y>2 and y<6:
				px(im,left+5,5+y,"bd9c60");px(im,left+17,5+y,"bd9c60")
		for y in [7,11]:
			px(im,6+(y-5)/3,y,"d4b877");px(im,7+(y-5)/3,y,"9d814e")
		px(im,17,9,"f0dba0");px(im,16,10,"d3ae68");px(im,18,10,"d3ae68")
		px(im,22,16,"b06d52");px(im,22,17,"76513c")
	else:
		# Curved pages and an inset binding follow the floor perspective.
		for x in range(3,29):
			var fold:=absf(float(x)-15.5)
			var top:=6+x/13+(1 if fold<3 else 0)
			for y in range(top,top+10):
				var color: String="49372c" if y==top+9 else c[1] if y==top+8 else "e8d6ae" if x<15 else "cfb88d"
				if y==top: color="f2e1bc" if x<15 else "e6cfa3"
				if fold<1.5 and y<top+8: color="8e704f" if fold<.6 else "b29a70"
				if x in [3,28]: color="866d50"
				px(im,x,y,color)
			for line in range(3):
				if (x>5 and x<13 or x>18 and x<26) and (x+line*2)%6!=0:
					px(im,x,top+3+line*2,"a99069" if x<15 else "9c815c")
		px(im,16,16,"9f5549");px(im,16,17,"bd7960");px(im,17,18,"72463d")
	books[frame]=im
	return im

static func book_sheet() -> Image:
	var im:=Image.create(96,48,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
	for frame in range(6): im.blit_rect(book_cell(frame),Rect2i(0,0,32,24),Vector2i(frame%3*32,frame/3*24))
	return im

static func stain_cell(level: int,variant: int) -> Image:
	var im:=Base.stain_cell(level,variant)
	# Keep the large silhouette and soles. Restore warm wood-toned grit and
	# directional streaks instead of a uniform near-black centre.
	for y in range(CELL.y):
		for x in range(CELL.x):
			var color:=im.get_pixel(x,y)
			if color.a<=0 or color.get_luminance()>.34: continue
			var grain:=Base.grit(x/2,y,variant)
			var warm:=Color("332c27") if color.get_luminance()<.14 else Color("514332")
			if grain>.77: warm=Color("6e583d")
			elif grain<.15: warm=Color("282622")
			warm.a=color.a
			if y%7==variant%7 and grain>.24: warm.a*=.65
			im.set_pixel(x,y,warm)
	return im

static func fits(point: Vector2,pos: Vector2i,frame: int) -> bool:
	if not Rect2i(Vector2i.ZERO,CELL).encloses(Rect2i(pos,BOOK_CELL)): return false
	var im:=book_cell(frame)
	for y in range(24):
		for x in range(32):
			if im.get_pixel(x,y).a>0 and not Base.floor_pixel(point-Vector2(CELL)+Vector2((pos.x+x)*2+1,(pos.y+y)*2+1)): return false
	return true

static func fallen_books(point: Vector2,level: int,variant: int) -> Array:
	if level<2: return []
	var key:=Base.floor_key(point,level,variant)
	if placements.has(key): return placements[key]
	var result: Array=[]
	for n in range(1 if level==2 else 2):
		var frame:=posmod(variant+n,3)+(3 if n==1 else 0)
		var candidates: Array=[Vector2i(28,34),Vector2i(74,7)] if n==0 else [Vector2i(74,7),Vector2i(28,34)]
		for x in [48,52,56,60,40,44,64,24,72,16,80,8,88]:
			for y in [5,34,20]: candidates.append(Vector2i(x,y))
		for pos: Vector2i in candidates:
			if result.any(func(item): return Rect2i(item.pos,BOOK_CELL).grow(2).intersects(Rect2i(pos,BOOK_CELL))): continue
			if fits(point,pos,frame): result.append({"pos":pos,"frame":frame});break
	placements[key]=result
	return result

static func floor_image(point: Vector2,level: int,variant: int) -> Image:
	var key:=Base.floor_key(point,level,variant)
	if floors.has(key): return floors[key]
	var im:=stain_cell(level,variant%3)
	for y in range(CELL.y):
		for x in range(CELL.x):
			if not Base.floor_pixel(point-Vector2(CELL)+Vector2(x*2+1,y*2+1)): im.set_pixel(x,y,Color.TRANSPARENT)
	for item in fallen_books(point,level,variant): im.blend_rect(book_cell(item.frame),Rect2i(0,0,32,24),item.pos)
	floors[key]=im
	return im

static func draw_stain(g,point: Vector2,level: int,variant: int) -> void:
	if level<=0: return
	var key:=Base.floor_key(point,level,variant)
	if not textures.has(key):
		var tex:=CanvasTexture.new();tex.diffuse_texture=ImageTexture.create_from_image(floor_image(point,level,variant));tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;textures[key]=tex
	g.draw_texture_rect(textures[key],Rect2((point-Vector2(CELL)).round(),Vector2(CELL)*2),false)

static func crooked_book(g,p: Vector2,color: Color,tilt: int,width: int=33) -> void:
	for row in range(11):
		var at: Vector2=(p+Vector2((row/4)*tilt,row)).round()
		var fill:=Color("443327")
		if row==0 or row==9: fill=color.darkened(.28)
		elif row==1: fill=color.lightened(.18)
		elif row>1 and row<9: fill=Color("ddc7a0") if row%3 else Color("b29a73")
		g.draw_rect(Rect2(at,Vector2(width,1)),fill)
		if row>1 and row<9:
			g.draw_rect(Rect2(at+Vector2(1,0),Vector2(5,1)),color.darkened(.12))
			g.draw_rect(Rect2(at+Vector2(6,0),Vector2(1,1)),Color("8a704e"))
			if row in [3,7]: g.draw_rect(Rect2(at+Vector2(2,0),Vector2(3,1)),Color("d5b47b"))
			if row==4 or row==6: g.draw_rect(Rect2(at+Vector2(width-5,0),Vector2(3,1)),Color("f1dcad"))

static func draw_returned_books(g,p: Vector2,items: Array) -> void:
	var positions: Array=[Vector2(-34,-66),Vector2(3,-62),Vector2(-26,-78),Vector2(4,-74),Vector2(-35,-91),Vector2(-2,-88)]
	for i in range(items.size()): crooked_book(g,p+positions[i],Color("5d8270") if items[i]==0 else Color("726b8b"),1 if i%2 else -1)
	if items.size()>=4: Base.draw_paper(g,p+Vector2(37,-67),0)
	if items.size()>=6: Base.draw_paper(g,p+Vector2(-39,-51),1)

static func draw_used_seat(g,p: Vector2,variant: int) -> void:
	var t:=p+Vector2(-18,-111)
	for row in range(13):
		var inset:=absi(6-row)*2+posmod(row+variant,3)
		g.draw_rect(Rect2((t+Vector2(inset,row)).round(),Vector2(39-inset*2,1)),Color("584431"))
		if row%3==1: g.draw_rect(Rect2(t+Vector2(inset+3,row),Vector2(31-inset*2,1)),Color("96754c"))
	g.draw_rect(Rect2(t+Vector2(15,2),Vector2(16,10)),Color("594638"))
	g.draw_rect(Rect2(t+Vector2(16,2),Vector2(13,7)),Color("bba686"))
	g.draw_rect(Rect2(t+Vector2(17,1),Vector2(11,5)),Color("e3d7b8"))
	g.draw_rect(Rect2(t+Vector2(17,3),Vector2(4,6)),Color("765438"))
	g.draw_rect(Rect2(t+Vector2(18,3),Vector2(2,5)),Color("3b3027"))
	g.draw_rect(Rect2(t+Vector2(23,2),Vector2(1,5)),Color("c29b58"))
	g.draw_rect(Rect2(t+Vector2(28,1),Vector2(5,5)),Color("b19771"))
	g.draw_rect(Rect2(t+Vector2(29,2),Vector2(3,3)),Color("66503a"))
	g.draw_rect(Rect2(t+Vector2(26,10),Vector2(12,1)),Color("d2c4a8"))
	g.draw_rect(Rect2(t+Vector2(36,9),Vector2(4,3)),Color("a49b87"))
	Base.draw_paper(g,t+Vector2(42,5),variant)
	crooked_book(g,t+Vector2(-13,20),Color("98724d"),1 if variant else -1,30)
