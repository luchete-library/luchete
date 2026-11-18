extends RefCounted

# Presentation only: the state owns slots, settlement and pending visits.
static func time_label(minutes: int) -> String:
	return "%02d:%02d"%[minutes/60,minutes%60]

static func available_topic(g) -> int:
	for i in range(g.state.ink_visits.TOPICS.size()):
		if g.state.ink_visits.start_error(g.state,i)=="": return i
	return -1

static func current_action(g) -> Dictionary:
	var s: Dictionary=g.state.operating_summary()
	var visits=g.state.ink_visits
	if s.closing:
		return {"title":"오늘 운영을 마쳤어요" if s.ready else "손님 이용을 마무리하고 있어요",
			"detail":"결산을 확인하고 다음 날을 시작해요." if s.ready else "이용과 홍보가 끝나면 결산을 확인해요.",
			"label":"오늘 결산" if s.ready else "일정 · 마감","action":"growth_summary" if s.ready else "growth_rest"}
	if available_topic(g)>=0:
		var period: String="오전" if g.state.operating.slot(g.state.minutes)==0 else "오후"
		return {"title":"지금 %s 홍보 1회 가능"%period,
			"detail":"손님이 이용 중이어도 홍보를 맡길 수 있어요." if not visits.guests.is_empty() else "홍보를 맡기고 첫 잉크를 맞아요." if visits.total==0 else "오늘 홍보 %d / 2회 · 원하는 주제를 골라요."%s.promotions,
			"label":"홍보 맡기기 P","action":"promotion"}
	if visits.topic>=0:
		return {"title":"스텔라가 홍보를 진행하고 있어요","detail":"열람실에서 홍보와 손님 이용이 이어져요.","label":"홍보 현황 P","action":"promotion"}
	var wait_target: int=g.state.promotion_wait_target()
	if wait_target>=0:
		var opening: bool=g.state.minutes<600
		return {"title":"홍보는 10:00에 시작해요" if opening else "다음 홍보는 14:00에 시작해요",
			"detail":"준비가 끝났다면 오전 홍보를 시작해요." if opening else "다음 일정 %s · 예약 손님도 차례로 맞아요."%time_label(wait_target),
			"label":time_label(wait_target)+"까지 기다리기","action":"growth_promotion_wait"}
	if s.promotions>=2 or g.state.minutes>=1020:
		var pending: bool=not visits.guests.is_empty() or visits.has_due_arrivals(g.state) or visits.reservations_for(g.state.day)>0
		return {"title":"오늘 홍보 2회를 모두 맡겼어요" if s.promotions>=2 else "오늘 홍보 접수가 끝났어요",
			"detail":"남은 손님 이용과 예약을 일정에서 확인해요." if pending else "교류·꾸미기를 즐기거나 오늘을 마감해요.",
			"label":"일정 · 마감","action":"growth_rest"}
	return {"title":"다음 홍보를 준비해요","detail":"홍보창에서 접수 시간과 상태를 확인해요.","label":"홍보 확인 P","action":"promotion"}

static func draw_footer(g) -> void:
	var action:=current_action(g)
	g.draw_line(Vector2(645,700),Vector2(645,769),Color("b89661"),2)
	g._text(Vector2(39,715),action.title,19)
	g._text(Vector2(39,742),action.detail,15,g.MUTED)
	g._button(Rect2(452,702,175,44),action.label,action.action,true)
	g._text(Vector2(39,769),"이동 WASD / 방향키 · E 상호작용 · 클릭 인사 · 가구로 드래그",13,g.MUTED)
	var threshold: int=g.growth.next_threshold()
	var rank: int=g.growth.rank()
	if threshold>0:
		g._text(Vector2(665,715),"다음 성장까지 기억의 빛 %d"%maxi(0,threshold-g.growth.memory_light),18)
		var unlocks: Array=["2단계 · 독서등과 방문 안내 개선 해금","3단계 · 대출 서비스 개선과 추가 의상 해금","4단계 · 별빛 장식과 동시 이용 정원 +1"]
		var benefits: Array=["달성 다음 날부터 일반 잉크 하루 2명 방문","달성 다음 날부터 일반 잉크 하루 4명 방문","기억의 빛은 누적되며 해금에 소비하지 않아요"]
		g._text(Vector2(665,740),unlocks[rank],14,g.MUTED)
		g._text(Vector2(665,767),benefits[rank],13,g.MUTED)
	else:
		g._text(Vector2(665,715),"도서관이 마지막 성장 단계에 도달했어요",18)
		g._text(Vector2(665,740),"골드로 가구와 공개된 추가 의상을 마련해요.",14,g.MUTED)
		g._text(Vector2(665,767),"누적 방문 %d명 · 대출 중 %d권"%[g.state.ink_visits.total,g.outstanding_loans()],13,g.MUTED)
	g._button(Rect2(1081,736,159,31),"방송 기록 서가","growth_archive")

