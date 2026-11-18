extends SceneTree

class Preview:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game=Preview.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	var failed:=0
	for index in range(game.MEMBERS.size()):
		var id: String=game.MEMBERS[index].id
		var points: Array=game.Chapters.BOOKS[id].points
		for scene in range(4):
			game.state=game.State.new()
			game.state.active_mission=id
			game.state.chapter_steps[id]=[0,1,1,2][scene]
			game.state.marked_actions=[id] if scene==2 else []
			game.story_member=index
			game.mode="chapter"
			game.chapter_question=false
			game.player_pos=Vector2(155,605) if scene==0 else points[scene-1]+Vector2(0,40)
			var target: Vector2=points[scene]
			if id=="kubby" and scene==1:
				game.player_pos=game.KubbyEmbers.Village.ENTRANCE
				target=game.KubbyEmbers.Village.STATION
			if id=="yato":
				game.player_pos=game.YatoForest.spawn(scene,[])
				target=game.YatoForest.SITES[game.YatoForest.sites(scene,[])[0]][0]
			if id=="fuwa":
				game.player_pos=game.FuwaSnow.spawn(scene,[])
				target=game.FuwaSnow.SITES[game.FuwaSnow.sites(scene,[])[0]][0]
			var intended_spawn:Vector2=game.player_pos
			game._setup_map()
			if game.player_pos!=intended_spawn:
				failed+=1
				print("OCCUPIED SPAWN ",id," / ",scene,": ",intended_spawn)
			game._path_to(target)
			var start:Vector2=game.player_pos
			var initial_route:int=game.route.size()
			for tick in range(1800):
				if game.route.is_empty():break
				game._process(1.0/60)
			var okay:bool=game.route.is_empty() and game.player_pos.distance_to(target)<24
			if not okay:
				failed+=1
				print("BLOCKED ",id," / ",scene," start=",start," end=",game.player_pos," target=",target," route=",initial_route," / ",game.route)
	print("24 dressed-map routes; failures: ",failed,". Player save untouched.")
	quit(1 if failed else 0)
