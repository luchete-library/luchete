extends RefCounted

# World-space coordinates. The field actor and the tool share the same feet anchor.
const ENTRANCE := Vector2(524,452)
const STATION := Vector2(358,324)
const LANE_LEFT := 281.0
const LANE_RIGHT := 368.0
const POINTS := [Vector2(292,244),Vector2(367,244)]
const GRIP := Vector2(-12,-19)
const GLASS_OFFSET := Vector2(-19,-18)
const MARKS := ["hand_pause","arrow_stack"]
const LABELS := ["손질하던 화살","겹쳐 놓은 화살"]
const HONEY := Color("ffdf99")
const DARK := Color("593b38")
const CLOSE_SCALE := 2.0
const CLOSE_OFFSET := Vector2(-62,-224)
const RAISE_TIME := .38
const STUDY_TIME := .85
const WORK_AREA := Rect2(247,206,170,90)
const ARROW_HALF_WIDTH := 23.0

var camera := 0.0
var active_time := 0.0
var pointer_x := 0.0
var follow_pointer := false
var steer_left := false
var steer_right := false
var key_held := false
var mouse_held := false
var pointer_arrow := -1
var anchor_y := STATION.y
var raised := 0.0
var studied := 0.0

func begin(g) -> void:
	active_time=0.0
	anchor_y=g.player_pos.y
	raised=0.0
	studied=0.0
	release()
	g.chapter_note="같은 작업대인데 화살은 겹겹이 쌓였어. 손질하던 화살과 나란히 비교해 볼까?"

func release() -> void:
	steer_left=false
	steer_right=false
	follow_pointer=false
	key_held=false
	mouse_held=false
	pointer_arrow=-1
	studied=0.0

func center(g) -> Vector2:
	return Vector2(g.player_pos.x+GRIP.x+GLASS_OFFSET.x,244)

static func arrow_at(x: float) -> int:
	for i in range(POINTS.size()):
		if absf(x-POINTS[i].x)<=ARROW_HALF_WIDTH: return i
	return -1

func reach(p: Vector2) -> void:
	var over_table:=WORK_AREA.has_point(p)
	var target:=arrow_at(p.x) if over_table else -1
	if mouse_held and target!=pointer_arrow: studied=0.0
	pointer_arrow=target
	if over_table:
		follow_pointer=true
		pointer_x=clampf(p.x,LANE_LEFT,LANE_RIGHT)

func advance(g,dt: float) -> void:
	active_time+=dt
	var dx:=int(steer_right)-int(steer_left)
	var dest: float=g.player_pos.x
	if dx!=0: dest=LANE_RIGHT-GRIP.x-GLASS_OFFSET.x if dx>0 else LANE_LEFT-GRIP.x-GLASS_OFFSET.x
	elif follow_pointer: dest=pointer_x-GRIP.x-GLASS_OFFSET.x
	var previous_arrow:=arrow_at(center(g).x)
	g.player_pos.x=move_toward(g.player_pos.x,dest,dt*104)
	raised=minf(1,raised+dt/RAISE_TIME)
	var i:=arrow_at(center(g).x)
	var observing:=i>=0 # Resting the magnifier on an arrow is the observation.
	if i<0 or i!=previous_arrow or not observing or raised<1 or MARKS[i] in g._chapter_progress().danming_notes:
		studied=0.0
		return
	studied=minf(STUDY_TIME,studied+dt)
	if studied>=STUDY_TIME:
		g.DanmingWorkshop.mark_found(g,MARKS[i])
		g.chapter_note=["천이 한 화살 위에 멈춰 있어. 처음 작업대에서 보던 단밍의 빠른 손길이 달라졌어.","반듯하게 손질된 화살이 몇 겹이나 포개졌어. 같은 일을 얼마나 오래 했던 걸까."][i]
		g._play_chime(635+i*105)
		studied=0.0

