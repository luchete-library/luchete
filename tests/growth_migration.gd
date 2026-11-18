extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Adapter = preload("res://scripts/growth_state_adapter.gd")
const Growth = preload("res://scripts/library_growth.gd")
class Host:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func snapshot(value: RefCounted) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value.to_data()))

func old_state(count: int = 6, pending: bool = false) -> RefCounted:
	var old := State.new()
	for i in range(count):
		var id: String = old.BOOKS[i].id
		old.residents.append(id)
		old.chapter_steps[id] = 3
		old.friendship[id] = 5
	old.opening_pending = pending
	old.day = 37
	old.minutes = 660
	old.energy = 77
	old.intro_seen = true
	old.bookmarks = 125
	old.total_loans = 4
	old.restored = ["yato"] if count > 0 else []
	old.fan_form = "yato" if count > 0 else ""
	old.read_bonds = {"yato": 1} if count > 0 else {}
	if count > 0:
		old.costumes = {"yato": "yato_headset"}
		old.place_furniture("tea", old.Furniture.DEFAULTS[1])
	return old

func reject_unchanged(current: RefCounted, raw: Dictionary, label: String) -> void:
	var before := JSON.stringify(current.to_data())
	var marker: bool = current.migrated_from_legacy
	check(not current.apply_data(raw), label + " rejected")
	check(JSON.stringify(current.to_data()) == before and current.migrated_from_legacy == marker, label + " leaves live state untouched")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var partial_old = old_state(2)
	var partial := Adapter.new()
	check(partial.apply_data(snapshot(partial_old)), "two recruited residents migrate")
	check(partial.growth.phase == "recruiting" and partial.migrated_from_legacy, "partial story remains recruiting")
	check(partial.day == 37 and partial.minutes == 660 and partial.energy == 77, "calendar and energy are preserved")
	check(partial.residents == partial_old.residents and partial.chapter_steps == partial_old.chapter_steps, "resident unlocks and story progress are preserved")
	check(partial.friendship == partial_old.friendship and partial.read_bonds == partial_old.read_bonds, "affection and reading bonds are preserved")
	check(partial.restored == partial_old.restored and partial.fan_form == "yato", "existing registered books and fan transformation survive")
	check(partial.bookmarks == 125 and partial.total_loans == 4 and partial.growth.gold == 0 and partial.growth.memory_light == 0, "old bookmarks are retained without invented conversion")
	check(partial.furniture == partial_old.furniture and partial.growth.owned_furniture == ["tea"], "existing furniture and ownership migrate together")
	check(partial.costumes.yato == "yato_headset" and partial.growth.owned_costumes == ["yato_headset"], "only the equipped legacy extra outfit is grandfathered")
	check("yato_bunny" not in partial.growth.owned_costumes, "unworn old free outfits are not all granted")
	var partial_reload := Adapter.new()
	check(partial_reload.apply_data(snapshot(partial)) and not partial_reload.migrated_from_legacy, "migrated partial state reloads as modern data")
	check(partial_reload.growth.data() == partial.growth.data(), "partial migration is stable on a second load")
	var partial_bad := snapshot(partial_old)
	partial_bad.chapter_steps.yato = 1
	reject_unchanged(partial, partial_bad, "resident with unfinished story")
	partial_bad = snapshot(partial_old)
	partial_bad.residents.append("yato")
	reject_unchanged(partial, partial_bad, "duplicate recruited resident")
	var pending := Adapter.new()
	check(pending.apply_data(snapshot(old_state(6, true))), "six recruits awaiting legacy opening migrate")
	check(pending.growth.phase == "rebuilding" and pending.growth.completed_tasks.is_empty() and not pending.opening_pending, "unopened legacy library starts first reconstruction")
	check(pending.restored == ["yato"], "book returns are not immediately all registered")
	var affection := pending.friendship.duplicate()
	check(not pending.complete_reconstruction_task("shelves"), "shelves cannot bypass the corridor prerequisite")
	check(pending.complete_reconstruction_task("corridor"), "initial corridor works through state API")
	check(pending.restored == ["yato"], "corridor does not register unrelated books")
	check(pending.complete_reconstruction_task("shelves"), "shelf work registers the collection")
	check(pending.restored.size() == 6 and pending.friendship == affection, "all six completed books register without affection rewards")
	check(pending.growth.gold == 0 and pending.growth.memory_light == 0 and pending.bookmarks == 125, "shelf registration gives no currency or memory windfall")
	check(not pending.complete_reconstruction_task("shelves") and pending.restored.size() == 6, "repeated shelf completion is idempotent")
	var midway := Adapter.new()
	check(midway.apply_data(snapshot(pending)) and midway.restored.size() == 6 and midway.growth.phase == "rebuilding", "partially rebuilt shelf registration survives reload")
	check(pending.complete_reconstruction_task("reading") and pending.growth.phase == "ready", "last initial work enables reopening")
	check(pending.growth.open_library(), "first reconstruction can reopen normally")
	var open_old = old_state()
	open_old.costumes.danming = "danming_origin"
	var opened := Adapter.new()
	check(opened.apply_data(snapshot(open_old)), "already-open legacy library migrates")
	check(opened.growth.phase == "open" and opened.growth.completed_tasks.size() == 3, "already-open library is never relocked")
	check(opened.restored.size() == 6 and opened.friendship == open_old.friendship, "open library normalizes registered completed books without affection gain")
	check(opened.growth.owned_furniture.has("chair") and opened.growth.owned_furniture.has("tea"), "open library keeps furnishings plus free starter chair ownership")
	check(opened.costumes.danming == "danming_origin" and "danming_origin" not in opened.growth.owned_costumes, "default costume stays available without an extra ownership grant")
	check(opened.growth.gold == 0 and opened.growth.memory_light == 0 and opened.bookmarks == 125, "already-open migration also starts new resources at zero")
	# A genuinely older save inferred residents from affection rather than steps.
	var oldest := snapshot(open_old)
	oldest.version = 2
	oldest.erase("residents")
	oldest.erase("chapter_steps")
	oldest.erase("active_mission")
	oldest.erase("page_complete")
	var inferred := Adapter.new()
	check(inferred.apply_data(oldest), "version-two inferred unlocks remain supported")
	check(inferred.residents.size() == 6 and inferred.chapter_steps.size() == 6 and inferred.growth.phase == "open", "old inferred unlocks become explicit completed chapters")
	check(Adapter.new().apply_data(snapshot(inferred)), "oldest migration produces a reloadable modern snapshot")
	# Preserve a legacy ordinary loan, settle it exactly once in old bookmarks,
	# and never credit that old obligation as a new paid visit or light event.
	var loan_old = old_state()
	loan_old.active_loan = {"book_id": "yato", "due_day": 38, "visitor": "기존 방문객"}
	loan_old.loan_today = true
	var loan := Adapter.new()
	check(loan.apply_data(snapshot(loan_old)) and snapshot(loan).active_loan == snapshot(loan_old).active_loan, "unsettled ordinary legacy loan is preserved")
	check(loan.lend_book(1) != "" and loan.active_loan.book_id == "yato", "new manual loans cannot enter the retired reward loop")
	loan.sleep()
	check(loan.active_loan.is_empty() and loan.bookmarks == 145 and loan.total_loans == 5, "already-promised ordinary return settles once")
	check(loan.growth.gold == 0 and loan.growth.memory_light == 0 and loan.ink_visits.total == 0, "old ordinary return creates no new economy reward")
	loan.sleep()
	check(loan.bookmarks == 145 and loan.total_loans == 5, "later nights cannot settle the old loan twice")
	# Legacy promotion migration retains real visitors and counts; already
	# admitted guests must never be charged a retroactive entrance fee.
	var visits_old = old_state()
	visits_old.ink_visits.campaigns = 4
	visits_old.ink_visits.total = 31
	visits_old.ink_visits.topic = 1
	visits_old.ink_visits.host = "dori"
	visits_old.ink_visits.pending = 2
	visits_old.ink_visits.delay = .8
	visits_old.ink_visits.guests.assign([
		{"slot": 0, "phase": "read", "pos": Vector2(288,402), "facing": "down", "distance": 550.0, "elapsed": 12.0},
		{"slot": 2, "phase": "leave", "pos": Vector2(504,650), "facing": "down", "distance": 900.0, "elapsed": .2}
	])
	var visitors := Adapter.new()
	check(visitors.apply_data(snapshot(visits_old)), "in-progress legacy campaign migrates")
	check(visitors.ink_visits.total == 31 and visitors.ink_visits.campaigns == 4, "historical visits and campaign count are retained")
	check(visitors.ink_visits.topic == 1 and visitors.ink_visits.host == "dori" and visitors.ink_visits.pending == 2 and visitors.ink_visits.batch_size == 5, "campaign choice, host and original batch size survive")
	check(visitors.ink_visits.guests.size() == 2 and visitors.ink_visits.guests[0].pos == Vector2(288,402), "visible guests retain their position and stage")
	check(visitors.ink_visits.guests[0].admitted and visitors.ink_visits.guests[1].completed, "existing admission and already-finished reading are marked settled")
	check(visitors.growth.gold == 0 and visitors.growth.memory_light == 0, "migration itself never awards income or light")
	var visitors_reload := Adapter.new()
	check(visitors_reload.apply_data(snapshot(visitors)), "migrated active campaign reloads before it finishes")
	var host := Host.new()
	root.add_child(host)
	host.set_process(false)
	await process_frame
	host.state = visitors_reload
	host.mode = "play"
	host._setup_map()
	for frame in range(1800):
		host._find_object("dori").promo_ready = true
		visitors_reload.ink_visits.advance(host,.1)
		if visitors_reload.ink_visits.topic == -1: break
	check(visitors_reload.ink_visits.topic == -1 and visitors_reload.ink_visits.guests.is_empty(), "converted campaign resumes to completion")
	var reach=visitors_reload.ink_visits.outreach
	check(visitors_reload.ink_visits.total-reach.arrivals.natural==33 and visitors_reload.growth.gold-reach.income.natural==35,"legacy campaign charges only its two new guests; organic visitor accounted separately")
	check(visitors_reload.growth.memory_light-reach.light.natural==7,"unfinished old reading earns light; settled old departure does not")
	host.queue_free()
	await process_frame
	# Every invalid decode below starts from a populated, valid current state.
	var valid := snapshot(opened)
	var invalid := valid.duplicate(true)
	invalid.library_growth.gold = -1
	reject_unchanged(opened, invalid, "negative gold")
	invalid = valid.duplicate(true)
	invalid.library_growth.income_total = 1
	reject_unchanged(opened, invalid, "unbalanced income ledger")
	invalid = valid.duplicate(true)
	invalid.library_growth.phase = "recruiting"
	invalid.library_growth.completed_tasks = []
	reject_unchanged(opened, invalid, "six recruits in recruiting phase")
	invalid = valid.duplicate(true)
	invalid.residents.erase("fuwa")
	invalid.chapter_steps.fuwa = 2
	reject_unchanged(opened, invalid, "open library without all six residents")
	invalid = valid.duplicate(true)
	invalid.erase("growth_visitors")
	reject_unchanged(opened, invalid, "missing modern visitor data")
	invalid = valid.duplicate(true)
	invalid.erase("library_growth")
	reject_unchanged(opened, invalid, "visitor-only partial modern data")
	invalid = valid.duplicate(true)
	invalid.day = NAN
	reject_unchanged(opened, invalid, "nonfinite day")
	invalid = valid.duplicate(true)
	invalid.active_loan = {"book_id":"yato", "due_day":INF, "visitor":"test"}
	reject_unchanged(opened, invalid, "nonfinite old loan due day")
	invalid = valid.duplicate(true)
	invalid.opening_pending = true
	reject_unchanged(opened, invalid, "retired opening flag in modern game")
	invalid = valid.duplicate(true)
	invalid.library_growth.owned_furniture.erase("tea")
	reject_unchanged(opened, invalid, "placed but unowned furniture")
	invalid = valid.duplicate(true)
	invalid.furniture.append({"kind":"unknown", "x":200, "y":300})
	reject_unchanged(opened, invalid, "unknown furniture cannot silently disappear")
	invalid = valid.duplicate(true)
	invalid.costumes.danming = "odanming_idle"
	reject_unchanged(opened, invalid, "equipped but unowned extra costume")
	invalid = valid.duplicate(true)
	invalid.library_growth.owned_costumes.append("invented_costume")
	reject_unchanged(opened, invalid, "unknown owned costume")
	invalid = snapshot(visitors)
	invalid.library_growth.phase = "rebuilding"
	invalid.library_growth.completed_tasks = []
	reject_unchanged(opened, invalid, "active visitors before opening")
	var plain := snapshot(old_state())
	plain.ink_visits.total = -1
	reject_unchanged(opened, plain, "invalid legacy visitors cannot be discarded")
	# Read the actual v1 slot if present. It is never written or copied over.
	if FileAccess.file_exists(State.SAVE_PATH):
		var before := FileAccess.get_file_as_bytes(State.SAVE_PATH)
		var real := Adapter.new()
		check(real.apply_data(JSON.parse_string(before.get_string_from_utf8())), "actual local v1 save decodes through migration")
		check(FileAccess.get_file_as_bytes(State.SAVE_PATH) == before, "actual v1 bytes remain unchanged")
		print("LOCAL V1 READ-ONLY: residents=", real.residents.size(), ", day=", real.day, ", phase=", real.growth.phase)
	print("GROWTH MIGRATION: ", checks, " checks, ", failures, " failures. No save files written.")
	quit(1 if failures else 0)
