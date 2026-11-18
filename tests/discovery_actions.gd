extends RefCounted

# End-to-end actions: use the same visible objects, mouse events and keys as a player.
static func held(t,key: Key,seconds: float) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.pressed=true
	t.root.push_input(event,true)
	for i in range(ceili(seconds*60)): await t.elapse(1.0/60)
	event.pressed=false
	t.root.push_input(event,true)
	await t.repaint()

static func play(t,scene: int,demo: bool=false) -> void:
	var g=t.game
	var id: String=g.MEMBERS[g.story_member].id
	await t.repaint()
	match id:
		"danming":
			match scene:
				0:
					for place in ["notice","voice","reply"]: await t.inspect_field_site("bee_"+place)
					t.check(g.DanmingWorkshop.ready(0,g.state.danming_notes),"square observations can be discovered in another order")
				1:
					await t.inspect_field_site("bee_bench")
					await t.swipe(Vector2(700,329),Vector2(865,329))
					t.check("quill" in g.state.danming_notes and not "tip" in g.state.danming_notes,"cloth movement reveals the arrow progressively")
					if demo: await t.capture("book_discovery_20261115/danming_work")
					await t.swipe(Vector2(865,329),Vector2(1024,329))
				2:
					await t.inspect_field_site("bee_album")
					await t.elapse(.5)
					var lens=g.danming_workshop.lens
					var motion:=InputEventMouseMotion.new()
					for i in range(100):
						motion.position=g.WORLD_OFFSET+(lens.POINTS[1]+Vector2(sin(i)*2,0))*g.WORLD_SCALE
						t.root.push_input(motion,true)
						await t.elapse(1.0/60)
					t.check("arrow_stack" in g.state.danming_notes and not "hand_pause" in g.state.danming_notes,"steady magnifier observation works without holding a button")
					if demo: await t.capture("book_discovery_20261115/danming_lens")
					await held(t,KEY_A,.9)
					await t.elapse(1.05)
				3:
					await t.inspect_field_site("bee_empty")
					await t.inspect_field_site("bee_threshold")
					await t.swipe(Vector2(250,334),Vector2(1030,334))
		"yune":
			match scene:
				0:
					await t.inspect_field_site("dream_loom")
					await t.tap(g.YuneDream.FEATHER)
					t.check("feather" in g.state.yune_notes and not "web" in g.state.yune_notes,"either detail can be noticed first")
					await t.reader_key(KEY_UP)
					await t.reader_key(KEY_E)
					await t.elapse(.01)
					await t.elapse(1.3)
				1:
					await t.inspect_field_site("dream_gold")
					await t.inspect_field_site("dream_shadow")
					await t.elapse(g.YuneDream.FEED_TIME*.6)
					if demo: await t.capture("book_discovery_20261115/yune_dream")
					await t.elapse(g.YuneDream.FEED_TIME*.45)
				2:
					await t.inspect_field_site("dream_nights")
					var night=g.yune_dream.nights
					await t.elapse(night.DURATION*.55)
					t.check("bed" in g.state.yune_notes and not "window" in g.state.yune_notes,"the dreamlight changes before the last night")
					if demo: await t.capture("book_discovery_20261115/yune_nights")
					await t.elapse(night.DURATION*.46)
				3:
					await t.inspect_field_site("dream_call")
					await t.elapse(g.YuneDream.WALK_TIME)
					await t.inspect_field_site("dream_door")
		"kubby":
			match scene:
				0:
					for place in ["snow","village"]: await t.inspect_field_site("wisp_"+place)
				1:
					await t.inspect_field_site("wisp_watch")
					var village=g.kubby_embers.village
					await t.elapse(village.FLINCH+.3-village.elapsed)
					t.check(village.kubby_feet().x>village.KUBBY.x+10,"Kubby recoils from the separate hamster")
					if demo: await t.capture("book_discovery_20261115/kubby_hamster")
					await t.elapse(village.END-village.elapsed+.03)
				2:
					await t.inspect_field_site("wisp_ice")
					if demo: await t.capture("book_discovery_20261115/kubby_reflection")
					await t.inspect_field_site("wisp_glow")
					t.check(g.kubby_embers.flow==1,"walking the ice trail preserves the hamster transformation")
				3:
					for place in ["night","journey"]: await t.inspect_field_site("wisp_"+place)
		"yato":
			match scene:
				0:
					for place in ["trail","nest","family"]: await t.inspect_field_site("mato_"+place)
				1:
					await t.inspect_field_site("mato_basket")
					var room=g.yato_forest.storehouse
					await t.elapse(room.UNFOLD_TIME+.02)
					t.check("basket" in g.state.yato_notes and not g.chapter_question,"examining food returns naturally to the family on the map")
					await t.inspect_field_site("mato_truth")
					await t.elapse(room.SHOCK+.3-room.elapsed)
					if demo: await t.capture("book_discovery_20261115/yato_family")
					await t.elapse(room.END-room.elapsed+.03)
				2:
					for place in ["bend","village","gaze"]: await t.inspect_field_site("mato_"+place)
				3:
					await t.inspect_field_site("mato_beside")
					await t.elapse(g.YatoForest.LIGHT_TIME+.02)
		"fuwa":
			match scene:
				0:
					await t.inspect_field_site("tenbi_together")
					var ward=g.fuwa_snow.practice
					await t.elapse(ward.join_time+.1)
					await t.elapse(.5)
					var a: Vector2=g.WORLD_OFFSET+ward.DOTS[0]*g.WORLD_SCALE
					var b: Vector2=g.WORLD_OFFSET+ward.DOTS[1]*g.WORLD_SCALE
					await t.swipe(a,b)
					t.check(ward.step==2,"mouse traces the first complete side in the map")
					await held(t,KEY_E,2.65)
					t.check(ward.phase==ward.Phase.BLOOM and "ward_loop" in g.state.fuwa_notes,"one consistent held key continues the remaining brush strokes")
					await t.elapse(.7)
					if demo: await t.capture("book_discovery_20261115/fuwa_ward")
					await t.elapse(ward.BLOOM_TIME)
				1:
					for place in ["empty","gate","overlook","pass"]:
						await t.inspect_field_site("tenbi_"+place)
						if demo and place=="overlook": await t.capture("book_discovery_20261115/fuwa_overlook")
				2:
					for place in ["clearing","wait"]: await t.inspect_field_site("tenbi_"+place)
					await t.elapse(g.FuwaSnow.REUNION_TIME+.02)
				3:
					await t.inspect_field_site("tenbi_spell")
					await t.elapse(2)
					if demo: await t.capture("book_discovery_20261115/fuwa_rift")
					await t.button("fuwa_turn")
					await t.elapse(2)
					if demo: await t.capture("book_discovery_20261115/fuwa_awake")
					await t.reader_key(KEY_E)
					await t.inspect_field_site("tenbi_shelves")
	await t.elapse(.01)
	await t.repaint()
	t.check(g._chapter_progress().chapter_ready(id,scene) and g.book_discovery.result_scene==scene,"field actions produce the automatic discovery for %s/%d"%[id,scene])
	for b in g.buttons:
		t.check(b.id not in ["chapter_remember","bee_read","dream_read","ward_read","village_read","store_read"],"no duplicate confirmation control")
