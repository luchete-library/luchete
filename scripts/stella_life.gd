extends RefCounted

# Original post-recruitment broadcasts, separate from the sourced debut books.
const SHOWS := {
	"yato":{"title":"야토의 손바닥 지도","prompt":"지도에 우리 약속 장소를 표시해 줄래요?","returning":["당근 잎 끝에서 기다렸어요. 오늘은 어디서 만나요?","발자국 둘이 만나는 데 찾았어요! 다음 표시도 그려 줄래요?"],
		"choices":["당근을 그린다","발자국을 찍는다"],"lines":["당근 잎 끝에서 만나자!","두 발자국이 만나는 데가 여기야."],"chats":["당근 잎 끝! 다음에도 찾아갈게요.","제 지도에도 발자국 두 개 찍어 뒀어요."]},
	"danming":{"title":"단밍의 한 줄 우편함","prompt":"오늘을 봉투에 담는다면 겉에 뭘 쓸까요?","returning":["‘버리에게’라고 쓴 봉투, 책상 위에 있어요. 오늘 봉투는요?","지난번 달 그림 옆에 붙일 봉투 하나 더 만들어 줄래요?"],
		"choices":["받을 사람 이름 쓰기","작은 달 그리기"],"lines":["받는 사람 칸에 ‘버리에게’라고 썼어.","달 하나 그렸어. 밤에 열어 봐!"],"chats":["제 이름이 쓰인 봉투, 잘 받았어요.","오늘 달 보면 그 봉투 생각날 것 같아요."]},
	"kubby":{"title":"쿠비의 불빛 합주","prompt":"불빛에 맞춰서 우리도 같이 소리 내 볼까요?","returning":["짝, 짝! 지난번 박자 기억해요. 오늘은 뭘로 맞춰 볼까요?","끝 음을 종일 흥얼거렸어요. 오늘도 같이 소리 내요!"],
		"choices":["손뼉 두 번 치기","콧노래 불러 주기"],"lines":["짝, 짝! 다음 두 번은 햄님 차례!","내가 먼저 흥얼거릴게. 끝 음을 이어 줘!"],"chats":["여기서도 짝짝! 박자가 딱 맞았어요.","방송 끝나도 그 끝 음이 맴돌겠어요."]},
	"yune":{"title":"유네의 베갯머리 라디오","prompt":"오늘 밤 꿈에 소리 하나만 가져갈 수 있다면요?","returning":["풍경 소리에 잠들었어요. 오늘도 소리 하나 골라 줄래요?","베개 옆 종이배가 그대로예요. 오늘 밤은 무슨 소리예요?"],
		"choices":["풍경 한 번 울리기","종이배 접어 띄우기"],"lines":["잘 들어 봐. 소리가 작아질 때까지 같이 있자.","사각사각. 이 배엔 몽치 자리도 있어."],"chats":["눈 감아도 방금 풍경 소리가 들려요.","저도 종이배 하나 접어 베개 옆에 뒀어요."]},
	"dori":{"title":"도리의 책상 위 사건","prompt":"수첩에 네모난 자국이 생겼어요. 단서부터 볼까요?","returning":["모서리 빈 도장, 기억나요! 새 자국은 뭘 대 볼까요?","지난번 책갈피 챙겨 왔어요. 오늘 자국도 같이 볼까요?"],
		"choices":["책상 위 도장 찍기","책갈피 포개 보기"],"lines":["도장 모서리가 비었어. 여기 자국이랑 똑같지?","책갈피를 포개니까 자국 안에 쏙 들어가!"],"chats":["모서리 하나로 찾다니! 수첩에 그려 뒀어요.","저도 책갈피 대 봤어요. 오늘은 저도 탐정!"]},
	"fuwa":{"title":"후와의 눈길 소리방","prompt":"눈 오는 날 들고 갈 소리를 하나 골라 주세요.","returning":["뽀드득 소리를 따라왔어요. 오늘 눈길에선 뭐가 들려요?","지난 방울 소리 듣고 또 왔어요. 오늘도 들려줄래요?"],
		"choices":["눈 밟는 소리 내기","방울 살짝 흔들기"],"lines":["뽀드득, 뽀드득. 텐비 발소리도 들려?","딸랑! 소리가 나는 쪽으로 따라와."],"chats":["내일 눈길 걸으면 이 발소리 떠올릴게요.","딸랑 소리 듣고 여기까지 잘 왔어요."]}
}

