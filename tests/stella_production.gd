extends SceneTree

const Game=preload("res://scripts/growth_game.gd")
const Driver=preload("res://tests/stella_play_driver.gd")
const OUT="res://artifacts/stella_adventures_20261118/"
var checks: Array=[]
var failures:=0
var g
var captures:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failures+=1;push_error(label)
func spawn():
	var game=Game.new();game.persist=false;root.add_child(game);game.set_process(false);game.audio_enabled=false;game.background_paused=false
	return game
func enter(id: String) -> void:
	g.mode="missions";g.mission_index=g._mission_index_for(id);g._take_mission();g._turn_story()
func shot(name: String) -> void:
	if not captures: return
	g.queue_redraw();g.stella_book.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
func run() -> void:
	captures=DisplayServer.get_name()!="headless";root.size=Vector2i(1280,800)
	for id in Game.StellaAdventure.Chapters.CHAPTERS:
		g=spawn();enter(id)
		check(g.mode=="stella_adventure" and g.stella_book.member==id,id+": Ete assignment enters protagonist book")
		g.stella_book.pause_on_focus_loss=false
		var clock_before: int=g.state.minutes;var fan_before: String=g.state.fan_form
		check(not g.state.complete_stella_adventure(id),id+": cannot unlock before arrival")
		check(not g.world_map_active() and not g.stella_book.is_processing_unhandled_input(),id+": one input owner; library suspended")
		for stage_index in range(g.stella_book.Chapters.CHAPTERS[id].size()):
			check(g.stella_book.stage==stage_index,id+": ordered stage "+str(stage_index))
			await shot(id+"_%02d_entry"%stage_index)
			var completed: bool=Driver.play_stage(g)
			check(completed,id+": actual move/action completes "+str(stage_index)+"; kind="+g.stella_book.kind())
			if not completed: break
			if g.stella_book.phase!="arrived": check(id not in g.state.residents,id+": intermediate stage never recruits")
		check(g.stella_book.completed and id in g.state.residents and g.state.chapter_steps[id]==3,id+": arrival recruits and finishes book")
		check(g.state.minutes==clock_before and g.state.fan_form==fan_before,id+": library clock and fan selection preserved")
		check(g.state.wear_fan_form(id),id+": corresponding fan unlocks")
		var snapshot: Dictionary=g.state.to_data().duplicate(true)
		g._stella_arrived();g._return_with_stella();Driver.step(g,1)
		check(g.state.to_data()==snapshot,id+": duplicate arrival and stale rescue harmless")
		await shot(id+"_arrived")
		Driver.press(g)
		check(g.mode=="dialog" and not g._find_object(id).is_empty(),id+": actual resident visible in library")
		g._open_story(g._mission_index_for(id),"journal");g._replay_debut()
		snapshot=g.state.to_data().duplicate(true)
		check(Driver.complete(g),id+": completed book replay playable")
		Driver.press(g)
		check(g.state.to_data()==snapshot and g.mode=="story",id+": replay read-only")
		g.free()
		# Resume partial action marks through actual disk/Continue/book entry.
		g=spawn();enter(id);Driver.play_stage(g);g._save()
		var before: Dictionary=g.stella_book.snapshot()
		check(g.state.save_to(OUT+id+"_checkpoint.json")==OK,id+": isolated save writes")
		g.free();g=spawn();g.save_path=OUT+id+"_checkpoint.json";g._continue_game();g._open_story(g._mission_index_for(id),"journal");g._turn_story()
		check(g.stella_book.stage==before.stage and g.state.residents.is_empty(),id+": Continue resumes without early unlock")
		Driver.press(g,KEY_ESCAPE);var paused_clock: float=g.stella_book.clock;Driver.step(g,2)
		check(g.stella_book.clock==paused_clock,id+": pause stops story")
		Driver.press(g,KEY_ESCAPE);Driver.press(g,KEY_Q)
		check(g.mode=="journal" and g.state.residents.is_empty(),id+": close incomplete book safe")
		g.free()
		# Corrupt optional data cannot manufacture an arrival.
		var cleaner=Game.StellaAdventure.Chapters
		check(cleaner.clean(id,{"version":1,"stage":0,"done":0,"x":230,"y":460,"clock":0,"phase":"arrived"}).is_empty(),id+": invalid early arrived checkpoint rejected")
	FileAccess.open(OUT+"integration_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("STELLA PRODUCTION: ",checks.size()," checks; failures=",failures);quit(1 if failures else 0)
