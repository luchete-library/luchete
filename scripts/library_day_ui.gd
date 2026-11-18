extends RefCounted

const Data = preload("res://scripts/library_day_state.gd")
const Preferences = preload("res://scripts/ink_reading_preferences.gd")
const StellaLines = preload("res://scripts/stella_library_lines.gd")
const CareArt = preload("res://scripts/library_care_art.gd")
const INK := Color("49372f")
const MUTED := Color("78644d")
const PAPER := Color("f2dfb7")

static func card(g, rect: Rect2, title: String) -> void:
	g._panel(rect,PAPER);g.ui_regions.append(rect)
	g._text(rect.position+Vector2(22,34),title,21,INK)
	g.draw_line(rect.position+Vector2(20,48),rect.position+Vector2(rect.size.x-20,48),Color("ba9870"),1)

static func mark(g, p: Vector2, book: int, size: float=1.0) -> void:
	var c:=Color(Data.BOOKS[book].color)
	if book==0:
		g.draw_colored_polygon(PackedVector2Array([p+Vector2(-5,4)*size,p+Vector2(-7,-2)*size,p+Vector2(-1,-7)*size,p+Vector2(7,-7)*size,p+Vector2(6,1)*size,p+Vector2(0,5)*size]),c)
		g.draw_line(p+Vector2(-5,6)*size,p+Vector2(4,-4)*size,Color("eee3bb"),size)
	else:
		g.draw_rect(Rect2(p+Vector2(-2,-7)*size,Vector2(4,14)*size),c)
		g.draw_rect(Rect2(p+Vector2(-7,-2)*size,Vector2(14,4)*size),c)
		g.draw_rect(Rect2(p-Vector2(3,3)*size,Vector2(6,6)*size),Color("eee3bb"))

static func carried_book(g, p: Vector2, book: int) -> void:
	# A small rigid volume at the hands; never cover or warp the fan's face.
	g.draw_rect(Rect2(p-Vector2(1,1),Vector2(23,8)),Color("514437"))
	g.draw_rect(Rect2(p,Vector2(21,6)),Color(Data.BOOKS[book].color))
	g.draw_rect(Rect2(p+Vector2(3,2),Vector2(16,2)),Color("f0dfb8"))
	g.draw_rect(Rect2(p+Vector2(2,0),Vector2(2,6)),Color("d5bd84"))

static func draw_world(g, flow) -> void:
	var d=g.state.library_day
	if flow.active(g):
		var s: Dictionary=d.direct
		var p: Vector2=flow.station(g,int(s.stage))
		if g.mode=="day_promotion":
			g.draw_arc(p+Vector2(0,1),19,0,TAU,24,Color("c6bd80"),2)
			mark(g,p+Vector2(0,-20),int(s.book),1.0)
		if int(s.stage)==0:
			g.Pixels.book(g,p+Vector2(-18,-29),Color(Data.BOOKS[0].color),false,1)
			g.Pixels.book(g,p+Vector2(4,-26),Color(Data.BOOKS[1].color),false,1)
		if s.topic==1:
			for i in range(2):
				var guest: Dictionary={"slot":i,"kind":"read","phase":"browse","pos":flow.prospect(g,i),"facing":"up","distance":0.,"elapsed":g.clock}
				g.state.ink_visits.draw_guest(g,guest)
		elif s.topic==2:
			g.draw_rect(Rect2(flow.STAGE+Vector2(-62,18),Vector2(124,10)),Color("8b6a4b"))
			for i in range(2):
				var guest: Dictionary={"slot":i,"kind":"read","phase":"browse","pos":flow.safe_point(g,flow.STAGE+Vector2(-82+i*164,40)),"facing":"up","distance":0.,"elapsed":g.clock}
				g.state.ink_visits.draw_guest(g,guest)
		return
	if g.player_pos.x>=1280: return
	if not d.returned.is_empty():
		var p: Vector2=flow.CART
		CareArt.draw_returned_books(g,p,d.returned)
		g._panel(Rect2(p+Vector2(-13,-112),Vector2(26,25)),PAPER)
		mark(g,p+Vector2(0,-100),int(d.returned[0]))
	for i in range(2):
		var pos: Vector2=Data.BOOKS[i].shelf+Vector2(0,-28)
		for j in range(mini(4,d.shelved[i])): carried_book(g,pos+Vector2(20,-44-j*5),i)
		if not d.carried.is_empty() and d.carried[0]==i:
			g.draw_rect(Rect2(pos-Vector2(13,13),Vector2(26,26)),Color("efddb4"))
			mark(g,pos,i,1.5)
	for seat in d.dirty:
		CareArt.draw_used_seat(g,flow.SEATS[seat],seat)

