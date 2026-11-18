extends RefCounted

# All six books share a reader-paced result. Official facts remain in debut_records.json.
const MEMBERS := ["danming","dori","yune","kubby","yato","fuwa"]
const FADE := .65
var paused := false
var was_question := false
var result_scene := -1
var result_id := ""
var elapsed := 0.0
var duration := 5.0
var arrival_fade := 0.0
var cancel_at := Vector2(-10000,-10000)
var automatic := false # Session preference only; reset/returning to a book preserves it.
var next_requested := false
var reviewing := false
var detail_time := 0.0
const DETAILS := {
	"yune_1":{"label":"악몽의 흐름 살펴보기","note":"유네에게 모여드는 어두운 꿈의 모양을 눈으로 따라가 보자.","point":Vector2(604,403)},
	"yune_2":{"label":"꿈빛 비교하기","note":"깃털 사이와 바닥의 꿈빛을 함께 바라보자. 밤이 지날수록 같은 자리가 옅어진다.","point":Vector2(563,392)},
	"kubby_1":{"label":"작은 햄스터 살펴보기","note":"바닥을 지나가는 작은 햄스터와 내가 움직이는 햄님은 서로 다른 모습이야.","point":Vector2(595,489)},
	"yato_1":{"label":"가족의 표정 살펴보기","note":"말을 건네는 토끼 가족과 그 말을 듣는 야토의 표정을 번갈아 보자.","point":Vector2(583,395)},
	"yato_3":{"label":"야토 곁의 빛 살펴보기","note":"야토 곁에 머물며 주변의 빛을 바라보자. 떠나온 숲과 마을의 기억도 함께 떠올려 보자.","point":Vector2(535,328)},
	"fuwa_2":{"label":"눈발 너머 살펴보기","note":"눈 덮인 공터와 나무 사이를 살펴보자. 고개를 든 자리에서 후와가 다가오는 모습을 기다릴 수 있어.","point":Vector2(607,429)}
}

func active(g) -> bool:
	if g.mode!="chapter" or not g.MEMBERS[g.story_member].id in MEMBERS: return false
	if g.MEMBERS[g.story_member].id=="dori" and g._chapter_progress().debut_scene("dori")==2:
		return result_scene>=0 or g.dori_rubbing.phase==g.DoriCase.Rubbing.Phase.MATCHED
	return true

func reset() -> void:
	paused=false
	result_scene=-1
	result_id=""
	elapsed=0.0
	arrival_fade=0.0
	cancel_at=Vector2(-10000,-10000)
	next_requested=false
	reviewing=false
	detail_time=0.0

func request_next(g) -> void:
	if not active(g) or result_scene<0 or paused or next_requested: return
	next_requested=true
	reviewing=false
	elapsed=0.0
	g.chapter_question=true

func review(g) -> void:
	if result_scene<0 or next_requested: return
	reviewing=not reviewing
	if reviewing:
		release(g)
		g.danming_workshop.reset()
		g.yune_dream.reset()
		g.fuwa_snow.viewing=false
		g.fuwa_snow.practice.reset()
		g.kubby_embers.village.watching=false
		g.yato_forest.storehouse.phase=g.YatoForest.Storehouse.Phase.FIELD
		if result_id=="dori":
			g.dori_rubbing.phase=g.DoriCase.Rubbing.Phase.FIELD
			g.dori_rubbing.camera=0.0
	g.chapter_question=not reviewing
	g.route.clear()
	g.pending_object=""
	g._setup_map()

func detail(g) -> Dictionary:
	return DETAILS.get("%s_%d"%[g.MEMBERS[g.story_member].id,g._chapter_progress().debut_scene(g.MEMBERS[g.story_member].id)],{})

