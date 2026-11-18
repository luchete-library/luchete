extends SceneTree
const Visits=preload("res://scripts/growth_visitors.gd")
class Ledger:
	extends RefCounted
	var phase: String="open"
	var gold:=0
	var memory_light:=0
	var entries: Dictionary={}
	var expanded:=false
	func visitor_capacity() -> int: return 4 if expanded else 2
	func entrance_fee() -> int: return 10
	func loan_fee() -> int: return 20 if expanded else 15
	func reading_seconds() -> float: return 9.0 if expanded else 13.0
	func rank() -> int: return 1 if expanded else 0
	func reward(id: String,money: int,light: int) -> bool:
		if phase!="open" or entries.has(id): return false
		entries[id]=true;gold+=money;memory_light+=light
		return true
class Preview:
	extends "res://scripts/main.gd"
	var growth:=Ledger.new()
	var saves:=0
	func _save() -> void: saves+=1
var game:=Preview.new()
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")
func ready_host(v) -> void:
	if v.host!="": game._find_object(v.host).promo_ready=true
func clone(v):
	var result:=Visits.new();result.bind_growth(game.growth)
	check(result.restore(JSON.parse_string(JSON.stringify(v.data())),game.state.residents),"JSON visitor/loan snapshot restores")
	return result
func run() -> void:
	root.add_child(game)
	await process_frame
	game.set_process(false);game.audio_enabled=false;game.mode="play"
	game.state=game.State.new()
	for member in game.MEMBERS:
		game.state.residents.append(member.id)
		game.state.chapter_steps[member.id]=3
	game._setup_map()
	var v:=Visits.new();v.bind_growth(game.growth);game.state.ink_visits=v
	game.growth.phase="rebuilding"
	check(not v.start(game.state,0),"promotion blocked before opening")
	game.growth.phase="open"
	check(v.start(game.state,1,"dori"),"first campaign starts")
	check(game.growth.gold==0 and game.growth.memory_light==0,"pressing promotion grants no resources")
	check(not v.start(game.state,2,"fuwa"),"simultaneous campaign rejected")
	var phases: Dictionary={};var restored:=false;var saved_checkout: Dictionary={}
	for tick in range(1800):
		ready_host(v);v.advance(game,.1)
		for guest in v.guests:
			phases[guest.phase]=true
			if guest.phase=="checkout" and saved_checkout.is_empty(): saved_checkout=v.data().duplicate(true)
		if not restored and phases.has("read") and phases.has("checkout"):
			v=clone(v);game.state.ink_visits=v;restored=true
		if v.topic==-1: break
	check(restored,"resumed a campaign between visit actions")
	check(v.topic==-1 and v.guests.is_empty(),"visits finish without a stuck guest")
	for phase in ["shelf","browse","to_read","read","to_desk","checkout","leave"]:
		check(phases.has(phase),"physical visitor phase "+phase)
	check(v.total==2,"only real paid entries counted")
	check(game.growth.gold==35 and game.growth.memory_light==5,"two entries, one rental and two different memory outcomes")
	check(v.loans.size()==1 and v.loans[0].due_day==2,"borrowed book recorded for next-day return")
	check(v.return_queue.is_empty(),"same-day borrower is not immediately returned")
	# A stale visitor snapshot cannot duplicate already settled income.
	var replay:=Visits.new();replay.bind_growth(game.growth)
	check(replay.restore(saved_checkout,game.state.residents),"pre-settlement checkout snapshot loads")
	for tick in range(1800):
		ready_host(replay);replay.advance(game,.1)
		if replay.topic==-1: break
	check(game.growth.gold==35 and game.growth.memory_light==5,"replayed settled visit does not pay twice")
	v=clone(v);game.state.ink_visits=v
	game.state.day=2;v.on_new_day(2);v.on_new_day(2)
	check(v.return_queue.size()==1,"due book is queued exactly once")
	v=clone(v);game.state.ink_visits=v
	var returned_phases: Dictionary={}
	for tick in range(1200):
		v.advance(game,.1)
		for guest in v.guests:
			returned_phases[guest.phase]=true
			if guest.phase=="return_desk": check(v.carrying(guest),"return visitor carries original book")
		if v.return_queue.is_empty() and v.guests.is_empty(): break
	check(returned_phases.has("return_desk") and returned_phases.has("checkin"),"return visitor reaches the physical desk")
	check(v.loans[0].returned,"return transaction completed")
	check(game.growth.gold==35 and game.growth.memory_light==5 and v.total==2,"returns do not double-charge entry or repeat rewards")
	v.on_new_day(3);check(v.return_queue.is_empty(),"returned book never queues again")
	# Validate failed restoration atomically.
	var before:=v.data();var bad:=before.duplicate(true);bad.next_uid=0
	check(not v.restore(bad,game.state.residents) and v.data()==before,"bad snapshot does not partially mutate live visitors")
	game.growth.expanded=true
	check(v.start(game.state,2,"fuwa") and v.group_size()==4,"purchased capacity affects the next group")
	for tick in range(1800):
		ready_host(v);v.advance(game,.1)
		if v.topic==-1: break
	check(v.total==6 and game.growth.gold==115 and game.growth.memory_light==15,"upgrades affect real visits and rental fees")
	# Entirely blocked map: no invisible entrance fee and campaign can recover.
	var blocked:=Visits.new();blocked.bind_growth(game.growth)
	game.navigation.fill_solid_region(game.navigation.region,true)
	check(blocked.start(game.state,1,"dori"),"blocked campaign accepted until path preflight")
	var money:=game.growth.gold
	for tick in range(150): ready_host(blocked);blocked.advance(game,.1)
	check(blocked.topic==-1 and blocked.total==0 and game.growth.gold==money,"unreachable visits cancel without generating income")
	game._setup_map()
	check(blocked.start(game.state,1,"dori"),"fixed layout allows a new campaign")
	print("GROWTH VISITORS: ",checks," checks, ",failures," failures. Player save untouched.")
	game.queue_free();await process_frame
	quit(1 if failures else 0)