const Workout = preload("res://scripts/workout.gd")
const Calendar = preload("res://scripts/library_growth.gd")
const BOOK_CHAT := {
	"yato":["응! 입구에서 서가까지 길도 알려 줄게.","당근 모양 책갈피를 찾아봐. 거기가 시작이야!"],
	"danming":["네가 와 준다니 초대장을 쓴 보람이 있다!","첫 장에 마음에 드는 문장이 있어. 찾으면 알려 줘."],
	"kubby":["책 들고 오면 나도 반가워서 손 흔들 거야!","조용히 첫 장을 펴 봐. 어떤 소리가 떠올라?"],
	"yune":["기다릴게. 창가에 햇빛이 포근해.","오늘 꿈에 가져가고 싶은 장면부터 골라 봐."],
	"dori":["좋아, 탐정 조수 한 명 도착 예정!","첫 장부터! 단서 하나도 놓치면 아깝잖아."],
	"fuwa":["곰방후와! 도서관에서 만나자!","천천히 읽어 봐. 첫 장은 내가 같이 응원할게!"]
}
const Stage = preload("res://scripts/activity_stage.gd")
var stage := Stage.new()
var broadcast_started := 0.0
const INVITES := {"yato":"숲길 한 바퀴 돈 셈 치자. 오늘은 네가 코스를 골라 줘!","danming":"네 자리까지 매트를 펴 놨어. 오늘은 뭐 하고 싶어?","kubby":"둘이 하면 박자 맞추기 쉽겠다. 내가 먼저 셀까?","yune":"창가가 조용해서 좋아. 내 옆에서 같이 할래?","dori":"수첩에 오늘 운동 칸을 그려 왔어. 첫 줄에 뭘 적을까?","fuwa":"오늘은 내가 네 짝이야. 우리 끝까지 같이 해 보자!"}
const MILK := Color("fff1d0")
var member_index := 0
var phase := "roster"
var reply := -1
var gain := 0

func open(g) -> void:
	if not g.MEMBERS[member_index].id in g.state.residents:
		member_index = g._mission_index_for(g.state.residents[0])
	phase = "roster"
	g.mode = "stella_life"

func handle_key(g, key: int) -> void:
	if key == KEY_ESCAPE: action(g,"back")
	elif phase == "roster":
		if key >= KEY_1 and key <= KEY_6: action(g,"member_%d" % (key-KEY_1))
		elif key == KEY_B: action(g,"stream")
		elif key == KEY_T: action(g,"workout")
	elif phase == "training_menu" and key >= KEY_1 and key <= KEY_4: action(g,Workout.ORDER[key-KEY_1])
	elif phase in ["stream","promo_chat"] and key in [KEY_1,KEY_2]: action(g,"reply_%d" % (key-KEY_1))
	elif key in [KEY_E,KEY_SPACE,KEY_ENTER]:
		if phase == "stream": action(g,"signoff")
		elif phase == "result": action(g,"back")

func action(g, command: String) -> void:
	var id: String = g.MEMBERS[member_index].id
	if command == "back":
		if phase in ["roster","promo_chat"]:
			g.mode = "play"
			phase = "roster"
		else: phase = "roster"
	elif phase == "roster":
		if command.begins_with("member_"):
			var index := int(command.trim_prefix("member_"))
			if index >= 0 and index < g.MEMBERS.size() and g.MEMBERS[index].id in g.state.residents: member_index = index
		elif command == "workout" and g.state.yard_session.is_empty() and g.state.can_do_activity(id,"workout"):
			phase = "training_menu"
		elif command == "stream" and g.state.can_do_activity(id,"stream"):
			if g.state.yard_host == id: open_chat(g)
			else: g._begin_yard_stream(member_index)
	elif phase == "training_menu" and command in Workout.ORDER and g.state.can_do_activity(id,"workout"):
		g._begin_yard_workout(member_index,command)
	elif phase in ["stream","promo_chat"]:
		if reply < 0 and command in ["reply_0","reply_1"]:
			reply = int(command.right(1))
			broadcast_started = g.clock
		elif phase=="stream" and reply >= 0 and command == "signoff": _finish(g,id)
	g.queue_redraw()

func open_chat(g, recommendation:=false) -> void:
	phase = "promo_chat" if recommendation else "stream"
	reply = -1
	broadcast_started = g.clock