func detail_focus(g) -> Vector2:
	var id: String=g.MEMBERS[g.story_member].id
	var scene: int=g._chapter_progress().debut_scene(id)
	var point: Vector2=detail(g).point
	if id=="yune" and scene==1:
		if g.yune_dream.view==1:
			var flow: float=g.yune_dream.flow
			var mouth: Vector2=g.YuneDream.FRAME.position+Vector2(113,45)*4
			var origin: Vector2=g.YuneDream.FRAME.position+Vector2(121,139)
			var blend:=smoothstep(0.0,1.0,clampf(flow/.74,0,1))
			return origin.lerp(mouth,blend)+Vector2(0,sin(blend*PI)*-34+(1-blend)*sin(flow*TAU)*5)
		point=Vector2(460,414)
	elif id=="yune" and scene==2: point=g.yune_dream.nights.RING
	elif id=="kubby": point=g.kubby_embers.village.hamster_feet()-Vector2(0,9)
	elif id=="yato" and scene==1: point=g.yato_forest.storehouse.SPEAKER-Vector2(0,21)
	elif id=="yato": point=g.YatoForest.YATO_AT_REST-Vector2(0,40)
	elif id=="fuwa": point=g.fuwa_snow.reunion_feet-Vector2(0,38)
	return point*g.WORLD_SCALE+g.WORLD_OFFSET

func release(g) -> void:
	g.danming_workshop.release()
	g.yune_dream.holding=false
	g.fuwa_snow.practice.release()
	if g.book_activity!=null: g.book_activity.dragging=false

func toggle_pause(g) -> void:
	if not active(g): return
	if not paused: was_question=g.chapter_question
	paused=not paused
	release(g)
	g.chapter_question=true if paused else was_question
	g.route.clear()
	g.pending_object=""

func autostart_allowed(g) -> bool:
	return not active(g) or g.player_pos.distance_to(cancel_at)>36

func tool_open(g) -> bool:
	return g.danming_workshop.view>=0 or g.yune_dream.view>=0 or g.kubby_embers.village.watching or g.yato_forest.storehouse.phase!=g.YatoForest.Storehouse.Phase.FIELD or g.fuwa_snow.viewing or g.fuwa_snow.practice.phase!=g.FuwaSnow.WardPractice.Phase.FIELD

func back(g) -> void:
	if not active(g): return
	if result_scene>=0 or not tool_open(g):
		toggle_pause(g)
		return
	release(g)
	if g.danming_workshop.view>=0: g.danming_workshop.close(g,false)
	if g.yune_dream.view==2: g.yune_dream.nights.close(g,false)
	elif g.yune_dream.view>=0: g.yune_dream.close(g,false)
	g.kubby_embers.village.watching=false
	g.yato_forest.storehouse.phase=g.YatoForest.Storehouse.Phase.FIELD
	g.fuwa_snow.viewing=false
	g.fuwa_snow.practice.phase=g.FuwaSnow.WardPractice.Phase.FIELD
	g.chapter_question=false
	g.route.clear()
	g.pending_object=""
	cancel_at=g.player_pos
	g._setup_map()

func begin_result(g) -> void:
	if not active(g) or result_scene>=0: return
	var id: String=g.MEMBERS[g.story_member].id
	var scene: int=g._chapter_progress().debut_scene(id)
	if not g._chapter_progress().chapter_ready(id,scene): return
	result_id=id
	result_scene=scene
	elapsed=0.0
	duration=clampf(g.Chapters.BOOKS[id].records[scene].length()*.075,4.8,9.0)
	g.chapter_question=true
	g.route.clear()
	g.pending_object=""
	release(g)
	if g.replay_progress==null: g._save()

