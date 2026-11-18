extends RefCounted

enum Phase {FIELD, INSPECT, FAMILY}
const ENTRANCE := Vector2(264,584)
const BASKET := Vector2(307,425)
const BASKET_SIDE := Vector2(263,444)
const FAMILY_SIDE := Vector2(490,474)
const SPEAKER := Vector2(540,431)
const YATO := Vector2(629,426)
const UNFOLD_TIME := 1.55
const CONFESSION := 1.15
const SHOCK := 1.95
const END := 5.25
const OBSERVATION := "토끼들은 야토에게 야토가 사람이라는 사실을 털어놓았어. 어렴풋이 짐작하고 있던 야토도 그 말을 듣고 큰 충격을 받았어."
const SCALE := 1.93
const SHOCK_SHEET := preload("res://assets/characters/interactions/motion/yato_storehouse_shock.png")

var phase := Phase.FIELD
var elapsed := 0.0
var camera := 0.0
var arrival := FAMILY_SIDE
var witness := FAMILY_SIDE
var focus := BASKET
var shock_texture: CanvasTexture

func restore(notes: Array) -> void:
	phase=Phase.FIELD
	elapsed=END if "truth" in notes else 0.0
	camera=0.0

func camera_offset() -> Vector2:
	return (Vector2(640,435)-focus*SCALE).clamp(Vector2(1280,800)-Vector2(936,718)*SCALE,-Vector2(32,140)*SCALE)

static func near_family(p: Vector2) -> bool:
	return p.distance_to(FAMILY_SIDE)<22 or p.distance_to(SPEAKER)<57 or p.distance_to(YATO)<60

func begin(g,id: String) -> void:
	var site: Dictionary=g._find_object("mato_"+id)
	if site.is_empty() or g.chapter_question: return
	var stock: bool=id=="basket"
	var close_enough: bool=g.player_pos.distance_to(BASKET_SIDE)<site.reach if stock else near_family(g.player_pos)
	if not close_enough:
		g._go_to(site)
		return
	arrival=g.player_pos
	witness=arrival
	# If the player approaches through an actor, take a short step aside.
	if not stock and arrival.distance_to(YATO)<60:
		witness=YATO+Vector2(63 if arrival.x>=YATO.x else -61,31)
	elif not stock and arrival.distance_to(SPEAKER)<48:
		witness=SPEAKER+Vector2(-43,39)
	phase=Phase.INSPECT if stock else Phase.FAMILY
	elapsed=0.0
	focus=(BASKET+BASKET_SIDE)/2-Vector2(0,15) if stock else (YATO+SPEAKER+witness)/3-Vector2(0,31)
	g.route.clear()
	g.pending_object=""
	g.chapter_question=true
	g.buttons.clear()
	g.fan_motion.direction="right" if g.player_pos.x<(BASKET.x if stock else YATO.x) else "left"

func advance(g,delta: float) -> void:
	var notes: Array=g._chapter_progress().yato_notes
	if phase==Phase.FIELD and not g.chapter_question and g.book_discovery.autostart_allowed(g) and "basket" in notes and "truth" not in notes and near_family(g.player_pos):
		begin(g,"truth")
	camera=move_toward(camera,0.0 if phase==Phase.FIELD else 1.0,delta*1.75)
	if phase==Phase.FIELD: return
	elapsed=minf(END,elapsed+delta)
	if phase==Phase.FAMILY and arrival!=witness:
		g.player_pos=arrival.lerp(witness,smoothstep(0,.56,elapsed))
		if elapsed>=.56: arrival=witness
	if phase==Phase.INSPECT and elapsed>=UNFOLD_TIME:
		g.YatoForest.mark_found(g,"basket")
		elapsed=0.0
		phase=Phase.FIELD
		g.chapter_question=false
		g.chapter_note="덮개를 걷어 보니 바닥이 드러났어. 한쪽 구석에만 먹을 게 조금 남아 있어."
		g._setup_map()
	elif phase==Phase.FAMILY and elapsed>=END and "truth" not in notes:
		g.YatoForest.mark_found(g,"truth")
		g._play_chime(562)

func read(g) -> void:
	if phase!=Phase.FAMILY or elapsed<END: return
	phase=Phase.FIELD
	g.chapter_question=false
	g._setup_map()
	g._inspect_chapter(1,OBSERVATION)

func input(g,event: InputEvent) -> bool:
	if phase==Phase.FIELD: return false
	if event is InputEventKey:
		if event.physical_keycode in [KEY_F5,KEY_F11]: return false
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE: g._leave_chapter()
				KEY_E,KEY_ENTER,KEY_SPACE: read(g)
				KEY_R:
					if phase==Phase.FAMILY and elapsed>=END: elapsed=0.0
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for item in g.buttons:
			if not item.rect.has_point(event.position): continue
			match item.id:
				"chapter_leave": g._leave_chapter()
				"store_read": read(g)
				"store_again":
					if phase==Phase.FAMILY and elapsed>=END: elapsed=0.0
			break
	return true

static func basket_rect() -> Rect2:
	return Rect2(BASKET-Vector2(50,51),Vector2(100,59))

