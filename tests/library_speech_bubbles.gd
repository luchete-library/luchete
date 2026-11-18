extends "res://tests/library_day_flow.gd"
const Bubbles=preload("res://scripts/library_speech_bubbles.gd")
const DEST:="res://artifacts/speech_bubbles_20261118/"

func visitor(slot: int,point: Vector2,request: bool=true) -> Dictionary:
	var v: Dictionary=g.state.ink_visits._guest(slot,"read","dori")
	v.pos=point;v.phase="browse";v.request=request;v.noisy=not request;v.admitted=true;v.feature=0;v.source_host="dori"
	g.state.ink_visits.guests.append(v);g.library_day_flow.sync_targets(g)
	return v

func entries(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for b in Bubbles.layout(g,g.library_day_flow):
		if b.kind==kind: result.append(b)
	return result

func snap(name: String,crop: Rect2i=Rect2i()) -> void:
	g.toast_time=0;g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	if crop.has_area(): frame=frame.get_region(crop)
	frame.save_png(DEST+name+".png")

func check_layout() -> void:
	var current:=Bubbles.layout(g,g.library_day_flow)
	var bodies:=Bubbles.bodies(g)
	for i in range(current.size()):
		var bubble: Dictionary=current[i]
		check(Rect2(0,0,1280,800).encloses(bubble.rect),"balloon stays inside screen")
		for body in bodies: check(not bubble.rect.intersects(body),"balloon never covers a character")
		for j in range(i): check(not bubble.rect.intersects(current[j].rect),"balloons do not overlap")

func run() -> void:
	root.size=Vector2i(1280,800)
	fresh();g.growth.reward("visual",500,250)
	var request:=visitor(0,Vector2(376,328))
	visitor(1,Vector2(744,328),false)
	g.state.library_day.returned.assign([0,0,1,1]);g.state.library_day.neglect_seconds=120
	var old_mode: String=g.mode;var old_position: Vector2=g.player_pos
	g.library_day_flow.update(g,.1);g.library_day_flow.ete_elapsed=1.0
	check(g.mode==old_mode and g.player_pos==old_position,"Ete speaks without modal or teleport")
	check(entries("ete").size()==1 and entries("request").size()==1 and entries("quiet").size()==1,"Ete and both request kinds have speech bubbles")
	check(not entries("request")[0].expanded,"distant request is a compact exclamation")
	check_layout()
	var saved: String=JSON.stringify(g.state.to_data())
	await snap("01_overview")
	check(saved==JSON.stringify(g.state.to_data()),"rendering balloons does not mutate saved game")
	await snap("02_ete_speech",Rect2i(0,290,450,270))
	root.size=Vector2i(960,600)
	await snap("03_overview_960");check_layout()
	root.size=Vector2i(1280,800)
	g.player_pos=request.pos+Vector2(0,76)
	check(entries("request")[0].expanded,"nearby request shows invitation text")
	await snap("04_nearby_request")
	await snap("05_request_detail",Rect2i(250,180,340,250))
	root.size=Vector2i(960,600)
	await snap("06_nearby_960")
	var marker: Dictionary=entries("request")[0]
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=marker.rect.get_center()
	g._unhandled_input(mouse)
	for i in range(200):
		if g.mode=="day_choice": break
		g._process(.1)
	check(g.mode=="day_choice" and g.library_day_flow.selected_uid==request.uid,"click balloon reaches its visitor and opens recommendation at 960")
	check(Bubbles.layout(g,g.library_day_flow).is_empty(),"balloons hide behind choice menus")
	await snap("07_recommendation_960")
	g._action("day_pick_0")
	check(not request.request and entries("request").is_empty(),"accepted request removes exclamation immediately")
	check(g.state.library_day.recommended==1,"balloon does not create a second recommendation")
	root.size=Vector2i(1280,800)
	fresh();request=visitor(0,Vector2(376,328));g.player_pos=Vector2(560,720)
	marker=entries("request")[0]
	mouse.position=marker.rect.get_center();g._unhandled_input(mouse)
	check(g.pending_object=="day_ink_%d"%request.uid and not g.route.is_empty(),"distant balloon schedules walking to correct visitor")
	for i in range(240):
		if g.mode=="day_choice": break
		g._process(.1)
	check(g.mode=="day_choice","distant click walks and talks before request expires")
	g._action("day_back")
	request.elapsed=23.9;step(.2)
	check(not request.request and entries("request").is_empty(),"expired self-service request loses marker")
	check(not Bubbles.click(g,g.library_day_flow,marker.rect.get_center()),"stale marker cannot reopen a completed request")
	fresh();g.state.library_day.returned.assign([0,0,1,1]);g.state.library_day.neglect_seconds=120
	g.library_day_flow.update(g,.1)
	var elapsed: float=g.library_day_flow.ete_elapsed
	g.mode="pause";step(4)
	check(Bubbles.layout(g,g.library_day_flow).is_empty() and g.library_day_flow.ete_elapsed==elapsed,"pause hides and freezes Ete speech")
	g.mode="play";g.player_pos=Layout.HOME_DOOR
	check(Bubbles.layout(g,g.library_day_flow).is_empty(),"public balloons are absent in private rooms")
	g.player_pos=Layout.ENTRY;g.state.library_day.returned.clear();step(.1)
	check(entries("ete").is_empty(),"filing the pile dismisses Ete speech")
	g.state.library_day.returned.assign([0,0,1,1]);g.state.library_day.neglect_seconds=120;g.library_day_flow.update(g,.1)
	step(5.8)
	check(entries("ete").is_empty() and g.state.library_day.ete_warned,"speech ends without repeating the same warning")
	# Crowded shelves retain all request markers while respecting actors.
	fresh()
	for i in range(5): visitor(i,Layout.VISITOR_SHELVES[i])
	check(entries("request").size()==5,"all five supported visitor slots have distinct markers")
	check_layout();await snap("08_crowded_requests")
	var text_width: float=g.font.get_string_size("서가에 정리해 주세요.",HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	check(text_width<=238,"Ete speech fits its bubble")
	print("LIBRARY_SPEECH_BUBBLES: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
