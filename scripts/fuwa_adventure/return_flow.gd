extends RefCounted

# Preview-only ending. The spell succeeds as an action; the unexpected rift
# is the authored event, never a punishment for player timing or accuracy.
const STAGES:=["return_ready","casting","rift","crossing","awakening","arrived"]
const CAST_SECONDS:=3.0
const RIFT_SECONDS:=3.4
const CROSS_SECONDS:=1.2
const WAKE_SECONDS:=3.0
const ACTION:=Rect2(870,718,210,39)
const LIBRARY_START:=Vector2(395,450)
const LIBRARY_TENBI:=Vector2(458,455)
const LIBRARY_FLOOR:=Rect2(290,412,242,58)
var elapsed:=0.0
var cast_count:=0
var arrivals:=0
var history: Array[String]=[]
var abandoned: CanvasTexture
var furnished: CanvasTexture

func reset() -> void:
	elapsed=0;cast_count=0;arrivals=0;history.clear()

func enter(g,stage: String) -> void:
	g.phase=stage;elapsed=0;history.append(stage)
	g.held.clear();g.route.clear();g.pending="";g.observing=false;g.moving=false;g.exposure=0
	if stage=="casting": cast_count+=1;g.facing="down"
	if stage=="awakening":
		arrivals+=1;g.zone=2;g.player_pos=LIBRARY_START;g.tenbi=LIBRARY_TENBI;g.facing="down"
		g.rocks.clear();g.ghosts.clear();g.transition=0
		g.setup_zone()

func interact(g) -> void:
	if g.paused: return
	if g.phase=="return_ready": enter(g,"casting")
	elif g.phase=="arrived": g.say("후와가 눈을 뜬 곳은 책으로 둘러싸인 낯선 도서관이었다.",4)

func update(g,dt: float) -> bool:
	if not g.phase in STAGES: return false
	elapsed+=dt
	match g.phase:
		"casting":
			if elapsed>=CAST_SECONDS: enter(g,"rift")
		"rift":
			if elapsed>=RIFT_SECONDS: enter(g,"crossing")
		"crossing":
			if elapsed>=CROSS_SECONDS: enter(g,"awakening")
		"awakening":
			if elapsed>=WAKE_SECONDS: enter(g,"arrived")
	return g.phase!="arrived"

func draw_pose(g) -> bool:
	if g.phase=="awakening":
		var frame: int=g.Interactions.Samples.transition(3,5,clampf((elapsed-.7)/2.0,0,1))
		g.Interactions.draw(g,"fuwa","focus",g.player_pos,frame,g.COSTUME)
		return true
	if g.phase in ["casting","rift","crossing"]:
		# Chest-height hands are existing complete authored cels. The face,
		# torso and limbs always retain their original canvas and proportions.
		var frame: int=g.Interactions.Samples.transition(0,3,minf(elapsed/1.1,1)) if g.phase=="casting" else 24
		g.Interactions.draw(g,"fuwa","focus",g.player_pos,frame,g.COSTUME)
		return true
	return false

func draw_library(g) -> void:
	if abandoned==null:
		abandoned=CanvasTexture.new();abandoned.diffuse_texture=load("res://assets/library_world/library_abandoned.png")
		furnished=CanvasTexture.new();furnished.diffuse_texture=load("res://assets/library_world/library_finished.png")
		abandoned.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		furnished.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	g.draw_texture_rect(abandoned,Rect2(Vector2.ZERO,g.MAP_SIZE),false)
	# Book-filled shelves support the canonical book-lined arrival. Dusty
	# covered furniture stays visible; no library-opening state is implied.
	var factor: Vector2=g.MAP_SIZE/Vector2(1280,800)
	var source_factor:=furnished.get_size()/Vector2(1280,800)
	for rect in [Rect2(234,28,264,151),Rect2(340,231,162,68),Rect2(617,231,174,68),Rect2(340,346,162,72),Rect2(617,346,174,72)]:
		g.draw_texture_rect_region(furnished,Rect2(rect.position*factor,rect.size*factor),Rect2(rect.position*source_factor,rect.size*source_factor))
	# Small drifting dust dots are scenery, rendered behind whole actors.
	for i in range(24):
		var q:=Vector2(200+fposmod(i*67.0+g.clock*2,520),140+fposmod(i*43.0+g.clock*3,300))
		g.draw_rect(Rect2(q.round(),Vector2(1,1)),Color(1,.84,.5,.28))

func pixel_line(g,a: Vector2,b: Vector2,color: Color,size: float=2.0) -> void:
	var steps:=maxi(1,ceili(a.distance_to(b)/size))
	for i in range(steps+1):
		var q: Vector2=(a.lerp(b,float(i)/steps)/size).round()*size
		g.draw_rect(Rect2(q,Vector2.ONE*size),color)

func spell_center(g) -> Vector2: return (g.player_pos+g.tenbi)*.5+Vector2(0,5)

