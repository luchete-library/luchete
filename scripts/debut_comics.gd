extends RefCounted

# The preview GIFs and these in-game pages use the same captions and frame atlas.
const PROFILES = preload("res://assets/comics/debuts.json")
const PLAYBACK = preload("res://assets/comics/playback.json")
const SHEETS := {
	"dori": preload("res://assets/comics/dori.png"),
	"yune": preload("res://assets/comics/yune.png"),
	"yato": preload("res://assets/comics/yato.png"),
	"danming": preload("res://assets/comics/danming.png"),
	"kubby": preload("res://assets/comics/kubby.png"),
	"fuwa": preload("res://assets/comics/fuwa.png")
}
static var KEY_FRAMES: int=PLAYBACK.data.key_frames
static var FRAMES: int=PLAYBACK.data.frames
static var COLUMNS: int=PLAYBACK.data.columns
static var ROWS_PER_CUT: int=PLAYBACK.data.rows_per_cut
static var SUBSTEPS: int=PLAYBACK.data.substeps
const CELL := Vector2i(228,110)
static var filtered_sheets := {}

static func sheet(id: String) -> CanvasTexture:
	if not filtered_sheets.has(id):
		var tex := CanvasTexture.new()
		tex.diffuse_texture=SHEETS[id]
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		filtered_sheets[id]=tex
	return filtered_sheets[id]

# Each cut has its own anticipation, action and reading hold. The preview GIF
# consumes these same millisecond durations and the same second-line cue.
static func sample(id: String, elapsed: float) -> Vector2i:
	var ms:=maxi(0,roundi(elapsed*1000.0))
	var cues: Array=PLAYBACK.data.books[id].cues
	for cut in range(cues.size()):
		var durations: Array=cues[cut].frames_ms
		for frame in range(durations.size()):
			var hold:=int(durations[frame])
			if ms<hold: return Vector2i(cut,frame)
			ms-=hold
	return Vector2i(cues.size()-1,FRAMES-1)

static func duration(id: String) -> float:
	var total:=0
	for cue in PLAYBACK.data.books[id].cues:
		for ms in cue.frames_ms: total+=int(ms)
	return total/1000.0

static func cut_start(id: String, cut: int) -> float:
	var total:=0
	for i in range(clampi(cut,0,4)):
		for ms in PLAYBACK.data.books[id].cues[i].frames_ms: total+=int(ms)
	return total/1000.0

static func region(cut: int, tick: int) -> Rect2:
	var cell:=Vector2i(tick%COLUMNS,cut*ROWS_PER_CUT+floori(tick/float(COLUMNS)))
	return Rect2(Vector2(cell*CELL),Vector2(CELL))

# Story interaction thresholds use the original authored key poses. They must
# not become one third of the animation when its in-between frames increase.
static func key_region(cut: int, authored_tick: float) -> Rect2:
	return region(cut,clampi(floori(authored_tick*SUBSTEPS),0,FRAMES-1))

static func cut_sample(id: String, cut: int, elapsed: float) -> int:
	var ms:=maxi(0,roundi(elapsed*1000.0))
	var durations: Array=PLAYBACK.data.books[id].cues[cut].frames_ms
	for i in range(durations.size()):
		if ms<int(durations[i]): return i
		ms-=int(durations[i])
	return FRAMES-1

static func caption(id: String, cut: int, frame: int) -> String:
	var book: Dictionary=PROFILES.data[id]
	var full: String=book.captions[cut]
	return full if frame>=int(PLAYBACK.data.books[id].cues[cut].reveal) else full.get_slice("\n",0)

static func layout(g) -> Dictionary:
	# Work in physical pixels, then map back to the game's input coordinates.
	# This also accounts for the bars around a non-16:10 window.
	var transform: Transform2D=g.get_viewport().get_final_transform()
	var scale: float=transform.x.length()
	var area:=Vector2(1280,800)*scale
	var compact:=area.y<760
	var header:=46 if compact else 106
	var footer:=34 if compact else 70
	var cap:=32 if compact else 46
	var gap:=8 if compact else 20
	var enlarged: bool=g.comic_player.enlarged
	var factor: int
	if enlarged:
		cap=48 if compact else 60
		factor=maxi(1,floori(minf((area.x-40)/CELL.x,(area.y-header-footer-cap-28)/CELL.y)))
	else:
		factor=maxi(1,floori(minf((area.x-40-gap)/(CELL.x*2.0),(area.y-header-footer-cap*2-gap)/(CELL.y*2.0))))
	var art:=Vector2(CELL)*factor
	var block:=Vector2(art.x,art.y+cap)
	var full: Vector2=block if enlarged else Vector2(block.x*2+gap,block.y*2+gap)
	var origin:=Vector2(floor((area.x-full.x)/2),floor(header+(area.y-header-footer-full.y)/2))
	var boxes: Array[Rect2]=[]
	for i in range(1 if enlarged else 4):
		boxes.append(Rect2(origin+Vector2((i%2)*(block.x+gap),floori(i/2.0)*(block.y+gap)),art))
	return {"scale":scale,"offset":transform.origin,"area":area,"compact":compact,"factor":factor,"boxes":boxes,"caption":cap,"enlarged":enlarged,"bounds":Rect2(origin-Vector2(9,9),full+Vector2(18,18))}