static func draw_plan(g) -> void:
	var s: Dictionary=g.state.operating_summary()
	g._text(Vector2(165,193),"오늘의 운영과 마감",25)
	g._text(Vector2(165,231),s.calendar+"   ·   "+time_label(g.state.minutes),18)
	g._text(Vector2(165,270),"09시 준비 · 10~20시 영업 · 22시 결산",18)
	g._panel(Rect2(158,292,961,110),Color("ead4ab"))
	g._text(Vector2(177,322),"홍보는 오전 10~13시, 오후 14~17시 각각 한 번",18)
	g._text(Vector2(177,352),"오늘 맡긴 홍보 %d / 2  ·  같은 주제는 하루 한 번"%s.promotions,17,g.GOLD)
	g._text(Vector2(177,381),"다음 일정  ·  "+s.next_event_label,15,g.MUTED)
	g._text(Vector2(165,433),"오늘 방문 %d명 · 수입 %d G · 기억의 빛 +%d"%[s.visitors,s.income,s.light],18)
	if s.closing:
		g._text(Vector2(165,472),"마감 중이에요. 열람실에서는 손님과 진행 중인 홍보가 계속 움직여요.",16,g.MUTED)
		g._button(Rect2(165,510,450,46),"결산 확인" if s.ready else "열람실로 돌아가 마무리 보기","growth_summary" if s.ready else "close",true)
	else:
		g._button(Rect2(165,480,450,46),"다음 일정까지 기다리기","growth_wait",true)
		g._button(Rect2(636,480,450,46),"오늘 마감하기","growth_close_request")
		g._text(Vector2(165,564),"마감하면 남은 홍보 %d회는 쓰지 않아요. 아직 오지 않은 예약은 다음 날로 이어져요."%s.remaining_slots,15,g.MUTED)
	g._text(Vector2(165,619),"이 수첩에서는 시간이 멈춰요. 열람실로 돌아가면 다시 흘러요.",15,g.MUTED)

static func draw_close_confirmation(g) -> void:
	var s: Dictionary=g.state.operating_summary()
	g._text(Vector2(165,193),"오늘의 영업을 마칠까요?",25)
	g._text(Vector2(165,249),"사용하지 않은 홍보 %d회는 다음 날에 쌓이지 않아요."%s.remaining_slots,19)
	g._text(Vector2(165,299),"도서관 안의 손님과 진행 중인 홍보는 먼저 마무리해요.",18)
	g._text(Vector2(165,343),"아직 입장하지 않은 예약은 다음 날로 이어져요.",18)
	g._text(Vector2(165,387),"수입과 기억의 빛은 실제 이용을 끝냈을 때만 기록돼요.",17,g.MUTED)
	g._button(Rect2(165,470,450,50),"마감 시작 · 열람실로 돌아가기","growth_close_confirm",true)
	g._button(Rect2(636,470,450,50),"오늘 더 운영하기","close")
	g._text(Vector2(165,599),"벌금이나 강제 기절은 없어요. 내일 예약과 대출 기록은 남아요.",16,g.MUTED)

