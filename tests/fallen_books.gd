extends "res://tests/library_day_flow.gd"
const Art=preload("res://scripts/library_care_art.gd")
const DEST:="res://artifacts/fallen_books_20261118/"

func snap(name: String,crop: Rect2i=Rect2i()) -> void:
	g.toast_time=0;g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if crop.has_area(): image=image.get_region(crop)
	check(image.save_png(DEST+name+".png")==OK,"capture "+name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	root.size=Vector2i(1280,800);fresh()
	g.growth.reward("visual",500,250);g.player_pos=Vector2(560,648)
	var d=g.state.library_day
	var counts: Array=[]
	for level in range(1,4):
		var row: Array=[]
		for index in range(8):
			var books: Array=Art.fallen_books(Art.FLOOR_POINTS[index],level,index)
			row.append(books.size())
			check(books.is_empty() if level==1 else not books.is_empty(),"book stage visible in area %d level %d"%[index,level])
			for book in books:
				check(Art.book_fits(Art.FLOOR_POINTS[index],book.pos,book.frame),"complete book avoids all furniture silhouettes")
		counts.append(row)
	print("FALLEN_BOOK_COUNTS: ",counts)
	d.returned.assign([0,0,0,1,1,1]);d.dirty.assign([0,1]);d.grime.fill(3)
	g.library_day_flow.sync_targets(g)
	var saved: String=JSON.stringify(g.state.to_data())
	await snap("01_neglected_1280")
	check(saved==JSON.stringify(g.state.to_data()),"drawn books do not create inventory or save mutations")
	await snap("02_floor_detail",Rect2i(330,560,790,165))
	root.size=Vector2i(960,600)
	await snap("03_neglected_960")
	root.size=Vector2i(1280,800)
	var book: Dictionary=Art.fallen_books(Art.FLOOR_POINTS[5],3,5)[0]
	# Click the visible colored cover, then walk and collect before mopping.
	var p: Vector2=Art.FLOOR_POINTS[5]-Vector2(Art.CELL)+(Vector2(book.pos)+Vector2(12,10))*2
	g.player_pos=Vector2(552,704);g.ui_regions.clear();g.buttons.clear()
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=p*g.WORLD_SCALE+g.WORLD_OFFSET
	check(g.library_day_flow.input(g,click),"fallen book itself is a valid cleanup click")
	for i in range(200):
		g._process(.1)
		if g.mode=="day_action": break
	check(g.mode=="day_action" and g.library_day_flow.action_kind=="mop" and g.library_day_flow.action_index==5,"book click reaches its own area action")
	g.library_day_flow.action_elapsed=.65
	await snap("04_gathering_books",Rect2i(490,535,380,195))
	g.library_day_flow.action_elapsed=1.6
	await snap("05_then_mopping",Rect2i(490,535,380,195))
	step(1.5)
	check(d.grime[5]==0 and d.grime[4]==3 and d.grime[6]==3,"one action clears its books and dirt only")
	check(d.returned.size()==6 and d.carried.is_empty(),"floor dressing does not duplicate real returned books")
	check(g.toast.contains("떨어진 책"),"completion describes gathering books, not mopping books away")
	g.player_pos=Vector2(560,648);g.route.clear();g.pending_object=""
	await snap("06_one_area_cleaned")
	var report: Dictionary={"checks":count,"failures":failures,"book_counts_by_stage":counts,"resolutions":[[1280,800],[960,600]]}
	var f:=FileAccess.open(DEST+"visual_report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("FALLEN_BOOKS: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
