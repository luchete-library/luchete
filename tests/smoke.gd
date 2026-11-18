extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Encounters = preload("res://scripts/encounter_books.gd")
var checks: int = 0
var failures: int = 0

class TestGame:
	extends "res://scripts/main.gd"
	func _save() -> void:
		pass # Never change the player's real save during tests.

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",description)

func inspect_memory(game,scene: int) -> void:
	var member: String=game.MEMBERS[game.story_member].id
	if member=="dori" and scene==2 and not game.DoriCase.ready(2,game._chapter_progress().dori_notes):
		var r=game.dori_rubbing
		game._interact(game._find_object("clue_rubbing"))
		check(r.phase==r.Phase.FIELD,"rubbing requires walking up to the stone")
		game.player_pos=r.STONE_SIDE
		game._interact(game._find_object("clue_rubbing"))
		r.held=true
		r.advance(game,.4)
		check(not r.has_print(game),"a brief touch cannot finish a rubbing")
		r.advance(game,r.RUB_TIME)
		check(r.has_print(game) and not r.held_by_ete(game),"paper is ready before Ete collects Dori")
		game.clock+=r.WALK_TIME+.1
		game.player_pos=r.ETE_SIDE
		game._interact(game._find_object("clue_overlay"))
		r.align(game)
		check(r.phase==r.Phase.ALIGN,"an offset print cannot unlock the record")
		r.offset=Vector2.ZERO
		r.align(game)
		game._remember_chapter()
		check(game._chapter_progress().debut_scene("dori")==2,"matching leaves time to see the discovery")
		game.book_discovery.begin_result(game)
		game.book_discovery.request_next(game)
		game._process(game.book_discovery.FADE+.1)
		check(game._chapter_progress().debut_scene("dori")==3 and not game.chapter_question,"discovery records itself and continues to the library")
		return
	if game.MEMBERS[game.story_member].id=="fuwa" and not game.FuwaSnow.ready(scene,game._chapter_progress().fuwa_notes):
		game._inspect_chapter(scene)
		check(not game.chapter_question,"Tenbi explores the place before the official record opens")
		if scene==0:
			var ward=game.fuwa_snow.practice
			var notes: Array=game._chapter_progress().fuwa_notes
			game._interact(game._find_object("tenbi_together"))
			check(ward.phase==ward.Phase.FIELD and game.pending_object=="tenbi_together","Tenbi must walk up to Fuwa")
			game.player_pos=ward.STATION
			game._process(.01)
			ward.advance(game,ward.join_time)
			check(ward.phase==ward.Phase.TRACE and game.book_activity==null,"practice takes place in the courtyard")
			var key:=InputEventKey.new()
			key.pressed=true
			key.physical_keycode=KEY_LEFT
			ward.input(game,key)
			check(ward.step==0,"an out-of-order direction cannot start a line")
			key.physical_keycode=KEY_UP
			ward.input(game,key)
			for dir in [KEY_RIGHT,KEY_DOWN,KEY_LEFT,KEY_UP]:
				key.physical_keycode=dir
				key.pressed=true
				ward.input(game,key)
				ward.advance(game,.25)
				check(ward.fraction>0 and ward.fraction<1,"the brush and Tenbi advance partway on a held key")
				key.pressed=false
				ward.input(game,key)
				var stopped_at: Vector2=game.player_pos
				ward.advance(game,.18)
				check(game.player_pos==stopped_at,"releasing the key pauses the stroke")
				key.pressed=true
				ward.input(game,key)
				ward.advance(game,.85)
			check("ward_loop" in notes and "together" not in notes,"the closed outline precedes the shared practice effect")
			ward.read(game)
			game._remember_chapter()
			check(ward.phase==ward.Phase.BLOOM and game._chapter_progress().debut_scene("fuwa")==0,"the joint practice is visible before the record")
			ward.advance(game,ward.BLOOM_TIME)
			ward.read(game)
			return
		var stops: Array=[[],["empty","gate","overlook","pass"],["clearing","wait"],["spell"]][scene]
		for stop in stops: game._interact(game._find_object("tenbi_"+stop))
		if scene==2:
			game._process(game.FuwaSnow.REUNION_TIME)
			game._inspect_chapter(scene)
		if scene==3:
			game._remember_chapter()
			check(not game._chapter_progress().page_complete,"the spell alone cannot seal Fuwa's book")
			game._process(2.0)
			game.fuwa_snow.turn(game)
			game._process(3.0)
			game.fuwa_snow.turn(game)
			game._interact(game._find_object("tenbi_shelves"))
		return
	if game.MEMBERS[game.story_member].id=="yato" and not game.YatoForest.ready(scene,game._chapter_progress().yato_notes):
		game._inspect_chapter(scene)
		check(not game.chapter_question,"Mato explores before the official record can open")
		if scene==1:
			var room=game.yato_forest.storehouse
			var notes: Array=game._chapter_progress().yato_notes
			game.player_pos=room.FAMILY_SIDE
			game._process(.1)
			check(room.phase==room.Phase.FIELD and game._find_object("mato_truth").is_empty(),"the family waits while the stores are unexamined")
			game._interact(game._find_object("mato_basket"))
			check(game.pending_object=="mato_basket" and not game.chapter_question,"the basket must be examined beside it")
			game.player_pos=room.BASKET_SIDE
			game._interact(game._find_object("mato_basket"))
			room.advance(game,room.UNFOLD_TIME)
			check("basket" in notes and "truth" not in notes and not game.chapter_question,"the empty basket is bookmarked; Mato can walk again")
			game.player_pos=room.SPEAKER+Vector2(-8,9)
			game._process(.02)
			check(room.phase==room.Phase.FAMILY and game.book_activity==null,"walking up to the family starts the on-map conversation")
			room.advance(game,room.CONFESSION)
			check(room.feet()==room.YATO and "truth" not in notes,"the rabbits speak before Yato recoils")
			room.read(game)
			check(room.phase==room.Phase.FAMILY,"early input cannot skip the revelation")
			room.advance(game,room.SHOCK+.5-room.elapsed)
			check(room.feet().x>room.YATO.x and "truth" not in notes,"Yato steps back before the memory is completed")
			room.advance(game,room.END)
			game._remember_chapter()
			check(game._chapter_progress().debut_scene("yato")==1,"watching opens the record before the next chapter")
			room.read(game)
			return
		var stops: Array=[["trail","nest","family"],[],["bend","village","gaze"],["beside"]][scene]
		for stop in stops: game._interact(game._find_object("mato_"+stop))
		if scene==3:
			game.player_pos=game.YatoForest.SITES.beside[0]
			game.moving=false
			game.yato_forest.watch(game,game.YatoForest.LIGHT_TIME)
		if scene in [2,3]: game._inspect_chapter(scene)
		return
	if game.MEMBERS[game.story_member].id=="kubby" and not game.KubbyEmbers.ready(scene,game._chapter_progress().kubby_notes):
		game._inspect_chapter(scene)
		check(not game.chapter_question,"Hamnim must explore each memory first")
		var stops: Array=[["snow","village"],[],["ice","glow"],["night","journey"]][scene]
		for stop in stops:
			if stop=="glow":
				game._interact(game._find_object("wisp_glow"))
				check(not game.chapter_question,"the far bank alone cannot transform the hamster")
				for i in range(1,51):
					game.kubby_embers.walk(game,game.KubbyEmbers.trail_point((i-1)/50.0),game.KubbyEmbers.trail_point(i/50.0))
			game._interact(game._find_object("wisp_"+stop))
		if scene==1:
			var v=game.kubby_embers.village
			game._interact(game._find_object("wisp_watch"))
			check(not v.watching and game.pending_object=="wisp_watch","the village memory cannot be opened remotely")
			# Approaching Kubby on foot triggers the encounter without an interact button.
			game.route.clear()
			game.pending_object=""
			game.player_pos=v.KUBBY+Vector2(-40,3)
			game._process(.01)
			check(v.watching and game.chapter_question,"Hamnim can arrive from the other side")
			game._process(v.REVEAL+.12)
			var notes: Array=game._chapter_progress().kubby_notes
			check("found" in notes and "home" not in notes and v.kubby_feet()==v.KUBBY,"the hamster appears before Kubby recoils")
			check(game.player_pos.distance_to(v.hamster_feet())>32,"Hamnim and the hamster have separate silhouettes")
			v.read(game)
			check(v.watching,"reading cannot skip the recoil")
			game._process(v.END)
			game._remember_chapter()
			check(game._chapter_progress().debut_scene("kubby")==1,"watching the reaction cannot skip the official record")
			v.read(game)
		return
	if game.MEMBERS[game.story_member].id=="danming" and not game.DanmingWorkshop.ready(scene,game._chapter_progress().danming_notes):
		game._inspect_chapter(scene)
		check(not game.chapter_question,"Beori explores before reading the official memory")
		var stops: Array=[["voice","reply","notice"],["bench"],["album"],["empty","threshold"]][scene]
		if scene==2: game.player_pos=game.DanmingWorkshop.MemoryLens.STATION
		for stop in stops: game._interact(game._find_object("bee_"+stop))
		if scene==2:
			var workshop=game.danming_workshop
			var notes: Array=game._chapter_progress().danming_notes
			var lens=workshop.lens
			lens.reach(lens.POINTS[0])
			workshop.advance(game,1)
			var observe:=InputEventKey.new()
			observe.physical_keycode=KEY_E
			observe.pressed=true
			lens.input(game,observe)
			workshop.advance(game,.5)
			check("hand_pause" not in notes,"quick checks cannot commit an observation")
			workshop.advance(game,.6)
			workshop.advance(game,1)
			workshop.close(game,true)
			check("hand_pause" in notes and "arrow_stack" not in notes and workshop.view==2,"one observation alone cannot open the record")
			lens.reach(lens.POINTS[1])
			workshop.advance(game,1)
			workshop.advance(game,1)
			workshop.close(game,true)
		if scene in [1,3]:
			game._remember_chapter()
			check(game.danming_workshop.view==scene and not game._chapter_progress().page_complete,"inspection cannot skip to the next chapter")
			game.danming_workshop.set_fraction(game,1.0)
			game.danming_workshop.close(game,true)
		return
	if game.MEMBERS[game.story_member].id=="yune" and not game.YuneDream.ready(scene,game._chapter_progress().yune_notes):
		game._inspect_chapter(scene)
		check(not game.chapter_question,"Yune's memory starts with a field interaction")
		match scene:
			0:
				game._interact(game._find_object("dream_loom"))
				game.yune_dream.observe(game,"feather")
				check("feather" in game._chapter_progress().yune_notes and "web" not in game._chapter_progress().yune_notes,"either dreamcatcher detail can be examined first")
				game.yune_dream.observe(game,"web")
				game.yune_dream.observe(game,"feather")
				game.yune_dream.close(game,true)
			1:
				game._interact(game._find_object("dream_gold"))
				check(not game.chapter_question,"the good dream remains on the field")
				game._interact(game._find_object("dream_shadow"))
				game.yune_dream.control(game,"dream_hold")
				game.yune_dream.advance(game,game.YuneDream.FEED_TIME)
				game.yune_dream.close(game,true)
			2:
				var n=game.yune_dream.nights
				var site: Dictionary=game._find_object("dream_nights")
				game._interact(site)
				check(game.pending_object==site.id and game.yune_dream.view<0,"Mongchi approaches the hanging ring before time passes")
				game.player_pos=n.STATION
				game._interact(site)
				n.advance(game,n.DURATION*.55)
				check("bed" in game._chapter_progress().yune_notes and not game.YuneDream.ready(2,game._chapter_progress().yune_notes),"the first nights bookmark only the midpoint")
				n.close(game,true)
				game._remember_chapter()
				check(game.yune_dream.view==2,"the watch must finish before reading the official memory")
				n.advance(game,n.DURATION*.5)
				n.close(game,true)
			3:
				game._interact(game._find_object("dream_call"))
				game.clock+=2
				game._interact(game._find_object("dream_door"))
		return
	if game.MEMBERS[game.story_member].id=="dori":
		var notes: Array=game._chapter_progress().dori_notes
		if scene<3 and not game.DoriCase.ready(scene,notes):
			game._inspect_chapter(scene)
			check(not game.chapter_question,"Doldori must investigate before opening the official memory")
			for clue in game.DoriCase.REQUIRED[scene]:
				game._interact(game._find_object("clue_"+("paving" if clue=="stone_compare" else clue)))
			return
		if scene==3 and not game.DoriCase.ready(3,notes):
			game._inspect_chapter(scene)
			game._remember_chapter()
			game.DoriCase.choose_card(game,1)
			check(game._dori_notebook_open() and not game._chapter_progress().page_complete and not "card3" in notes,"an out-of-order card cannot seal the book")
			for pick in [2,0,1]: game.DoriCase.choose_card(game,pick)
			return
	game._inspect_chapter(scene)