func advance(g,dt: float) -> void:
	arrival_fade=maxf(0,arrival_fade-dt)
	if not active(g) or paused: return
	detail_time=maxf(0,detail_time-dt)
	if result_scene<0:
		begin_result(g)
		return
	if reviewing: return
	elapsed+=dt
	if automatic and not next_requested and elapsed>=duration: request_next(g)
	if not next_requested or elapsed<FADE: return
	var progress=g._chapter_progress()
	var id:=result_id
	var scene:=result_scene
	if progress.debut_scene(id)!=scene or not progress.chapter_ready(id,scene):
		reset()
		return
	var success: bool
	if scene==0: success=progress.record_chapter_step(id,0)
	elif scene==1: success=progress.mark_first_action(id)
	elif scene==2: success=progress.record_chapter_step(id,1)
	else: success=progress.seal_page(id)
	if not success: return
	g.danming_workshop.reset()
	g.danming_workshop.lens.camera=0.0
	g.yune_dream.reset()
	g.yune_dream.nights.camera=0.0
	g.fuwa_snow.viewing=false
	g.fuwa_snow.practice.reset()
	g.kubby_embers.village.watching=false
	g.kubby_embers.village.camera=0.0
	g.yato_forest.storehouse.phase=g.YatoForest.Storehouse.Phase.FIELD
	g.yato_forest.storehouse.camera=0.0
	reset()
	if scene<3: g._next_chapter_site(id,scene)
	else:
		g.chapter_question=false
		g.mode="rescue"
		if g.replay_progress==null:
			g.ink_returned_at=g.clock
			g._save()
		g._play_chime(740)
	arrival_fade=FADE

func input(g,event: InputEvent) -> bool:
	if not active(g): return false
	if g._dori_notebook_open(): return false
	if event is InputEventKey:
		if event.physical_keycode in [KEY_F5,KEY_F11]: return false
		if event.pressed and not event.echo:
			if result_scene>=0 and not paused and event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER] and not reviewing:
				request_next(g)
				return true
			if event.physical_keycode==KEY_ESCAPE:
				if paused: toggle_pause(g)
				else: back(g)
				return true
			if paused and event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
				toggle_pause(g)
				return true
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for b in g.buttons:
			if not b.rect.has_point(event.position): continue
			match b.id:
				"discovery_pause","discovery_resume": toggle_pause(g)
				"discovery_back": back(g)
				"discovery_leave": g._leave_chapter()
				"discovery_next": request_next(g)
				"discovery_review": review(g)
				"discovery_auto":
					automatic=not automatic
					elapsed=0.0
				"discovery_detail":
					detail_time=6.0
					g._play_chime(610)
				_: continue
			return true
	return paused or (result_scene>=0 and not reviewing)

func caption(g) -> String:
	var id: String=g.MEMBERS[g.story_member].id
	var scene: int=g._chapter_progress().debut_scene(id)
	if detail_time>0 and not detail(g).is_empty(): return detail(g).note
	if result_scene>=0: return g.Chapters.BOOKS[id].records[scene]
	if id=="danming" and g.danming_workshop.view==2:
		return g.chapter_note if not g._chapter_progress().danming_notes.is_empty() else "같은 작업대인데, 화살과 손길은 어떻게 달라졌을까?"
	if id=="yune" and g.yune_dream.view==2:
		var n=g.yune_dream.nights
		return "아까 밝던 자리가 비어 가고 있어. 유네 너머로 바닥이 비치기 시작해." if n.fraction>.5 else "깃털 사이와 바닥에 꿈빛이 머물러 있어. 같은 자리를 지켜보자."
	if id=="kubby" and g.kubby_embers.village.watching:
		var v=g.kubby_embers.village
		if v.elapsed<v.REVEAL: return "쿠비가 골목 안쪽을 보고 있어."
		if v.elapsed<v.FLINCH: return "돌바닥을 타고 작은 햄스터가 다가와."
		return "쿠비가 움찔했어. 햄님 곁을 지나간 작은 햄스터를 보고 놀랐구나."
	if id=="yato" and g.yato_forest.storehouse.phase!=g.YatoForest.Storehouse.Phase.FIELD:
		var s=g.yato_forest.storehouse
		if s.phase==s.Phase.INSPECT: return "덮개 아래, 남아 있는 식량을 살펴보자."
		return "토끼 가족이 말을 꺼내고 있어. 야토의 표정을 지켜보자."
	if id=="fuwa" and g.fuwa_snow.viewing:
		var frame: int=g.fuwa_snow.frame(g)
		if frame<4: return "후와가 함께 신사로 돌아가기 위한 귀환술을 펼치고 있어."
		if frame<13: return "돌아가려던 눈밭 한가운데서 뜻밖의 빛이 갈라져."
		return "눈을 뜬 후와 주위에는 눈산 대신 수많은 책이 있어. 여기는 어디일까?"
	if id=="fuwa" and g.fuwa_snow.practice.phase!=g.FuwaSnow.WardPractice.Phase.FIELD:
		var p=g.fuwa_snow.practice
		if p.phase in [p.Phase.BLOOM,p.Phase.FINISHED]: return "그린 선이 빛나고 있어. 후와와 텐비의 수련이 하나로 이어졌어."
		return "붓끝 가까이로 돌아오면 그리던 자리에서 계속 이어져." if p.needs_regrab else "바닥의 문양을 따라 그리면, 후와도 함께 술식을 이어 가."
	return g.chapter_note

