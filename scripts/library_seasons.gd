extends RefCounted

# The approved interior is a painted bitmap. These new exterior pixels are
# composited only inside its four glass panes, leaving curtains and trim intact.
# Call after Pixels.background(), in the same world transform as the library.
const WINDOW := Vector2(682,142)
const SIZE := Vector2i(96,96)
const NAMES := ["봄","여름","가을","겨울"]
const WEATHER_NAMES := {"clear":"맑음","breeze":"꽃바람","rain":"비","wind":"낙엽바람","snow":"눈"}
static var PANES := [
	PackedVector2Array([Vector2(30,11),Vector2(44,11),Vector2(44,42),Vector2(25,42),Vector2(27,28)]),
	PackedVector2Array([Vector2(52,11),Vector2(65,11),Vector2(67,27),Vector2(71,42),Vector2(52,42)]),
	PackedVector2Array([Vector2(24,51),Vector2(44,51),Vector2(44,79),Vector2(28,79),Vector2(25,67)]),
	PackedVector2Array([Vector2(52,51),Vector2(73,51),Vector2(71,67),Vector2(67,79),Vector2(52,79)])
]
static var _textures: Dictionary={}
static var _sill_textures: Dictionary={}

static func _native_texture(image: Image) -> CanvasTexture:
	var texture:=CanvasTexture.new()
	texture.diffuse_texture=ImageTexture.create_from_image(image)
	texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return texture

static func season_index(calendar: Dictionary) -> int:
	var value: Variant=calendar.get("season_index",calendar.get("season",0))
	if value is String:
		var index:=NAMES.find(value)
		if index<0: index=["spring","summer","autumn","winter"].find(value)
		return maxi(0,index)
	return clampi(int(value),0,3)

static func label(calendar: Dictionary) -> String:
	return "재건 %d년차 · %s %d일" % [maxi(1,int(calendar.get("year",1))),NAMES[season_index(calendar)],maxi(1,int(calendar.get("day_in_season",calendar.get("season_day",calendar.get("day",1)))))]

static func weather_for(day: int, season: int) -> String:
	# Stable after loading: weather is determined by the calendar, never RNG.
	var slot:=posmod(maxi(1,day)-1,7)
	match clampi(season,0,3):
		0: return "rain" if slot in [2,6] else "breeze" if slot in [1,4] else "clear"
		1: return "rain" if slot in [1,2,5] else "clear"
		2: return "rain" if slot==5 else "wind" if slot in [1,3,6] else "clear"
		3: return "snow" if slot in [0,2,3,5] else "clear"
	return "clear"

static func inside_glass(p: Vector2i) -> bool:
	for pane: PackedVector2Array in PANES:
		if Geometry2D.is_point_in_polygon(Vector2(p)+Vector2(.5,.5),pane): return true
	return false

static func _pixel(im: Image, x: int, y: int, ink: Color) -> void:
	if x>=0 and x<SIZE.x and y>=0 and y<SIZE.y: im.set_pixel(x,y,ink)

static func _rect(im: Image, box: Rect2i, ink: Color) -> void:
	for y in range(maxi(0,box.position.y),mini(SIZE.y,box.end.y)):
		for x in range(maxi(0,box.position.x),mini(SIZE.x,box.end.x)):
			im.set_pixel(x,y,ink)

static func _line(im: Image, a: Vector2i, b: Vector2i, ink: Color, width: int=1) -> void:
	var distance:=maxi(absi(b.x-a.x),absi(b.y-a.y))
	for i in range(distance+1):
		var p:=Vector2(a).lerp(Vector2(b),float(i)/maxi(1,distance)).round()
		_rect(im,Rect2i(Vector2i(p),Vector2i(width,width)),ink)

static func _leaf_cluster(im: Image, center: Vector2i, radius: Vector2i, colors: Array, seed: int) -> void:
	for y in range(center.y-radius.y,center.y+radius.y+1):
		for x in range(center.x-radius.x,center.x+radius.x+1):
			var distance:=pow(float(x-center.x)/radius.x,2)+pow(float(y-center.y)/radius.y,2)
			var noise:=posmod(x*37+y*19+seed*13,23)
			if distance>1.0 or (distance>.74 and noise<5): continue
			var shade:=0 if y>center.y+radius.y/3 else 2 if y<center.y-radius.y/3 else 1
			if noise in [0,1,2]: shade=mini(3,shade+1)
			_pixel(im,x,y,colors[shade])