func confirm_record(game) -> void:
	var id: String=game.MEMBERS[game.story_member].id
	var scene: int=game._chapter_progress().debut_scene(id)
	if game.book_discovery.active(game):
		game.book_discovery.begin_result(game)
		if game.book_discovery.result_scene<0: return
		game.book_discovery.request_next(game)
		game._process(game.book_discovery.FADE+.1)
		check(game.mode=="rescue" if scene==3 else game._chapter_progress().debut_scene(id)==scene+1,"observed memory advances once without a confirm button")
		return
	game._remember_chapter()
	if not game._chapter_progress().route_pending(id): return
	check(game._chapter_progress().debut_scene(id)==scene and not game.chapter_question,"reading opens the path without teleporting to the next scene")
	var target: Dictionary=game._find_object("story_path")
	check(not target.is_empty(),"a readable memory has a world-space continuation")
	if target.is_empty(): return
	game._go_to(target)
	for tick in range(1600):
		if game.pending_object=="": break
		game._process(1.0/60.0)
	check(game._chapter_progress().debut_scene(id)==scene+1 and not game._chapter_progress().route_pending(id),"walking the revealed route advances exactly one scene")

func check_activities() -> void:
	for legacy in [["shelf","basket"],["bowl2"],["shelf"]]:
		var stores=State.YatoForest.restored_notes(legacy)
		check(stores==["basket"] and State.YatoForest.restored_notes(stores)==stores,"old partial stores resume at the family")
	check(State.YatoForest.restored_notes(["bowl1","truth","village"])==["basket","truth","village"],"old completed revelations and later travel are preserved")
	check(State.DoriCase.valid_notes(["print1","print2"])==["print1","print2"],"partial old trail survives as an unfinished rubbing")
	check(State.FuwaSnow.restored_notes(["ward"])==["ward"],"an old shrine observation is credited without closing the ring")
	check(State.FuwaSnow.WardPractice.next_corner(State.FuwaSnow.restored_notes(["brush_top","seal"]))==2,"the illustrated ward bookmark resumes at its next corner")
	check(State.FuwaSnow.ready(0,State.FuwaSnow.restored_notes(["together"])),"a finished legacy shrine stays finished")
	check(State.KubbyEmbers.restored_notes(["grain","found"])==["grain","found"],"the old hamster discovery survives")
	check(State.YuneDream.restored_notes(["window"])==["window"],"a single old dream remains a partial bookmark")
	var old_notes=State.DanmingWorkshop.restored_notes(["morning","bundle"])
	check("album_open" in old_notes and "arrow_stack" in old_notes and not State.DanmingWorkshop.ready(2,old_notes),"an old bookmark at the arrow pile keeps its observation")
	check(State.DanmingWorkshop.ready(2,State.DanmingWorkshop.restored_notes(["morning","bundle","again"])),"a completed old workshop remains complete")
	var s = State.new()
	var yard = State.new()
	check(not yard.begin_yard_session("dori","gym"),"only rescued members practice in the yard")
	yard.residents = ["dori","yune"]
	yard.scene = "library"
	check(yard.begin_yard_session("dori","yoga") and not yard.begin_yard_session("yune","rope"),"a second assignment cannot replace an active session")
	yard.advance_yard_session(2.5)
	var resumed = State.new()
	check(resumed.apply_data(JSON.parse_string(JSON.stringify(yard.to_data()))) and resumed.yard_session.elapsed == 2.5,"saved field sessions resume at the same animation time")
	check(resumed.advance_yard_session(3.5) == 1 and resumed.advance_yard_session(9) == 0 and not resumed.can_do_activity("dori","workout"),"a resumed field session pays once")
	yard.sleep()
	check(yard.yard_session.is_empty() and yard.activities.is_empty(),"an unfinished session cannot cross days")
	var stale: Dictionary = yard.to_data()
	stale.yard_session = {"member":"unknown","routine":"rope","elapsed":2}
	stale.scene = "garden"
	check(resumed.apply_data(stale) and resumed.yard_session.is_empty(),"invalid field assignment does not block an otherwise valid save")
	check(not s.can_do_activity("dori","stream") and s.finish_activity("dori","workout") == 0,"no activities before return")
	s.residents = ["dori","yune"]
	check(s.can_do_activity("dori","stream") and not s.can_do_activity("dori","other"),"only supported activities are available")
	check(s.finish_activity("dori","stream",3) == 0 and s.activities.is_empty(),"incomplete broadcast cannot record a memory")
	check(s.finish_activity("dori","workout") == 1 and s.finish_activity("dori","workout") == 0,"workout counts once per day")
	s.sleep()
	var restored = State.new()
	check(restored.apply_data(JSON.parse_string(JSON.stringify(s.to_data()))) and restored.activity_record("dori").prepared,"warmup carries overnight and through save")
	check(restored.finish_activity("dori","stream",1) == 3 and not restored.activity_record("dori").prepared,"next broadcast consumes warmup")
	check(restored.finish_activity("dori","stream",0) == 0 and restored.activity_record("dori").reply == 1,"same day cannot replace the remembered reply")
	check(restored.finish_activity("yune","stream",0) == 2 and restored.activity_record("dori").memory == 4,"each member has a separate set of activities")
	var latest: Dictionary = restored.to_data()
	check(s.apply_data(JSON.parse_string(JSON.stringify(latest))) and s.activity_record("yune").reply == 0,"save remembers separate fan responses")
	var corrupted := latest.duplicate(true)
	corrupted.activities.dori.reply = 7
	check(not s.apply_data(corrupted) and s.to_data() == latest,"invalid reply cannot damage an existing session")
	latest.erase("activities")
	check(s.apply_data(latest) and s.activities.is_empty() and s.can_do_activity("yune","stream"),"older resident save opens fresh activities")

