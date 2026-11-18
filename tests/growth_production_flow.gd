extends "res://tests/render.gd"

# Production lifecycle, with the existing 24-scene exploration/input helpers.
# Only this isolated artifact slot may be written; neither normal nor review
# player saves are used for any action in this test.
const Production=preload("res://scripts/growth_game.gd")
const Adapter=preload("res://scripts/growth_state_adapter.gd")
const FuwaDriver=preload("res://tests/fuwa_play_driver.gd")
const StellaDriver=preload("res://tests/stella_play_driver.gd")
const OUT="res://artifacts/growth_rollout_20261117/"
const SLOT=OUT+"production_flow_save.json"
var checks:=0
var campaigns: Array[Dictionary]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

# Avoid renderer-only waits and images in this headless regression. World input,
# collision/path finding and the actual scene state machines remain active.
func repaint() -> void:
	await process_frame
func capture(_name: String) -> void:
	await process_frame
func button(id: String) -> void:
	game._action(id)
	await repaint()
func inspect_field_site(id: String) -> void:
	var obj: Dictionary=game._find_object(id)
	check(not obj.is_empty(),"visible investigation object "+id)
	if obj.is_empty(): return
	game._go_to(obj)
	await finish_walk()
func snapshot_file(path: String) -> Dictionary:
	return {"exists":FileAccess.file_exists(path),"bytes":FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}

func play_book(index: int) -> void:
	var member: Dictionary=game.MEMBERS[index]
	var before: int=game.state.residents.size()
	await button("journal")
	await button("memory_%d"%index)
	check(game.mode=="story" and game.story_page==0,"uncompleted book opens its own story: "+member.id)
	await button("story_next")
	await finish_walk()
	check(game.mode=="missions","unassigned book still takes player to Ete's commission: "+member.id)
	await button("offer_%d"%index)
	await button("take_mission")
	check(game.state.active_mission==member.id and game.mode=="story","Ete assigns the selected book through the original mission UI: "+member.id)
	await button("story_next")
	if member.id=="fuwa":
		check(game.mode=="fuwa_adventure","Fuwa book enters direct protagonist control")
		check(FuwaDriver.find_tenbi(game),"Fuwa traverses mountain and finds Tenbi with live controls")
		check(member.id not in game.state.residents,"reunion alone does not unlock Fuwa")
		FuwaDriver.key(game,KEY_E);FuwaDriver.key(game,KEY_E,false);FuwaDriver.step(game,11)
		check(game.state.residents.size()==before+1 and game.fuwa_book.phase=="arrived","spell and rift arrive before Fuwa unlock")
		FuwaDriver.key(game,KEY_E)
		for line in range(12):
			if game.mode!="dialog": break
			await button("next")
		check(game.mode==("growth_ops" if before==5 else "play") and not game.state.opening_pending,"Fuwa arrival respects reconstruction progression")
		return
	check(game.mode=="stella_adventure" and game.stella_book.member==member.id,"assignment enters direct Stella control: "+member.id)
	check(StellaDriver.complete(game),"actual movement and actions finish the protagonist story: "+member.id)
	check(member.id in game.state.residents and game.state.residents.size()==before+1,"arrival recruits exactly the completed Stella: "+member.id)
	StellaDriver.press(game)
	for line in range(12):
		if game.mode!="dialog": break
		await button("next")
	check(game.mode==("growth_ops" if before==5 else "play") and not game.state.opening_pending,"arrival respects reconstruction progression: "+member.id)
	check(game.state.rebuild_stage()==0 and game.growth.gold==0 and game.growth.memory_light==0,"recruitment does not auto-build or pay resources: "+member.id)
	check(game.growth.phase==("rebuilding" if before==5 else "recruiting"),"last arrival begins first reconstruction: "+member.id)
	print("PRODUCTION BOOK COMPLETE: ",member.id)