static func promotion(g, flow) -> void:
	g.state.operating.ensure(g.state)
	var r:=Rect2(316,169,648,491)
	card(g,r,"도서관 홍보 · 오늘 %d / 2회"%g.state.operating.used_slots.size())
	g._text(Vector2(338,240),"오전 10~13시 / 오후 14~17시 · 각 1회 · 같은 주제는 하루 한 번",15,MUTED)
	var topics: Array=["추천 방송","잡지 배포","짧은 공연"]
	for i in range(3): g._button(Rect2(338+i*204,256,192,41),topics[i],"day_topic_%d"%i,flow.topic==i)
	g._text(Vector2(338,326),"함께 소개할 스텔라",17,INK)
	for i in range(6): g._button(Rect2(338+i*102,341,93,38),g.MEMBERS[i].short,"day_member_%d"%i,flow.member_index==i)
	var selected: Dictionary=flow.member(g)
	g._text(Vector2(338,410),selected.short+" · "+["방송: 오늘 독서 2명·대출 1명 + 완료 시 빛 3","잡지: 내일 독서 2명·대출 2명 예약","공연: 오늘 독서 손님 5명 초대"][flow.topic],16,INK)
	g._text_block(Vector2(338,442),"직접 할 때만 잠시 스텔라를 조작해요. 맡겨도 손님 수와 보상은 같아요.",600,15,MUTED,22)
	var reason: String=flow.error(g)
	var ordinary: int=g.state.ink_visits.Outreach.natural_count(g.state.operating.opening_rank)
	g._text_block(Vector2(338,487),reason if reason!="" else "홍보 없이 일반 손님 %d명/일. 좋은 추천·정돈된 이용은 내일 재방문으로 이어져요."%ordinary,600,15,INK,22)
	g._button(Rect2(338,534,293,45),selected.short+"로 직접 홍보하기","day_direct",true,reason!="")
	g._button(Rect2(645,534,293,45),selected.short+"에게 맡기기","day_assign",false,reason!="")
	var wait: int=g.state.promotion_wait_target()
	if wait>=0: g._button(Rect2(338,598,300,38),"%02d:%02d까지 기다리기"%[wait/60,wait%60],"growth_promotion_wait")
	else: g._text(Vector2(338,621),"메뉴를 보는 동안 시간은 잠시 멈춰요.",14,MUTED)
	g._button(Rect2(730,598,208,38),"돌아가기 · Esc","close")

static func draw(g, flow) -> void:
	if g.mode=="promotion": promotion(g,flow);return
	if flow.active(g):
		var s: Dictionary=g.state.library_day.direct
		var name: String=g.MEMBERS[g._mission_index_for(s.member)].short
		g._panel(Rect2(16,136,276,58),PAPER)
		g._text(Vector2(31,159),name+" 직접 조작 중",18,INK)
		g._text(Vector2(31,182),"원래 팬 모습은 그대로 · Esc 맡기기",13,MUTED)
		g.ui_regions.append(Rect2(16,136,276,58))
	if g.mode=="day_promotion":
		var r:=Rect2(345,650,590,83)
		card(g,r,flow.instruction(g))
		g._text(r.position+Vector2(22,70),"방향키 / WASD로 이동 · 표시를 누르거나 가까이서 E",15,MUTED)
	elif g.mode=="day_action":
		var labels: Dictionary={"present":"책을 펼쳐 보여 주는 중","perform":"인사와 발걸음으로 짧게 공연하는 중","handoff":"잉크에게 책 소식을 건네는 중","signoff":"이야기를 마치고 도서관으로 초대하는 중","shelve":"같은 표시의 책을 서가에 꽂는 중","clean":"책과 찻잔을 정돈하는 중","mop":"바닥의 얼룩과 발자국을 닦는 중"}
		if flow.action_kind=="mop" and g.state.library_day.grime[flow.action_index]>=2:
			labels.mop="떨어진 책을 먼저 챙기는 중" if flow.action_elapsed<1.0 else "책을 챙기고 바닥을 닦는 중"
		var r:=Rect2(353,657 if flow.active(g) and g.state.library_day.direct.topic==0 else 146,574,72)
		g._panel(r,PAPER);g.ui_regions.append(r)
		g._text(r.position+Vector2(22,31),labels.get(flow.action_kind,"이야기를 이어가는 중"),19,INK)
		g.draw_rect(Rect2(r.position+Vector2(22,48),Vector2(530,5)),Color("bfaa83"))
		g.draw_rect(Rect2(r.position+Vector2(22,48),Vector2(530*minf(1,flow.action_elapsed/3.0),5)),Color("6c9478"))
		if flow.action_kind in ["handoff","signoff"]:
			var caption: String="잉크 · 이 책부터 읽어 볼게요!" if flow.reply==0 else "잉크 · 찾아가는 길, 기억해 둘게요!"
			g._panel(Rect2(390,r.end.y+9,500,34),PAPER)
			g._text(Vector2(408,r.end.y+32),caption,16,INK)
	elif g.mode=="day_pause":
		card(g,Rect2(378,307,524,225),"홍보를 잠시 멈췄어요")
		g._text_block(Vector2(400,384),"계속 직접 하거나 스텔라에게 이어서 맡길 수 있어요. 사용한 홍보 기회는 그대로예요.",480,17,MUTED,25)
		g._button(Rect2(400,447,225,48),"계속 직접 하기","day_resume",true)
		g._button(Rect2(641,447,239,48),"이어 맡기고 돌아가기","day_handback")
	elif g.mode=="day_choice": choice_panel(g,flow)