func check_comic_timing() -> void:
	var comics=preload("res://scripts/debut_comics.gd")
	for id in comics.SHEETS:
		var book: Dictionary=comics.PROFILES.data[id]
		var elapsed_ms:=0
		var atlas_bounds:=Rect2(Vector2.ZERO,comics.SHEETS[id].get_size())
		for cut in range(4):
			var cue: Dictionary=comics.PLAYBACK.data.books[id].cues[cut]
			var authored: Dictionary=book.cues[cut]
			check(cue.frames_ms.size()==comics.FRAMES and comics.FRAMES>comics.KEY_FRAMES,"in-between frames are scheduled: "+id)
			var authored_ms:=0
			var output_ms:=0
			var authored_reveal_ms:=0
			var output_reveal_ms:=0
			for f in range(authored.frames_ms.size()):
				authored_ms+=int(authored.frames_ms[f])
				if f<int(authored.reveal): authored_reveal_ms+=int(authored.frames_ms[f])
			for f in range(cue.frames_ms.size()):
				output_ms+=int(cue.frames_ms[f])
				if f<int(cue.reveal): output_reveal_ms+=int(cue.frames_ms[f])
			check(output_ms==authored_ms and output_reveal_ms==authored_reveal_ms,"smoother motion preserves story and reading timing: %s/%d"%[id,cut])
			check(int(cue.frames_ms.back())==int(authored.frames_ms.back()),"last reading hold is preserved: %s/%d"%[id,cut])
			check(comics.key_region(cut,comics.KEY_FRAMES-1)==comics.region(cut,comics.FRAMES-1),"story scrubbing still reaches the final illustrated event: %s/%d"%[id,cut])
			check(atlas_bounds.encloses(comics.region(cut,comics.FRAMES)),"unopened cel fits: "+id)
			var in_sync:=true
			for frame in range(cue.frames_ms.size()):
				in_sync=in_sync and comics.sample(id,elapsed_ms/1000.0)==Vector2i(cut,frame)
				in_sync=in_sync and comics.cut_sample(id,cut,(elapsed_ms-roundi(comics.cut_start(id,cut)*1000.0))/1000.0)==frame
				in_sync=in_sync and atlas_bounds.encloses(comics.region(cut,frame))
				in_sync=in_sync and (comics.caption(id,cut,frame).count("\n")==int(frame>=int(cue.reveal)))
				elapsed_ms+=int(cue.frames_ms[frame])
				in_sync=in_sync and comics.sample(id,(elapsed_ms-1)/1000.0)==Vector2i(cut,frame)
			check(in_sync,"both ends of every frame and the caption cue agree: %s/%d"%[id,cut])
		check(is_equal_approx(elapsed_ms/1000.0,comics.duration(id)),"duration: "+id)
		check(comics.sample(id,100.0)==Vector2i(3,comics.FRAMES-1),"last cut stays open: "+id)

