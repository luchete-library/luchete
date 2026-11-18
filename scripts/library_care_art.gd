extends RefCounted

# Native pixel assets: no filtering, body warping or screenshot overlays.
const CELL := Vector2i(128,64)
const FLOOR_POINTS := [Vector2(552,304),Vector2(552,432),Vector2(824,328),Vector2(824,480),Vector2(352,600),Vector2(680,648),Vector2(1040,688),Vector2(296,552)]
const Layout=preload("res://scripts/library_world_layout.gd")
# These are painted furniture silhouettes, not new navigation obstacles.
const FLOOR_CUTOUTS := [Rect2(20,380,292,143),Rect2(852,263,276,171),Rect2(858,502,269,132),Rect2(242,551,93,146),Rect2(0,525,243,216),Rect2(735,516,98,94),Rect2(1136,291,107,244),Rect2(1130,548,118,130)]
static var stain_images: Dictionary={}
static var stain_textures: Dictionary={}
static var symbol_texture: CanvasTexture
static var paper_texture: CanvasTexture
const BOOK_CELL := Vector2i(32,24)
static var book_images: Dictionary={}
static var book_places: Dictionary={}
static var book_texture: CanvasTexture

static func pixel(image: Image,x: int,y: int,color: Color) -> void:
	if x>=0 and y>=0 and x<image.get_width() and y<image.get_height(): image.set_pixel(x,y,color)

