extends RefCounted

# The player reconstructs Dori's memories. These are notebook illustrations
# and playable observations, not additional witnesses to the village case.
const Rubbing = preload("res://scripts/book_activities/dori_rubbing.gd")
const SITES := [
	[
		{"id":"practice","pos":Vector2(337,397),"label":"둔갑 연습 그림","art":"sketch","note":"다른 윤곽은 지워졌는데 돌 모양만 또렷해. 도리가 해낸 둔갑은 이거였구나."},
		{"id":"report","pos":Vector2(669,526),"label":"접힌 연습장","art":"report","note":"추리를 고쳐 쓴 자리마다 낙제 표시가 남았어. 도리는 그래도 연습장을 덮지 않았네."}
	],
	[
		{"id":"paving","pos":Vector2(343,501),"label":"돌 살펴보기","art":"stone","note":"돌바닥 틈에 꼭 끼어 있어. 한참 봐도 꼼짝하지 않아."},
		{"id":"sleeper","pos":Vector2(586,364),"label":"돌 살펴보기","art":"stone","note":"가만… 돌이 들썩여. 잠복하던 도리가 돌로 변한 채 잠들었구나!"},
		{"id":"wall","pos":Vector2(734,542),"label":"돌 살펴보기","art":"stone","note":"차가운 돌이야. 등불 그림자만 흔들리고 있어."}
	]
]
const REQUIRED := [["practice","report"],["stone_compare","sleeper"],["print1","print2","print3"],["card1","card2","card3"]]
const CARDS := [
	{"id":"card2","title":"에테의 산책","art":"print","caption":"에테가 자기 애완돌인 줄 알고 길가의 돌을 데려갔다."},
	{"id":"card3","title":"도리의 한마디","art":"lens","caption":"도서관에서 깨어난 도리가 즉흥적으로 추리를 내놓았다."},
	{"id":"card1","title":"마을의 잠복","art":"stone","caption":"도리가 작은 사건을 살피다가 돌로 둔갑한 채 잠들었다."}
]
const TASK := ["학교 뜰에서 연습 그림과 접힌 연습장을 찾아 비교해 보자.","골목에 놓인 돌 세 개를 지켜보자. 어느 돌이 숨을 쉴까?","골목에서 잠든 돌 곁으로 다가가 탁본을 떠 보자.","도리 곁에서 조사 수첩을 펼쳐 세 장면을 이어 보자."]
const ORDER_HINT := ["에테가 길을 나서기 전, 도리는 어디에서 무엇을 하고 있었지?","잠든 도리가 자기 발로 도서관까지 갈 수 있었을까?","도서관에서 눈을 뜬 뒤에야 도리는 무엇을 했지?"]

static func count(scene: int, notes: Array) -> int:
	var found := 0
	for id in REQUIRED[scene]:
		if id in notes: found+=1
	return found

static func ready(scene: int, notes: Array) -> bool:
	return count(scene,notes)==REQUIRED[scene].size()

static func valid_notes(raw: Variant) -> Array:
	var result := []
	if raw is Array:
		for id in raw:
			if id in result: continue
			if id in ["paving","wall"] or id in REQUIRED[0] or id in REQUIRED[1]:
				result.append(id)
			for stage in [2,3]:
				var step: int=REQUIRED[stage].find(id)
				if step>=0 and step==count(stage,result): result.append(id)
	return result

static func add_sites(objects: Array, scene: int, notes: Array) -> void:
	if scene==2:
		Rubbing.add_site(objects,notes)
		return
	for site in SITES[scene]:
		if scene==0 and site.id=="report" and "practice" not in notes: continue
		objects.append({"id":"clue_"+site.id,"type":"dori_clue","index":scene,"pos":site.pos,"label":site.label,"clue":site})

static func inspect(g, obj: Dictionary) -> void:
	var progress=g._chapter_progress()
	var scene: int=progress.debut_scene("dori")
	if g.mode!="chapter" or g.MEMBERS[g.story_member].id!="dori" or g.chapter_question or scene!=obj.index: return
	var site: Dictionary=obj.clue
	var notes: Array=progress.dori_notes
	if scene==0 and site.id=="report" and "practice" not in notes: return
	g.chapter_note=site.note
	if site.id in notes: return
	notes.append(site.id)
	if scene==1 and site.id in ["paving","wall"] and "stone_compare" not in notes:
		notes.append("stone_compare")
		g.chapter_note="이 돌은 꼼짝하지 않아. 이제 다른 돌의 움직임과 비교해 보자."
	elif scene==1 and site.id=="sleeper" and "stone_compare" not in notes:
		g.chapter_note="이 돌은 들썩여. 다른 돌도 같은지 살펴보면 차이를 알 수 있겠어."
	if g.replay_progress==null: g._save()
	g._play_chime(520+count(scene,notes)*70)
	g._setup_map()
	if ready(scene,notes):
		g._inspect_chapter(scene)

static func choose_card(g, index: int) -> void:
	if g.mode!="chapter" or not g.chapter_question or g.MEMBERS[g.story_member].id!="dori" or index<0 or index>=CARDS.size(): return
	var progress=g._chapter_progress()
	if progress.debut_scene("dori")!=3: return
	var notes: Array=progress.dori_notes
	var slot:=count(3,notes)
	if slot>=CARDS.size(): return
	var id: String=CARDS[index].id
	if id in notes: return
	if id!=REQUIRED[3][slot]:
		g.chapter_note=ORDER_HINT[slot]
		return
	notes.append(id)
	g.chapter_note="셋을 이어 보니, 잠든 돌이 어떻게 도서관에서 탐정이 되었는지 알겠어." if ready(3,notes) else "수첩에 끼웠어. 그다음 장면은 뭐였지?"
	g._play_chime(590+slot*100)
	if g.replay_progress==null: g._save()
	if ready(3,notes): g.book_discovery.begin_result(g)