func run() -> void:
	check_comic_timing()
	var forms = State.new()
	check(not forms.wear_fan_form("dori") and forms.fan_form == "", "cannot wear a form before returning together")
	for id in forms.friendship:
		forms.residents.append(id)
		check(forms.wear_fan_form(id) and forms.fan_form == id,"each arrival unlocks its own form: "+id)
	var loaded_forms = State.new()
	check(loaded_forms.apply_data(JSON.parse_string(JSON.stringify(forms.to_data()))) and loaded_forms.fan_form == forms.fan_form,"fan appearance survives save")
	var older: Dictionary = forms.to_data()
	older.erase("fan_form")
	check(loaded_forms.apply_data(older) and loaded_forms.fan_form == "" and loaded_forms.residents.size() == 6,"old saves start as the traveler with all earned forms")
	older.residents = ["yune"]
	older.fan_form = "dori"
	check(loaded_forms.apply_data(older) and loaded_forms.fan_form == "" and not loaded_forms.wear_fan_form("dori"),"stale form falls back to traveler")
	check(forms.wear_fan_form("") and forms.fan_form == "","can revert to the traveler")
	forms.friendship.dori = 10
	check(forms.finish_activity("dori","workout",-1,"unknown") == 0 and forms.can_do_activity("dori","workout"),"unrecognized routine cannot consume workout slot")
	check(forms.finish_activity("dori","workout",-1,"yoga") == 1 and forms.friendship.dori == 10,"workout respects friendship cap")
	check(loaded_forms.apply_data(forms.to_data()) and loaded_forms.activity_record("dori").last_workout == "yoga","save remembers the chosen routine")
	older = forms.to_data()
	older.activities.dori.erase("last_workout")
	check(loaded_forms.apply_data(older) and loaded_forms.activity_record("dori").last_workout == "rope" and not loaded_forms.can_do_activity("dori","workout"),"older workouts retain the rope note and cooldown")
	check_activities()
	var bond = State.new()
	bond.residents.append("yato")
	for score in range(11):
		bond.friendship.yato = score
		check(bond.bond_tier("yato") == [0,0,0,0,1,1,1,1,2,2,2][score],"relationship at %d points" % score)
	bond.friendship.yato = 3
	check(bond.talk("yato") and bond.bond_tier("yato") == 1,"first greeting reaches the first milestone")
	check(not bond.talk("yato") and bond.friendship.yato == 4,"repeat greeting keeps current relationship")
	bond.friendship.yato = 6
	check(bond.restore_book(0) == "" and bond.bond_tier("yato") == 2,"restoration reaches the second milestone")
	var continued = State.new()
	check(continued.apply_data(JSON.parse_string(JSON.stringify(bond.to_data()))) and continued.bond_tier("yato") == 2 and continued.bond_tier("dori") == 0,"load restores each relationship independently")
	var s = State.new()
	for id in Encounters.VOLUMES:
		var book: Dictionary = Encounters.VOLUMES[id].data
		check(book.working_title != book.title and Encounters.shelf_title(s,id) == book.working_title,"new shelf uses the provisional title for "+id)
	check(s.residents.is_empty() and not s.talk("yato") and s.restore_book(0) != "", "librarian starts alone with locked interactions")
	check(not s.record_chapter_step("yato",2) and not s.record_chapter_step("other",0),"cannot skip a case or invite an unknown character")
	check(not s.record_chapter_step("yato",0) and s.accept_mission("yato"),"a real assignment is required before collecting story clues")
	check(s.record_chapter_step("yato",0) and not s.record_chapter_step("yato",0),"finding a clue is idempotent")
	var partial = State.new()
	check(partial.apply_data(JSON.parse_string(JSON.stringify(s.to_data()))) and partial.chapter_steps.yato == 1 and partial.residents.is_empty(),"incomplete book survives save without unlocking")
	check(partial.active_mission == "yato" and partial.accept_mission("dori") and partial.chapter_steps.yato == 1,"changing assignments keeps other bookmarks")
	var legacy_partial: Dictionary = s.to_data()
	legacy_partial.version = 3
	check(partial.apply_data(legacy_partial) and partial.active_mission == "" and partial.chapter_steps.yato == 1,"pre-quest save keeps clues for a new commission")
	check(not Encounters.titled(partial,"yato"),"an old unfinished book still uses its provisional title")
	check(not s.record_chapter_step("yato",1) and s.mark_first_action("yato") and not s.mark_first_action("yato"),"two fan actions require distinct scenes")
	check(partial.apply_data(JSON.parse_string(JSON.stringify(s.to_data()))) and partial.debut_scene("yato") == 2,"bookmark retains the first fan action")
	check(partial.accept_mission("dori") and partial.accept_mission("yato") and partial.debut_scene("yato") == 2,"individual scene bookmarks survive mission changes")
	check(s.record_chapter_step("yato",1) and not s.record_chapter_step("yato",2) and s.seal_page("yato"),"solving restores the last page before rescue")
	check(partial.apply_data(JSON.parse_string(JSON.stringify(s.to_data()))) and partial.page_complete and not partial.accept_mission("dori") and partial.residents.is_empty(),"can resume a sealed story before returning together")
	check(Encounters.shelf_title(partial,"yato") == Encounters.VOLUMES.yato.data.title and not Encounters.titled(partial,"dori"),"sealing reveals only that member's title, including after a reload")
	check(s.record_chapter_step("yato",2) and not s.record_chapter_step("yato",2) and s.residents == ["yato"] and s.active_mission == "" and not s.page_complete,"return completes only this mission once")
	check(partial.apply_data(s.to_data()) and Encounters.titled(partial,"yato"),"recruited chapter retains its title across saves")
	check(s.day == 1 and s.energy == 100,"fresh game")
	check(s.talk("yato"),"first daily greeting")
	check(not s.talk("yato") and s.friendship.yato == 1,"repeat greeting cannot farm friendship")
	s.energy = 11
	var before: Dictionary = s.to_data()
	check(s.restore_book(0) != "" and s.to_data()==before,"insufficient energy rejects repair atomically")
	s.sleep()
	check(s.day == 2 and s.energy == 100 and s.minutes == 540,"rest recovers time and energy")
	check(s.talked_today.is_empty(),"daily greetings reset")
	check(s.talk("yato") and s.friendship.yato == 2,"friendship persists between days")
	check(s.restore_book(-1) != "" and s.restore_book(6) != "","invalid selection safe")
	var play = State.new()
	play.residents = play.friendship.keys()
	for i in range(State.BOOKS.size()):
		check(play.restore_book(i)=="","a resident's lending copy can be repaired at the table")
	check(play.restored.size()==6 and play.energy==28 and play.minutes==780,"six repairs cost only 12 energy and 40 minutes each")
	before = play.to_data()
	check(play.restore_book(0) != "" and play.to_data() == before,"completed books cannot charge twice")
	play.player = Vector2(195,633)
	play.scene = "garden"
	var path := "res://artifacts/test-save.json"
	check(play.save_to(path) == OK,"save writes successfully")
	var loaded = State.new()
	check(loaded.load_from(path),"save loads successfully")
	check(loaded.to_data() == play.to_data(),"all game state round-trips")
	check(play.save_to(path) == OK,"second save safely replaces file")
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string("{broken-json")
	f.close()
	check(loaded.load_from(path),"backup recovers a damaged save")
	check(not loaded.apply_data({"version":1}),"malformed save rejected")
	var malformed: Dictionary = play.to_data()
	malformed.friendship.yato = "bad"
	check(not loaded.apply_data(malformed),"invalid friendship rejected")
	# Existing v0.1 saves have no economy fields. Load them as they appear on disk.
	var legacy: Dictionary = play.to_data()
	legacy.version = 1
	for field in ["bookmarks","claimed_requests","active_loan","loan_today","total_loans"]:
		legacy.erase(field)
	var economy = State.new()
	check(economy.apply_data(JSON.parse_string(JSON.stringify(legacy))),"v1 save migrates after actual JSON decoding")
	check(economy.restored == play.restored and economy.friendship == play.friendship,"migration preserves books and friends")
	check(economy.bookmarks == 0 and economy.total_loans == 0 and economy.active_loan.is_empty(),"legacy save starts with an unused lending desk")
	check(economy.claim_request(0) == "" and economy.bookmarks == 40,"first restored book award available on migrated save")
	check(economy.claim_request(0) != "" and economy.bookmarks == 40,"one-off reward cannot be claimed twice")
	check(economy.claim_request(2) != "","incomplete daily request rejected")
	for person in ["yato","dori","fuwa"]: economy.talk(person)
	check(economy.claim_request(2) == "" and economy.claim_request(2) != "","daily greeting award paid once")
	economy.energy = 80
	check(economy.buy_tea() == "" and economy.energy == 100 and economy.bookmarks == 40,"tea caps recovery and charges the right amount")
	check(economy.buy_tea() != "" and economy.bookmarks == 40,"full energy doesn't spend currency")
	var desired: int = economy.requested_book_index()
	check(economy.lend_book((desired+1)%6) != "","reader accepts the requested title")
	check(economy.lend_book(desired) == "" and economy.energy == 98,"lending consumes energy once")
	check(economy.lend_book(desired) != "" and economy.energy == 98,"repeated submission is safe")
	var old_v4: Dictionary = economy.to_data()
	old_v4.version = 4
	old_v4.inventory = {"paper":32,"ink":12,"star":5}
	old_v4.collected_today = ["lib_paper","garden_s1"]
	old_v4.claimed_requests.append("daily_gather_%d"%economy.day)
	for id in old_v4.residents: old_v4.chapter_steps[id] = 3
	var migrated:=State.new()
	check(migrated.apply_data(JSON.parse_string(JSON.stringify(old_v4))) and migrated.rebuild_stage()==6,"v4 migration keeps the reopened library")
	var upgraded:=migrated.to_data()
	check(upgraded.version==7 and not upgraded.has("inventory") and not upgraded.has("collected_today") and migrated.claimed_requests==economy.claimed_requests,"retired materials and gather claim disappear on save")
	check(migrated.active_loan.book_id==economy.active_loan.book_id and migrated.active_loan.due_day==economy.active_loan.due_day and migrated.bookmarks==economy.bookmarks and migrated.residents==economy.residents,"v4 migration keeps the loan, balance and residents")
	migrated.sleep()
	check(migrated.active_loan.is_empty() and migrated.total_loans==economy.total_loans+1 and migrated.bookmarks==economy.bookmarks+20,"a migrated loan returns and pays once")
	old_v4.residents.erase("fuwa")
	old_v4.restored.erase("fuwa")
	old_v4.active_mission="fuwa"
	old_v4.chapter_steps.fuwa=2
	old_v4.page_complete=true
	old_v4.erase("fuwa_notes")
	check(migrated.apply_data(old_v4) and migrated.page_complete and migrated.active_mission=="fuwa" and migrated.rebuild_stage()==5,"v4 sealed books resume before the last return")
	check("awoke" in migrated.fuwa_notes and State.FuwaSnow.ready(3,migrated.fuwa_notes),"sealed legacy Fuwa books reopen in the waking library")
	check(economy.save_to(path) == OK and loaded.load_from(path),"open loan saves and loads")
	check(loaded.claim_request(0) != "" and loaded.claim_request(2) != "" and loaded.lend_book(desired) != "","reload preserves outstanding loan and paid rewards")
	loaded.sleep()
	check(loaded.bookmarks == 60 and loaded.total_loans == 1 and loaded.active_loan.is_empty(),"overnight return paid once")
	check(loaded.claim_request(0) != "" and not loaded.request_claim_key(2) in loaded.claimed_requests,"daily claims reset, milestone stays claimed")
	loaded.sleep()
	check(loaded.bookmarks == 60 and loaded.total_loans == 1,"a second morning cannot pay the same return")
	# Real map navigation: every object can be reached from every other object.
	var game := TestGame.new()
	root.add_child(game)
	await process_frame
	var old_save: Dictionary = game.state.to_data()
	old_save.erase("read_bonds")
	old_save.version = 2
	old_save.erase("residents")
	old_save.erase("chapter_steps")
	old_save.friendship.dori = 10
	check(game.state.apply_data(old_save),"legacy friendship without conversation history loads")
	game._setup_map()
	check(game.state.residents == ["dori"] and game._find_object("yato").is_empty(),"only a previously met member returns in old saves")
	var dori: Dictionary = game._find_object("dori")
	game._interact(dori)
	var first_line: String = game.dialogue_lines[0]
	game._advance_dialogue()
	var resumed = State.new()
	check(resumed.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))) and resumed.read_bonds.is_empty(),"unfinished scene remains available on load")
	game.state = resumed
	game._interact(dori)
	check(game.dialogue_lines[0] == first_line,"interrupted scene restarts")
	game._advance_dialogue()
	game._advance_dialogue()
	var reread = State.new()
	check(reread.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))) and reread.read_bonds.get("dori") == 1,"completed scene survives a JSON save")
	game.state = reread
	game._interact(dori)
	check(game.dialogue_lines[0] == game.Stories.ENTRIES.dori.bond[1][0],"legacy ten-point save reaches both scenes in order")
	game.state = State.new()
	game.state.residents = game.state.friendship.keys()
	for location in ["library","garden"]:
		game.state.scene = location
		game._setup_map()
		for source in game.objects:
			for destination in game.objects:
				var start: Vector2i = game._grid_at(source.pos)
				var finish: Vector2i = game._grid_at(destination.pos)
				var route: PackedVector2Array = game.navigation.get_point_path(start,finish)
				check(not route.is_empty(),"%s: %s reaches %s" % [location,source.id,destination.id])
				check(game.navigation.get_point_position(finish).distance_to(destination.pos) < 78,"interaction radius reachable")
		for destination in game.objects:
			check(destination.type!="pickup","no material pickup in "+location)
	# Menu and completion logic, including dialogue and keyboard handling.
	game.state.scene = "library"
	game._setup_map()
	game.state.energy = 100
	for i in range(6):
		game.selected_book = i
		game._restore()
		check(game.mode == "dialog","restoration feedback")
		while game.mode == "dialog": game._advance_dialogue()
	check(game.mode == "play","restoration remains available independently of the arrival ending")
	game._action("close")
	check(game.mode == "play","can keep playing after completion")
	game._interact(game._find_object("yato"))
	check(game.dialogue_lines[0] == game.MEMBERS[0].after,"restored book changes dialogue")
	# Each history is available at first contact. Every choice survives reload and unlocks its own final page.
	for index in range(game.MEMBERS.size()):
		var id: String = game.MEMBERS[index].id
		var entry: Dictionary = game.Stories.ENTRIES[id]
		for branch in range(2):
			game.state = State.new()
			game.state.accept_mission(id)
			game._open_story(index,"journal")
			check(game.mode == "story" and game.story_member == index and game.story_page == 0,"shelf opens correct debut record")
			game._turn_story()
			game._inspect_chapter(2)
			check(not game.chapter_question and game.state.residents.is_empty(),"cannot finish before collecting the clues")
			inspect_memory(game,0)
			check(game.chapter_question and game.state.debut_scene(id)==0,"opening a record waits for the reader")
			game._action("chapter_look")
			check(game.state.debut_scene(id)==0,"looking around does not change the past or skip the discovery")
			game._inspect_chapter(0)
			confirm_record(game)
			inspect_memory(game,1)
			var record: Dictionary = game.Chapters.BOOKS[id]
			check(record.records.size()==4 and not record.has("keys") and not record.has("key"),"official events have no invented answer key")
			confirm_record(game)
			check(not game.chapter_question and game._find_object("leaf_1").is_empty() and game.state.debut_scene(id) == 2,"remembering advances the walkable scene")
			confirm_record(game)
			check(game.state.debut_scene(id)==2,"duplicate confirm cannot skip an unread memory")
			inspect_memory(game,2)
			confirm_record(game)
			check(not game.chapter_question and game.state.debut_scene(id)==3,"completed fieldwork opens the last scene")
			inspect_memory(game,3)
			check(game.chapter_question and game.state.residents.is_empty(),"last record opens before sealing and inviting anyone")
			confirm_record(game)
			check(game.mode == "rescue" and game.state.residents.is_empty() and game.state.rebuild_stage() == 0,"writing the last page alone does not rebuild the room")
			game._return_with_stella()
			check(game.state.residents == [id] and game.state.rebuild_stage() == 1 and not game._find_object("gift_"+id).is_empty(),"first return adds the matching landmark regardless of order")
			game._open_story(index,"journal")
			var before_replay: Dictionary = game.state.to_data()
			game._replay_debut()
			for scene in range(4):
				check(not game.objects.is_empty() and game.objects[0].index==scene,"replay exposes the current scene only")
				inspect_memory(game,scene)
				confirm_record(game)
			game._return_with_stella()
			check(game.mode == "story" and before_replay == game.state.to_data(),"finishing a replay preserves the campaign for "+id)
			game._turn_story()
			game._choose_story(branch)
			check(game.story_page == 2 and game.state.story_choices[id] == branch,"decision recorded for " + id)
			check(not game.state.remember_choice(id,1-branch),"rereading cannot overwrite a choice")
			game._turn_story()
			check(game.mode == "journal","unrestored story returns to its shelf")
			var backup = State.new()
			check(backup.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))) and backup.story_choices[id] == branch,"decision survives JSON round trip")
			game.state = backup
			check(game.state.restore_book(index) == "","member's own book can be restored")
			check(game.state.rebuild_stage() == 1,"repairing a loan copy cannot advance the library a second time")
			game._open_story(index,"journal")
			for page in range(3): game._turn_story()
			check(game.story_page == 3 and entry.ends[branch] != entry.ends[1-branch],"two distinct epilogues for " + id)
			game._turn_story()
			check(game.mode == "journal","reread returns to the journal")
			game._interact(game._find_object(id))
			check(game.dialogue_lines[0] == entry.recalls[branch],"in-person dialogue remembers the player's actual decision")
	var previous: Dictionary = game.state.to_data()
	previous.erase("story_choices")
	check(game.state.apply_data(previous) and game.state.story_choices.is_empty(),"v0.2 save without stories loads")
	game.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

