extends SceneTree

class Preview:
	extends "res://scripts/main.gd"
	func _save() -> void:
		state.player=player_pos

var game:=Preview.new()
var checks:=0
var failures:=0
var render:=false

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func capture(label: String) -> void:
	if not render: return
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/"+label+".png")==OK,label)

func click_at(screen: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=screen
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	game._unhandled_input(event)

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	game._unhandled_input(event)

func _initialize() -> void:
	call_deferred("run")

func capture_broadcast_rooms() -> void:
	var camera:=Rect2i(145,222,395,370)
	var sheet:=Image.create_empty(camera.size.x*3,camera.size.y*2,false,Image.FORMAT_RGB8)
	game.life.open(game)
	for i in range(game.MEMBERS.size()):
		game.life.member_index=i
		game.life.open_chat(game)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame,camera,Vector2i(i%3,i/3)*camera.size)
	check(sheet.save_png("res://artifacts/studio_broadcast_rooms.png")==OK,"all six broadcast sets rendered")

func run() -> void:
	render="--render" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,800)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	game.mode="play"
	for i in [4,2,5,0,3,1]:
		var id: String=game.MEMBERS[i].id
		game.state.residents.append(id)
		game.state.chapter_steps[id]=3
		if game.state.residents.size()<6:
			game._setup_map()
			check(not game.split_view(),"a partly restored library keeps its original camera")
	game.state.opening_pending=true
	game.mode="ending"
	game._setup_map()
	check(not game.split_view(),"opening ceremony precedes the overview")
	game._action("close")
	check(game.mode=="play" and game.split_view(),"ordinary ending action opens the new map")
	var rooms: Array[Rect2]=[]
	var player:=game.player_pos
	var residents:=0
	for npc in game.objects:
		if npc.type!="npc": continue
		residents+=1
		var room:=game.Studios.room(npc.index)
		var feet: Vector2=npc.pos*game.WORLD_SCALE+game.WORLD_OFFSET
		for other in rooms: check(not other.intersects(room),"private rooms do not overlap")
		rooms.append(room)
		check(room.size.x==room.size.y and Rect2(0,0,1280,800).encloses(room),"entire square is visible")
		check(npc.in_studio and room.has_point(feet) and game.character_touch.hit(game,npc.pos-Vector2(0,48)).get("id","")==npc.id,"owner and hit box match despite rescue order")
	check(residents==6 and game.WORLD_OFFSET.x+936*game.WORLD_SCALE<rooms[0].position.x,"public library and all six rooms fit")
	var pixels:=game.Studios.CELL
	check(game.Studios.ATLAS.get_size()==Vector2(3,4)*pixels,"overview has six room and six foreground tiles")
	check(game.Studios.CLOSEUP.get_size()==Vector2(3,2)*(pixels*2),"broadcast rooms use double-resolution backplates")
	for member in game.MEMBERS:
		var npc: Dictionary=game._find_object(member.id)
		var original: Vector2=npc.pos
		var pointer: Vector2=(npc.pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET
		check(game.Studios.hovered_resident(game,pointer).get("id","")==member.id,"hover identifies room resident: "+member.id)
		check(game.Studios.hovered_resident(game,game.Studios.room(npc.index).position+Vector2(5,5)).is_empty(),"room background has no character tooltip")
		npc.pos=game.Studios.feet(npc.index,true)
		pointer=(npc.pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET
		check(game.Studios.hovered_resident(game,pointer).get("id","")==member.id,"hover follows broadcast position: "+member.id)
		npc.pos=original
	await capture("studios_reopened")
	var dori: Dictionary=game._find_object("dori")
	var start: Vector2=(dori.pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET
	game.character_touch.dragging=true
	check(game.Studios.hovered_resident(game,start).is_empty(),"dragging suppresses room tooltip")
	game.character_touch.dragging=false
	game.mode="furniture"
	check(game.Studios.hovered_resident(game,start).is_empty(),"furniture editor suppresses room tooltip")
	game.mode="play"
	click_at(start,true)
	click_at(start,false)
	check(game.character_touch.reactions.has("dori"),"click in room plays a member reaction")
	await capture("studio_greeting")
	for member in game.MEMBERS:
		game.character_touch.reactions.clear()
		game._action("studio_"+member.id)
		var greeting: Dictionary=game.character_touch.reactions.get(member.id,{})
		check(not greeting.is_empty() and game.Studios.GREETINGS[member.id].get(greeting.id)==greeting.greeting,"personal greeting and gesture for "+member.id)
		check(game.mode=="play" and game.state.friendship[member.id]==0 and game.state.talked_today.is_empty(),"home never consumes daily bond dialogue")
	game.character_touch.reactions.clear()
	key(KEY_R)
	check(game.mode=="play" and game.player_pos==player,"private greetings cannot start a shared activity")
	var floor_pos:=Vector2(482,565)
	click_at(start,true)
	click_at((floor_pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET,false)
	check(not dori.in_studio and dori.pos.distance_to(floor_pos)<1,"drag from private room to library floor")
	check(game.Studios.hovered_resident(game,start).is_empty(),"empty room does not retain former resident tooltip")
	check(game.Studios.hovered_resident(game,(dori.pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET).is_empty(),"public hall does not show mouse hover names")
	game._action("studio_dori")
	check(game.pending_object=="" and game.mode=="play" and game.state.friendship.dori==0,"empty room nameplate does not call the owner")
	game.player_pos=dori.pos+Vector2(20,0)
	key(KEY_E)
	check(game.mode=="dialog" and game.state.friendship.dori==1,"local public conversation earns daily affinity")
	key(KEY_ESCAPE)
	game.player_pos=player
	click_at((dori.pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET,true)
	click_at(start,false)
	check(dori.in_studio,"drag back into the correct room")
	var agent: Dictionary=game.garden_residents.agents.dori
	agent.timer=.01
	game._process(.05)
	check(not dori.in_studio and game._walkable(dori.pos),"resident exits via a walkable public threshold")
	agent.public_time=0.
	for t in range(60):
		game._process(.05)
		if dori.in_studio: break
	check(dori.in_studio,"resident can return to the same room")
	game._begin_yard_stream(dori.index)
	game._process(.05)
	check(dori.id==game.state.yard_host and game._find_object("dori").in_studio and game._find_object("dori").yard_action=="stream","broadcast takes place in the owner's room")
	var on_air: Vector2=(game._find_object("dori").pos-Vector2(0,55))*game.WORLD_SCALE+game.WORLD_OFFSET
	click_at(on_air,true)
	click_at(on_air,false)
	check(game.mode=="stella_life" and game.life.phase=="stream","clicking the broadcasting resident opens live chat")
	await capture("studios_broadcast")
	game.life.action(game,"reply_0")
	game.life.action(game,"signoff")
	game.life.action(game,"back")
	game.life.action(game,"back")
	var v=game.state.ink_visits
	check(not v.live_recommendation and not v.promoting("dori"),"a finished personal show attracts visitors without reopening the stream")
	game._action("furniture_open")
	game._action("furn_suggest")
	game._action("furn_done")
	game._begin_yard_stream(2)
	var saw_readers:=false
	for t in range(1000):
		game._process(.05)
		if v.guests.size()>=2 and v.guests.all(func(guest): return guest.phase=="read"):
			saw_readers=true
			await capture("studios_readers")
			break
	check(saw_readers and game.split_view() and game.player_pos==player and game._find_object("kubby").yard_action=="stream","visitors can read while another resident broadcasts from her room")
	game.state.scene="garden"
	game._setup_map()
	check(not game.split_view(),"garden retains its usual camera")
	game.state.scene="library"
	game._setup_map()
	check(game.split_view(),"return to library restores overview")
	for t in range(1200):
		if v.topic==-1: break
		game._process(.05)
	game._action("promotion")
	game._action("promote_0")
	game._process(.05)
	var host: String=v.host
	game._action("studio_"+host)
	check(game.mode=="stella_life" and game.life.phase=="promo_chat","recommendation broadcast nameplate opens audience chat")
	key(KEY_2)
	check(game.life.reply==1,"player sends a message in the recommendation broadcast")
	for t in range(60): game._process(.05)
	check(game.mode=="stella_life" and not v.guests.is_empty(),"audience can enter while the player reads broadcast chat")
	key(KEY_ESCAPE)
	check(game.mode=="play" and v.live_recommendation and v.campaigns==2,"leaving chat preserves the campaign")
	for t in range(120):
		game._process(.05)
	check(v.guests.size()>0 and v.promoting(host),"the host can still receive chat after the first guest arrives")
	var reloaded=game.State.new()
	check(reloaded.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))) and reloaded.ink_visits.promoting(host),"live recommendation survives a save during arrivals")
	game._setup_map()
	var partner: Dictionary=game._find_object("fuwa" if host!="fuwa" else "yato")
	for kind in ["chair","tea"]:
		var pos:=game.Furniture.position(game.Furniture.find(game.state.furniture,kind))
		var grab: Vector2=(partner.pos-Vector2(0,44))*game.WORLD_SCALE+game.WORLD_OFFSET
		click_at(grab,true)
		click_at(pos*game.WORLD_SCALE+game.WORLD_OFFSET,false)
		check(not partner.in_studio and game.garden_residents.occupant(kind)==partner.id,"placed member uses "+kind)
		game.player_pos=game.Furniture.ENTRANCE
		game._action("join_"+partner.id)
		check(game.mode=="play","cannot join "+kind+" from the other side of the library")
		game.player_pos=pos+Vector2(12,44)
		if kind=="chair": key(KEY_R)
		else: game._action("join_"+partner.id)
		check(game.mode=="together" and game.shared.kind==kind and game.shared.member==partner.id,"both people start "+kind)
		var walkable:=true
		for t in range(42):
			game._process(.05)
			walkable=walkable and game._walkable(game.player_pos)
		check(walkable and game.shared.path.is_empty() and game.player_pos.distance_to(partner.pos)<78,"player walks to a usable spot beside the resident")
		await capture("shared_"+kind)
		if kind=="chair": key(KEY_E)
		else:
			for t in range(145): game._process(.05)
		check(game.mode=="play" and game.state.friendship[partner.id]==0,"shared activity ends cleanly and preserves daily talk")
	game._action("studio_"+host)
	for t in range(1400):
		if v.topic==-1: break
		game._process(.05)
	check(game.mode=="play" and v.topic==-1 and not v.live_recommendation,"broadcast chat closes when its host signs off")
	if render: await capture_broadcast_rooms()
	print("STUDIOS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