static func ui_rect(physical: Rect2, plan: Dictionary) -> Rect2:
	var origin: Vector2=(physical.position+plan.offset).round()-plan.offset
	return Rect2(origin/plan.scale,physical.size/plan.scale)

static func ink(g, plan: Dictionary, at: Vector2, words: String, size: int, color: Color) -> void:
	g._text(ui_rect(Rect2(at,Vector2.ZERO),plan).position,words,maxi(1,roundi(size/plan.scale)),color)

static func button(g, plan: Dictionary, box: Rect2, words: String, command: String) -> void:
	var ui:=ui_rect(box,plan)
	g._panel(ui,Color("e8c58d") if box.has_point(g.get_global_mouse_position()*plan.scale) else Color("ecdbb8"))
	var size:=12 if plan.compact else 16
	var font_size:=maxi(1,roundi(size/plan.scale))
	var text_width: float=g.font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	g._text(Vector2(ui.get_center().x-text_width/2,ui.get_center().y+font_size*.35),words,font_size,g.CREAM)
	g.buttons.append({"rect":ui,"id":command})

static func draw(g, id: String, elapsed: float) -> void:
	var book: Dictionary=PROFILES.data[id]
	var now:=sample(id,elapsed)
	var plan:=layout(g)
	var area: Vector2=plan.area
	g.ui_regions.append(Rect2(0,0,1280,800))
	g._panel(ui_rect(Rect2(8,5,area.x-16,area.y-10),plan),g.PAPER)
	var left: float=maxf(20,plan.bounds.position.x)
	ink(g,plan,Vector2(left,27 if plan.compact else 57),book.title,18 if plan.compact else 32,g.CREAM)
	ink(g,plan,Vector2(area.x-182,24 if plan.compact else 54),book.name+" 편",13 if plan.compact else 18,g.MUTED)
	var help: String="1~4 / 컷 클릭 · 해당 컷 다시 보기   ←→ 컷 이동   Space 멈춤"
	if plan.enlarged: help="선택한 컷 크게 보기 · ←→ 다른 컷 · Space 멈춤 · Z 네 컷으로"
	ink(g,plan,Vector2(left,41 if plan.compact else 84),help,11 if plan.compact else 14,g.MUTED)
	for j in range(plan.boxes.size()):
		var i: int=now.x if plan.enlarged else j
		var physical: Rect2=plan.boxes[j]
		var frame: int=now.y if i==now.x else FRAMES-1 if i<now.x else FRAMES
		var active: bool=i==now.x
		var paper:=Rect2(physical.position,physical.size+Vector2(0,plan.caption))
		g.draw_rect(ui_rect(paper.grow(3),plan),g.GOLD if active else g.MUTED)
		g.draw_texture_rect_region(sheet(id),ui_rect(physical,plan),region(i,frame))
		g.draw_rect(ui_rect(Rect2(Vector2(physical.position.x,physical.end.y),Vector2(physical.size.x,plan.caption)),plan),Color("f8ecd2"))
		var number:=Rect2(physical.position.x+5,physical.end.y+6,22,20)
		g.draw_rect(ui_rect(number,plan),Color("785953") if active else Color("867768"))
		ink(g,plan,number.position+Vector2(3,15),"%02d"%(i+1),12,Color("fff0d0"))
		if i<=now.x:
			var size:=13 if plan.compact and not plan.enlarged else 16
			var line:=15 if plan.compact and not plan.enlarged else 20
			var at:=Vector2(physical.position.x+33,physical.end.y+(14 if plan.compact and not plan.enlarged else 19))
			for paragraph in caption(id,i,frame).split("\n"):
				ink(g,plan,at,paragraph,size,g.CREAM)
				at.y+=line
		# A panel click replays just that cut and holds its final frame.
		g.buttons.append({"rect":ui_rect(paper,plan),"id":"comic_cut_%d"%i})
	var controls: Array=[
		["공식 프로필 ↗","comic_source",142],
		["계속 / 재생 Space" if g.comic_player.paused else "멈춤 Space","comic_pause",152],
		["전체 다시 V","comic_play",122],
		["네 컷 보기 Z" if plan.enlarged else "크게 보기 Z","comic_zoom",128],
		["책으로 돌아가기 E","comic_close",166]
	]
	var ratio:=1.0 if plan.compact else 1.12
	var total: float=710*ratio+8*4
	var x: float=floorf((area.x-total)/2)
	for item in controls:
		var width: float=floor(item[2]*ratio)
		button(g,plan,Rect2(x,area.y-(31 if plan.compact else 52),width,24 if plan.compact else 34),item[0],item[1])
		x+=width+8
