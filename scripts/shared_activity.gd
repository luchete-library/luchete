extends RefCounted

const Furniture = preload("res://scripts/garden_furniture.gd")
const NAMES := {"chair":"함께 책 읽기","tea":"같이 차 마시기"}
const LINES := {
	"yato":["여기 갈림길이야. 어느 쪽으로 갔는지 같이 볼래?","조금 식었나? 자, 네 잔부터!"],
	"danming":["이 문장 참 예쁘다. 편지에 옮겨 적고 싶어.","네 잔도 따라 뒀어. 향부터 맡아 봐."],
	"kubby":["여기 소리 내서 읽으면 노래 같아. 들어 볼래?","잔 부딪치는 소리 들었어? 맑은 음이네!"],
	"yune":["이 줄에서 잠깐만 쉬자. 풍경이 그려지는 것 같아.","두 손으로 감싸 봐. 손끝까지 따뜻해."],
	"dori":["잠깐, 앞장의 단서랑 이어져! 같이 다시 볼까?","찻잔 자국이 동그라미 두 개네. 우리가 앉았던 증거야."],
	"fuwa":["여기부터는 내가 읽을게. 다음 장은 네 차례야!","후후, 아직 뜨거워. 한 모금씩 천천히!"]
}
const DURATION := 6.0
var member := ""
var kind := ""
var path := PackedVector2Array()
var elapsed := 0.0
var activity_line := ""

func nearby(g) -> Dictionary:
	if g.state.scene!="library" or g.mode!="play" or g.character_touch.held!="": return {}
	var closest:=78.0
	var result: Dictionary={}
	for furniture_kind in NAMES:
		var id: String=g.garden_residents.occupant(furniture_kind)
		if id=="" or id=="ete" or g.character_touch.locked(g,id): continue
		var obj: Dictionary=g._find_object(id)
		if obj.is_empty() or obj.get("in_studio",false) or obj.get("promo_away",false): continue
		var distance: float=g.player_pos.distance_to(obj.pos)
		if distance<closest:
			result={"id":id,"kind":furniture_kind,"pos":obj.pos}
			closest=distance
	return result

func begin(g, expected_id: String="") -> void:
	var seat:=nearby(g)
	if seat.is_empty() or (expected_id!="" and seat.id!=expected_id): return
	var start: Vector2i=g._grid_at(g.player_pos)
	var shortest:=INF
	var approach:=PackedVector2Array()
	for offset in [Vector2(52,12),Vector2(-52,12),Vector2(0,55)]:
		if offset.x==0 and not approach.is_empty(): break
		var cell:=Furniture.nearby_cell(g.navigation,seat.pos+offset)
		if cell.x<0 or start.x<0: continue
		var point: Vector2=g.navigation.get_point_position(cell)
		var occupied:=false
		for other in g.objects:
			if other.type in ["npc","librarian"] and other.pos.distance_to(point)<26:
				occupied=true
				break
		if occupied: continue
		var steps: PackedVector2Array=g.navigation.get_point_path(start,cell)
		if steps.is_empty(): continue
		var length: float=g.player_pos.distance_to(steps[0])
		for i in range(1,steps.size()): length+=steps[i-1].distance_to(steps[i])
		if length<shortest:
			shortest=length
			approach=steps
	if approach.is_empty():
		g._notify("가구 옆에 함께 설 자리가 필요해요.")
		return
	member=seat.id
	kind=seat.kind
	activity_line=g.FanRecognition.line(member,g.state.fan_form,kind,LINES[member][0 if kind=="chair" else 1])
	path=approach
	elapsed=0.0
	var agent: Dictionary=g.garden_residents.agents[member]
	agent.timer=maxf(agent.timer,1.8)
	g.pending_object=""
	g.route.clear()
	g.mode="together"

func advance(g, delta: float) -> Vector2:
	var obj: Dictionary=g._find_object(member)
	if obj.is_empty() or obj.get("in_studio",false) or g.garden_residents.occupant(kind)!=member:
		g.mode="play"
		return Vector2.ZERO
	var agent: Dictionary=g.garden_residents.agents[member]
	agent.elapsed+=delta
	obj.yard_seconds=agent.elapsed
	var before: Vector2=g.player_pos
	if path.is_empty():
		elapsed+=delta
		if elapsed>=DURATION: g.mode="play"
	else:
		var budget:=170.*minf(delta,.15)
		while budget>0.0 and not path.is_empty():
			var step: float=g.player_pos.distance_to(path[0])
			g.player_pos=g.player_pos.move_toward(path[0],budget)
			if step>budget: break
			budget-=step
			path.remove_at(0)
	return g.player_pos-before

func draw_prop(g, feet: Vector2) -> void:
	if not path.is_empty(): return
	var lift:=roundf(4.*sin(elapsed*2.2))
	var hand:=feet+Vector2(0,-19 if g.state.fan_form!="" else -29)
	if kind=="chair":
		g.Pixels.book(g,hand+Vector2(-12,-3),Color("c9a584"),true,.9)
		g.draw_line(hand+Vector2(0,9),hand+Vector2(lift,0),Color("ead7ae"),2)
	else:
		var p:=hand+Vector2(-5,lift)
		g.draw_rect(Rect2(p+Vector2(8,2),Vector2(6,6)),Color("654c43"),false,2)
		g.draw_rect(Rect2(p,Vector2(10,9)),Color("755f53"))
		g.draw_rect(Rect2(p+Vector2(1,1),Vector2(8,6)),Color("f3dbb3"))
		g.draw_line(p+Vector2(1,1),p+Vector2(8,1),Color("9f7050"),2)
		g.draw_line(p+Vector2(4,-2),p+Vector2(5,-6),Color("e7dcc6"),1)

func draw_panel(g) -> void:
	var name: String=g.MEMBERS[g._mission_index_for(member)].short
	g._panel(Rect2(278,635,724,125),g.PAPER)
	g._text(Vector2(305,670),name+" · "+NAMES[kind],20,g.CREAM)
	var line: String="옆자리로 다가가는 중…"
	if path.is_empty(): line=activity_line
	g._text_block(Vector2(305,713),line,660,17,g.MUTED,22)
	g._button(Rect2(847,650,130,35),"일어나기   E","shared_end")
