extends SceneTree

# Exercise the actual opt-in game node and its UI actions, not a mock ledger
# or a manually prepared promotion host. No normal/preview save is written.
const Game = preload("res://scripts/growth_game.gd")
const Adapter = preload("res://scripts/growth_state_adapter.gd")
var game: Node2D
var checks := 0
var failures := 0
var campaign_results: Array[Dictionary] = []
var observed_actions: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func file_snapshot(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}

func tick(seconds: float) -> void:
	for i in range(ceili(seconds / .1)):
		game._process(.1)
		for obj in game.objects:
			if obj.type == "npc": observed_actions[str(obj.get("yard_action", ""))] = true

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func finish_work() -> void:
	for frame in range(600):
		tick(.1)
		if game.mode=="play": return
	check(false,"reconstruction finishes through small animation steps")

func finish_day() -> void:
	game._action("close")
	var before_day: int=game.state.day
	game._action("sleep_confirm")
	for frame in range(2400):
		tick(.1)
		if game.mode=="growth_summary": break
	check(game.mode=="growth_summary" and game.state.day==before_day,"closing presents its summary before changing the date")
	game._action("growth_next_day")
	check(game.state.day==before_day+1 and game.state.minutes==540,"next day starts with the 09:00 preparation hour")

func settle_present_visitors() -> void:
	if game.state.minutes<600: game._action("growth_wait")
	for frame in range(2400):
		tick(.1)
		if game.state.ink_visits.topic<0 and game.state.ink_visits.guests.is_empty() and not game.state.ink_visits.has_due_arrivals(game.state): return
	check(false,"present visitors and returns settle before the next task")

func prepare_campaign(topic: int) -> void:
	game._action("close")
	for attempt in range(20):
		settle_present_visitors()
		if game.state.operating.promotion_error(game.state,topic).is_empty(): return
		if topic in game.state.operating.used_topics or game.state.operating.used_slots.size()==2 or game.state.minutes>=1020:
			finish_day()
		else: game._action("growth_wait")
	check(false,"available daily promotion slot for topic "+str(topic))

func earn_for(kind: String,id: String) -> void:
	var item: Dictionary=game.growth.catalogue(kind)[id]
	for attempt in range(18):
		if game.growth.gold>=item.price and game.growth.rank()>=item.rank: return
		campaign(0 if attempt%2==0 else 2)
	check(false,"real visitor income can afford "+id)

func campaign(topic: int) -> Dictionary:
	prepare_campaign(topic)
	game._action("close")
	game._action("promotion")
	check(game.mode == "promotion", "promotion menu opens after reopening")
	var before_gold: int = game.growth.gold
	var before_light: int = game.growth.memory_light
	var before_total: int = game.state.ink_visits.total
	game._action("promote_%d" % topic)
	var visits = game.state.ink_visits
	check(game.mode == "play" and visits.topic == topic, "chosen promotion starts from the UI")
	check(game.growth.gold == before_gold and game.growth.memory_light == before_light, "assigning promotion grants no immediate rewards")
	var host: String = visits.host
	var phases: Dictionary = {}
	var host_ready := false
	var host_moved := false
	var elapsed := 0.0
	for frame in range(6000):
		tick(.1)
		elapsed += .1
		var actor: Dictionary = game._find_object(host)
		host_ready = host_ready or actor.get("promo_ready", false)
		host_moved = host_moved or float(actor.get("walk_distance", 0.0)) > 0.0
		for guest in visits.guests: phases[guest.phase] = true
		if visits.topic == -1 and visits.guests.is_empty() and visits.reservations_for(game.state.day)==0: break
	check(visits.topic == -1 and visits.guests.is_empty() and visits.reservations_for(game.state.day)==0, "promotion, visits and due reservations finish without a stall")
	check(host_ready, "promotion host becomes ready through normal resident update")
	if topic != 0: check(host_moved, "outdoor promotion host physically walks out of the studio")
	var result := {"topic": topic, "seconds": snappedf(elapsed, .1), "gold": game.growth.gold - before_gold,
		"light": game.growth.memory_light - before_light, "visitors": visits.total - before_total, "phases": phases.keys()}
	campaign_results.append(result)
	return result

