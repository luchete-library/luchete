extends "res://tests/library_day_flow.gd"
const Preferences=preload("res://scripts/ink_reading_preferences.gd")
const Care=preload("res://scripts/library_day_state.gd")
const Art=preload("res://scripts/library_care_art.gd")

func run() -> void:
	for temperament in range(4):
		for kind in ["read","borrow"]:
			for matching in [true,false]:
				fresh()
				var v: Dictionary=g.state.ink_visits._guest(0,kind,"dori")
				v.temperament=temperament;v.phase="browse";v.pos=Vector2(376,328);v.admitted=true;v.request=true
				g.state.ink_visits.guests.append(v);g.library_day_flow.sync_targets(g)
				var hint: String=Preferences.profile(v).hint
				check(not hint.is_empty() and not hint.contains(Preferences.profile(v).id),"in-world clue without hidden trait label")
				g.player_pos=v.pos+Vector2(0,40);g._interact(g._find_object("day_ink_%d"%v.uid))
				var pick: int=Preferences.profile(v).book if matching else 1-int(Preferences.profile(v).book)
				g._action("day_pick_%d"%pick)
				check(v.helped and v.feature==pick and not v.request,"one recommendation accepted")
				check(g.growth.gold==0 and g.growth.memory_light==0,"no reward at choice time")
				g.library_day_flow.action(g,"day_pick_%d"%pick)
				check(g.state.library_day.recommended==1,"repeated click cannot recommend twice")
				var saved: Dictionary=JSON.parse_string(JSON.stringify(g.state.to_data()))
				var loaded:=Adapter.new()
				check(loaded.apply_data(saved),"save after recommendation before use")
				check(loaded.ink_visits.guests[0].temperament==temperament,"temperament survives load")
				step(80)
				check(v.completed,"recommended visitor actually completes use")
				var expected_gold: int=(15 if kind=="borrow" else 0)+(Preferences.BONUS_GOLD if matching else 0)
				var expected_light: int=(3 if kind=="borrow" else 2)+(Preferences.BONUS_LIGHT if matching else 0)
				check(g.growth.gold==expected_gold and g.growth.memory_light==expected_light,"only matching completed use earns modest bonus")
				g.state.ink_visits._finish_reading(g,v) if kind=="read" else g.state.ink_visits._lend(g,v)
				check(g.growth.gold==expected_gold and g.growth.memory_light==expected_light,"completion cannot double-pay")
				check(Adapter.new().apply_data(JSON.parse_string(JSON.stringify(g.state.to_data()))),"completed reward survives JSON roundtrip")
	fresh()
	var d=g.state.library_day
	var empty: Dictionary=d.data()
	step(100)
	check(d.grime==empty.grime,"empty clean library does not grow mystery stains")
	d.returned.assign([0,0,1,1]);d.dirty.assign([0])
	step(91)
	check(d.grime[0]==1,"neglected work creates first stain with time")
	check(not d.ete_warned,"no instant reprimand")
	step(30)
	check(d.ete_warned and g.library_day_flow.ete_elapsed>=0,"Ete reacts once after prolonged book pile")
	step(6)
	check(g.library_day_flow.ete_elapsed<0,"warning naturally recovers")
	step(10)
	check(g.library_day_flow.ete_elapsed<0,"same pile does not spam warning")
	var frozen: String=JSON.stringify(d.data())
	g.mode="day_choice";step(120)
	check(JSON.stringify(d.data())==frozen,"choice pauses dirt and warning timers")
	g.mode="play";g.player_pos=Layout.HOME_DOOR;step(91)
	check(d.grime[1]==1,"library care continues while visiting personal rooms")
	var previous: Dictionary=d.data()
	d.ensure(g.state.day+1)
	check(d.returned==previous.returned and d.dirty==previous.dirty and d.grime==previous.grime,"persistent overnight dirt and books")
	check(d.ete_warned,"warning does not reset just because day changed")
	# New and old activity snapshots are decoded without touching live data.
	var current:=Care.new()
	check(current.restore(d.data(),g.state.residents,g.state.day+1),"current care snapshot loads")
	var legacy: Dictionary=d.data();legacy.version=1
	for key in ["grime","soil_seconds","neglect_seconds","ete_warned"]: legacy.erase(key)
	var migrated:=Care.new()
	check(migrated.restore(JSON.parse_string(JSON.stringify(legacy)),g.state.residents,g.state.day+1),"v1 activities migrate")
	check(migrated.grime==[0,0,0,0,0,0,0,0] and migrated.returned==d.returned,"no retroactive grime or book loss")
	for mutation in [{"grime":[4,0,0,0,0,0,0,0]},{"grime":[0]},{"soil_seconds":90.0},{"neglect_seconds":-1},{"ete_warned":"true"}]:
		var bad: Dictionary=d.data();bad.merge(mutation,true)
		var original: String=JSON.stringify(current.data())
		check(not current.restore(bad,g.state.residents,g.state.day+1) and JSON.stringify(current.data())==original,"corrupt care snapshot rejected atomically")
	for i in range(30000): d.advance_care(.1)
	check(d.grime==[3,3,3,3,3,3,3,3],"all stains capped at three stages")
	check(d.unfiled()<=6 and d.dirty.size()<=2,"persistent duties do not multiply")
	# Real click/E route and action for every cleanup site.
	fresh();d=g.state.library_day
	d.grime.assign([3,3,3,3,3,3,3,3]);g.library_day_flow.sync_targets(g)
	for i in range(8):
		var spot: Dictionary=g._find_object("day_floor_%d"%i)
		check(not spot.is_empty() and not Layout.path(g.navigation,g.player_pos,spot.pos).is_empty(),"floor stain reachable %d"%i)
		g._go_to(spot)
		for frame in range(1000):
			g._process(.1)
			if g.mode=="day_action": break
		check(g.mode=="day_action" and g.library_day_flow.action_kind=="mop","walk to actual floor action %d"%i)
		step(3.2)
		check(d.grime[i]==0 and g._find_object("day_floor_%d"%i).is_empty(),"one wipe removes whole patch %d"%i)
	check(g.growth.gold==0 and g.growth.memory_light==0,"cleanup is not a currency faucet")
	d.returned.assign([0,0,1,1]);d.neglect_seconds=120;d.ete_warned=true
	g.library_day_flow.sync_targets(g)
	for batch in range(2):
		g._go_to(g._find_object("day_cart"));step(60)
		g._go_to(g._find_object("day_shelf"));step(60)
	check(d.unfiled()==0 and not d.ete_warned and d.neglect_seconds==0,"filing all books resolves Ete's warning")
	var environment: Array=[{"index":-8,"pos":Vector2(300,600)},{"index":-3,"pos":Vector2(300,590)},{"index":-4,"pos":Vector2(300,590)}]
	for character in [{"index":0,"pos":Vector2(300,280)},{"index":-1,"pos":Vector2(300,280)},{"index":-2,"pos":Vector2(300,280)},{"index":-7,"pos":Vector2(300,280)}]:
		for prop in environment: check(g._actor_less(prop,character) and not g._actor_less(character,prop),"character is above furniture and foreground")
	g.mode="chapter"
	check(g._actor_less({"index":0,"pos":Vector2(300,280)},environment[0]),"authored story depth is preserved")
	g.mode="play"
	check(Art.stain_sheet().get_size()==Vector2i(384,192),"three variants by three detailed dirt levels asset")
	# Resume a matched loan from the actual decoded state, then return it.
	fresh()
	var visitor: Dictionary=g.state.ink_visits._guest(0,"borrow","yune")
	visitor.temperament=2;visitor.feature=1;visitor.helped=true;visitor.request=false;visitor.admitted=true;visitor.phase="to_desk";visitor.pos=Vector2(376,328)
	g.state.ink_visits.guests.append(visitor)
	g.state.library_day.grime.assign([1,2,3,0,0,0,0,0]);g.state.library_day.returned.assign([0,1]);g.state.library_day.soil_seconds=37
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(g.state.to_data()))
	check(g.state.apply_data(snapshot),"replace live state from mid-loan JSON save")
	g.growth=g.state.growth;g._setup_map()
	var resumed: Dictionary=g.state.ink_visits.guests[0]
	check(g.state.library_day.grime==[1,2,3,0,0,0,0,0] and g.state.library_day.soil_seconds==37,"restore persistent grime and partial timer")
	step(80)
	check(resumed.completed and g.growth.gold==20 and g.growth.memory_light==5,"resumed matched loan settles full reward once")
	var loan: Dictionary=g.state.ink_visits.loans[0]
	check(loan.temperament==2 and loan.feature==1,"loan preserves reader temperament and book")
	var returning: Dictionary=g.state.ink_visits._guest(0,"return","yune",loan.id)
	returning.temperament=loan.temperament;returning.feature=loan.feature
	g.state.ink_visits._return_book(g,returning)
	check(g.growth.gold==20 and g.growth.memory_light==5,"return visit pays no repeat recommendation bonus")
	var corrupted: Dictionary=g.state.to_data()
	corrupted.growth_visitors.loans[0].temperament=4
	check(not Adapter.new().apply_data(corrupted),"invalid hidden temperament rejected")
	var old_reader: Dictionary={"uid":90,"helped":true,"feature":1,"kind":"read","completed":true}
	check(g.state.ink_visits._recommendation_bonus(g,old_reader)=="","old saved recommendations receive no retroactive bonus")
	# Face-overlapping hints relocate, and a character wins over a floor click.
	var ete: Dictionary=g._find_object("ete")
	var body: Rect2=g.Field.stella_hit_rect("aethe",ete.pos)
	var hint: Rect2=g.world.clear_hint_rect(g,Rect2(ete.pos+Vector2(-80,-95),Vector2(200,30)))
	check(not hint.has_area() or not hint.intersects(body),"nearby prompt does not cover Ete's body")
	var npc: Dictionary=g._find_object("dori")
	npc.pos=Vector2(552,480);npc.in_studio=false
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=npc.pos+Vector2(0,-48)
	check(not g.library_day_flow.input(g,mouse),"character click is not stolen by floor cleaning")
	var lines=preload("res://scripts/stella_library_lines.gd")
	for m in g.MEMBERS:
		check(lines.promotion(m.id,0)!=lines.promotion(m.id,1),"member has context-dependent book dialogue: "+m.id)
	print("LIBRARY_CARE_FLOW: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