func _finish(g, id: String) -> void:
	gain = g.state.finish_activity(id,"stream",reply)
	if gain == 0:
		phase = "roster"
		return
	phase = "result"
	if g.state.yard_host == id: g.state.yard_host = ""
	if g.state.ink_visits.start(g.state,0,id):
		g._notify("방송을 보고 잉크가 방문할 예정이에요. 도서관에서 맞이해요.")
	elif g.state.has_method("operating_summary"):
		g._notify("이번 방송은 개인 교류로 기록했어요. "+g.state.ink_visits.start_error(g.state,0,id))
	broadcast_started = g.clock
	g._save()
	g._play_chime(784)

func draw(g) -> void:
	var member: Dictionary = g.MEMBERS[member_index]
	var show: Dictionary = SHOWS[member.id]
	var record: Dictionary = g.state.activity_record(member.id)
	var fan: String = g.Chapters.BOOKS[member.id].fan
	g._panel(Rect2(100,64,1080,666),g.PAPER)
	var place := "책 속 정원" if g.state.scene == "garden" else "루체테 도서관"
	var calendar: Dictionary=g.state.library_calendar() if g.state.has_method("library_calendar") else Calendar.calendar(g.state.day)
	g._text(Vector2(144,113),"%s   /   스텔라의 하루   ·   %s" % [place,calendar.label],16,g.GOLD)
	var title: String = show.title
	if phase == "roster": title = "스텔라의 하루"
	elif phase == "training_menu": title = "오늘의 운동 약속"
	elif phase == "promo_chat": title = g.state.ink_visits.TOPICS[0].title
	g._text(Vector2(142,164),title,36)
	g._button(Rect2(943,105,187,44),("정원으로   Esc" if g.state.scene == "garden" else "도서관으로   Esc") if phase in ["roster","promo_chat"] else "활동 목록   Esc","life_back")
	g.draw_line(Vector2(144,190),Vector2(1135,190),Color("b68d60"),2)
	if phase == "roster":
		g._text(Vector2(145,232),"오늘 누구와 함께할까?",22)
		for i in range(g.MEMBERS.size()):
			var other: Dictionary = g.MEMBERS[i]
			var locked: bool = other.id not in g.state.residents
			g._button(Rect2(145,258+i*53,270,44),"%d   %s%s" % [i+1,other.name,"  ·  책 속" if locked else ""],"life_member_%d" % i,i == member_index,locked)
		_stage(g,Rect2(450,217,258,352),member)
		g._text(Vector2(742,254),member.name,29)
		g._text(Vector2(742,292),"%s의 기억  ·  %d" % [fan,record.memory],19,g.GOLD)
		g._text(Vector2(742,353),"팬이 간직한 한마디",15,g.MUTED)
		var last: String = "방송을 켜면 첫 채팅이 도착해요."
		if record.reply >= 0: last = "“%s”" % show.chats[record.reply]
		elif record.workout_day > 0: last = "“%s”" % Workout.ROUTINES[record.last_workout].note
		g._text_block(Vector2(742,390),last,365,20,g.CREAM,30)
		g._text_block(Vector2(742,486),"몸풀기 완료 · 다음 방송에 기억 +1" if record.prepared else "운동으로 몸을 풀면 다음 방송에 힘이 실려요.",365,16,g.MUTED,26)
		var stream_ready: bool = g.state.can_do_activity(member.id,"stream") and g.state.yard_session.get("member","") != member.id
		var stream_label := "도서관 방송 켜기   B" if g.state.yard_host != member.id else "도서관 방송 채팅   B"
		g._button(Rect2(450,590,330,54),stream_label if stream_ready else "방송 쉬는 중","life_stream",true,not stream_ready)
		var workout_ready: bool = g.state.can_do_activity(member.id,"workout") and g.state.yard_session.is_empty()
		g._button(Rect2(798,590,332,54),"실내 운동 정하기   T" if workout_ready else ("운동 진행 중" if not g.state.yard_session.is_empty() else "오늘 운동 마침"),"life_workout",false,not workout_ready)
	elif phase == "training_menu":
		g._text(Vector2(150,250),member.name,24)
		g._text_block(Vector2(150,296),"“%s”" % INVITES[member.id],940,20,g.CREAM,28)
		for i in range(Workout.ORDER.size()):
			var id: String = Workout.ORDER[i]
			var pos := Vector2(150+(i%2)*500,340+floori(i/2.0)*128)
			g._button(Rect2(pos,Vector2(476,61)),"%d    %s" % [i+1,Workout.ROUTINES[id].name],"life_"+id)
			g._text(pos+Vector2(10,92),Workout.ROUTINES[id].description,16,g.MUTED)
		g._text(Vector2(151,627),"종목을 고르면 도서관 안에서 운동을 시작해요.   ·   하루 한 종목",17,g.GOLD)
	else:
		_stage(g,Rect2(145,222,395,370),member)
		g._text(Vector2(580,255),member.name+"  ·  방송 채팅",18,g.GOLD)
		if phase=="promo_chat":
			var messages:=["도서관에 보러 갈게!","어디부터 읽으면 좋을까?"]
			g._text(Vector2(580,320),"도서관 추천 방송",18,g.GOLD)
			if reply<0:
				g._text(Vector2(580,390),"어떤 채팅을 남길까?",21,g.CREAM)
				for i in range(messages.size()):
					g._button(Rect2(580,450+i*64,550,52),"%d    %s" % [i+1,messages[i]],"life_reply_%d" % i)
			else:
				g._text(Vector2(580,392),"나   “%s”" % messages[reply],19,g.MUTED)
				g._text_block(Vector2(580,461),BOOK_CHAT[member.id][reply],524,22,g.CREAM,32)
				g._button(Rect2(580,589,550,54),"채팅 닫기   Esc","life_back",true)
		elif phase == "result":
			g._text(Vector2(580,321),"오늘을 기억하는 한마디",29)
			var note: String = show.chats[record.reply]
			g._text_block(Vector2(580,384),"%s   “%s”" % [fan,note],525,21,g.CREAM,33)
			g._text(Vector2(580,493),"%s의 기억 +%d    ·    누적 %d" % [fan,gain,record.memory],20,g.GOLD)
			g._text(Vector2(580,531),"활동실에 이 채팅을 간직했어요.",16,g.MUTED)
			g._button(Rect2(580,589,550,54),"하루 기록 덮기   E","life_back",true)
		elif phase == "stream":
			g._text(Vector2(580,307),fan+"의 첫 채팅" if record.reply < 0 else "다시 찾아온 "+fan,17,g.MUTED)
			var prompt: String = show.prompt if record.reply < 0 else show.returning[record.reply]
			g._text_block(Vector2(580,346),prompt,532,23,g.CREAM,32)
			if reply < 0:
				g._text(Vector2(580,440),"어떻게 답해 볼까?",18,g.MUTED)
				for i in range(2):
					g._button(Rect2(580,464+i*64,550,52),"%d    %s" % [i+1,show.choices[i]],"life_reply_%d" % i)
			else:
				g._text(Vector2(580,417),member.short+"  ·  마이크",14,g.MUTED)
				g._text_block(Vector2(580,447),show.lines[reply],528,20,g.CREAM,28)
				g._text(Vector2(580,502),fan+"  ·  채팅",14,g.MUTED)
				g._text_block(Vector2(580,534),show.chats[reply],528,20,g.GOLD,28)
				g._button(Rect2(580,589,550,54),"끝인사하고 방송 마치기   E","life_signoff",true)
	g._text(Vector2(145,690),"팬게임 창작 일상",14,g.MUTED)
	g._text(Vector2(450,690),"개인 교류와 운동은 멤버별 하루 한 번 · 도서관 홍보는 전체 하루 2회",14,g.MUTED)

