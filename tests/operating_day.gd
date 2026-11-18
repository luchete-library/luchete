extends SceneTree

const State=preload("res://scripts/growth_state_adapter.gd")
class Host:
	extends "res://scripts/main.gd"
	func _save() -> void: pass
var host:=Host.new()
var checks:=0
var failures:=0
var peak:=0
var phases: Dictionary={}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)

func _initialize() -> void: call_deferred("run")

func setup(light: int=0):
	var state:=State.new()
	for book in state.BOOKS:
		state.residents.append(book.id)
		state.chapter_steps[book.id]=3
	state.intro_seen=true
	state.growth.begin_rebuild(6)
	for task in state.Growth.TASKS: state.complete_reconstruction_task(task)
	state.growth.open_library()
	if light>0: state.growth.reward("fixture:light",0,light)
	host.state=state
	host._setup_map()
	state.operating.ensure(state)
	peak=0;phases.clear()
	return state

func tick(state, clock: bool=true) -> void:
	var visits=state.ink_visits
	if visits.host!="": host._find_object(visits.host).promo_ready=true
	if clock: state.advance_operating_time(.1)
	visits.advance(host,.1)
	peak=maxi(peak,visits.guests.size())
	for guest in visits.guests: phases[guest.phase]=true

func drain_today(state, max_ticks: int=5000) -> void:
	for i in range(max_ticks):
		tick(state)
		if state.ink_visits.topic<0 and state.ink_visits.guests.is_empty() and state.ink_visits.reservations_for(state.day)==0: return
	check(false,"today's visitors finish within bounded simulation")

func snapshot(state) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state.to_data()))

func reject(state, patch: Dictionary, label: String) -> void:
	var before:=snapshot(state)
	check(not state.apply_data(patch) and snapshot(state)==before,label)

