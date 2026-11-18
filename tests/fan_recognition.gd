extends "res://tests/studios.gd"

func equip(id: String) -> void:
	game._interact(game._find_object("ete"))
	key(KEY_F)
	key(KEY_0 if id=="" else KEY_1+game._mission_index_for(id))
	check(game.mode=="play" and game.state.fan_form==id,"Ete equips "+id)

func expected_line(id: String, form: String, moment: String, words: String) -> void:
	var pair: Dictionary=game.FanRecognition.PAIRS[id]
	var options: Array=pair.room.values() if moment=="room" else [pair[moment]]
	if id==form:
		check(words in options,id+" has its dedicated "+moment)
	else:
		check(words!="" and words not in options,id+" uses a different "+moment+" for "+form)
	if form!="": check(game.Chapters.BOOKS[form].fan in words,"addresses the equipped fan in "+moment)

func run() -> void:
	render="--render" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,800)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	game.mode="play"
	for member in game.MEMBERS:
		game.state.residents.append(member.id)
		game.state.chapter_steps[member.id]=3
	for i in range(game.Furniture.ORDER.size()):
		game.state.place_furniture(game.Furniture.ORDER[i],game.Furniture.DEFAULTS[i])
	game._setup_map()
	# Use the same room input, furniture drop and join actions as the playable map.
	for form in game.state.residents+[""]:
		equip(form)
		for member in game.MEMBERS:
			var id: String=member.id
			var npc:=game._find_object(id)
			game._action("studio_"+id)
			var reaction: Dictionary=game.character_touch.reactions[id]
			expected_line(id,form,"room",reaction.greeting)
			check(not game.StellaInteractions.definition(id,reaction.id).is_empty(),"existing room gesture")
			if form=="dori" and id=="dori":
				game.player_pos=Vector2(482,565)
				game.toast_time=0
				await capture("fan_dori_room")
			game.garden_residents.leave_studio(game,npc)
			npc.pos=Vector2(482,565)
			game.player_pos=npc.pos+Vector2(38,0)
			game._process(.05)
			check((game.recognition.nearby_member==id)==(id==form),"proximity recognition for "+id+" and "+form)
			if id==form:
				var first_end: float=game.recognition.bubble_until
				if id=="dori":
					game.toast_time=0
					await capture("fan_dori_approach")
				game._process(.1)
				check(first_end==game.recognition.bubble_until,"greeting is not repeated while standing still")
				game.player_pos.x+=130
				game._process(.05)
				game.player_pos.x-=130
				game._process(.05)
				check(game.recognition.bubble_until>first_end,"walking back re-arms greeting")
			var previous_score: int=game.state.friendship[id]
			var already_talked: bool=id in game.state.talked_today
			key(KEY_E)
			check(game.mode=="dialog","nearby public conversation")
			expected_line(id,form,"talk",game.dialogue_lines[0])
			check(game.state.friendship[id]==previous_score+(0 if already_talked else 1),"usual daily talk reward")
			key(KEY_ESCAPE)
			for kind in ["chair","tea"]:
				var seat:=game.Furniture.position(game.Furniture.find(game.state.furniture,kind))
				var grab: Vector2=(npc.pos-Vector2(0,48))*game.WORLD_SCALE+game.WORLD_OFFSET
				click_at(grab,true)
				click_at(seat*game.WORLD_SCALE+game.WORLD_OFFSET,false)
				game.player_pos=seat+Vector2(12,44)
				key(KEY_R)
				check(game.mode=="together" and game.shared.kind==kind,"joined "+kind)
				expected_line(id,form,kind,game.shared.activity_line)
				if render and id=="dori" and form==id:
					for t in range(40): game._process(.05)
					game.toast_time=0
					await capture("fan_dori_"+kind)
				key(KEY_E)
			game.garden_residents.enter_studio(npc)
		var restored=game.State.new()
		check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))) and restored.fan_form==form,"restores active fan appearance")
	print("FAN RECOGNITION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