func _stage(g, box: Rect2, member: Dictionary) -> void:
	var mid := box.get_center()
	var feet := Vector2(mid.x,box.end.y-43)
	var accent := Color(member.color)
	g.draw_rect(box,Color("604835"))
	if g.studios_open:
		g.Studios.paint(g,member_index,box.grow(-4),false)
	else:
		g.draw_rect(box.grow(-4),Color("394051"))
		for i in range(5):
			g.draw_rect(Rect2(box.position.x+16+i*(box.size.x-25)/5,box.position.y+70,9,box.size.y-132),accent.darkened(0.52))
		g.draw_rect(Rect2(box.position.x+5,feet.y+2,box.size.x-10,36),Color("766655"))
		g.draw_rect(Rect2(mid.x-76,feet.y-4,152,10),accent.darkened(0.28))
	if phase != "roster":
		stage.broadcast(g,box,member,g.clock-broadcast_started,reply,phase == "result")
	else:
		g._draw_member(feet,member.id,213,true)
		if g.studios_open: g.Studios.paint(g,member_index,box.grow(-4),true)
	var label := "활동 준비"
	if phase in ["stream","promo_chat"]: label = "●  ON AIR"
	elif phase == "result": label = "기록 완료"
	g.draw_rect(Rect2(box.position+Vector2(12,12),Vector2(100,31)),Color("8d4049") if phase == "stream" else Color("365b56"))
	g._text(box.position+Vector2(23,34),label,15,MILK)
