extends RefCounted

# Local reader controls never modify story progress or save data.
var paused := false
var held := 0.0
var offset := 0.0
var selected_cut := -1
var enlarged := false

func reset() -> void:
	paused=false
	held=0.0
	offset=0.0
	selected_cut=-1
	enlarged=false

func elapsed(g) -> float:
	return held if paused else offset+maxf(0,g.clock-g.comic_started)

func update(g) -> void:
	if paused: return
	var id: String=g.MEMBERS[g.story_member].id
	var end: float=g.Comics.cut_start(id,selected_cut+1)-.001 if selected_cut>=0 else g.Comics.duration(id)
	if elapsed(g)>=end:
		held=end
		paused=true

func select(g, cut: int) -> void:
	var id: String=g.MEMBERS[g.story_member].id
	selected_cut=clampi(cut,0,3)
	held=g.Comics.cut_start(id,selected_cut)
	offset=held
	g.comic_started=g.clock
	paused=false

func action(g, command: String) -> bool:
	if command.begins_with("comic_cut_"):
		select(g,int(command.trim_prefix("comic_cut_")))
	elif command in ["comic_prev","comic_next"]:
		var id: String=g.MEMBERS[g.story_member].id
		var current: int=g.Comics.sample(id,elapsed(g)).x
		select(g,current+(-1 if command=="comic_prev" else 1))
	elif command=="comic_pause":
		if paused:
			var id: String=g.MEMBERS[g.story_member].id
			if selected_cut>=0 and held>=g.Comics.cut_start(id,selected_cut+1)-.002:
				select(g,selected_cut)
			elif held>=g.Comics.duration(id):
				held=0.0
				offset=0.0
				g.comic_started=g.clock
				paused=false
			else:
				offset=held
				g.comic_started=g.clock
				paused=false
		else:
			held=elapsed(g)
			paused=true
	elif command=="comic_zoom": enlarged=not enlarged
	else: return false
	g.queue_redraw()
	return true

func input(g, event: InputEvent) -> bool:
	if g.comic_started<0: return false
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_F5,KEY_F11: return false
				KEY_E,KEY_ESCAPE,KEY_ENTER: g._action("comic_close")
				KEY_SPACE: action(g,"comic_pause")
				KEY_V: g._action("comic_play")
				KEY_Z: action(g,"comic_zoom")
				KEY_LEFT: action(g,"comic_prev")
				KEY_RIGHT: action(g,"comic_next")
				KEY_1,KEY_2,KEY_3,KEY_4: select(g,event.physical_keycode-KEY_1)
		return true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			for i in range(g.buttons.size()-1,-1,-1):
				if g.buttons[i].id.begins_with("comic_") and g.buttons[i].rect.has_point(event.position):
					g._action(g.buttons[i].id)
					break
		return true
	return event is InputEventMouseMotion