static func draw_art(g, kind: String, center: Vector2, scale_factor: float, sleeping: bool=false) -> void:
	var brown:=Color("80553d")
	if kind=="stone":
		var breath: float=maxf(0,sin(g.clock*3.4)) if sleeping else 0.0
		g.WorldPixels.sprite(g,"prop_stone",center+Vector2(0,14-roundf(breath*3))*scale_factor,1.30*scale_factor)
		if sleeping and breath>.35:
			g._text(center+Vector2(13,-12-breath*4)*scale_factor,"z",roundi(13*scale_factor),Color("ffeac0"))
	elif kind=="lens":
		g.WorldPixels.sprite(g,"prop_lens",center+Vector2(0,17)*scale_factor,1.4*scale_factor)
	elif kind=="print":
		for step in range(2):
			var p: Vector2=center+Vector2(step*10-7,-step*8)*scale_factor
			# Stepped toes and a separate heel leave a readable boot imprint.
			g.draw_rect(Rect2(p+Vector2(2,-2)*scale_factor,Vector2(4,2)*scale_factor),brown)
			g.draw_rect(Rect2(p,Vector2(7,5)*scale_factor),brown)
			g.draw_rect(Rect2(p+Vector2(1,5)*scale_factor,Vector2(5,3)*scale_factor),brown)
			g.draw_rect(Rect2(p+Vector2(2,10)*scale_factor,Vector2(4,3)*scale_factor),brown)
	else:
		g._draw_book(center-Vector2(19,13)*scale_factor,Color("956a59"),true,1.4*scale_factor)
		if kind=="sketch":
			g.WorldPixels.sprite(g,"prop_stone",center+Vector2(5,6)*scale_factor,.57*scale_factor)
		else:
			g.draw_line(center+Vector2(4,-5)*scale_factor,center+Vector2(12,3)*scale_factor,Color("a84e46"),2*scale_factor)
			g.draw_line(center+Vector2(12,-5)*scale_factor,center+Vector2(4,3)*scale_factor,Color("a84e46"),2*scale_factor)

static func draw_sites(g,scene: int,notes: Array) -> void:
	for site in SITES[scene]:
		var pos: Vector2=site.pos
		var seen: bool=site.id in notes
		if scene==1 and site.id!="sleeper":
			var stone:=PackedVector2Array([pos+Vector2(-20,0),pos+Vector2(-16,-14),pos+Vector2(-5,-23),pos+Vector2(8,-22),pos+Vector2(19,-10),pos+Vector2(16,1),pos+Vector2(-6,4)])
			g.draw_colored_polygon(stone,Color("7b707b"))
			g.draw_colored_polygon(PackedVector2Array([stone[1],stone[2],stone[3],pos+Vector2(2,-14)]),Color("b5a9a3"))
			g.draw_colored_polygon(PackedVector2Array([pos+Vector2(2,-14),stone[3],stone[4],stone[5],pos+Vector2(6,-2)]),Color("6b606c"))
			g.draw_rect(Rect2(pos+Vector2(-9,-12),Vector2(4,2)),Color("a89998"))
			g.draw_line(stone[5],stone[6],Color("554a59"),3)
		else:
			draw_art(g,site.art,pos-Vector2(0,10),1.0,site.id=="sleeper")
		if seen:
			g.draw_polyline(PackedVector2Array([pos+Vector2(11,1),pos+Vector2(14,4),pos+Vector2(20,-3)]),Color("e1e5b1"),2)
		elif scene==0 and (site.id!="report" or "practice" in notes):
			g._star(pos+Vector2(15,-24),3.4+sin(g.clock*2),Color("ffdf91"))

static func draw_notebook(g,notes: Array) -> void:
	var filled:=count(3,notes)
	g._text(Vector2(250,221),"돌돌이의 조사 수첩",16,g.GOLD)
	g._text(Vector2(250,264),"도리는 어떻게 탐정이라 불리게 됐을까?",25,g.CREAM)
	for slot in range(3):
		var x:=249+slot*267
		g._panel(Rect2(x,293,245,64),Color("ecdfbf"))
		var label: String=["첫 장면","두 번째 장면","마지막 장면"][slot]
		for card in CARDS:
			if card.id==REQUIRED[3][slot] and card.id in notes: label=card.title
		g._center(333,label,18,g.CREAM if slot<filled else g.MUTED,x+122)
	for i in range(CARDS.size()):
		var card: Dictionary=CARDS[i]
		var x:=249+i*267
		draw_art(g,card.art,Vector2(x+121,406),1.6)
		g._button(Rect2(x,439,245,42),"%d   %s"%[i+1,card.title],"dori_card_%d"%i,false,card.id in notes)
		g._text_block(Vector2(x+7,509),card.caption,229,15,g.MUTED,22)
		if card.id not in notes:
			g.buttons.append({"rect":Rect2(x,367,245,178),"id":"dori_card_%d"%i})
	g._text(Vector2(250,576),g.chapter_note,16,g.CREAM)
	g._button(Rect2(790,590,243,36),"현장 더 보기   Esc","chapter_look")
