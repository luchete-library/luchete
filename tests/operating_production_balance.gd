extends SceneTree
const State=preload("res://scripts/growth_state_adapter.gd")
class Host:
	extends "res://scripts/growth_game.gd"
	func _save() -> void: pass
var host:=Host.new()
var failures:=0

func _initialize() -> void: call_deferred("run")

func simulate(topics: Array) -> Dictionary:
	var state:=State.new()
	for book in state.BOOKS:
		state.residents.append(book.id);state.chapter_steps[book.id]=3
	state.growth.begin_rebuild(6)
	for task in state.Growth.TASKS: state.complete_reconstruction_task(task)
	state.growth.open_library();state.operating.ensure(state)
	host.state=state;host.growth=state.growth;host._reset_session();host.mode="play";host._setup_map()
	var milestones: Array=[]
	var days: Array=[]
	var seconds:=0.0
	var jumps:=0
	var max_guests:=0
	var previous_rank:=0
	while state.day<=20:
		var started:=0
		var today:=state.day
		var day_seconds:=seconds
		for frame in range(12000):
			var slot: int=state.operating.slot(state.minutes)
			if slot>=0 and slot<topics.size() and slot not in state.operating.used_slots:
				if state.ink_visits.start(state,topics[slot]): started+=1
			var inactive: bool=state.ink_visits.topic<0 and state.ink_visits.guests.is_empty()
			var today_reservations: int=state.ink_visits.reservations_for(state.day)
			var finished_slots: bool=state.operating.used_slots.size()>=topics.size() or state.minutes>=1020
			if inactive and today_reservations==0 and state.ink_visits.return_queue.is_empty() and finished_slots:
				state.request_day_close()
			if state.day_close_ready():
				var row: Dictionary=state.operating_summary()
				row.seconds=snappedf(seconds-day_seconds,.1);row.start_count=started
				days.append(row)
				state.finish_operating_day();host.mode="play";host.summary_snoozed=false;host._setup_map()
				break
			if inactive and not state.operating.closing and not state.ink_visits.has_due_arrivals(state):
				var before: int=state.minutes
				state.wait_until_next_event()
				if state.minutes>before: jumps+=1
			host.background_paused=false
			host._process(.1);seconds+=.1
			max_guests=maxi(max_guests,state.ink_visits.guests.size())
			if state.growth.rank()>previous_rank:
				previous_rank=state.growth.rank()
				milestones.append({"rank":previous_rank+1,"day":state.day,"clock":"%02d:%02d"%[state.minutes/60,state.minutes%60],"seconds":snappedf(seconds,.1),"gold":state.growth.gold,"light":state.growth.memory_light})
		if state.day==today:
			failures+=1;push_error("operating day failed to close within bound")
			break
	return {"topics":topics,"milestones":milestones,"days":days,"active_seconds":snappedf(seconds,.1),"max_guests":max_guests,"wait_jumps":jumps,"total_gold":state.growth.gold,"total_light":state.growth.memory_light,"total_visitors":state.ink_visits.total}

func run() -> void:
	host.persist=false;root.add_child(host);await process_frame
	host.set_process(false);host.audio_enabled=false;host.mode="play"
	var results: Array=[]
	for topics in [[0,2],[0,1],[0]]:
		var result:=simulate(topics)
		results.append(result)
		print("PRODUCTION BALANCE ",topics," milestones=",result.milestones," seconds=",result.active_seconds," gold=",result.total_gold," light=",result.total_light," visitors=",result.total_visitors)
	var file:=FileAccess.open("res://artifacts/ui_fix_20261117/operating_production_balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rules":"20 days; production growth_game._process including autonomous NPC promotion preparation and visitor navigation; no purchases; active clock plus available wait and early close; no menu or conversation time","results":results},"\t"));file.close()
	host.queue_free();await process_frame
	quit(1 if failures else 0)