func draw_field(g,notes: Array) -> void:
	var opened:=1.0 if "basket" in notes else 0.0
	if phase==Phase.INSPECT: opened=smoothstep(.15,1.02,elapsed)
	var column:=roundi(8*opened)
	g.draw_ellipse_shadow(BASKET,Vector2(43,9))
	g.draw_texture_rect_region(g.WorldPixels.texture("yato_provisions"),basket_rect(),Rect2(64*column,0,64,38))
	var step:=smoothstep(.08,.7,elapsed) if phase==Phase.FAMILY else 0.0
	var rabbit:=SPEAKER+Vector2(8*step,0)
	var speaking:=phase==Phase.FAMILY and elapsed>=.62 and elapsed<SHOCK+.22 and posmod(floori(elapsed*7),2)==1
	draw_rabbit(g,SPEAKER+Vector2(-36,-14),1.45,1,false)
	draw_rabbit(g,rabbit-Vector2(0,roundf(sin(step*PI)*5)),1.85,0,speaking)

static func draw_rabbit(g,p: Vector2,s: float,row: int,speaking: bool) -> void:
	var data: Dictionary=g.WorldPixels.MANIFEST.data.sprites.rabbit
	var size:=Vector2(data.size[0],data.size[1])
	var native_size:=Vector2(data.native_size[0],data.native_size[1])
	var anchor:=Vector2(data.anchor[0],data.anchor[1])
	g.draw_ellipse_shadow(p+Vector2(0,2),Vector2(12,3))
	g.Field.Finish.cel(g,g.WorldPixels.texture("yato_rabbit_family"),Rect2((p-anchor*s).round(),size*s),Rect2(Vector2(int(speaking),row)*native_size,native_size))

func draw_mato(g,p: Vector2) -> void:
	var lean:=smoothstep(.12,.64,elapsed)*(1.0-smoothstep(1.12,UNFOLD_TIME,elapsed))
	var facing:=1 if p.x<BASKET.x else -1
	g.BookRole.Fans.draw(g,"yato",p+Vector2(facing*roundf(2*lean),0),false,facing*.15*lean)

func feet() -> Vector2:
	var recoil:=smoothstep(SHOCK,SHOCK+.32,elapsed)
	var settle:=smoothstep(SHOCK+.32,SHOCK+.60,elapsed)
	return YATO+Vector2(roundf(10*recoil-2*settle),roundf(-3*recoil+3*settle))

func draw_yato(g,p: Vector2) -> void:
	var key: String=g._field_costume_key("yato")
	if elapsed<SHOCK or phase==Phase.INSPECT:
		g.Field.draw_stella_turn(g,"yato",key,p,"left",false,0)
		return
	if shock_texture==null:
		shock_texture=CanvasTexture.new()
		shock_texture.diffuse_texture=SHOCK_SHEET
		shock_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var col:=roundi(smoothstep(SHOCK,SHOCK+.38,elapsed)*8)
	var size:=Vector2(g.Field.CELL)
	var row: int=g.Field.COSTUMES.find(key)
	var rect:=Rect2(g.Field.origin(g,p,g.Field.STELLA_SCALE),size*g.Field.STELLA_SCALE)
	g.draw_ellipse_shadow(p+Vector2(0,3),Vector2(24,6))
	g.Field.Finish.cel(g,shock_texture,rect,Rect2(Vector2(col,row)*size,size))

func draw_words(g) -> void:
	if phase!=Phase.FAMILY or elapsed<.62 or elapsed>=END: return
	var line: String="야토야…" if elapsed<CONFESSION else "야토야, 너는 사람이야."
	var scale_factor: float=g.WORLD_SCALE
	var size:=roundi(15*scale_factor)
	var width: float=g.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+20*scale_factor
	var anchor: Vector2=(g.WORLD_OFFSET+(SPEAKER+Vector2(4,-86))*scale_factor).round()
	var rect:=Rect2(anchor-Vector2(width,0),Vector2(width,27*scale_factor))
	var tip:=rect.end-Vector2(17*scale_factor,0)
	g.draw_set_transform(Vector2.ZERO)
	g.draw_rect(rect.grow(2*scale_factor),Color("523e36"))
	g.draw_colored_polygon(PackedVector2Array([tip-Vector2(5,0)*scale_factor,tip+Vector2(8,8)*scale_factor,tip+Vector2(6,0)*scale_factor]),Color("523e36"))
	g.draw_rect(rect,Color("fff0cd"))
	g.draw_colored_polygon(PackedVector2Array([tip-Vector2(4,1)*scale_factor,tip+Vector2(6,6)*scale_factor,tip+Vector2(4,-1)*scale_factor]),Color("fff0cd"))
	g._text((rect.position+Vector2(10,19)*scale_factor).round(),line,size,Color("503c34"))
	g._transform()

func draw_hud(g) -> void:
	g._panel(Rect2(97,698,1086,93),g.PAPER)
	var line: String
	if phase==Phase.INSPECT:
		line="덮개 아래가 거의 비었어. 구석에 뿌리 몇 개만 남았네." if elapsed>=.68 else "바구니 덮개 밑을 들여다보자."
	elif elapsed<CONFESSION: line="토끼 가족이 야토 곁에 모였어."
	elif elapsed<SHOCK: line="토끼가 야토를 보고 나지막이 말을 꺼냈어."
	elif elapsed<END: line="야토가 한 걸음 물러섰어. 두 손을 든 채 가만히 서 있어."
	else: line="야토는 한동안 그 자리에 서 있었어."
	g._text(Vector2(122,750),"마토   ·   "+line,19,g.CREAM)
	if phase==Phase.FAMILY and elapsed>=END:
		g._button(Rect2(724,719,190,42),"다시 보기   R","store_again")
		g._button(Rect2(927,719,226,42),"기억 펼치기   E","store_read",true)
