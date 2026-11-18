extends SceneTree

class Preview:
	extends "res://scripts/main.gd"
	var opened_sources: Array[String]=[]
	var save_calls:=0
	func _save() -> void:
		save_calls+=1
	func _open_archive_source(url: String) -> void:
		opened_sources.append(url)

var game:=Preview.new()
var checks:=0
var failures:=0
var render:=false
const DEST:="res://artifacts/broadcast_shelf_applied_20261115/"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.pressed=true
	event.physical_keycode=code
	game._unhandled_input(event)

func click(point: Vector2) -> void:
	var event:=InputEventMouseButton.new()
	event.position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	game._unhandled_input(event)
	event.pressed=false
	game._unhandled_input(event)

func repaint() -> void:
	game.queue_redraw()
	await process_frame
	await process_frame

func button(id: String) -> void:
	await repaint()
	for item in game.buttons:
		if item.id==id:
			click(item.rect.get_center())
			return
	check(false,"missing visible button: "+id)

func capture(label: String) -> void:
	if not render: return
	await repaint()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DEST+label+".png")==OK,"capture "+label)

func setup(stage: int) -> void:
	game.mode="play"
	game.state=game.State.new()
	game.state.intro_seen=true
	game.state.residents=["yato","danming","kubby","yune","dori","fuwa"].slice(0,stage)
	for id in game.state.residents: game.state.chapter_steps[id]=3
	game.state.opening_pending=false
	game.player_pos=Vector2(490,620)
	game._setup_map()

func run() -> void:
	render="--render" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(DEST)
	root.size=Vector2i(1280,800)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	game.save_available=false
	var catalogue: Dictionary=game.ActivityArchive.CATALOG.data
	var ids: Array[String]=[]
	var announced:=0
	var count:=0
	for volume in catalogue.volumes:
		check(not volume.entries.is_empty(),"each volume has records")
		for entry in volume.entries:
			count+=1
			check(entry.id not in ids,"unique catalogue record")
			ids.append(entry.id)
			for member in entry.members:
				check(member in game.state.friendship,"only current members are indexed")
			check(entry.status in ["recorded","announced"],"record explicitly distinguishes notice and history")
			if entry.status=="announced": announced+=1
			check(not entry.sources.is_empty(),"record links to its source")
			for source in entry.sources:
				check(source.url.begins_with("https://") and source.kind!="", "explicit public source")
			check(game.font.get_string_size(entry.title,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x<=459,"page title fits: "+entry.id)
			check(game.font.get_string_size("%02d   %s"%[count,entry.title],HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=438,"contents title fits: "+entry.id)
			var source_width: float=(465.0-(entry.sources.size()-1)*12.0)/entry.sources.size()
			for source in entry.sources:
				check(game.font.get_string_size(source.label+"  ↗",HORIZONTAL_ALIGNMENT_LEFT,-1,17).x<=source_width-12,"source label fits: "+entry.id)
	check(count==101 and announced==1,"100 curated records and one dated notice")
	for stage in [0,3,6]:
		setup(stage)
		check(not game._find_object("activity_archive").is_empty(),"archive available at restoration stage %d"%stage)
		await repaint()
		# The actual painted left bookcase must be clickable in both camera layouts.
		click(game.WORLD_OFFSET+Vector2(235,235)*game.WORLD_SCALE)
		check(game.pending_object=="activity_archive","click sets a route to the general bookshelf")
		for tick in range(1400):
			if game.mode!="play": break
			game._process(1.0/60.0)
		check(game.mode=="archive_shelf","walking reaches and opens the archive")
		check(game.route.is_empty() and game.pending_object=="","reading cancels movement")
		key(KEY_ESCAPE)
		check(game.mode=="play","Esc returns to same library")
		game.player_pos=Vector2(214,283)
		check(game._walkable(game.player_pos),"keyboard approach is walkable")
		await capture("library_stage_%d"%stage)
		key(KEY_E)
		check(game.mode=="archive_shelf","nearby E opens the activity shelf")
		var position: Vector2=game.player_pos
		var before: String=JSON.stringify(game.state.to_data())
		for i in range(catalogue.volumes.size()):
			await button("archive_volume_%d"%i)
			check(game.mode=="archive_book" and game.activity_archive.volume==i,"click removes the selected album")
			for page_index in range(catalogue.volumes[i].entries.size()):
				if page_index>0: key(KEY_RIGHT)
				await button("archive_page_%d"%page_index)
				check(game.activity_archive.page==page_index,"contents selects exact record")
				var opens:=game.opened_sources.size()
				click(Vector2(1250,780))
				key(KEY_J)
				key(KEY_P)
				check(game.mode=="archive_book" and game.route.is_empty(),"reading absorbs world clicks and game shortcuts")
				check(game.opened_sources.size()==opens,"reading never opens a browser automatically")
				if stage==6:
					var record: Dictionary=game.activity_archive.entry()
					if page_index in [0,5,catalogue.volumes[i].entries.size()-1]: await capture(record.id)
					for source_index in range(record.sources.size()):
						await button("archive_source_%d"%source_index)
						check(game.opened_sources.back()==record.sources[source_index].url,"explicit source button opens the exact recorded URL")
			key(KEY_RIGHT)
			check(game.activity_archive.page==catalogue.volumes[i].entries.size()-1,"last page is bounded")
			for n in range(catalogue.volumes[i].entries.size()+2): key(KEY_LEFT)
			check(game.activity_archive.page==0,"first page is bounded")
			key(KEY_RIGHT)
			check(game.activity_archive.page==1,"keyboard page turn works")
			key(KEY_ESCAPE)
			check(game.mode=="archive_shelf","Esc puts album back before leaving library")
		game._process(2.0)
		check(JSON.stringify(game.state.to_data())==before,"browsing does not change progress, rewards or activity sessions")
		check(game.player_pos==position,"reader returns to original world position")
		if stage==6: await capture("shelf")
		await button("archive_back")
		check(game.mode=="play" and game.split_view()==(stage==6),"closing preserves camera and restoration stage")
		# Existing story shelf and Ete still open their own independent interfaces.
		game._interact(game._find_object("shelf"))
		check(game.mode=="journal","playable story shelf is unchanged")
		key(KEY_ESCAPE)
		game._interact(game._find_object("ete"))
		check(game.mode=="missions","librarian assignments are unchanged")
	# Check keyboard-only selection and notices that never become completed by passage of time.
	game.mode="play"
	game._interact(game._find_object("activity_archive"))
	key(KEY_2)
	game.activity_archive.page=catalogue.volumes[1].entries.size()-1
	check(game.activity_archive.entry().status=="announced","upcoming 3D is an announcement, not a completed event")
	game._process(3600)
	check(game.activity_archive.entry().status=="announced","game time does not convert an unverified announcement")
	key(KEY_ESCAPE)
	key(KEY_LEFT)
	key(KEY_E)
	check(game.activity_archive.volume==0 and game.mode=="archive_book","arrow selection plus E opens the chosen book")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	game.activity_archive.open(game)
	key(KEY_7)
	await button("archive_contents_next")
	check(game.activity_archive.page==5,"next contents group opens record six")
	key(KEY_2)
	check(game.activity_archive.page==6,"numeric keys use the visible contents group")
	await button("archive_contents_prev")
	check(game.activity_archive.page==0,"previous contents group returns to first group")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	game.state.scene="garden"
	game._setup_map()
	game.activity_archive.open(game)
	check(game.mode=="play" and game._find_object("activity_archive").is_empty(),"archive only belongs to the library")
	check(game.save_calls==0,"tests and read-only browsing never overwrite the player save")
	print("ACTIVITY ARCHIVE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