func run() -> void:
	root.add_child(host)
	await process_frame
	host.set_process(false);host.audio_enabled=false;host.mode="play"
	var state=setup()
	check(state.minutes==540 and state.library_calendar().day_in_season==1,"day begins at 09:00 in short spring")
	for i in range(80): state.advance_operating_time(.1)
	check(state.minutes==550,"eighty real 0.1-second frames advance exactly ten game minutes")
	check(not state.advance_operating_time(NAN) and state.minutes==550,"non-finite deltas cannot corrupt clock")
	check(not state.ink_visits.start(state,0),"promotion unavailable before 10:00")
	check("10:00" in state.wait_until_next_event() and state.minutes==600,"wait skips empty opening hour")
	check(state.growth.gold==0 and state.growth.memory_light==0,"waiting grants no resources")
	check(state.ink_visits.start(state,0),"morning broadcast accepted")
	check(state.growth.memory_light==0,"assigning an unfinished broadcast grants no immediate light")
	for i in range(65): tick(state,false)
	check(state.growth.memory_light==3,"completed broadcast grants light exactly once")
	check(state.ink_visits.appointments.size()+state.ink_visits.guests.size()==4,"broadcast schedules three visitors plus one organic reader independently of capacity two")
	var resumed:=State.new()
	check(resumed.apply_data(snapshot(state)),"in-progress appointments and guests survive JSON save")
	state=resumed;host.state=state;host._setup_map()
	drain_today(state)
	check(peak<=2 and state.ink_visits.total==4,"capacity queues complete batch without exceeding two visitors")
	check(state.growth.gold==55 and state.growth.memory_light==12,"broadcast and organic reader settle 55 gold and twelve light")
	for phase in ["shelf","browse","read","checkout","leave"]: check(phases.has(phase),"real visitor action: "+phase)
	check(state.ink_visits.loans.size()==1 and state.ink_visits.loans[0].due_day==2,"loan return date uses monotonic absolute day")
	check(not state.ink_visits.start(state,1),"used morning slot rejects second promotion")
	state.minutes=840
	check(not state.ink_visits.start(state,0),"same topic cannot repeat in afternoon")
	check(state.ink_visits.start(state,2),"different afternoon performance accepted")
	drain_today(state)
	check(state.ink_visits.total==9 and state.growth.gold==105 and state.growth.memory_light==22,"performance adds five readers with actual settlement")
	check(state.operating_summary().promotions==2 and state.operating_summary().remaining_slots==0,"summary reports both used slots")
	check(not state.ink_visits.start(state,1),"third daily promotion denied")
	state.request_day_close()
	check(state.day_close_ready() and state.finish_operating_day(),"early closing settles completed day")
	check(state.day==2 and state.minutes==540 and state.operating.last_summary.visitors==9,"next day retains immutable previous settlement")
	check(state.operating_summary().income==0 and state.operating_summary().light==0,"new day's financial deltas reset")
	check(not state.finish_operating_day(),"settlement cannot advance same day twice")
	check(state.ink_visits.return_queue.size()==1,"loan queues once after next morning")
	for i in range(20): tick(state,false)
	check(state.ink_visits.guests.is_empty(),"returns do not enter before 10:00")
	state.minutes=600;drain_today(state)
	check(state.ink_visits.loans[0].returned and state.growth.gold==115 and state.growth.memory_light==24,"return animation settles no duplicate payment or light")
	check(State.new().apply_data(snapshot(state)),"settled summary and returned loan reload")

	state=setup();state.minutes=600
	check(state.ink_visits.start(state,1),"magazine campaign accepted")
	for i in range(65): tick(state,false)
	check(state.ink_visits.total==0 and state.ink_visits.reservations_for(2)==4 and state.growth.memory_light==0,"magazine books four tomorrow, earns nothing today")
	state.request_day_close();check(state.finish_operating_day(),"tomorrow's magazine reservation does not block closing")
	check(state.ink_visits.reservations_for(2)==6 and state.operating.last_summary.next_reservations==5,"early close preserves booked visitors")
	state.minutes=600;drain_today(state)
	check(state.ink_visits.total==6 and state.growth.gold==90 and state.growth.memory_light==14,"magazine two readers/two loans settle next day")

	state=setup();state.minutes=600;state.ink_visits.start(state,0)
	state.request_day_close()
	check(not state.day_close_ready(),"closing waits for active broadcast")
	for i in range(65): tick(state,false)
	check(state.day_close_ready() and state.ink_visits.reservations_for(2)==4 and state.ink_visits.guests.is_empty(),"late completed broadcast carries guests to tomorrow")
	check(state.growth.memory_light==3,"closing broadcast still settles its completed light once")
	check(state.finish_operating_day(),"closing completes after active promotional work")
	check(state.operating.last_summary.light==3 and state.operating.last_summary.promotions==1,"closing summary records actual completed promotion")

	state=setup();state.minutes=600
	check(state.finish_activity("dori","stream",0)>0 and state.growth.memory_light==0,"personal stream alone grants no global light")
	check(state.ink_visits.start(state,0,"dori") and state.growth.memory_light==3,"finished personal broadcast uses one real promotion slot")
	check(state.finish_activity("yune","stream",0)>0 and not state.ink_visits.start(state,0,"yune") and state.growth.memory_light==3,"six personal broadcasts cannot bypass daily global limit")
	check(state.finish_activity("dori","stream",0)==0,"personal friendship activity still limited once daily")

	state=setup();state.growth.reward("fixture:later-rank",0,30)
	check(state.ink_visits.appointments.size()==1,"same-day rank advance does not conjure natural visitors")
	state.request_day_close();state.finish_operating_day()
	check(state.ink_visits.reservations_for(2)==3,"stage two adds two natural visitors next day")
	state.minutes=600;drain_today(state)
	check(phases.has("exhibit") and state.ink_visits.total==3,"stage two guests inspect recommendation display")
	state.growth.reward("fixture:stage-three",0,70);state.request_day_close();state.finish_operating_day()
	check(state.ink_visits.reservations_for(3)==4,"stage three adds four natural visitors next day")
	state.minutes=600;drain_today(state)
	check(phases.has("record"),"stage three guests leave a physical visitor record")

	state=setup(100);state.minutes=600
	# User placement may block only optional exhibit: reading must still finish.
	var blocked_cell: Vector2i=host._grid_at(state.ink_visits.EXHIBIT)
	host.navigation.set_point_solid(blocked_cell,true)
	drain_today(state)
	check(state.ink_visits.total==4 and state.ink_visits.loans.size()==2,"blocked optional stop does not strand normal visitors")
	check(not phases.has("exhibit"),"unreachable optional exhibit is skipped")

	state=setup();state.minutes=1190
	state.ink_visits._book_appointment(state,"read",2,state.day,1190)
	for i in range(80): state.advance_operating_time(.1)
	check(state.minutes==1200 and state.ink_visits.reservations_for(2)==2,"20:00 closes admissions and preserves waiting guests")
	state.minutes=1310
	for i in range(80): state.advance_operating_time(.1)
	check(state.minutes==1320 and state.operating.closing and state.day_close_ready(),"22:00 marks daily closing without advancing date")

	# Complete a delayed broadcast exactly as the admission clock reaches 20:00.
	# A waiting appointment and a partial broadcast are saved before that edge.
	state=setup();state.minutes=600;state.ink_visits.start(state,0)
	state.minutes=1190;state.operating.fraction=1.9
	state.ink_visits._book_appointment(state,"read",2,state.day,1190)
	host.navigation.fill_solid_region(host.navigation.region,true)
	for i in range(50): tick(state)
	check(state.minutes==1190 and state.ink_visits.topic==0 and state.growth.memory_light==0,"before-cutoff save retains unfinished broadcast without reward")
	resumed=State.new()
	check(resumed.apply_data(snapshot(state)),"19:50 reservation and partial broadcast reload together")
	state=resumed;host.state=state;host._setup_map()
	for i in range(12): tick(state)
	check(state.minutes==1200 and state.ink_visits.topic==-1 and state.growth.memory_light==3,"broadcast finishing at admission cutoff earns light once")
	check(state.ink_visits.guests.is_empty() and state.ink_visits.reservations_for(2)==5 and state.growth.gold==0,"cutoff carries waiting visitor and three broadcast bookings without invisible admission")
	resumed=State.new()
	check(resumed.apply_data(snapshot(state)),"completed cutoff transaction survives second JSON reload")
	state=resumed;host.state=state;host._setup_map()
	for i in range(80): tick(state,false)
	check(state.growth.memory_light==3 and state.ink_visits.reservations_for(2)==5,"reloaded cutoff cannot repeat broadcast reward or reservation")
	state.request_day_close();state.finish_operating_day()
	check(state.day==2 and state.ink_visits.reservations_for(2)==6,"five carried appointments plus next-day organic visitor survive settlement")

	# Block an already moving return guest, then close and restore the desk.
	state=setup();state.minutes=600
	state.ink_visits.loans.append({"id":"fixture:blocked-return","book":"dori","due_day":1,"queued":false,"returned":false})
	state.ink_visits.on_new_day(1)
	for i in range(10): tick(state,false)
	check(state.ink_visits.guests.size()==1 and state.ink_visits.guests[0].kind=="return","due borrower begins a real return trip")
	host.navigation.fill_solid_region(host.navigation.region,true);state.ink_visits.paths.clear()
	for i in range(220): tick(state,false)
	check(state.ink_visits.guests.is_empty() and state.ink_visits.return_queue==["fixture:blocked-return"],"blocked return visitor departs and requeues exactly once")
	check(state.ink_visits.loans.size()==1 and not state.ink_visits.loans[0].returned,"failed desk route preserves outstanding book")
	state.request_day_close();check(state.day_close_ready() and state.finish_operating_day(),"queued blocked return does not deadlock daily closing")
	resumed=State.new();check(resumed.apply_data(snapshot(state)),"unreturned book and next-day retry survive save")
	state=resumed;host.state=state;host._setup_map();state.minutes=600
	drain_today(state)
	check(state.ink_visits.loans[0].returned and state.ink_visits.return_queue.is_empty() and state.ink_visits.guests.is_empty(),"repaired desk completes physical return next day")
	check(state.growth.gold==20 and state.growth.memory_light==4,"two natural readers settle; failed and retried return never creates fees or repeat light")

	state=setup();state.minutes=600;state.ink_visits.start(state,0)
	var raw:=snapshot(state)
	for edit in [{"fraction":8},{"day":2},{"used_slots":[0,0],"used_topics":[0,1]},{"used_topics":[2]},{"closing":1},{"calendar_offset":-5},{"start_income":100}]:
		var malformed:=raw.duplicate(true)
		for key in edit: malformed.operating_day[key]=edit[key]
		reject(state,malformed,"invalid operating state remains atomic: "+str(edit))
	var malformed:=raw.duplicate(true);malformed.growth_visitors.planned_day=999
	reject(state,malformed,"future natural-visitor planning day rejected")
	malformed=raw.duplicate(true);malformed.growth_visitors.appointments=[{"id":1,"book":"dori","kind":"read","source":0,"day":1,"minute":599,"retries":0}];malformed.growth_visitors.next_appointment=2
	reject(state,malformed,"outside-hours appointment rejected")

	state=setup();state.day=37;state.operating.day=0;state.growth.memory_light=45
	raw=snapshot(state);raw.erase("operating_day");raw.library_growth.version=1;raw.library_growth.erase("rank_floor")
	raw.growth_visitors.version=1
	resumed=State.new()
	check(resumed.apply_data(raw) and resumed.day==37,"legacy absolute day remains monotonic during short-season migration")
	check(resumed.library_calendar().year==1 and resumed.library_calendar().season_index==1 and resumed.library_calendar().day_in_season==3,"legacy summer remains summer after seven-day conversion")
	check(resumed.growth.rank()==2 and resumed.growth.memory_light==45,"previously earned stage three is grandfathered without fake light")
	check(State.new().apply_data(snapshot(resumed)),"migrated display offset and rank survive second save")

	print("OPERATING DAY: ",checks," checks, ",failures," failures. No save files written.")
	host.queue_free();await process_frame
	quit(1 if failures else 0)