func campaign(topic: int) -> Dictionary:
	await button("close")
	await button("promotion")
	check(game.mode=="promotion","promotion menu opens after construction and reopening")
	var gold: int=game.growth.gold
	var light: int=game.growth.memory_light
	var visitors: int=game.state.ink_visits.total
	await button("promote_%d"%topic)
	check(game.state.ink_visits.topic==topic and game.growth.gold==gold and game.growth.memory_light==light,"promotion assignment itself pays nothing")
	var phases: Dictionary={}
	for tick in range(6000):
		game._process(.1)
		for guest in game.state.ink_visits.guests: phases[guest.phase]=true
		if game.state.ink_visits.topic<0 and game.state.ink_visits.guests.is_empty() and game.state.ink_visits.reservations_for(game.state.day)==0: break
	var result: Dictionary={"gold":game.growth.gold-gold,"light":game.growth.memory_light-light,"visitors":game.state.ink_visits.total-visitors,"phases":phases.keys()}
	campaigns.append(result)
	check(game.state.ink_visits.topic<0 and game.state.ink_visits.guests.is_empty() and game.state.ink_visits.reservations_for(game.state.day)==0,"promotion, actual visits and all due reservations finish")
	var expected: Dictionary={0:{"gold":55,"light":12,"visitors":4},2:{"gold":50,"light":10,"visitors":5}}[topic]
	check(result.gold==expected.gold and result.light==expected.light and result.visitors==expected.visitors,"promotion visitors settle their exact entry, reading, borrowing and broadcast rewards: "+str(result))
	check(phases.has("read") and (topic!=0 or phases.has("checkout")),"campaign includes the promised visible visitor activities")
	return result

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var normal_before:=snapshot_file(Production.State.SAVE_PATH)
	var production_before:=snapshot_file(Production.PRODUCTION_SAVE)
	var preview_before:=snapshot_file(Production.PREVIEW_SAVE)
	game=Production.new()
	game.persist=false
	game.save_path=SLOT
	game.legacy_save_path=OUT+"unused_legacy_fixture.json"
	root.add_child(game)
	game.set_process(false)
	game.audio_enabled=false
	await process_frame
	check(not game.preview_mode and game.mode=="title","production entry defaults to title, not a six-member review fixture")
	game.save_available=false
	await button("new")
	check(game.state is Adapter and game.growth==game.state.growth,"new game retains growth-aware state and bound ledger")
	check(game.state.residents.is_empty() and game.growth.phase=="recruiting" and game.state.furniture.is_empty(),"new game starts with only librarian and unfinished library")
	check(game.mode=="dialog" and game._is_ete_line(),"new game begins with Ete's original introduction")
	for line in range(12):
		if game.mode!="dialog": break
		await button("next")
	check(game.mode=="play" and game.state.intro_seen,"intro completes into playable empty library")
	await button("promotion")
	check(game.mode=="play" and game.state.ink_visits.topic<0,"recruitment cannot start a visitor campaign")
	await button("growth_open")
	check(game.growth.phase=="recruiting","opening action cannot skip recruitment or construction")
	for index in [4,3,1,2,0,5]:
		await play_book(index)
		if failures>0:
			print("PRODUCTION FLOW STOPPED after failed book; checks=",checks," failures=",failures)
			game.free();quit(1);return
	check(game.state.residents.size()==6 and game.growth.completed_tasks.is_empty(),"all six returned before any first construction task")
	await button("close")
	await button("goto_ete")
	await finish_walk()
	check(game.mode=="world_ete","Ete now offers operation and upgrade choices")
	await button("growth_ops")
	await button("growth_work_shelves")
	check(game.mode!="growth_work" and game.growth.completed_tasks.is_empty(),"uncleared corridor blocks later work")
	for task in ["corridor","reading","shelves"]:
		await button("growth_work_"+task)
		check(game.mode=="growth_work" and game.work_task==task,"request starts visible reconstruction: "+task)
		for tick in range(600):
			game._process(.1)
			if game.mode=="play": break
		check(task in game.growth.completed_tasks and game.mode=="play","completed work changes facilities: "+task)
	check(game.growth.phase=="ready" and game.state.rebuild_stage()==5 and game.growth.gold==0,"all initial work is free and readiness waits for actual opening")
	check(game._calendar().window_open and not game.state.furniture.is_empty(),"reading work opens seasonal windows and supplies first chair")
	await button("growth_open")
	check(game.mode=="ending","first actual reopening shows its celebration after all works")
	await button("close")
	while game.mode=="dialog": await button("next")
	check(game.mode=="promotion","first-opening Ete tutorial leads into current promotion menu")
	check(game.growth.phase=="open" and game.state.rebuild_stage()==6 and game.studios_open and game.world_map_active() and not game.split_view(),"reopening keeps full-screen library with six rooms through the door")
	await button("growth_wait")
	check(game.state.minutes==600,"first opening waits from preparation to the 10 AM promotion slot")
	await campaign(0)
	for slot in range(8):
		if game.state.minutes>=840: break
		await button("growth_wait")
	await campaign(2)
	check(game.growth.gold==105 and game.growth.memory_light==22,"campaigns plus one natural reader settle actual first-day income")
	await button("world_furniture_shop")
	await button("growth_buy_tea")
	check("tea" in game.growth.owned_furniture and game.growth.gold==45 and game.growth.memory_light==22,"earned gold buys usable tea table without consuming memory light")
	check(game.mode=="furniture" and not game.Furniture.find(game.state.furniture,"tea").is_empty(),"purchased furniture enters the real placement editor")
	await button("furn_done")
	var balance: int=game.growth.gold
	var total_light: int=game.growth.memory_light
	var furniture: Array=game.state.furniture.duplicate(true)
	game.persist=true
	game._save()
	check(not game.save_failed and FileAccess.file_exists(SLOT),"production saver writes only the explicitly isolated slot")
	game.persist=false
	game.state=Adapter.new();game.growth=game.state.growth
	await button("continue")
	check(game.mode=="play" and game.growth==game.state.growth and game.growth.gold==balance and game.growth.memory_light==total_light,"production Continue restores currencies and rebinds growth reference")
	check(game.growth.phase=="open" and game.state.residents.size()==6 and game.state.furniture==furniture and game.outstanding_loans()==1,"Continue preserves completion, purchased layout and the actual outstanding book")
	await button("sleep_confirm")
	for tick in range(2400):
		game._process(.1)
		if game.mode=="growth_summary": break
	check(game.state.day==1 and game.mode=="growth_summary","closing finishes the day in its summary before changing the date")
	await button("growth_next_day")
	check(game.state.day==2 and game.state.ink_visits.return_queue.size()==1,"next production day queues the actual loan return")
	await button("growth_wait")
	for tick in range(2400):
		game._process(.1)
		if game.state.ink_visits.return_queue.is_empty() and game.state.ink_visits.guests.is_empty(): break
	check(game.outstanding_loans()==0 and game.growth.gold==balance and game.growth.memory_light==total_light,"physical next-day returns complete without repeated charges or memory")
	check(snapshot_file(Production.State.SAVE_PATH)==normal_before,"normal player save remained byte-identical")
	check(snapshot_file(Production.PRODUCTION_SAVE)==production_before,"production player save remained byte-identical")
	check(snapshot_file(Production.PREVIEW_SAVE)==preview_before,"separate preview player save remained byte-identical")
	print("GROWTH PRODUCTION FLOW: ",checks," checks; ",failures," failures; full 24-scene story, construction, opening, paid visits, purchase, disk Continue and returns.")
	game.free()
	quit(1 if failures else 0)
