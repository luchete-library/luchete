extends RefCounted

# Each illustrated leaf owns its gestures. The paper, controls and bookmarks are shared.
const FRAME := Rect2(160,178,684,330)
const BACK := Rect2(157,652,201,42)
const READ := Rect2(837,652,286,42)
const LINE := Color("937451")
const GOLD := Color("ffdf91")
var member: String
var scene: int
var title: String
var caption: String
var instructions: String
var note := ""
var dragging := false

func notes(g) -> Array:
	return g._chapter_progress().get(member+"_notes")

func remember(g,marks: Array) -> void:
	var saved:=notes(g)
	var changed:=false
	for mark in marks:
		if mark not in saved:
			saved.append(mark)
			changed=true
	if changed:
		g._play_chime(650)
		if g.replay_progress==null: g._save()

func open(g) -> void:
	g.chapter_question=true
	g.buttons.clear()
	g.queue_redraw()

func close(g,read: bool) -> void:
	if read and not finished(g): return
	dragging=false
	g.book_activity=null
	g.chapter_question=false
	g.chapter_note=note
	g._setup_map()
	if read: g._inspect_chapter(scene,note)
	elif finished(g): g.chapter_observation=note
	g.queue_redraw()

func finished(_g) -> bool: return false
func paint(_g) -> void: pass
func key(_g,_code: int) -> void: pass
func pointer(_g,_p: Vector2,_start: bool) -> void: pass
func release(_g,_p: Vector2) -> void: pass

func picture(g,cut: int,frame: float) -> void:
	g.draw_texture_rect_region(g.Comics.sheet(member),FRAME,g.Comics.key_region(cut,frame))

func side_text(g,y: int,value: String,heading: bool=false) -> void:
	g._text_block(Vector2(878,y),value,240,21 if heading else 17,g.CREAM if heading else g.MUTED,26)

func target(g,p: Vector2,radius: int,selected: bool=true) -> void:
	var color:=GOLD if selected else Color("eadbb9")
	g.draw_arc(p,radius,0,TAU,32,Color("594657"),5)
	g.draw_arc(p,radius,0,TAU,32,color,2)

func draw(g) -> void:
	g._panel(Rect2(113,66,1054,658),g.PAPER)
	g._text(Vector2(157,121),title,29,g.CREAM)
	var fan_frame: int=g.FanForms.frame_at(member,g.clock,false)
	g.draw_texture_rect_region(g.FanForms.texture(member),Rect2(837,79,56,56),g.FanForms.region_for(fan_frame))
	g._text(Vector2(901,118),g.Chapters.BOOKS[member].fan+"의 책갈피",19,g.MUTED)
	g._text(Vector2(159,160),caption,16,g.MUTED)
	g.draw_rect(FRAME.grow(3),LINE)
	paint(g)
	g.draw_line(Vector2(158,545),Vector2(1121,545),LINE,1)
	g._text_block(Vector2(160,580),note,954,19,g.CREAM,25)
	g._text(Vector2(160,626),instructions,16,g.MUTED)
	g._button(BACK,"현장으로   Esc","activity_back")
	if finished(g): g._button(READ,"기억 펼치기   E","activity_read",true)

func input(g,event: InputEvent) -> bool:
	if event is InputEventKey:
		var code: int=event.physical_keycode
		if code in [KEY_F5,KEY_F11]: return false
		if event.pressed and not event.echo:
			if code==KEY_ESCAPE: close(g,false)
			elif code in [KEY_E,KEY_SPACE,KEY_ENTER] and finished(g): close(g,true)
			else: key(g,code)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if BACK.has_point(event.position): close(g,false)
			elif finished(g) and READ.has_point(event.position): close(g,true)
			else: pointer(g,event.position,true)
		else:
			if dragging: release(g,event.position)
			dragging=false
	elif event is InputEventMouseMotion and dragging: pointer(g,event.position,false)
	g.queue_redraw()
	return true