func controls(g) -> String:
	if result_scene>=0: return "현장을 자유롭게 둘러본 뒤 다음으로 이어갈 수 있어." if reviewing else "읽은 뒤 E / Space / Enter로 다음 이야기"
	if g.danming_workshop.view==2: return "화살 위에 돋보기 두기   /   ← → 또는 A D로 옮기기"
	if g.danming_workshop.view in [1,3]: return "천 / 책장 끌기   /   → 또는 D 길게 누르기"
	if g.yune_dream.view==0: return "매듭 / 깃털 클릭   /   ↑ ↓로 고르고 E 살펴보기"
	if g.yune_dream.view==1: return "유네의 손길을 지켜보기   ·   Esc 현장으로"
	if g.yune_dream.view==2: return "지나가는 밤의 꿈빛을 비교해 보기   ·   Esc 현장으로"
	if g.fuwa_snow.viewing:
		var f=g.fuwa_snow
		if not f.beyond_rift and f.frame(g)>=f.RIFT_FRAME: return "E / 그림 클릭   균열 너머 바라보기"
		if f.beyond_rift and f.frame(g)==g.Comics.KEY_FRAMES-1: return "E / 그림 클릭   낯선 도서관 둘러보기"
		return "귀환술이 이어지는 모습을 지켜보기   ·   Esc 현장으로"
	if g.fuwa_snow.practice.phase==g.FuwaSnow.WardPractice.Phase.TRACE: return "붓끝을 잡고 선 따라가기   /   E 길게 눌러 이어 그리기"
	if tool_open(g): return "장면의 변화를 지켜보기   ·   Esc 현장으로"
	return "방향키 / WASD 이동   ·   가까이에서 E 살펴보기   ·   클릭 이동"

func draw_focus(g) -> void:
	if not active(g) or g.chapter_question: return
	var near: Dictionary=g._nearest()
	if near.is_empty(): return
	var at: Vector2=near.pos*g.WORLD_SCALE+g.WORLD_OFFSET+Vector2(0,38)
	var label: String=near.label
	var width: float=g.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+49
	var box:=Rect2(Vector2(clampf(at.x-width/2,100,1180-width),clampf(at.y,100,648)),Vector2(width,33))
	g.chapter_signs.append({"id":near.id,"rect":Rect2((box.position-g.WORLD_OFFSET)/g.WORLD_SCALE,box.size/g.WORLD_SCALE)})
	g.in_world=false
	g._transform()
	g._panel(box,g.PAPER,g.GOLD)
	g._text(box.position+Vector2(12,23),"E  "+label,16,g.CREAM)
	g.in_world=true
	g._transform()

