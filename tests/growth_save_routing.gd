extends SceneTree

const Game=preload("res://scripts/growth_game.gd")
const Adapter=preload("res://scripts/growth_state_adapter.gd")
const OUT="res://artifacts/growth_rollout_20261117/"
const LEGACY_COPY=OUT+"legacy_save_before.json"
var checks:=0
var failures:=0
var folder: String
var nodes: Array[Node]=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func file_hash(path: String) -> Dictionary:
	return {"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
func file_states(paths: Array[String]) -> Dictionary:
	var result: Dictionary={}
	for path in paths: result[path]=file_hash(path)
	return result
func write(path: String,bytes: PackedByteArray) -> void:
	check(path.begins_with(folder),"fixture writes stay in the unique artifact test directory")
	if not path.begins_with(folder): return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	check(file!=null,"open isolated fixture for write")
	if file==null: return
	file.store_buffer(bytes);file.close()
func spawn_game(save_file: String,legacy_file: String):
	var game=Game.new()
	game.save_path=save_file
	game.legacy_save_path=legacy_file
	game.persist=true
	root.add_child(game)
	game.set_process(false)
	game.audio_enabled=false
	nodes.append(game)
	return game

func run() -> void:
	folder=OUT+"save_routing_%d_%d/"%[int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(folder)==OK,"create isolated nonce directory")
	var protected: Array[String]=[Game.State.SAVE_PATH,Game.State.SAVE_PATH+".bak",Game.PRODUCTION_SAVE,Game.PRODUCTION_SAVE+".bak",Game.PREVIEW_SAVE,Game.PREVIEW_SAVE+".bak",LEGACY_COPY]
	var protected_before:=file_states(protected)
	check(FileAccess.file_exists(LEGACY_COPY),"pre-rollout legacy backup is available as read-only fixture source")
	if not FileAccess.file_exists(LEGACY_COPY): quit(1);return
	var original:=FileAccess.get_file_as_bytes(LEGACY_COPY)
	var legacy_data: Variant=JSON.parse_string(original.get_string_from_utf8())
	check(legacy_data is Dictionary and not legacy_data.has("library_growth"),"fixture is the actual preserved legacy format")
	var legacy: String=folder+"legacy.json"
	var v2: String=folder+"growth.json"
	write(legacy,original)
	var game=spawn_game(v2,legacy)
	check(game.mode=="title" and game.save_available,"legacy-only slot offers Continue at production title")
	game._action("continue")
	check(game.mode=="play" and game.migrated_from_legacy and not game.save_failed,"Continue migrates the real legacy fixture and reports successful first write")
	check(game.state.residents==legacy_data.residents and game.state.day==int(legacy_data.day) and game.state.fan_form==legacy_data.fan_form,"first migration preserves recruited members, calendar and selected fan")
	check(game.growth==game.state.growth and game.state.ink_visits.growth==game.growth,"first migration binds both gameplay and visitor ledger to loaded growth")
	check(FileAccess.file_exists(v2) and FileAccess.get_file_as_bytes(legacy)==original,"first migration creates v2 without rewriting source v1")
	var first:=Adapter.new()
	check(first.load_from(v2) and first.to_data()==game.state.to_data(),"automatically created v2 is complete and immediately reloadable")
	check(game.toast.contains("원래 저장") and not game.toast.contains("실패"),"successful migration retains the source-preservation notice")

	# Make valid v2 progress intentionally different from still-valid v1.
	var newer:=Adapter.new()
	check(newer.load_from(v2),"load an isolated migrated fixture for distinct v2 progress")
	newer.day=17
	check(newer.save_to(v2)==OK,"write distinct current v2 progress")
	game._action("continue")
	check(game.state.day==17 and not game.migrated_from_legacy,"valid v2 always wins over valid older v1")
	check(FileAccess.get_file_as_bytes(legacy)==original,"v2 Continue also preserves legacy source")
	newer.day=27
	check(newer.save_to(v2)==OK,"atomic save creates day-17 backup before newer day-27 primary")
	var good_backup:=FileAccess.get_file_as_bytes(v2+".bak")
	var decoded_backup: Variant=JSON.parse_string(good_backup.get_string_from_utf8())
	check(decoded_backup is Dictionary and int(decoded_backup.day)==17,"recovery fixture has a genuinely older valid v2 backup")
	write(v2,"{broken primary".to_utf8_buffer())
	game._action("continue")
	check(game.mode=="play" and game.state.day==17 and not game.migrated_from_legacy,"corrupt v2 primary recovers its v2 backup instead of rolling back to v1")
	check(game.growth==game.state.growth and game.state.ink_visits.growth==game.growth,"backup recovery rebinds the active ledger")
	check(FileAccess.get_file_as_bytes(legacy)==original and FileAccess.get_file_as_bytes(v2+".bak")==good_backup,"recovery leaves both legacy source and valid backup unchanged")

	# Existing but invalid new-format data must not cause a silent legacy fallback.
	write(v2+".bak","{broken backup".to_utf8_buffer())
	var before_state: Dictionary=game.state.to_data().duplicate(true)
	var before_state_ref=game.state
	var before_growth_ref=game.growth
	var before_files:=file_states([v2,v2+".bak",legacy])
	game.mode="pause"
	game._action("continue")
	check(game.state==before_state_ref and game.growth==before_growth_ref and game.state.to_data()==before_state,"both invalid v2 files preserve current state and object bindings atomically")
	check(game.state.day==17 and game.mode=="pause" and not game.migrated_from_legacy,"both invalid v2 files never silently load still-valid day-1 legacy progress")
	check(game.toast.contains("백업") and game.toast.contains("읽지 못"),"complete v2 failure produces a persistent readable failure message")
	check(file_states([v2,v2+".bak",legacy])==before_files,"failed loading writes no source, backup or legacy file")

	# A backup alone still counts as a v2 save for the routing decision.
	var backup_only: String=folder+"backup_only.json"
	write(backup_only+".bak",good_backup)
	var recovered=spawn_game(backup_only,legacy)
	recovered._action("continue")
	check(recovered.state.day==17 and not recovered.migrated_from_legacy and recovered.mode=="play","missing primary plus valid v2 backup chooses the newer format")
	check(not FileAccess.file_exists(backup_only),"backup-only Continue does not unexpectedly rewrite a primary")

	# Absent parent directory deterministically rejects only the target write;
	# it needs no permissions change and cannot affect any existing player file.
	var fail_target: String=folder+"intentionally_missing_directory/growth.json"
	var failed=spawn_game(fail_target,legacy)
	failed._action("continue")
	check(failed.save_failed and failed.migrated_from_legacy and failed.mode=="play","initial migration write failure retains loaded legacy progress for recovery")
	check(failed.state.residents==legacy_data.residents and failed.state.day==int(legacy_data.day),"failed first write does not erase the loaded campaign")
	check(failed.toast.contains("저장에 실패") and not failed.toast.contains("원래 저장") and failed.toast_time>0,"first-write failure toast is not overwritten by migration-success notice")
	check(not FileAccess.file_exists(fail_target) and not FileAccess.file_exists(fail_target+".tmp"),"failed destination does not leave a misleading save or temporary file")
	check(FileAccess.get_file_as_bytes(legacy)==original,"first-write failure preserves legacy bytes exactly")
	check(file_states(protected)==protected_before,"actual v1/v2/preview saves, their backups and pre-rollout source are hash-identical")
	for node in nodes: node.free()
	print("GROWTH SAVE ROUTING: ",checks," checks, ",failures," failures. Only nonce paths under growth_rollout_20261117 were written.")
	quit(1 if failures else 0)
