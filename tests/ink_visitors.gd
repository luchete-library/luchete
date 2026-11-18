extends SceneTree

class Preview:
	extends "res://scripts/main.gd"
	func _save() -> void:
		state.player=player_pos

var game:=Preview.new()
var failures:=0
var checks:=0
var render:=false

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func key(code: Key) -> void:
	var input:=InputEventKey.new()
	input.physical_keycode=code
	input.pressed=true
	game._unhandled_input(input)

func capture(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/ink_visitor_draft/"+label+".png")==OK,"render "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	render="--ink-render" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,800)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	game.mode="play"
	key(KEY_P)
	check(game.mode=="play" and not game.state.ink_visits.start(game.state,0),"unopened library has no promotions")
	for book in game.MEMBERS:
		game.state.residents.append(book.id)
		game.state.chapter_steps[book.id]=3
	var old: Dictionary=game.state.to_data()
	old.version=5
	old.erase("ink_visits")
	check(game.state.apply_data(old) and game.state.ink_visits.total==0,"reopened v5 starts with an empty guestbook")
	for i in range(game.Furniture.ORDER.size()):
		game.state.place_furniture(game.Furniture.ORDER[i],game.Furniture.DEFAULTS[i])
	game.player_pos=game.AETHE_POS+Vector2(49,30)
	game._setup_map()
	var starting_player:=game.player_pos
	var previous_total:=0
	var directions: Dictionary={}
	for campaign in range(4):
		key(KEY_P)
		check(game.mode=="promotion","P opens promotion")
		if render and campaign==0: await capture("promotion")
		key([KEY_1,KEY_2,KEY_3,KEY_2][campaign])
		var v=game.state.ink_visits
		var count: int=v.group_size()
		check(game.mode=="play" and v.pending==count and count==campaign+2,"topic schedules a growing group")
		var host: String=v.host
		check(not v.start(game.state,1),"no duplicate assignment")
		var appeared: Dictionary={}
		var read: Dictionary={}
		var browse: Dictionary={}
		var left: Dictionary={}
		var seen_host:=false
		var saved:=false
		var resumed_queue:=false
		var saw_entrance:=false
		var walkable:=true
		for tick in range(1500):
			game._process(0.05)
			var actor: Dictionary=game._find_object(host)
			if actor.get("promo_ready",false):
				seen_host=actor.get("promo_away",false) if campaign!=0 else actor.yard_action=="stream"
			for visitor in v.guests:
				directions[visitor.facing]=true
				walkable=walkable and game._walkable(visitor.pos)
				if not appeared.has(visitor.slot):
					appeared[visitor.slot]=true
					check(visitor.pos.distance_to(v.DOOR)<10,"guest starts at the doorway")
				if visitor.phase=="browse": browse[visitor.slot]=true
				if visitor.phase=="read": read[visitor.slot]=true
				if visitor.phase=="leave": left[visitor.slot]=true
			if render and campaign==0 and not saw_entrance and v.guests.size()==1 and v.guests[0].pos.y<632:
				await capture("first-arrival")
				saw_entrance=true
			if campaign==0 and read.size()==count and not saved:
				if render: await capture("library-reading")
				var before: Dictionary=v.data()
				game._action("pause")
				game._process(.1)
				check(before==v.data(),"visitors pause in menus")
				game._action("close")
				var snapshot: Dictionary=JSON.parse_string(JSON.stringify(game.state.to_data()))
				var loaded=game.State.new()
				check(loaded.apply_data(snapshot),"mid-read JSON loads")
				game.state=loaded
				game._setup_map()
				v=loaded.ink_visits
				check(v.total==before.total and v.guests.size()==count and v.guests[0].phase=="read","reading and attendance resume")
				saved=true
			if campaign==1 and appeared.size()==1 and not resumed_queue:
				var recorded: Dictionary=v.data()
				var snapshot: Dictionary=JSON.parse_string(JSON.stringify(game.state.to_data()))
				var loaded=game.State.new()
				check(loaded.apply_data(snapshot),"pending arrivals survive JSON save")
				game.state=loaded
				v=loaded.ink_visits
				game.state.scene="garden"
				game._setup_map()
				game._process(.15)
				check(v.data().guests[0].phase=="shelf" and v.pending==recorded.pending and is_equal_approx(v.delay,recorded.delay),"garden suspends the queue")
				game.state.scene="library"
				game._setup_map()
				resumed_queue=true
			if v.topic==-1: break
		check(seen_host,"automatic host reached the broadcast or outdoor appointment")
		check(walkable,"guests walk around placed furniture")
		check(v.topic==-1 and appeared.size()==count and browse.size()==count and read.size()==count and left.size()==count,"every guest chooses a book, reads and leaves")
		check(v.total==previous_total+count,"one attendance per physical entry")
		check(game.player_pos==starting_player,"player stays in library")
		previous_total=v.total
	check(directions.size()==4,"all four facings occur during real visits")
	# The original broadcast flow should also send listeners to the reopened library.
	game._begin_yard_stream(4)
	game.life.member_index=4
	game.life.open_chat(game)
	game.life.action(game,"reply_0")
	game.life.action(game,"signoff")
	check(game.state.ink_visits.topic==0 and game.state.ink_visits.host=="dori","personal broadcast brings listeners")
	print("INK VISITORS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