func draw_hud(g) -> void:
	var id: String=g.MEMBERS[g.story_member].id
	var scene: int=g._chapter_progress().debut_scene(id)
	if g._dori_notebook_open():
		g._panel(Rect2(202,170,876,470),g.PAPER)
		g.ui_regions.append(Rect2(202,170,876,470))
		g.DoriCase.draw_notebook(g,g._chapter_progress().dori_notes)
		return
	# Keep the existing pixel actions; their old menus are omitted in discovery mode.
	if id=="kubby" and scene==2 and "ice" in g._chapter_progress().kubby_notes:
		g.kubby_embers.draw_reflection(g)
		g.ui_regions.append(g.KubbyEmbers.FRAME.grow(4))
	if id=="fuwa" and scene==1 and "overlook" in g._chapter_progress().fuwa_notes:
		g.fuwa_snow.draw_overlook(g)
	if g.danming_workshop.view in [1,3]: g.danming_workshop.draw_closeup(g)
	if g.yune_dream.view in [0,1]: g.yune_dream.draw_closeup(g)
	if g.fuwa_snow.viewing: g.fuwa_snow.draw_view(g)
	var top:=Rect2(97,12,1086,52)
	g._panel(top,g.PAPER)
	g.ui_regions.append(top)
	g._text(Vector2(119,44),g.MEMBERS[g.story_member].short+"의 책 · "+g.Chapters.BOOKS[id].fan,15,g.GOLD)
	var question: String=g.StoryTrail.entry(id,scene).question if result_scene<0 else "발견한 기억 · 읽은 뒤 다음으로"
	var size:=20
	while size>15 and g.font.get_string_size(question,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>690: size-=1
	g._text(Vector2(330,45),question,size,g.CREAM)
	g._button(Rect2(1040,21,124,33),"메뉴  Esc","discovery_pause")
	var footer:=Rect2(97,689,1086,101)
	g._panel(footer,g.PAPER)
	g.ui_regions.append(footer)
	g._text_block(Vector2(120,718),caption(g),1018,18,g.CREAM,24)
	if result_scene>=0:
		g._button(Rect2(118,750,228,30),"기록으로 돌아가기" if reviewing else "현장 다시 보기","discovery_review")
		g._button(Rect2(359,750,202,30),"자동 넘김 켜짐" if automatic else "자동 넘김 꺼짐","discovery_auto")
		g._button(Rect2(904,750,258,30),"다음 이야기  E" if scene<3 else "책 마무리  E","discovery_next",true)
	else:
		g._text(Vector2(120,775),controls(g),15,g.MUTED)
		var extra:=detail(g)
		if not extra.is_empty():
			g._button(Rect2(835,650,328,30),extra.label+" · 선택","discovery_detail")
	if detail_time>0:
		var focus:=detail_focus(g)
		var pulse: float=2+roundf(sin(g.clock*4)*2)
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var p: Vector2=(focus+corner*Vector2(29+pulse,23+pulse)).round()
			g.draw_line(p,p-Vector2(corner.x*9,0),Color("ffdf91"),2)
			g.draw_line(p,p-Vector2(0,corner.y*9),Color("ffdf91"),2)
	if tool_open(g) and result_scene<0: g._button(Rect2(1031,744,132,33),"현장  Esc","discovery_back")
	if paused:
		g.buttons.clear()
		g.draw_rect(Rect2(0,0,1280,800),Color("172029b8"))
		g._panel(Rect2(410,267,460,254),g.PAPER)
		g._center(315,"잠시 책갈피를 꽂아 둘까?",22,g.CREAM)
		g._center(348,"발견한 기억은 그대로 남아 있어.",16,g.MUTED)
		g._button(Rect2(451,374,378,44),"계속 살펴보기   E / Esc","discovery_resume",true)
		g._button(Rect2(451,436,378,44),"책갈피 꽂고 책 나가기","discovery_leave")

func draw_transition(g) -> void:
	if paused: return # The pause menu must remain readable even during an arrival fade.
	var opacity:=arrival_fade/FADE
	if next_requested and not paused: opacity=maxf(opacity,clampf(elapsed/FADE,0,1))
	if opacity>0: g.draw_rect(Rect2(0,0,1280,800),Color(.13,.12,.16,opacity))
