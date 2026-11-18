extends RefCounted

const Pixels = preload("res://scripts/world_pixels.gd")
const Finish = preload("res://scripts/story_finish.gd")
const RECORDS = preload("res://assets/story/debut_records.json")
const FLOORS = preload("res://assets/world_pixels/chapter_floors.json")
# Fixed official events; traversing them in a fan avatar is the fan-game frame.
static var BOOKS: Dictionary = _load_books()

static func _load_books() -> Dictionary:
	var books: Dictionary = RECORDS.data.books.duplicate(true)
	for id in books:
		var coordinates: Array = books[id].points
		for i in range(coordinates.size()):
			coordinates[i] = Vector2(coordinates[i][0],coordinates[i][1])
	return books

static func floor_polygon(id: String, scene: int) -> PackedVector2Array:
	if id=="yato" and scene==1:
		return PackedVector2Array([Vector2(76,460),Vector2(210,408),Vector2(325,388),Vector2(520,384),Vector2(700,405),Vector2(889,436),Vector2(898,650),Vector2(80,655)])
	var floor_points := PackedVector2Array()
	for point in FLOORS.data[id][scene]:
		floor_points.append(Vector2(point[0],point[1]))
	return floor_points

static func landscape(g, id: String, scene: int) -> void:
	var book: Dictionary = BOOKS[id]
	var accent := Color(book.accent)
	var mountain: bool=id=="yato" and g.YatoForest.on_mountain(scene,g._chapter_progress().yato_notes)
	var art_scene: int=g.FuwaSnow.map_index(scene,g._chapter_progress().fuwa_notes) if id=="fuwa" else scene
	var hall: bool=id=="fuwa" and scene==3 and "awoke" in g._chapter_progress().fuwa_notes
	if mountain: g.draw_texture_rect(Pixels.texture("yato_mountain"),Rect2(32,140,904,578),false)
	elif hall: g.FuwaSnow.draw_hall(g)
	elif Finish.background(g,id,art_scene): pass
	else: Pixels.background(g,"story_"+id+"_"+str(art_scene))
	g.Dressing.atmosphere(g,id,0 if hall else art_scene)
	var site: Vector2 = book.points[scene]
	if id=="fuwa":
		var notes: Array=g._chapter_progress().fuwa_notes
		g.fuwa_snow.draw_field(g,scene,notes)
		if g.fuwa_snow.practice.phase!=g.FuwaSnow.WardPractice.Phase.FIELD or not g.FuwaSnow.ready(scene,notes): return
		site=g.FuwaSnow.record_site(scene)
	if id=="yato":
		var notes: Array=g._chapter_progress().yato_notes
		g.yato_forest.draw_field(g,scene,notes)
		if g.yato_forest.storehouse.phase!=g.YatoForest.Storehouse.Phase.FIELD or not g.YatoForest.ready(scene,notes): return
		site=g.YatoForest.record_site(scene)
	if id=="kubby":
		var notes: Array=g._chapter_progress().kubby_notes
		g.kubby_embers.draw_field(g,scene,notes)
		if g.kubby_embers.village.watching or not g.KubbyEmbers.ready(scene,notes): return
		site=g.KubbyEmbers.record_site(scene)
	if id=="danming":
		g.danming_workshop.draw_field(g,scene,g._chapter_progress().danming_notes)
		if g.danming_workshop.view==2 or not g.DanmingWorkshop.ready(scene,g._chapter_progress().danming_notes): return
		site=g.DanmingWorkshop.record_site(scene)
	if id=="yune":
		g.yune_dream.draw_field(g,scene,g._chapter_progress().yune_notes)
		if g.yune_dream.view==2 or not g.YuneDream.ready(scene,g._chapter_progress().yune_notes): return
		site=g.YuneDream.record_site(scene,site)
	if id=="dori" and scene==2:
		g.dori_rubbing.draw_ground(g)
		return
	if id=="dori" and scene<3 and not g.DoriCase.ready(scene,g._chapter_progress().dori_notes):
		g.DoriCase.draw_sites(g,scene,g._chapter_progress().dori_notes)
		return
	if g.book_discovery.active(g): return
	for mark: Vector2 in g.chapter_trail:
		g.draw_rect(Rect2(mark-Vector2(2,1),Vector2(5,3)),Color("3f344790"))
		g.draw_rect(Rect2(mark-Vector2(1,1),Vector2(3,2)),Color("f4dc9dc9"))
	if g._chapter_progress().route_pending(id):
		g.StoryTrail.draw_exit(g)
		return
	# Put the live clue on a contrasting ground ring, even on snow and moonlit stone.
	g.draw_ellipse_shadow(site,Vector2(33,9))
	var radius := 31.0+sin(g.clock*2)
	g.draw_arc(site,radius,0,TAU,40,Color("443b42b0"),4)
	g.draw_arc(site,radius,0,TAU,40,accent.lightened(0.18),2)
	draw_prop(g,site-Vector2(0,20),book.props[scene] if id=="dori" and scene!=2 else "record",accent)
	var label: String=book.labels[scene]
	if id=="dori" and scene==3 and not g.DoriCase.ready(scene,g._chapter_progress().dori_notes): label="돌돌이의 조사 수첩"
	if id!="fuwa" or g.player_pos.distance_to(site)>=78: g._world_sign(site+Vector2(0,21),label,"leaf_%d"%scene)