func input(g,event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: int=event.physical_keycode
		if key in [KEY_F11,KEY_F5]: return false
		if event.echo: return true
		match key:
			KEY_ESCAPE:
				if event.pressed: g.danming_workshop.close(g,false)
			KEY_LEFT,KEY_A:
				steer_left=event.pressed
				follow_pointer=false
			KEY_RIGHT,KEY_D:
				steer_right=event.pressed
				follow_pointer=false
			KEY_E,KEY_SPACE,KEY_ENTER:
				key_held=event.pressed
	elif event is InputEventMouseMotion:
		reach((event.position-g.WORLD_OFFSET)/g.WORLD_SCALE)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			mouse_held=false
			if not key_held: studied=0.0
			return true
		for b in g.buttons:
			if b.rect.has_point(event.position):
				match b.id:
					"bee_read": g.danming_workshop.close(g,true)
					"bee_back": g.danming_workshop.close(g,false)
					"chapter_leave": g._leave_chapter()
				return true
		var world: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
		if WORK_AREA.has_point(world):
			reach(world)
			mouse_held=true
	return true

static func arrow(g,p: Vector2,scale_factor: float=1.0) -> void:
	# A continuous shaft, notched fletching and the fairy's heart-shaped tip.
	var s:=Vector2.ONE*scale_factor
	g.draw_line(p+Vector2(-22,2)*s,p+Vector2(21,-2)*s,DARK,4*scale_factor)
	g.draw_line(p+Vector2(-21,1)*s,p+Vector2(21,-3)*s,Color("efc484"),2*scale_factor)
	for i in range(3):
		var root:=p+Vector2(-21+i*4,1)*s
		g.draw_line(root+Vector2(-4,-4)*s,root,Color("f1d8c3"),2*scale_factor)
		g.draw_line(root+Vector2(-4,5)*s,root,Color("c28693"),2*scale_factor)
	var tip:=p+Vector2(16,-3)*s
	var pts:=PackedVector2Array()
	for off: Vector2 in [Vector2(0,0),Vector2(-3,-3),Vector2(0,-6),Vector2(4,-5),Vector2(9,0),Vector2(3,5),Vector2(-1,5),Vector2(-3,2)]:
		pts.append(tip+off*s)
	g.draw_colored_polygon(pts,Color("cf7e93"))
	g.draw_line(tip+Vector2(0,-4)*s,tip+Vector2(3,-3)*s,Color("ffd6c8"),2*scale_factor)

func draw_table(g,active: bool,notes: Array) -> void:
	# Fitted tabletop, front apron and grounded legs surround the leather work pad.
	g.draw_rect(Rect2(247,229,170,36),Color("493437"))
	g.draw_rect(Rect2(249,229,166,31),Color("b9825c"))
	for plank in range(3):
		g.draw_rect(Rect2(250,230+plank*10,164,1),Color("dfb181"))
		g.draw_rect(Rect2(250,238+plank*10,164,1),Color("80513e"))
	g.draw_rect(Rect2(249,261,166,5),Color("80503e"))
	g.draw_rect(Rect2(250,261,164,1),Color("d7a16a"))
	for x in [253,403]:
		g.draw_rect(Rect2(x,266,8,16),Color("49383a"))
		g.draw_rect(Rect2(x+1,266,2,14),Color("94674d"))
		g.draw_rect(Rect2(x-2,281,13,2),Color("49383a80"))
		g.draw_rect(Rect2(x+2,262,2,2),Color("efd393"))
	var mat:=Rect2(255,232,153,25)
	# A fitted leather work pad: bevel, stitched border and tiny brass corners.
	g.draw_rect(mat.grow(3),Color("3f303d"))
	g.draw_rect(mat.grow(2),DARK)
	g.draw_rect(mat,Color("556259"))
	g.draw_line(mat.position+Vector2(2,21),mat.end-Vector2(2,4),Color("3f504a"),1)
	for i in range(26):
		var x:=mat.position.x+4+posmod(i*59,143)
		var y:=mat.position.y+3+posmod(i*13,19)
		g.draw_rect(Rect2(x,y,2+i%4,1),Color("61695b"))
	for x in range(259,404,8):
		g.draw_rect(Rect2(x,234,4,1),Color("acac85"))
		g.draw_rect(Rect2(x,254,3,1),Color("8d9772"))
	for corner: Vector2 in [Vector2(257,233),Vector2(403,233),Vector2(257,253),Vector2(403,253)]:
		g.draw_rect(Rect2(corner,Vector2(3,3)),Color("9b713e"))
		g.draw_rect(Rect2(corner,Vector2(2,1)),Color("f0d291"))
	arrow(g,POINTS[0])
	# The cloth makes short strokes, then rests on the last arrow.
	var stroke:=roundf(5*sin(g.clock*5)*(1.0-smoothstep(.15,1.35,active_time))) if active else roundf(5*sin(g.clock*5))
	var cloth:=Vector2(287+stroke,239)
	g.draw_rect(Rect2(cloth,Vector2(12,7)),Color("735675"))
	g.draw_rect(Rect2(cloth+Vector2(-2,1),Vector2(11,5)),Color("d5bad0"))
	g.draw_line(cloth+Vector2(3,1),cloth+Vector2(6,4),Color("b49aac"),1)
	g.draw_line(cloth+Vector2(-1,5),cloth+Vector2(8,5),Color("f0dce1"),1)
	for stitch in range(3): g.draw_rect(Rect2(cloth+Vector2(stitch*3,2),Vector2(1,1)),Color("ead3df"))
	for i in range(4):
		arrow(g,POINTS[1]+Vector2(i%2*5-3,i*4-6),.86)
	for i in range(2):
		if MARKS[i] in notes:
			g.draw_line(POINTS[i]+Vector2(13,-14),POINTS[i]+Vector2(16,-11),HONEY,2)
			g.draw_line(POINTS[i]+Vector2(16,-11),POINTS[i]+Vector2(22,-17),HONEY,2)
		elif not active: g._star(POINTS[i]-Vector2(0,15),3+sin(g.clock*2+i),HONEY)

func draw_beori(g,feet: Vector2) -> void:
	# Beori floats up to tabletop height; keep the original whole-body wing and blink frames.
	g.draw_ellipse_shadow(feet+Vector2(0,2),Vector2(15-raised*3,3))
	var body: Vector2=(feet-Vector2(0,raised*(anchor_y-281)+roundf(sin(g.clock*3)*raised))).round()
	var frame: int=g.FanForms.frame_at("danming",g.clock,false)
	g.Field.Finish.cel(g,g.FanForms.texture("danming"),Rect2(body-Vector2(32,58),Vector2(64,64)),g.FanForms.region_for(frame,"left"))
	var grip: Vector2=body+GRIP
	var glass: Vector2=grip+GLASS_OFFSET*smoothstep(0,1,raised)
	if raised<.08: return
	# Handle begins at the mascot's near paw and ends at the lower rim.
	g.draw_line(grip,glass,DARK,6)
	g.draw_line(grip,glass,Color("cb986b"),3)
	g.draw_rect(Rect2(grip-Vector2(2,2),Vector2(5,4)),Color("f4ca89"))
	var radius:=lerpf(3,13,smoothstep(0,1,raised))
	g.draw_circle(glass,radius+2,DARK)
	g.draw_circle(glass,radius,Color("ddae68"))
	if raised>.8:
		g.draw_arc(glass,radius-1,PI*.93,PI*1.72,18,Color("fff1bf"),1)
		g.draw_arc(glass,radius-1,0,PI*.60,14,Color("99643f"),1)
	g.draw_circle(glass,radius-2,Color("466268"))
	g.draw_circle(glass,radius-4 if radius>5 else 1,Color("aac8b7"))
	if raised>.8:
		var i:=arrow_at(center(g).x)
		var c: Vector2=glass.round()
		# Shift the magnified strokes as the glass passes over them.
		var shift: float=clampf((POINTS[i].x-center(g).x)*.22,-3,3) if i>=0 else 0.0
		var sample:=c+Vector2(roundf(shift),0)
		if i==1:
			for j in [-1,0,1]: g.draw_line(sample+Vector2(-6,j*4+2),sample+Vector2(5,j*4-2),Color("a97146"),2)
		elif i==0:
			g.draw_line(sample+Vector2(-7,3),sample+Vector2(6,-1),Color("b47c53"),3)
			g.draw_rect(Rect2(sample-Vector2(4,4),Vector2(7,6)),Color("ac88a5"))
		g.draw_line(c+Vector2(-6,-4),c+Vector2(-2,-8),Color("f7f2d7"),2)
		if studied>0:
			g.draw_arc(c,radius+5,-PI/2,-PI/2+TAU*studied/STUDY_TIME,28,HONEY,3)

func draw_hud(g) -> void:
	var notes: Array=g._chapter_progress().danming_notes
	var n:=int("arrow_stack" in notes)+int("hand_pause" in notes)
	g._panel(Rect2(97,651,1086,140),g.PAPER)
	var i:=arrow_at(center(g).x)
	var title: String="작업대" if i<0 else LABELS[i]
	g._text(Vector2(123,686),"버리의 돋보기   ·   "+title+"     %d / 2"%n,21,g.CREAM)
	g._text(Vector2(123,719),"← → 또는 화살 쪽으로 마우스 이동   ·   E 또는 화살 위에서 왼쪽 버튼을 길게 눌러 관찰",17,g.MUTED)
	g._text_block(Vector2(123,758),g.chapter_note,826,16,g.CREAM,20)
	g._button(Rect2(949,663,209,35),"돋보기 내리기   Esc","bee_back")
	if n==2: g._button(Rect2(949,735,209,38),"기억 펼치기   E","bee_read",true)
