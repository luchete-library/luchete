extends "res://tests/library_day_flow.gd"

const Art=preload("res://scripts/library_care_art.gd")
const DEST:="res://artifacts/neglect_visibility_20261118/"
var frames: Array[Image]=[]

func snap(name: String) -> Image:
	g.toast_time=0;g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	check(frame.save_png(DEST+name+".png")==OK,"capture "+name)
	return frame

func visible_pixels(level: int) -> int:
	var total:=0
	for i in range(8):
		var patch: Image=Art.floor_image(Art.FLOOR_POINTS[i],level,i)
		for y in range(patch.get_height()):
			for x in range(patch.get_width()):
				if patch.get_pixel(x,y).a>.25: total+=1
	return total

func difference(a: Image,b: Image,rect: Rect2i) -> int:
	var total:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
			if maxf(absf(ca.r-cb.r),maxf(absf(ca.g-cb.g),absf(ca.b-cb.b)))>.15: total+=1
	return total

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	root.size=Vector2i(1280,800)
	fresh();g.growth.reward("visual",500,250);g.player_pos=Vector2(560,648)
	var d=g.state.library_day
	frames.append(await snap("01_clean_1280"))
	root.size=Vector2i(960,600)
	await snap("01_clean_960")
	root.size=Vector2i(1280,800)
	d.returned.assign([0,0,0,1,1,1]);d.dirty.assign([0,1])
	for level in range(1,4):
		d.grime.fill(level);g.library_day_flow.sync_targets(g)
		var saved: String=JSON.stringify(g.state.to_data())
		frames.append(await snap("0%d_level_%d_1280"%[level+1,level]))
		check(saved==JSON.stringify(g.state.to_data()),"drawing never mutates saved care state")
		if level==3:
			root.size=Vector2i(960,600)
			await snap("04_neglected_960")
			root.size=Vector2i(1280,800)
	var area:=Rect2i(336,568,786,145)
	var changes: Array=[]
	for i in range(1,4): changes.append(difference(frames[0],frames[i],area))
	check(changes[1]>changes[0]*1.5,"moderate dirt covers substantially more floor than light dirt")
	check(changes[2]>changes[1]*1.25,"severe dirt is visibly larger than moderate dirt")
	check(changes[2]>15000,"severe neglect visibly changes at least 15000 lower-floor pixels")
	var coverage: Array=[]
	for level in range(1,4): coverage.append(visible_pixels(level))
	check(coverage[1]>coverage[0]*1.5 and coverage[2]>coverage[1]*1.25,"masked stage coverage grows at all resolutions")
	for i in range(8):
		var patch: Image=Art.floor_image(Art.FLOOR_POINTS[i],3,i)
		var clipped_ok:=true
		for y in range(patch.get_height()):
			for x in range(patch.get_width()):
				if patch.get_pixel(x,y).a==0: continue
				if not Art.floor_pixel(Art.FLOOR_POINTS[i]-Vector2(Art.CELL)+Vector2(x*2+1,y*2+1)): clipped_ok=false
		check(clipped_ok,"floor patch avoids furniture silhouettes and walls %d"%i)
	# Click a real opaque edge more than 65px from the old 35px target radius.
	g.player_pos=Vector2(552,704);g.ui_regions.clear();g.buttons.clear()
	var spot: Dictionary=g._find_object("day_floor_5")
	var edge:=Vector2.ZERO
	for y in range(-50,51,2):
		for x in range(70,119,2):
			var p:=Art.FLOOR_POINTS[5]+Vector2(x,y)
			if Art.hit_stain(Art.FLOOR_POINTS[5],3,5,p): edge=p;break
		if edge!=Vector2.ZERO: break
	check(edge!=Vector2.ZERO,"opaque edge is well outside old click radius")
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	click.position=edge*g.WORLD_SCALE+g.WORLD_OFFSET
	check(g.library_day_flow.input(g,click),"visible outer dirt edge accepts click")
	check(g.pending_object==spot.id or g.mode=="day_action","edge click routes to the correct cleanup site")
	for i in range(220):
		g._process(.1)
		if d.grime[5]==0: break
	check(d.grime[5]==0 and g.mode=="play","walking and one three-second clean removes the whole large patch")
	check(d.grime[4]==3 and d.grime[6]==3,"cleanup leaves neighboring independent patches intact")
	g.player_pos=Vector2(560,648);g.route.clear();g.pending_object=""
	await snap("05_one_patch_cleaned")
	# All cleanup actions use existing state fields; no new chore is introduced.
	for i in range(8): d.clean_floor(i)
	d.dirty.clear();d.returned.clear();d.carried.clear()
	g.library_day_flow.sync_targets(g)
	await snap("06_restored_1280")
	root.size=Vector2i(960,600)
	await snap("06_restored_960")
	check(d.grime.count(0)==8,"all visual residue is removed with its existing cleanup target")
	# A reader standing on a large stain still owns their character click.
	d.grime[5]=3
	var visitor: Dictionary=g.state.ink_visits._guest(0,"read","dori")
	visitor.phase="browse";visitor.admitted=true;visitor.request=true;visitor.pos=Vector2(680,648)
	g.state.ink_visits.guests.append(visitor);g.player_pos=visitor.pos+Vector2(0,40)
	g.library_day_flow.sync_targets(g);g.buttons.clear();g.ui_regions.clear()
	click.position=(visitor.pos-Vector2(0,20))*g.WORLD_SCALE+g.WORLD_OFFSET
	check(g.library_day_flow.input(g,click),"reader body on dirt accepts character interaction")
	check(g.mode=="day_choice" and g.library_day_flow.choice=="request","reader request wins over enlarged floor cleanup")
	g.mode="play";visitor.request=false;g.library_day_flow.sync_targets(g)
	g.route.clear();g.pending_object=""
	check(not g.library_day_flow.input(g,click),"ordinary reader body does not start floor cleaning")
	# The mess now sits on the tabletop: clicking the actual cup starts tidying.
	g.state.ink_visits.guests.clear();d.dirty.assign([0,1])
	g.player_pos=Vector2(912,480);g.library_day_flow.sync_targets(g)
	click.position=(g.library_day_flow.SEATS[0]+Vector2(0,-105))*g.WORLD_SCALE+g.WORLD_OFFSET
	check(g.library_day_flow.input(g,click),"visible tabletop spill accepts click")
	check(g.pending_object=="day_seat_0" or g.library_day_flow.action_kind=="clean","tabletop click selects the matching used seat")
	for i in range(200):
		g._process(.1)
		if 0 not in d.dirty: break
	check(0 not in d.dirty and 1 in d.dirty,"tidying removes only that seat's spill, cup and papers")
	g.player_pos=Vector2(284,520);d.returned.assign([0,0,1,1])
	g.library_day_flow.sync_targets(g);g.ui_regions.clear();g.buttons.clear()
	click.position=(g.library_day_flow.CART+Vector2(-10,-82))*g.WORLD_SCALE+g.WORLD_OFFSET
	check(g.library_day_flow.input(g,click),"top of the leaning book stack accepts click")
	check(not d.carried.is_empty() or g.pending_object=="day_cart","book stack click collects or approaches returned books")
	var report: Dictionary={"checks":count,"failures":failures,"lower_floor_changed_pixels":changes,"masked_source_pixels_by_stage":coverage,"edge_click_world":[edge.x,edge.y],"resolutions":[[1280,800],[960,600]]}
	var file:=FileAccess.open(DEST+"visual_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NEGLECT_VISIBILITY: ",count," checks; failures=",failures,"; pixels=",changes,"; coverage=",coverage)
	g.free();quit(1 if failures else 0)
