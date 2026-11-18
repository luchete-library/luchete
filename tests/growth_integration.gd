extends SceneTree
const Adapter=preload("res://scripts/growth_state_adapter.gd")
const Growth=preload("res://scripts/library_growth.gd")
const Normal=preload("res://scripts/game_state.gd")
const SAVE: String="res://artifacts/growth_20261116/integration_save.json"
class Preview:
	extends "res://scripts/main.gd"
	func _save() -> void: pass
var game:=Preview.new()
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func disk_reload(state):
	check(state.save_to(SAVE)==OK,"write complete preview-slot save")
	var next:=Adapter.new()
	check(next.load_from(SAVE),"load isolated preview-slot save")
	return next
func use_state(state) -> void:
	game.state=state
	game._setup_map()
func run() -> void:
	root.add_child(game)
	await process_frame
	game.set_process(false);game.audio_enabled=false;game.mode="play"
	var state:=Adapter.new()
	for member in state.BOOKS:
		state.active_mission=member.id
		state.chapter_steps[member.id]=2
		state.page_complete=true
		check(state.record_chapter_step(member.id,2),"recruit through real chapter-completion method: "+member.id)
		if state.residents.size()<6:
			check(state.growth.phase=="recruiting" and state.rebuild_stage()==0,"partial recruitment does not rebuild facilities")
	check(state.residents.size()==6 and state.chapter_steps.values().count(3)==6,"all story books stay completed")
	check(state.growth.phase=="rebuilding" and state.rebuild_stage()==0 and not state.opening_pending,"last book starts free reconstruction instead of opening")
	check(state.growth.gold==0 and state.growth.memory_light==0,"first reconstruction starts without a payment gate")
	check(state.growth.complete_task("corridor") and state.rebuild_stage()==2,"first facility work changes reconstruction only")
	state=disk_reload(state)
	check(state.growth.phase=="rebuilding" and state.growth.completed_tasks==["corridor"] and state.rebuild_stage()==2,"mid-reconstruction resumes without automatic opening")
	check(state.growth.complete_task("reading") and state.growth.complete_task("shelves"),"remaining first works can finish in either order")
	check(state.growth.phase=="ready" and state.rebuild_stage()==5,"ready is separate from reopened")
	check(state.growth.open_library() and state.rebuild_stage()==6,"explicit opening enables full library")
	state.operating.ensure(state)
	check(state.place_furniture("tea",Vector2(192,512))!="","unowned furniture cannot be placed for free")
	check(state.growth.reward("integration:operating-fixture",500,30),"seed isolated operating test fixture")
	check(state.growth.purchase("furniture","tea")=="","buy usable furniture with gold")
	check(state.place_furniture("tea",Vector2(192,512))=="","purchased furniture can be placed")
	var catalogue: Dictionary=state.growth.catalogue("costume")
	check(not catalogue.is_empty(),"production source-verified costume catalogue supplied")
	var costume: String=catalogue.keys()[0]
	var owner: String=catalogue[costume].member
	check(state.growth.purchase("costume",costume)=="","verified additional costume purchase")
	state.costumes[owner]=costume
	var balance: int=state.growth.gold
	var light: int=state.growth.memory_light
	var placed: Array=state.furniture.duplicate(true)
	state=disk_reload(state)
	check(state.growth.gold==balance and state.growth.memory_light==light,"currency and cumulative light survive file reload exactly")
	check(state.furniture==placed and "tea" in state.growth.owned_furniture,"purchased furniture ownership and position survive together")
	check(state.costumes[owner]==costume and costume in state.growth.owned_costumes,"purchased equipped costume survives")
	check(state.growth.purchase("costume",costume)!="" and state.growth.gold==balance,"reloaded ownership prevents charging twice")
	use_state(state)
	var visitors=state.ink_visits
	check(visitors.growth==state.growth,"restored visitor income points to restored ledger")
	state.minutes=600
	check(visitors.start(state,0,"dori"),"reopened adapter starts a morning broadcast campaign")
	var saved:=false;var phases: Dictionary={}
	for tick in range(1800):
		if visitors.host!="": game._find_object(visitors.host).promo_ready=true
		state.advance_operating_time(.1)
		visitors.advance(game,.1)
		for guest in visitors.guests: phases[guest.phase]=true
		if not saved and phases.has("checkout"):
			state=disk_reload(state);use_state(state);visitors=state.ink_visits;saved=true
		if visitors.topic==-1 and visitors.guests.is_empty() and visitors.reservations_for(state.day)==0: break
	check(saved and visitors.topic==-1,"in-flight rental resumes and campaign ends")
	check(state.growth.gold==balance+55 and state.growth.memory_light==light+12,"resumed broadcast, three invited guests and one organic reader settle once")
	check(visitors.loans.size()==1 and not visitors.loans[0].returned,"open loan retained in adapter")
	var after_visits:=state.growth.data()
	state.sleep()
	check(state.day==2 and visitors.return_queue.size()==1,"sleep queues next-day borrower once")
	state=disk_reload(state);use_state(state);visitors=state.ink_visits
	state.minutes=600
	for tick in range(1200):
		visitors.advance(game,.1)
		if visitors.guests.is_empty() and visitors.return_queue.is_empty(): break
	check(visitors.loans[0].returned and visitors.guests.is_empty(),"saved return queue completes physical desk return")
	check(state.growth.data()==after_visits,"returns preserve money/light totals without duplicate fees")
	var before_broadcast: int=state.growth.memory_light
	check(state.finish_activity("dori","stream",0)>0,"daily broadcast can complete")
	check(state.growth.memory_light==before_broadcast,"personal broadcast alone does not bypass global promotion budget")
	check(visitors.start(state,0,"dori") and state.growth.memory_light==before_broadcast+3,"completed broadcast using daily promotion slot grants library light")
	check(state.finish_activity("dori","stream",1)==0 and state.growth.memory_light==before_broadcast+3,"same-day repeat cannot farm broadcast light")
	state=disk_reload(state)
	check(state.finish_activity("dori","stream",1)==0,"daily broadcast claim persists across disk reload")
	state.sleep()
	state.minutes=600
	check(state.finish_activity("dori","stream",1)>0 and state.ink_visits.start(state,0,"dori") and state.growth.memory_light==before_broadcast+6,"next-day completed broadcast uses a fresh promotion slot")
	for pair in [[7,8,1,1],[28,29,2,0]]:
		state.day=pair[0];state.sleep()
		var date:=state.library_calendar()
		check(state.day==pair[1] and date.year==pair[2] and date.season_index==pair[3] and date.day_in_season==1,"sleep crosses season/year boundary "+str(pair[0]))
	# Old saves are fixtures constructed in memory, never the real user save.
	var legacy:=Normal.new()
	for book in legacy.BOOKS:
		legacy.residents.append(book.id);legacy.chapter_steps[book.id]=3
	legacy.costumes={"yato":"yato_knit","danming":"danming_racing"}
	legacy.place_furniture("mat",Vector2(704,560))
	legacy.opening_pending=false
	var migrated:=Adapter.new()
	check(migrated.apply_data(legacy.to_data()),"legacy completed-library fixture migrates")
	check(migrated.growth.phase=="open" and migrated.rebuild_stage()==6,"legacy reopened library is not forced through first works again")
	check(migrated.costumes==legacy.costumes and "yato_knit" in migrated.growth.owned_costumes and "danming_racing" in migrated.growth.owned_costumes,"legacy worn outfits are grandfathered without inventing sale items")
	check("mat" in migrated.growth.owned_furniture and migrated.furniture==legacy.furniture,"legacy placed furniture retains ownership and layout")
	migrated=disk_reload(migrated)
	check(migrated.growth.phase=="open" and migrated.costumes==legacy.costumes,"migrated growth save round-trips")
	# All rejected payloads must leave both old and new state unchanged.
	var stable: Dictionary=state.to_data()
	var bad: Dictionary=stable.duplicate(true);bad.library_growth.gold=-1
	check(not state.apply_data(bad) and state.to_data()==stable,"invalid ledger is rejected atomically")
	bad=stable.duplicate(true);bad.growth_visitors.next_uid=0
	check(not state.apply_data(bad) and state.to_data()==stable,"invalid visitor snapshot is rejected atomically")
	bad=stable.duplicate(true);bad.energy="broken"
	check(not state.apply_data(bad) and state.to_data()==stable,"invalid original-state field is rejected atomically")
	# Cross-domain invariants: a new growth save cannot open with five residents
	# or equip placed furniture without an ownership entry.
	bad=stable.duplicate(true);bad.residents.erase("fuwa");bad.chapter_steps.erase("fuwa")
	check(not state.apply_data(bad) and state.to_data()==stable,"new open growth state requires all six residents")
	bad=stable.duplicate(true);bad.chapter_steps.fuwa=2
	check(not state.apply_data(bad) and state.to_data()==stable,"new reconstruction cannot precede completion of a story book")
	bad=stable.duplicate(true);bad.library_growth.owned_furniture.erase("tea")
	check(not state.apply_data(bad) and state.to_data()==stable,"new growth save cannot retain unowned placed furniture")
	print("GROWTH INTEGRATION: ",checks," checks, ",failures," failures. Only isolated artifact save written.")
	game.queue_free();await process_frame
	quit(1 if failures else 0)