static func draw_prop(g, p: Vector2, prop: String, tint: Color, scale_factor: float = 1.0) -> void:
	if prop=="record":
		g._draw_book(p-Vector2(23,24)*scale_factor,tint,true,1.65*scale_factor)
		return
	if Pixels.prop(g,prop,p,scale_factor):
		if prop=="stone": g._text(p+Vector2(17,-22)*scale_factor,"z",maxi(8,roundi(12*scale_factor)),Color("f5e6c8"))
		if prop in ["glow","rift"]:
			for j in range(4): g._star(p+Vector2(cos(j*1.6)*24,-12+sin(j*1.6)*22)*scale_factor,(2+sin(g.clock+j))*scale_factor,Color("f5e6c8"))
		return
	var ink := Color("514a49")
	var paper := Color("f5e6c8")
	g._transform(p,Vector2.ONE*scale_factor)
	match prop:
		"tracks","paw":
			for i in range(3):
				var q := Vector2(-13+i*12,-i*5)
				g.draw_circle(q,5,tint)
				g.draw_circle(q+Vector2(-3,-6),2,tint)
				g.draw_circle(q+Vector2(3,-6),2,tint)
		"sign":
			g.draw_rect(Rect2(-3,-31,6,45),ink)
			g.draw_colored_polygon(PackedVector2Array([Vector2(-23,-31),Vector2(12,-31),Vector2(22,-24),Vector2(12,-17),Vector2(-23,-17)]),tint)
			g.draw_line(Vector2(-12,-24),Vector2(9,-24),ink,2)
		"quill","feather":
			g.draw_colored_polygon(PackedVector2Array([Vector2(-12,9),Vector2(-8,-12),Vector2(21,-34),Vector2(16,-10),Vector2(1,3)]),paper)
			g.draw_line(Vector2(-18,15),Vector2(13,-19),ink,3)
		"post","letter":
			if prop == "post": g.draw_rect(Rect2(-7,-4,14,24),ink)
			g.draw_rect(Rect2(-23,-23,46,29),paper)
			g.draw_polyline(PackedVector2Array([Vector2(-22,-22),Vector2(0,-6),Vector2(21,-22)]),ink,2)
			g.draw_circle(Vector2(0,-5),4,Color("b87876"))
		"shelf":
			g.draw_rect(Rect2(-24,-27,49,37),ink)
			for i in range(4): g.draw_rect(Rect2(-18+i*9,-23+i%2*3,7,23),tint.darkened(0.13*i))
			g.draw_rect(Rect2(-23,2,49,5),tint)
			g.draw_line(Vector2(14,7),Vector2(22,14),Color("cf9168"),3)
	g._transform()