static func scene_image(season: int, weather: String,mask: bool=true) -> Image:
	season=clampi(season,0,3)
	var im:=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	var sky: Array=[Color("98c8cf"),Color("75bbd5"),Color("a6bac8"),Color("abbfd5")]
	var horizon: Array=[Color("e4e8b1"),Color("d5e7c5"),Color("f3d8b2"),Color("e3e9e8")]
	var wet:=weather=="rain"
	var top: Color=sky[season].darkened(.17 if wet else 0)
	var low: Color=horizon[season].darkened(.12 if wet else 0)
	for y in range(9,84):
		# Four discrete sky bands keep the scene in the library's pixel language.
		var color: Color=top.lerp(low,floorf(clampf(float(y-10)/65,0,1)*4)/4)
		_rect(im,Rect2i(12,y,73,1),color)
	# Small stepped clouds, with a shaded lower edge rather than smooth alpha.
	for cloud in [Vector2i(30,19),Vector2i(62,27)]:
		_rect(im,Rect2i(cloud+Vector2i(-7,0),Vector2i(16,3)),Color("d0dee0") if wet else Color("f6eed3"))
		_rect(im,Rect2i(cloud+Vector2i(-3,-2),Vector2i(9,3)),Color("e0e8e5") if wet else Color("fff8df"))
		_rect(im,Rect2i(cloud+Vector2i(-5,3),Vector2i(12,1)),Color("a8c5cf") if wet else Color("c0d6cf"))
	var distant: Array=[Color("8aa77b"),Color("6c9b79"),Color("bc9865"),Color("b2c7cb")]
	var near: Array=[Color("617e58"),Color("43765d"),Color("937047"),Color("899fa6")]
	for x in range(12,85):
		var ridge:=48+roundi(sin(x*.12)*4+sin(x*.043)*3)
		_rect(im,Rect2i(x,ridge,1,36),distant[season])
		_rect(im,Rect2i(x,ridge+6+posmod(x,3),1,30),near[season])
	var floor_color: Array=[Color("a3b56e"),Color("70945e"),Color("b2925a"),Color("dbe5df")]
	for y in range(64,83):
		_rect(im,Rect2i(15,y,68,1),floor_color[season].darkened(.08 if y%4==0 else 0))
		var half:=2+(y-64)/3
		_rect(im,Rect2i(49-half,y,half*2+1,1),Color("c4bb8d") if season!=3 else Color("c0d1d6"))
	# A far fence and alternating slat highlights provide an outdoor scale cue.
	for x in range(21,80,8):
		_line(im,Vector2i(x,59),Vector2i(x,70),Color("797d66"),2)
		_line(im,Vector2i(x,59),Vector2i(x,69),Color("c3bf91"))
	_line(im,Vector2i(19,62),Vector2i(82,62),Color("c7c098"),2)
	# Two trunks sit near the curtains; branches extend visibly into the glass.
	for side in [-1,1]:
		var trunk:=24 if side<0 else 76
		_line(im,Vector2i(trunk,78),Vector2i(trunk+side*2,29),Color("62594b"),3)
		_line(im,Vector2i(trunk,77),Vector2i(trunk+side,30),Color("a18c64"))
		for branch in range(4):
			var start:=Vector2i(trunk,39+branch*8)
			var finish:=start+Vector2i(-side*(12+branch%2*8),-11)
			_line(im,start,finish,Color("6a6050"),2)
			_line(im,finish,finish+Vector2i(-side*5,-8),Color("8b785c"))
	if season!=3:
		var leaves: Array
		match season:
			0: leaves=[Color("889a62"),Color("d6a1ae"),Color("efbfca"),Color("fff0dd")]
			1: leaves=[Color("386751"),Color("538360"),Color("76a875"),Color("b0c781")]
			_: leaves=[Color("875a42"),Color("b77b46"),Color("dba156"),Color("edc17c")]
		for i in range(7):
			_leaf_cluster(im,Vector2i(23+i%2*8,27+i*5),Vector2i(13-i%3,9),leaves,17+i)
			_leaf_cluster(im,Vector2i(75-i%3*6,24+i*6),Vector2i(12,8+i%2),leaves,51+i)
		for i in range(21):
			var x:=20+posmod(i*19,59)
			var y:=67+posmod(i*11,14)
			_pixel(im,x,y,leaves[2+i%2])
	else:
		for side in [-1,1]:
			var trunk:=24 if side<0 else 76
			for branch in range(4):
				var a:=Vector2i(trunk,38+branch*8)
				var b:=a+Vector2i(-side*(11+branch%2*8),-10)
				_line(im,a,b,Color("ecf0e9"))
		_rect(im,Rect2i(19,61,62,1),Color("f4f5e9"))
		for x in range(23,78,9): _rect(im,Rect2i(x,73+posmod(x,5),3,1),Color("f4f6ec"))
	# Reapply hard pane masks last. No tint/paint reaches the existing frame.
	if mask:
		for y in range(SIZE.y):
			for x in range(SIZE.x):
				if not inside_glass(Vector2i(x,y)): im.set_pixel(x,y,Color.TRANSPARENT)
	return im

