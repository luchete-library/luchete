extends RefCounted

const DATA = preload("res://assets/world_pixels/dressing.json")
const Pixels = preload("res://scripts/world_pixels.gd")

static func entries(g) -> Array:
	if g.state.scene=="garden" and g.mode not in ["chapter","rescue"]:
		return DATA.data.maps.garden
	return []

static func obstacles(g) -> Array:
	var result := []
	for entry in entries(g):
		var info: Dictionary=DATA.data.items[entry.kind]
		if info.foot==null: continue
		var f: Array=info.foot
		var p:=Vector2(entry.pos[0],entry.pos[1])
		result.append(Rect2(p+Vector2(f[0],f[1])*entry.scale,Vector2(f[2],f[3])*entry.scale))
	return result

static func append_actors(g, actors: Array) -> void:
	for entry in entries(g):
		actors.append({"index":-6,"pos":Vector2(entry.pos[0],entry.pos[1]),"decoration":entry})

static func draw(g, actor: Dictionary) -> void:
	var entry: Dictionary=actor.decoration
	Pixels.sprite(g,DATA.data.items[entry.kind].asset,actor.pos,entry.scale)

static func atmosphere(g, id: String, scene: int) -> void:
	var snow := id=="fuwa" and scene>0
	var leaves := id=="dori" and scene==2
	for i in range(16 if snow else 8):
		var x:=float(93+(i*113)%790)
		var y:=float(284+(i*73)%352)
		if snow:
			x+=roundf(sin(g.clock*.5+i)*9)
			y=284+fmod(y-284+g.clock*8,352)
			g.draw_rect(Rect2(roundf(x),roundf(y),2,2),Color("f1f1e1aa"))
		elif leaves:
			x+=roundf(sin(g.clock*.55+i)*14)
			y=284+fmod(y-284+g.clock*9,352)
			g.draw_rect(Rect2(x,y,4,2),Color("e5a553b8"))
			g.draw_rect(Rect2(x+2,y-1,2,1),Color("eda76680"))
		else:
			y+=roundf(sin(g.clock*.7+i)*3)
			var glint := Color("c3dce3") if id in ["yune","kubby"] else Color("f7dcac")
			glint.a=.21+.14*sin(g.clock+i)
			g.draw_rect(Rect2(x,y,2,2),glint)