func draw_spell(g) -> void:
	if not g.phase in ["casting","rift","crossing"]: return
	var center:=spell_center(g)
	var progress:=smoothstep(0,2.3,elapsed) if g.phase=="casting" else 1.0
	var strength:=1.0-smoothstep(0,CROSS_SECONDS,elapsed) if g.phase=="crossing" else 1.0
	# Ground ellipse contains both companions. No glow is drawn on their faces.
	for ring in [Vector2(77,27),Vector2(66,21)]:
		var count:=maxi(1,floori(110*progress))
		for i in range(count):
			var angle:=TAU*float(i)/110
			var next_angle:=TAU*float(i+1)/110
			pixel_line(g,center+Vector2(cos(angle),sin(angle))*ring,center+Vector2(cos(next_angle),sin(next_angle))*ring,Color(.74,.91,1,.8*strength))
	for i in range(floori(8*progress)):
		var a:=TAU*i/8
		var q:=center+Vector2(cos(a)*72,sin(a)*24)
		pixel_line(g,q-Vector2(4,0),q+Vector2(4,0),Color(.96,.96,1,strength))
		pixel_line(g,q-Vector2(0,3),q+Vector2(0,3),Color(.96,.96,1,strength))
	if g.phase=="casting":
		for i in range(12):
			var a:=i*TAU/12+elapsed*.3
			var p:=center+Vector2(cos(a)*70,sin(a)*22-fposmod(elapsed*10+i*3,32))
			g.draw_rect(Rect2(p.round(),Vector2(2,2)),Color(.84,.94,1,progress*.7))

func draw_rift(g) -> void:
	if not g.phase in ["rift","crossing"]: return
	var center:=spell_center(g)+Vector2(0,-65)
	var open:=smoothstep(.15,2.5,elapsed) if g.phase=="rift" else 1.0
	var height:=132.0*minf(1,elapsed/.8) if g.phase=="rift" else 132.0
	var width:=3.0+29.0*open
	# A jagged vertical light seam, not a deliberate doorway to select.
	for y in range(-ceili(height),ceili(height*.6),2):
		var taper:=maxf(0,1.0-absf(float(y)+height*.2)/(height*.8+1))
		var edge:=roundf(width*pow(taper,.7))
		var x:=roundf(sin(y*.21)*4+sin(y*.064)*5)
		var p: Vector2=(center+Vector2(x,y)).round()
		g.draw_rect(Rect2(p-Vector2(edge+5,0),Vector2((edge+5)*2,2)),Color(.45,.66,.98,.14))
		g.draw_rect(Rect2(p-Vector2(edge+2,0),Vector2((edge+2)*2,2)),Color(.63,.78,1,.5))
		g.draw_rect(Rect2(p-Vector2(edge,0),Vector2(maxf(2,edge*2),2)),Color(.89,.92,1,.94))
		if edge>6:
			g.draw_rect(Rect2(p-Vector2(edge-3,0),Vector2((edge-3)*2,2)),Color(.40,.49,.74,.9))
			g.draw_rect(Rect2(p-Vector2(maxf(1,edge*.38),0),Vector2(maxf(2,edge*.76),2)),Color(.63,.73,.91,.85))
			g.draw_rect(Rect2(p+Vector2(roundf(sin(y*.09)*3),0),Vector2(2,2)),Color(.94,.95,1,.95))
	for i in range(18):
		var a:=i*TAU/18
		var p:=center+Vector2(cos(a)*(width+18),sin(a)*height*.8)
		g.draw_rect(Rect2((p+Vector2(sin(elapsed+i)*4,0)).round(),Vector2(2,4)),Color(.83,.9,1,open*.7))

func draw_overlay(g) -> void:
	var opacity:=0.0
	if g.phase=="crossing": opacity=smoothstep(.05,.85,elapsed)
	elif g.phase=="awakening": opacity=1-smoothstep(.3,2.4,elapsed)
	if opacity>0: g.draw_rect(Rect2(0,0,1280,800),Color(.025,.035,.065,opacity))

func title(g) -> String:
	if g.zone==2: return "후와의 이야기 · 낯선 도서관"
	return "후와의 눈산 · "+("고갯길" if g.zone==0 else "안쪽 공터")

func goal(g) -> String:
	match g.phase:
		"return_ready": return "텐비를 찾았다. 후와의 귀환술로 돌아가자."
		"casting": return "후와가 귀환술을 펼친다."
		"rift","crossing": return "귀환술 뒤, 예상하지 못한 빛의 균열이 생겼다."
		"awakening": return "눈을 뜬 곳은 낯선 도서관이었다."
		"arrived": return "도서관 도착 · 후와를 움직여 주변을 둘러보자."
	return "텐비에게 다가가고 있어."

func draw_hud(g) -> void:
	var heading:="텐비, 여기 있었구나."
	var body:="이제 함께 돌아가자."
	var hint:="후와가 텐비 곁으로 다가가고 있어."
	match g.phase:
		"return_ready": hint="E 또는 오른쪽 버튼: 후와의 귀환술 시작"
		"casting":
			heading="후와 · 귀환술";body="후와가 집중하자 둘의 발밑에 술식의 빛이 번진다.";hint="후와의 동작과 술식이 이어지고 있어.   Esc: 쉬기"
		"rift","crossing":
			heading="예상하지 못한 균열";body="귀환술 뒤, 낯선 빛의 균열이 벌어진다.";hint="빛이 번지고, 눈산의 풍경이 사라진다."
		"awakening":
			heading="낯선 도서관";body="다시 눈을 뜬 후와의 주위에는 책으로 둘러싸인 서가가 있었다.";hint="눈산의 풍경이 사라지고 도서관이 모습을 드러낸다."
		"arrived":
			heading="낯선 도서관에 도착했다";body="후와는 이곳에서 눈을 떴다. 이번 시안은 도서관 도착까지 이어져.";hint="WASD / 방향키 · 바닥 클릭: 둘러보기   R: 눈산부터 다시   Esc: 쉬기"
	g.Pixels.panel(g,Rect2(170,635,940,136),Color("f0dfb6"))
	g.text_at(Vector2(201,674),heading,26,Color("513520"))
	g.text_at(Vector2(201,710),body,20,Color("513520"))
	g.text_at(Vector2(201,745),hint,17,Color("806047"))
	if g.phase=="return_ready": g.button(ACTION,"귀환술 쓰기   E")