static func draw_world_windows(g,calendar: Dictionary,time: float) -> void:
	var season:=season_index(calendar)
	var weather:=weather_for(int(calendar.get("absolute_day",1)),season)
	var key: String="world:%d:%s"%[season,weather]
	if not _textures.has(key): _textures[key]=_native_texture(scene_image(season,weather,false))
	# Individual panes preserve the approved carved frame and curtains.
	var panes: Array[Rect2]=[Rect2(926,42,10,17),Rect2(943,42,11,17),Rect2(921,67,14,18),Rect2(943,67,14,18),Rect2(920,93,15,19),Rect2(943,93,15,19)]
	for offset in [Vector2.ZERO,Vector2(128,0)]:
		for i in range(panes.size()):
			var r:=Rect2(panes[i].position+offset,panes[i].size)
			g.draw_texture_rect_region(_textures[key],r,Rect2(27+i%2*22,18+floori(i/2.0)*22,17,19))
		if weather in ["rain","snow"]:
			for i in range(5):
				var r: Rect2=panes[i]
				var pos: Vector2=r.position+offset+Vector2(3+i%2*4,fposmod(time*(16 if weather=="rain" else 5)+i*7,r.size.y-2))
				g.draw_rect(Rect2(pos,Vector2(1,2 if weather=="rain" else 1)),Color("d8e9e5"))

static func particles(season: int, weather: String, time: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var count:=24 if weather in ["rain","snow"] else 8 if weather in ["breeze","wind"] else 0
	for i in range(count):
		var speed:=28.0 if weather=="rain" else 6.0 if weather=="snow" else 4.0
		var x:=17+posmod(i*17+roundi(time*(3.0 if weather!="rain" else -6.0)),65)
		var y:=10+posmod(i*23+floori(time*speed),73)
		var ink:=Color("b3d8e2") if weather=="rain" else Color("f6f4e7") if weather=="snow" else Color("f5cbd0") if season==0 else Color("e0ac61")
		var shape: Array[Vector2i]=[Vector2i.ZERO]
		if weather=="rain": shape=[Vector2i.ZERO,Vector2i(0,1),Vector2i(-1,2)]
		elif weather in ["wind","breeze"]: shape=[Vector2i.ZERO,Vector2i(1,0)]
		for offset: Vector2i in shape:
			var point:=Vector2i(x,y)+offset
			if inside_glass(point): result.append({"pos":point,"ink":ink})
	return result

static func sill_image(season: int) -> Image:
	var im:=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	# A tiny vase and a seasonal bookmark stack rest on the sill. These are
	# separate decorations, not a colour filter over the carved window frame.
	_rect(im,Rect2i(34,87,8,6),Color("515c61"))
	_rect(im,Rect2i(35,87,6,5),[Color("9bb5a3"),Color("7daeb4"),Color("b88b64"),Color("b8c6cc")][season])
	_line(im,Vector2i(36,88),Vector2i(36,91),Color("dbe1c6"))
	_line(im,Vector2i(34,87),Vector2i(41,87),Color("e6cf9c"))
	_line(im,Vector2i(38,86),Vector2i(38,78),Color("658061"))
	if season==3:
		for y in range(78,86,2):
			var width:=1+(y-78)/2
			_rect(im,Rect2i(38-width,y,width*2+1,2),Color("587263"))
			_pixel(im,38-width,y,Color("f1eddd"))
	else:
		var blossom: Color=[Color("efbed2"),Color("d8d59a"),Color("d9a165")][season]
		for at in [Vector2i(36,78),Vector2i(41,81),Vector2i(35,83)]:
			_line(im,Vector2i(38,87),at,Color("708365"))
			_rect(im,Rect2i(at,Vector2i(3,2)),blossom)
			_pixel(im,at.x+1,at.y-1,blossom.lightened(.15))
	_rect(im,Rect2i(55,90,13,3),Color("745343"))
	_rect(im,Rect2i(56,90,11,2),Color("dfd0aa"))
	_rect(im,Rect2i(56,88,11,2),[Color("a77386"),Color("6e9d99"),Color("bd8c53"),Color("758fba")][season])
	_rect(im,Rect2i(60,88,2,5),Color("ecd79f"))
	return im

static func draw(g, calendar: Dictionary, time: float) -> void:
	if not bool(calendar.get("window_open",true)): return
	var season:=season_index(calendar)
	var day:=int(calendar.get("absolute_day",calendar.get("day",1)))
	var weather:=weather_for(day,season)
	var key: String="%d:%s"%[season,weather]
	if not _textures.has(key):
		_textures[key]=_native_texture(scene_image(season,weather))
	if not _sill_textures.has(season):
		_sill_textures[season]=_native_texture(sill_image(season))
	g.draw_texture(_textures[key],WINDOW)
	for mote in particles(season,weather,time):
		g.draw_rect(Rect2(WINDOW+Vector2(mote.pos),Vector2.ONE),mote.ink)
	g.draw_texture(_sill_textures[season],WINDOW)