static func choice_panel(g, flow) -> void:
	var title: String="소개할 책을 골라요"
	var body: String="도서관에서 함께 읽을 짧은 창작 책이에요. 정답 없이 마음에 드는 쪽을 골라요."
	var options: Array=[Data.BOOKS[0].title+" · 숲과 작은 단서",Data.BOOKS[1].title+" · 밤하늘과 산책"]
	match flow.choice:
		"chat":
			title="방송 채팅 · 처음 읽어도 괜찮을까요?"
			body=StellaLines.promotion(g.state.library_day.direct.member,int(g.state.library_day.direct.book))
			options=["짧은 첫 장부터 함께 펼쳐 보여 주기","좋아하는 장면을 소개하고 초대하기"]
		"leaflet":
			title="도서관 앞 잉크 · 어떤 곳인가요?"
			body="책 소개를 건네며 방문할 이유를 알려 줘요. 잡지를 받은 잉크들은 내일 예약으로 이어져요."
			options=["소개한 책과 읽을 자리를 알려 주기","찾아오는 길과 개관 시간을 알려 주기"]
		"invite":
			title="짧은 공연 뒤 · 도서관으로 초대해요"
			body=StellaLines.promotion(g.state.library_day.direct.member,int(g.state.library_day.direct.book))
			options=["소개한 책의 첫 장을 보여 주기","서가와 쉬어 갈 자리를 알려 주기"]
		"request":
			var v: Dictionary=flow.guest(g)
			title="잉크 · 소개한 책을 찾고 있어요"
			var feature: int=int(v.get("feature",0))
			var id: String=v.get("source_host","")
			var name: String=g.MEMBERS[g._mission_index_for(id)].short if id!="" else "스텔라"
			body="%s의 ‘%s’ 소개를 보고 왔어요. %s"%[name,Data.BOOKS[feature].title,Preferences.hint(v)]
			options=[Data.BOOKS[0].title+" · 숲속 관찰과 작은 발견",Data.BOOKS[1].title+" · 밤하늘과 상상의 산책"]
		"quiet":
			title="서가에서 조금 커진 목소리"
			body="잉크들이 책 이야기에 신났어요. 가볍게 안내하고 지나가도 괜찮아요."
			options=["다른 손님을 위해 작은 목소리로 부탁하기","읽을 책을 챙겨 이용 자리로 안내하기"]
	var r:=Rect2(334,386,612,335)
	card(g,r,title)
	g._text_block(r.position+Vector2(22,78),body,568,17,INK,26)
	for i in range(2): g._button(Rect2(356,524+i*55,568,46),options[i],"day_pick_%d"%i,i==0)
	g._text(Vector2(356,684),"맞는 추천: 이용 후 +5G · 빛 +2 · 만족 재방문은 하루 최대 2명" if flow.choice=="request" else "창작 도서관 일상 · 대화 중에는 시간과 손님이 잠시 멈춰요.",14,MUTED)
	g._button(Rect2(790,644,134,31),"잠깐 닫기","day_back")