func buy(kind: String, id: String) -> void:
	game._action({"furniture":"world_furniture_shop","costume":"world_costume_shop","upgrade":"world_upgrades"}[kind])
	check(game.mode == "growth_shop" and game.shop_tab == kind, "shop category " + kind + " opens")
	game._action("growth_buy_" + id)
	if kind == "furniture":
		check(game.mode == "furniture" and game.furniture_editor.selected == id, "bought furniture opens its placement editor")
		game._action("furn_done")
		check(game.mode == "play", "placement editor returns to live library")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var normal_before := file_snapshot(Game.State.SAVE_PATH)
	var preview_before := file_snapshot(Game.PREVIEW_SAVE)
	game = Game.new()
	game.preview_mode = true
	game.persist = false
	root.add_child(game)
	game.set_process(false)
	game.garden_residents.rng.seed = 241116
	await process_frame
	check(game.state.residents.size() == 6 and game.growth.phase == "rebuilding", "review starts with all six residents and initial reconstruction")
	check(game.growth.gold == 0 and game.growth.memory_light == 0, "new review has no invented currency")
	check(game.state.furniture.is_empty() and not game._calendar().window_open, "before works: no gifted furniture and closed windows")
	check(game.studios_open and game.world_map_active() and not game.split_view(), "common library and six personal rooms use the approved separate full-screen areas")
	game._action("promotion")
	check(game.mode == "play" and game.state.ink_visits.topic == -1, "promotion is unavailable before opening")
	game._action("growth_open")
	check(game.growth.phase == "rebuilding", "opening cannot bypass the three works")
	game._start_work("reading")
	check(game.mode == "play" and game.work_task == "", "corridor must precede the reading work")
	game._interact(game._find_object("work_corridor"))
	check(game.mode == "growth_work" and game.work_task == "corridor", "map work object starts the corridor sequence")
	tick(1.0)
	key(KEY_ESCAPE)
	var paused_at: float = game.work_elapsed
	tick(2.0)
	check(game.work_paused and is_equal_approx(game.work_elapsed, paused_at), "Escape pauses reconstruction without completing it")
	key(KEY_ESCAPE)
	finish_work()
	check(game.mode == "play" and "corridor" in game.growth.completed_tasks, "corridor completes and returns player control")
	check(game._find_object("work_corridor").is_empty(), "completed corridor object disappears")
	game._start_work("reading")
	finish_work()
	check(game.growth.phase == "rebuilding" and game._calendar().window_open, "reading work opens windows while another work remains")
	game._action("growth_work_shelves")
	finish_work()
	check(game.growth.phase == "ready" and game.growth.completed_tasks.size() == 3, "all three animated tasks unlock reopening")
	check(game.growth.gold == 0 and game.growth.memory_light == 0, "initial rebuilding is free")
	check("chair" in game.growth.owned_furniture and not game.Furniture.find(game.state.furniture, "chair").is_empty(), "initial work supplies and places a usable reading chair")
	game._action("growth_open")
	check(game.growth.phase == "open" and game.mode == "play" and game.state.rebuild_stage() == 6, "reopening enables the normal library operating loop")
	game._action("growth_ops")
	check(game.mode == "growth_ops", "operations UI opens")
	key(KEY_ESCAPE)
	check(game.mode == "play", "operations Escape returns to play")
	game._action("fan_forms")
	game._action("form_dori")
	check(game.state.fan_form == "dori", "unlocked fan transformation remains usable")
	game._action("forms_back")
	check(game.mode == "growth_ops", "fan form back action returns to operations")
	var first := campaign(0)
	check(first.gold == 45 and first.light == 10 and first.visitors == 3, "first broadcast settles 3 entries, two readers, one loan and broadcast memory")
	for phase in ["shelf", "browse", "to_read", "read", "to_desk", "checkout", "leave"]:
		check(phase in first.phases, "real game visitor phase " + phase)
	check(game.state.ink_visits.loans.size() == 1 and game.state.ink_visits.loans[0].due_day == 2, "physical checkout creates a next-day loan")
	game._action("growth_ledger")
	check(game.mode == "growth_ledger", "loan record UI opens")
	game._action("growth_rest")
	finish_day()
	check(game.state.day == 2 and game.state.ink_visits.return_queue.size() == 1, "next day queues the real loan return")
	game._action("growth_wait")
	var return_phases: Dictionary = {}
	for frame in range(1200):
		tick(.1)
		for guest in game.state.ink_visits.guests: return_phases[guest.phase] = true
		if game.state.ink_visits.guests.is_empty() and game.state.ink_visits.return_queue.is_empty(): break
	check(return_phases.has("return_desk") and return_phases.has("checkin"), "returning guest physically reaches and uses the desk")
	check(game.state.ink_visits.loans[0].returned, "return transaction marks the loan complete")
	check(game.growth.gold == 45 and game.growth.memory_light == 10 and game.state.ink_visits.total == 3, "return does not charge again or repeat memory rewards")
	# Insufficient funds, then earned funds, go through the same UI purchase path.
	game._action("growth_shop")
	game._action("growth_tab_furniture")
	game._action("growth_buy_tea")
	check(game.growth.gold == 45 and "tea" not in game.growth.owned_furniture, "insufficient gold keeps both money and inventory intact")
	campaign(0)
	campaign(2)
	check(game.growth.gold == 140 and game.growth.memory_light == 30 and game.growth.rank() == 1, "morning and afternoon visitor use unlock the 30-light growth threshold")
	buy("furniture", "tea")
	check(game.growth.gold == 80 and game.growth.memory_light == 30, "furniture spends gold but never memory light")
	check(not game.Furniture.find(game.state.furniture, "tea").is_empty(), "bought tea table is actually placed in the shared library")
	buy("furniture", "tea")
	check(game.growth.gold == 80, "reopening owned furniture editor does not charge again")
	earn_for("upgrade","reading_lamp")
	var lamp_balance: int=game.growth.gold
	buy("upgrade", "reading_lamp")
	check(game.growth.gold == lamp_balance-80 and game.growth.reading_seconds() == 9.0, "earned gold purchases the actual faster-reading effect")
	game._action("close")
	earn_for("upgrade","welcome_desk")
	var desk_balance: int=game.growth.gold
	buy("upgrade", "welcome_desk")
	check(game.growth.gold == desk_balance-120 and game.growth.visitor_capacity() == 4, "capacity upgrade changes the real visitor limit")
	var expanded := campaign(0)
	check(expanded.visitors>=3 and expanded.gold>=45 and expanded.light>=10, "broadcast keeps its advertised guest count while capacity improves simultaneous service")
	# Global broadcast memory belongs to the scheduled promotion receipt only.
	var light_before: int = game.growth.memory_light
	check(game.state.finish_activity("dori", "stream", 0) > 0, "regular completed broadcast is still available")
	check(game.growth.memory_light == light_before, "personal broadcast does not bypass the daily promotional light limit")
	game.state.finish_activity("dori", "stream", 0)
	check(game.growth.memory_light == light_before, "repeating personal broadcast cannot mint memory light")
	earn_for("costume","odanming_idle")
	var before_costume_light: int = game.growth.memory_light
	buy("costume", "odanming_idle")
	check("odanming_idle" in game.growth.owned_costumes and game.state.costumes.danming == "odanming_idle", "officially verified purchased outfit equips through the shop")
	check(game.growth.memory_light == before_costume_light, "outfit purchase does not consume the growth threshold")
	var before_equipping: int = game.growth.gold
	buy("costume", "odanming_idle")
	check(game.growth.gold == before_equipping, "equipping an owned outfit is free")
	game._action("close")
	tick(150.0)
	check(observed_actions.has("tea"), "residents autonomously use the purchased tea interaction")
	var day_before: int = game.state.day
	game._action("growth_season_3")
	check(game._calendar().season_label == "겨울" and game.state.day == day_before, "season preview changes windows without advancing saved date")
	game._action("growth_season_reset")
	check(game._calendar().season_label == game.state.library_calendar().season_label and game.season_override == -1, "season preview resets to the actual date")
	# Jump only the date fixture; use the real rest action for calendar rollover.
	game.state.day = 28
	game.state.ink_visits.on_new_day(28)
	game.state.operating.begin(game.state)
	check(game._calendar().season_label=="겨울" and game._calendar().day_in_season==7,"four seven-day seasons reach winter 7 on day 28")
	var no_skip_day: int = game.state.day
	game._action("growth_next_day")
	check(game.state.day == no_skip_day, "next-day action cannot bypass closing")
	finish_day()
	check(game._calendar().season_label == "봄" and game._calendar().day_in_season == 1 and game._calendar().year==2, "closing rolls winter 7 into year 2 spring 1")
	game._action("growth_ops")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.state.to_data()))
	var restored := Adapter.new()
	check(restored.apply_data(snapshot), "complete game review save round-trips through JSON atomically")
	check(restored.growth.data() == game.growth.data(), "reconstruction, resources, purchases and receipts survive reload")
	check(JSON.parse_string(JSON.stringify(restored.ink_visits.data())) == snapshot.growth_visitors, "loans and returning visitors survive reload")
	check(restored.costumes.danming == "odanming_idle" and restored.fan_form == "dori", "equipped official outfit and fan form survive reload")
	check(restored.day == 29 and restored.furniture.size() == game.state.furniture.size(), "season date and bought furnishings survive reload")
	var before_bad: Dictionary = restored.to_data()
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt.library_growth.gold = -1
	check(not restored.apply_data(corrupt) and restored.to_data() == before_bad, "invalid growth save cannot partially mutate an existing game")
	game.state = restored
	game.growth = restored.growth
	game.mode = "play"
	game._setup_map()
	var money_before_returns: int = game.growth.gold
	var light_before_returns: int = game.growth.memory_light
	var receipts_before: Array=game.growth.recent_events.duplicate()
	var old_loan_ids: Array=[]
	for loan in game.state.ink_visits.loans: old_loan_ids.append(loan.id)
	settle_present_visitors()
	check(game.state.ink_visits.guests.is_empty() and game.state.ink_visits.return_queue.is_empty(), "restored pending returns all finish in the real library")
	check(game.state.ink_visits.loans.all(func(loan): return loan.id not in old_loan_ids or loan.returned), "all books borrowed before the reload reach returned state")
	var new_gold:=0
	var new_light:=0
	for receipt in game.growth.recent_events:
		if receipt in receipts_before: continue
		check(receipt not in old_loan_ids and not "return" in receipt,"return receipts are not charged twice")
		if receipt.ends_with(":entry"): new_gold+=game.growth.entrance_fee()
		elif receipt.ends_with(":loan"):
			new_gold+=game.growth.loan_fee()
			new_light+=3
		elif receipt.ends_with(":read"): new_light+=2
	check(game.growth.gold==money_before_returns+new_gold and game.growth.memory_light==light_before_returns+new_light,"only newly admitted readers and borrowers earn rewards alongside the restored returns")
	game._save()
	check(file_snapshot(Game.State.SAVE_PATH) == normal_before, "normal player save untouched")
	check(file_snapshot(Game.PREVIEW_SAVE) == preview_before, "review save untouched with persist=false")
	print("GROWTH GAME FLOW: ", checks, " checks, ", failures, " failures. Player and preview saves untouched.")
	print("ACTUAL CAMPAIGNS: ", JSON.stringify(campaign_results))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