static func stain_sheet() -> Image:
	var result:=Image.create(CELL.x*3,CELL.y*3,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for variant in range(3):
		for level in range(1,4):
			result.blit_rect(stain_cell(level,variant),Rect2i(Vector2i.ZERO,CELL),Vector2i((level-1)*CELL.x,variant*CELL.y))
	return result

static func grit(x: int,y: int,variant: int) -> float:
	return float(posmod(x*73+y*151+x*y*17+variant*43,101))/100.0

static func stain_cell(level: int,variant: int) -> Image:
	var result:=Image.create(CELL.x,CELL.y,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	# Actual pixel coverage grows; this is not the same tiny mark stretched up.
	var spread: float=[0.0,.48,.77,1.0][level]
	var lumps: Array=[Vector4(-22,-3,21,10),Vector4(1,4,27,13),Vector4(28,-5,20,11),Vector4(-6,-12,18,9),Vector4(35,9,15,8)]
	for y in range(4,CELL.y-4):
		for x in range(4,CELL.x-4):
			var q:=Vector2(x-64,y-32)
			if variant==1: q.x=-q.x
			q.y+=roundf(sin(float(x+variant*13)*.09)*2)
			var edge:=9.0
			for lump: Vector4 in lumps:
				var d: Vector2=(q-Vector2(lump.x,lump.y)*spread)/(Vector2(lump.z,lump.w)*spread)
				edge=minf(edge,d.length_squared())
			edge+=(grit(x/3,y/2,variant)-.5)*.32
			if edge>1.23: continue
			var shade:=Color("7c7060")
			shade.a=.34 if level==1 else .52
			if edge<1.02:
				shade=Color("51483e");shade.a=.66 if level==1 else .86
			if edge<.71:
				shade=Color("2d2b2a");shade.a=.74 if level==1 else .94
			if edge<.43:
				shade=Color("202326");shade.a=.82 if level==1 else .98
			# Coarse grit and drag streaks keep the mass visibly pixel drawn.
			if edge<.85 and grit(x,y,variant)>.93:
				shade=Color("8d7c63");shade.a=.75
			pixel(result,x,y,shade)
	# A winding track of distinct soles, never an animated crawling texture.
	for foot in range(level*2):
		var p:=Vector2i(35+foot*10+(variant-1)*3,23+(foot%2)*13-foot)
		if variant==1: p.x=CELL.x-p.x
		for dy in range(8):
			for dx in range(5):
				if (dx==0 or dx==4) and (dy==0 or dy==7): continue
				if dy==5: continue
				pixel(result,p.x+dx,p.y+dy,Color("171c20"))
		pixel(result,p.x+1,p.y+1,Color("696354"))
	if level>=2:
		paper(result,Vector2i(37+variant*6,38),variant)
	if level==3:
		paper(result,Vector2i(81-variant*5,17),variant+1)
		paper(result,Vector2i(94,40-variant*5),variant+2)
	return result

static func paper(image: Image,p: Vector2i,variant: int) -> void:
	var rows: Array=["....ooo....","..oobbbbo..",".obbhhbbbbo","obbhhhbbbbbo","obbbbhhhbbbo",".obbbbhhbbo","..obbbhbbo.","....oooo..."]
	var colors: Dictionary={"o":Color("514c43"),"b":Color("b8ad91"),"h":Color("ece0b9")}
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key: String=rows[y][x]
			if colors.has(key): pixel(image,p.x+(x if variant%2==0 else 11-x),p.y+y,colors[key])

static func floor_pixel(p: Vector2) -> bool:
	if not Layout.floor_contains(p): return false
	for r in Layout.STACKS:
		if r.has_point(p): return false
	for r in FLOOR_CUTOUTS:
		if r.has_point(p): return false
	return true

static func floor_key(point: Vector2,level: int,variant: int,with_books: bool=true) -> String:
	return "%d:%d:%d:%d:%s"%[point.x,point.y,clampi(level,1,3),posmod(variant,3),with_books]

static func floor_image(point: Vector2,level: int,variant: int,with_books: bool=true) -> Image:
	var key:=floor_key(point,level,variant,with_books)
	if not stain_images.has(key):
		var result:=stain_cell(clampi(level,1,3),posmod(variant,3))
		for y in range(CELL.y):
			for x in range(CELL.x):
				if not floor_pixel(point-Vector2(CELL)+Vector2(x*2+1,y*2+1)):
					result.set_pixel(x,y,Color.TRANSPARENT)
		if with_books:
			for item in fallen_books(point,level,variant):
				result.blend_rect(book_cell(item.frame),Rect2i(Vector2i.ZERO,BOOK_CELL),item.pos)
		stain_images[key]=result
	return stain_images[key]

static func book_cell(frame: int) -> Image:
	if book_images.has(frame): return book_images[frame]
	var result:=Image.create(BOOK_CELL.x,BOOK_CELL.y,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var covers: Array[Color]=[Color("ae5253"),Color("427f87"),Color("687ca2")]
	var cover: Color=covers[posmod(frame,3)]
	if frame<3:
		var slant: int=-1 if frame==1 else 1
		# Hard cover, stepped page block, spine and gold tooling, all integer pixels.
		for y in range(3,21):
			var left:=4+(y/5)*slant
			for x in range(17):
				var shade:=Color("372a29")
				if y>=16 and x>1 and x<16: shade=Color("ded1af") if y%2 else Color("a28b6b")
				elif y>3 and y<16 and x>0 and x<16:
					shade=cover.darkened(.26) if x<4 else cover
					if y==5 or y==14 or x==5 or x==14: shade=cover.lightened(.28)
				pixel(result,left+x,y,shade)
		for y in range(7,13):
			var x:=12+(y/5)*slant
			pixel(result,x,y,Color("e5c47b"))
		pixel(result,11+slant,9,Color("e5c47b"));pixel(result,14+slant,9,Color("e5c47b"))
	else:
		# A visible central fold and two separate written pages distinguish this
		# from the small crumpled paper already present on the floor.
		for x in range(2,31):
			var inset: int=mini(x-2,30-x)
			# Foreshortened, diagonal pages lie on the floor plane rather than
			# looking like an upright sign facing the camera.
			var top:=7+inset/8+x/10
			var bottom:=top+10
			for y in range(top,bottom+3):
				var shade:=Color("3c302c")
				if y==bottom+1: shade=cover
				elif y>top and y<=bottom:
					shade=Color("f0dfb5") if x<16 else Color("cdbb97")
					if x==15 or x==16: shade=Color("746148")
					elif y>top+3 and y<bottom-2 and (y-top)%3==0 and x%14>3 and x%14<12: shade=Color("9e8966")
				pixel(result,x,y,shade)
		for y in range(19,23): pixel(result,24,y,Color("b95f59"))
	book_images[frame]=result
	return result

static func book_sheet() -> Image:
	var result:=Image.create(BOOK_CELL.x*3,BOOK_CELL.y*2,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for frame in range(6): result.blit_rect(book_cell(frame),Rect2i(Vector2i.ZERO,BOOK_CELL),Vector2i(frame%3*BOOK_CELL.x,(frame/3)*BOOK_CELL.y))
	return result

static func book_fits(point: Vector2,pos: Vector2i,frame: int) -> bool:
	if not Rect2i(Vector2i.ZERO,CELL).encloses(Rect2i(pos,BOOK_CELL)): return false
	var sprite:=book_cell(frame)
	for y in range(BOOK_CELL.y):
		for x in range(BOOK_CELL.x):
			if sprite.get_pixel(x,y).a==0: continue
			if not floor_pixel(point-Vector2(CELL)+Vector2((pos.x+x)*2+1,(pos.y+y)*2+1)): return false
	return true

static func fallen_books(point: Vector2,level: int,variant: int) -> Array:
	if level<2: return []
	var key:=floor_key(point,level,variant)
	if book_places.has(key): return book_places[key]
	var result: Array=[]
	var desired: int=1 if level==2 else 2
	for n in range(desired):
		var frame:=posmod(variant+n,3)+(3 if n==1 else 0)
		var candidates: Array=[Vector2i(28+posmod(variant,3)*3,34),Vector2i(74,7)] if n==0 else [Vector2i(74,7),Vector2i(28,34)]
		# Narrow aisles receive complete books along the path, never a book cut
		# in half by the furniture mask. Prefer the central aisle when necessary.
		for x in [48,52,56,60,40,44,64,24,72,16,80,8,88]:
			for y in [5,34,20]: candidates.append(Vector2i(x,y))
		for pos: Vector2i in candidates:
			var overlaps:=false
			for item in result:
				if Rect2i(pos,BOOK_CELL).grow(2).intersects(Rect2i(item.pos,BOOK_CELL)): overlaps=true;break
			if overlaps or not book_fits(point,pos,frame): continue
			result.append({"pos":pos,"frame":frame});break
	book_places[key]=result
	return result

static func draw_lifted_book(g,p: Vector2,frame: int) -> void:
	if book_texture==null:
		book_texture=CanvasTexture.new();book_texture.diffuse_texture=ImageTexture.create_from_image(book_sheet())
		book_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	g.draw_texture_rect_region(book_texture,Rect2(p.round(),Vector2(BOOK_CELL)),Rect2(Vector2(frame%3*BOOK_CELL.x,(frame/3)*BOOK_CELL.y),Vector2(BOOK_CELL)))

static func hit_stain(point: Vector2,level: int,variant: int,mouse: Vector2) -> bool:
	if level<=0: return false
	var cell:=Vector2i(((mouse-point+Vector2(CELL))*.5).floor())
	if cell.x<0 or cell.y<0 or cell.x>=CELL.x or cell.y>=CELL.y: return false
	return floor_image(point,level,variant).get_pixelv(cell).a>.25

static func warning_sheet() -> Image:
	var result:=Image.create(64,16,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var mark: Array=["...xx..xx...","....x..x....","....x..x....","xxxxx..xxxxx","............","............","xxxxx..xxxxx","....x..x....","....x..x....","...xx..xx..."]
	for frame in range(4):
		for y in range(1,15):
			for x in range(1,15):
				if (x<3 or x>12) and (y<3 or y>12): continue
				pixel(result,frame*16+x,y,Color("f3e2bf"))
		for y in range(mark.size()):
			for x in range(mark[y].length()):
				if mark[y][x]!="x": continue
				pixel(result,frame*16+x+3,y+4,Color("513329"))
				pixel(result,frame*16+x+2,y+3-(frame%2),Color("cf785d") if frame<2 else Color("a95646"))
	return result

static func draw_stain(g,point: Vector2,level: int,variant: int,with_books: bool=true) -> void:
	if level<=0: return
	var key:=floor_key(point,level,variant,with_books)
	if not stain_textures.has(key):
		var tex:=CanvasTexture.new();tex.diffuse_texture=ImageTexture.create_from_image(floor_image(point,level,variant,with_books))
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;stain_textures[key]=tex
	g.draw_texture_rect(stain_textures[key],Rect2((point-Vector2(CELL)).round(),Vector2(CELL)*2),false)

static func draw_paper(g,p: Vector2,variant: int) -> void:
	if paper_texture==null:
		var image:=Image.create(12,8,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT);paper(image,Vector2i.ZERO,0)
		paper_texture=CanvasTexture.new();paper_texture.diffuse_texture=ImageTexture.create_from_image(image)
		paper_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	g.draw_texture_rect(paper_texture,Rect2(p.round(),Vector2(-24 if variant%2 else 24,16)),false)

static func crooked_book(g,p: Vector2,color: Color,tilt: int,width: int=36) -> void:
	# Stepped integer rows make a slanted book without rotating a filtered sprite.
	for row in range(12):
		var offset:=Vector2((row/3)*tilt,row)
		var shade:=Color("342b28")
		if row==1 or row>=9 and row<=10: shade=color.darkened(.22)
		if row>=2 and row<=8: shade=Color("ddcaa4") if row%3 else Color("aa9578")
		g.draw_rect(Rect2((p+offset).round(),Vector2(width,1)),shade)
		if row>=2 and row<=10: g.draw_rect(Rect2((p+offset).round(),Vector2(5,1)),color)
	g.draw_rect(Rect2((p+Vector2(5,1)).round(),Vector2(width-9,1)),color.lightened(.25))

static func draw_returned_books(g,p: Vector2,books: Array) -> void:
	var positions: Array=[Vector2(-34,-66),Vector2(3,-62),Vector2(-26,-78),Vector2(4,-74),Vector2(-35,-91),Vector2(-2,-88)]
	for i in range(books.size()):
		crooked_book(g,p+positions[i],Color("76a78a") if books[i]==0 else Color("8f8fca"),1 if i%2 else -1)
	if books.size()>=4: draw_paper(g,p+Vector2(37,-67),0)
	if books.size()>=6: draw_paper(g,p+Vector2(-39,-51),1)

static func draw_used_seat(g,p: Vector2,variant: int) -> void:
	# Place evidence on the existing tabletop, not in mid-air by the chair feet.
	var table:=p+Vector2(-18,-111)
	for row in range(15):
		var inset:=absi(7-row)*2+posmod(row+variant,3)
		g.draw_rect(Rect2((table+Vector2(inset,row)).round(),Vector2(42-inset*2,1)),Color("49382b"))
		if row>3 and row<11: g.draw_rect(Rect2((table+Vector2(inset+3,row)).round(),Vector2(34-inset*2,1)),Color("756047"))
	# A tipped cup, dark opening and handle; loose pages sit beside the spill.
	g.draw_rect(Rect2(table+Vector2(15,2),Vector2(16,10)),Color("514333"))
	g.draw_rect(Rect2(table+Vector2(16,3),Vector2(14,7)),Color("e3d4b1"))
	g.draw_rect(Rect2(table+Vector2(17,3),Vector2(4,7)),Color("6b4a32"))
	g.draw_rect(Rect2(table+Vector2(27,0),Vector2(7,4)),Color("c3ad85"))
	draw_paper(g,table+Vector2(42,5),variant)
	crooked_book(g,table+Vector2(-13,20),Color("987d66"),1 if variant else -1,32)

static func draw_warning(g,point: Vector2,elapsed: float) -> void:
	if symbol_texture==null:
		symbol_texture=CanvasTexture.new();symbol_texture.diffuse_texture=ImageTexture.create_from_image(warning_sheet())
		symbol_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var frame:=int(elapsed*8)%4
	g.draw_texture_rect_region(symbol_texture,Rect2(point.round(),Vector2(32,32)),Rect2(frame*16,0,16,16))
