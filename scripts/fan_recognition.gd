extends RefCounted

const Chapters = preload("res://scripts/debut_chapters.gd")
# Original library dialogue. Form IDs are the IDs Ete equips and saves.
const PAIRS := {
	"yato":{
		"room":{"welcome":"마토! 거울에 네가 먼저 보였어.","curious":"마토야, 나 찾으러 왔어?"},
		"approach":"마토! 이쪽이야, 여기!",
		"talk":"마토야, 한 바퀴 돌고 왔어? 처음 보는 샛길 있으면 내 지도에도 그려 줘.",
		"chair":"마토야, 지도 나오는 장이야. 내가 길을 짚을 테니까 넌 당근 표시를 찾아 줘.",
		"tea":"마토, 네 잔은 여기! 차 식는 동안 우리 다음 산책길이나 골라 볼까?"},
	"danming":{
		"room":{"heart":"버리야! 이 하트, 네 거야.","welcome":"버리! 날개가 빼꼼 보였어."},
		"approach":"버리! 네 날개 보고 알았지.",
		"talk":"버리야, 마침 잘 왔어. 봉투에 네 이름을 써 놨는데 직접 건네줄 수 있겠다.",
		"chair":"버리, 이 책은 편지로 시작해. 받는 사람은 네가, 보낸 사람은 내가 읽을까?",
		"tea":"버리야, 찻잔 옆에 쪽지 봤어? ‘오늘도 와 줘서 고마워.’ 소리 내 읽으니까 좀 쑥스럽다."},
	"kubby":{
		"room":{"rhythm":"햄님! 짝짝, 다음 박자는?","relief":"햄님이구나! 불빛 보고 알았어."},
		"approach":"반짝! 햄님 왔구나!",
		"talk":"햄님, 책장 사이로 불빛이 보이길래 혹시 했어. 역시 햄님이었네!",
		"chair":"햄님, 이 시는 두 줄이 한 쌍이야. 내가 한 줄 읽으면 다음 줄은 햄님 차례!",
		"tea":"햄님, 잔을 살짝 맞대 볼까? 딸랑! 이 소리로 노래를 시작해 봐도 좋겠다."},
	"yune":{
		"room":{"listen":"몽치, 살금살금 와도 다 보여.","reassure":"몽치야, 여기 네 자리 있어."},
		"approach":"그 동그란 눈… 몽치구나.",
		"talk":"몽치야, 눈 마주쳤다. 간밤에 꾼 꿈이 한 조각 생각나는데, 들어 줄래?",
		"chair":"몽치, 눈 감고 들어 봐. 이 장은 내가 읽을게. 어떤 색의 꿈이 되는지 나중에 알려 줘.",
		"tea":"몽치야, 찻김이 구름 같아. 저 조그만 구름은 네 쪽으로 가네."},
	"dori":{
		"room":{"salute":"돌돌이! 꼬리 끝이 보였지.","inspect":"줄무늬 꼬리 발견! 돌돌이지?"},
		"approach":"그 줄무늬 꼬리! 돌돌이잖아!",
		"talk":"돌돌이, 기다렸어! 수첩에 발자국을 그려 놨거든. 네 눈에도 왼쪽 게 조금 작아 보여?",
		"chair":"돌돌이, 다음 장은 아직! 이 삽화에 발자국이 하나 더 있어. 범인을 먼저 맞혀 볼까?",
		"tea":"돌돌이, 잔 바닥에 나뭇잎이 뜬 줄 알았어. 가만 보니 네 꼬리가 비친 거네!"},
	"fuwa":{
		"room":{"welcome":"곰방후와! 텐비, 이리 와!","relief":"텐비! 이마의 소용돌이 딱 보였어."},
		"approach":"텐비다! 곰방후와!",
		"talk":"텐비! 멀리서도 그 소용돌이는 딱 보인다니까. 오늘은 내 옆에서 같이 책장을 지킬래?",
		"chair":"텐비, 이 장은 눈밭이야. 내가 읽을 테니까 발자국이 몇 줄인지 같이 세어 보자.",
		"tea":"텐비야, 김이 빙글 도는 것 봐. 어라, 네 이마랑 한 쌍이네! 다 식기 전에 마시자."}
}
const VISITOR_HELLO := {
	"yato":"%s! 여기까지 잘 찾아왔네.","danming":"%s, 반가워! 손 펴 봐.",
	"kubby":"%s! 발소리에 박자가 있네.","yune":"%s, 안녕. 잠깐 쉬다 갈래?",
	"dori":"발소리의 주인은… %s!","fuwa":"곰방후와, %s! 어서 와!"
}
var nearby_member := ""
var bubble_until := 0.0

static func line(owner: String, form: String, moment: String, ordinary: String="") -> String:
	if form==owner: return PAIRS[owner][moment]
	if not Chapters.BOOKS.has(form): return ordinary
	var fan: String=Chapters.BOOKS[form].fan
	return VISITOR_HELLO[owner] % fan if moment=="talk" else "%s, %s" % [fan,ordinary]

func update(g) -> void:
	var form: String=g.state.fan_form
	if g.state.scene!="library" or form=="":
		nearby_member=""
		return
	if g.mode!="play": return
	var obj: Dictionary=g._find_object(form)
	if obj.is_empty() or obj.get("in_studio",false) or obj.get("promo_away",false) or g.character_touch.locked(g,form) or g.character_touch.dragging:
		nearby_member=""
		return
	var distance: float=g.player_pos.distance_to(obj.pos)
	if distance>106.: nearby_member=""
	elif distance<70. and nearby_member!=form:
		nearby_member=form
		bubble_until=g.clock+2.8

func draw(g) -> void:
	if nearby_member=="" or nearby_member!=g.state.fan_form or g.clock>=bubble_until: return
	var obj: Dictionary=g._find_object(nearby_member)
	if obj.is_empty() or obj.get("in_studio",false): return
	var words: String=PAIRS[nearby_member].approach
	var width: float=g.font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+24
	var feet: Vector2=obj.pos*g.WORLD_SCALE+g.WORLD_OFFSET
	var right_edge:=700. if g.split_view() else 1180.
	var left: float=feet.x+22 if feet.x+width+22<right_edge else feet.x-width-22
	var box:=Rect2(clampf(left,22,right_edge-width),feet.y-64,width,34)
	g._panel(box,g.PAPER)
	g._text(box.position+Vector2(12,22),words,15,g.CREAM)