static func draw_summary(g) -> void:
	var s: Dictionary=g.state.operating_summary()
	var reach: Dictionary=s.outreach
	var previous_visits: int=maxi(0,int(s.visitors)-int(reach.arrivals.natural)-int(reach.arrivals.promotion)-int(reach.arrivals.revisit))
	g._text(Vector2(165,193),"오늘도 이야기를 기억해 줘서 고마워요",25)
	g._text(Vector2(165,231),s.calendar+" · 도서관 운영 기록",18,g.GOLD)
	var rows: Array=[
		["찾아온 잉크 · %d명"%s.visitors+(" (이전 기록 %d)"%previous_visits if previous_visits>0 else ""),"일반 %d · 홍보 %d · 재방문 %d"%[reach.arrivals.natural,reach.arrivals.promotion,reach.arrivals.revisit]],
		["오늘의 수입 / 구매","%d G / %d G"%[s.income,s.spent]],
		["기억의 빛","+%d  ·  누적 %d"%[s.light,g.growth.memory_light]],
		["내일 예약 / 대출 중","%d명 (만족 재방문 %d) / %d권"%[s.next_reservations,s.next_revisits,s.loans]]
	]
	for i in range(rows.size()):
		var y:=267+i*61
		g._panel(Rect2(158,y,961,52),Color("ead4ab"))
		g._text(Vector2(180,y+33),rows[i][0],18)
		g._text(Vector2(660,y+33),rows[i][1],19,g.GOLD)
	g._button(Rect2(165,539,450,48),"다음 날 · "+g.state.library_calendar(g.state.day+1).label,"growth_next_day",true,not s.ready)
	g._button(Rect2(636,539,450,48),"도서관을 조금 더 둘러보기","growth_summary_close")
	g._text(Vector2(165,628),"홍보 유입·방송으로 %dG · 빛 +%d. 정산된 보상이며 결산에서 다시 지급하지 않아요."%[reach.income.promotion,reach.light.promotion],15,g.MUTED)

static func draw_promotion(g) -> void:
	var visits=g.state.ink_visits
	var s: Dictionary=g.state.operating_summary()
	g._panel(Rect2(130,133,1020,540),g.PAPER)
	g._text(Vector2(163,180),"도서관 홍보 · 오늘 %d / 2회"%s.promotions,25)
	g._text(Vector2(163,216),"오전 10~13시 · 오후 14~17시 각 1회  |  현재 "+time_label(g.state.minutes),16,g.MUTED)
	var details: Array=["오늘 소개한 책을 찾아와요 · 독서 2명 / 대출 1명","다음 날 찾아올 손님을 예약해요 · 독서 2명 / 대출 2명","오늘 새로운 잉크가 찾아와요 · 열람 5명"]
	var wait_target: int=g.state.promotion_wait_target()
	for i in range(visits.TOPICS.size()):
		var y:=238+i*94
		g._panel(Rect2(157,y,961,84),Color("ead4ab"))
		g._text(Vector2(176,y+27),visits.TOPICS[i].method+" · "+visits.TOPICS[i].title,19)
		g._text(Vector2(176,y+59),details[i],15,g.MUTED)
		var error: String=visits.start_error(g.state,i)
		var label: String="%d  맡기기"%(i+1)
		if error!="":
			if s.closing: label="마감 중"
			elif visits.topic>=0: label="홍보 진행 중"
			elif s.promotions>=2 or g.state.minutes>=1020: label="오늘 접수 종료"
			elif g.state.minutes<600: label="10시부터 가능"
			elif g.state.minutes>=780 and g.state.minutes<840: label="14시부터 가능"
			elif g.state.operating.slot(g.state.minutes) in g.state.operating.used_slots: label="이 시간 접수 완료"
			elif i in g.state.operating.used_topics: label="오늘 맡긴 주제"
		g._button(Rect2(952,y+20,146,43),label,"promote_%d"%i,true,error!="")
	var reason: String=visits.start_error(g.state,0)
	if available_topic(g)>=0:
		reason="손님이 이용 중이어도 홍보를 맡길 수 있어요. 새 잉크는 빈자리에 차례로 들어와요."
	elif s.promotions>=2 and not s.closing and visits.topic<0:
		reason="오늘 홍보 2회를 모두 맡겼어요. 다음 날 새 주제를 골라 주세요."
	if wait_target>=0:
		reason="홍보는 10:00에 시작해요. 아직 방문객이 없어요." if g.state.minutes<600 else "다음 홍보는 14:00에 시작해요. 앞선 예약이 있으면 그 일정부터 기다려요."
	g._text_block(Vector2(164,548),reason,940,16,g.CREAM,23)
	g._text(Vector2(165,576),"준비가 끝났다면 기다리기를 눌러 오전 홍보를 시작해요." if wait_target>=0 and g.state.minutes<600 else "이 창에서는 시간이 멈춰요. 열람실로 돌아가면 방문과 홍보가 이어져요.",15,g.MUTED)
	if wait_target>=0:
		g._button(Rect2(165,603,430,47),time_label(wait_target)+"까지 기다리기","growth_promotion_wait",true)
	g._button(Rect2(811,603,307,47),"열람실로 돌아가기 · Esc","close")
