extends SceneTree

const Field = preload("res://scripts/field_sprites.gd")
class TestGame:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sheet: Image = Field.DIRECTIONAL.aethe.get_image()
	check(sheet.get_size()==Vector2i(480,448),"five complete cels per direction")
	check(sheet.get_region(Rect2i(0,0,96,112)).get_data()==Field.IDLE.get_image().get_region(Rect2i(0,15*112,96,112)).get_data(),"neutral exports match the runtime directional art")
	var vectors := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]
	for row in range(4):
		var direction: String = Field.DIRECTIONS[row]
		var neutral_bounds:=sheet.get_region(Rect2i(0,row*112,96,112)).get_used_rect()
		check(Field.direction_for(vectors[row]*50)==direction,"cardinal direction "+direction)
		for column in range(5):
			var cel := sheet.get_region(Rect2i(column*96,row*112,96,112))
			var bounds := cel.get_used_rect()
			check(absi(bounds.size.y-neutral_bounds.size.y)<=2 and bounds.size.y>=70 and bounds.size.y<=90 and bounds.size.x<=64 and bounds.end.y==104,"shared native scale and planted foot: %s/%d" % [direction,column])
			check(bounds.position.x>0 and bounds.end.x<96,"transparent gutters: %s/%d" % [direction,column])
			if column>0:
				var next := sheet.get_region(Rect2i((1+column%4)*96,row*112,96,112))
				check(cel.get_data()!=next.get_data(),"distinct whole-pose walking frames")
		check(Field.directional_region(direction,false,1000).position==Vector2(0,row*112),"stopping always selects the neutral cel")
		check(Field.directional_region(direction,true,0)==Field.directional_region(direction,true,32),"distance-based loop wraps without an empty frame")
		check(Field.directional_region(direction,true,8).position.x==384,"gait follows actual travel distance")
	check(Field.direction_for(Vector2.ZERO,"left")=="left","a stationary actor keeps facing")
	check(Field.direction_for(Vector2(51,50),"up")=="down","diagonal keeps vertical axis")
	check(Field.direction_for(Vector2(50,51),"right")=="right","diagonal keeps horizontal axis")
	check(Field.direction_for(Vector2(50,70),"right")=="down","clear axis change turns actor")
	for member in TestGame.Wardrobe.COSTUMES:
		for key in TestGame.Wardrobe.COSTUMES[member]:
			var turns: Texture2D=load("res://assets/characters/directional/"+key+".png")
			check(turns!=null and turns.get_size()==Vector2(17*96,3*112),"all wardrobe turns: "+key)
			var art:=turns.get_image()
			for row in range(3):
				var frames: Dictionary={}
				var registered:=true
				for col in range(17):
					var cel:=art.get_region(Rect2i(col*96,row*112,96,112))
					var rect:=cel.get_used_rect()
					registered=registered and rect.has_area() and rect.end.y<=105 and rect.position.x>0 and rect.end.x<96
					frames[hash(cel.get_data())]=true
				check(registered and frames.size()>=6,"complete registered gait: %s/%d"%[key,row])
	var g := TestGame.new()
	root.add_child(g)
	g.set_process(false)
	g.audio_enabled=false
	g.state=g.State.new()
	g.mode="play"
	g._setup_map()
	for row in range(4):
		g.player_pos=g.AETHE_POS+vectors[row]*90
		g._update_ete_facing()
		check(g._ete_field_pose().direction==Field.DIRECTIONS[row],"Ete acknowledges nearby player on each side")
	g.player_pos=g.AETHE_POS+Vector2(300,0)
	g._update_ete_facing()
	check(g.ete_facing=="up","distant player does not cause tracking")
	g.mode="pause"
	g.player_pos=g.AETHE_POS+Vector2(90,0)
	g._update_ete_facing()
	check(g.ete_facing=="up","menus freeze Ete's facing")
	g.in_world=true
	var screen_origin := Field.origin(g,Vector2(335.13,465.82),Field.PIXEL_SCALE)*g.WORLD_SCALE+g.WORLD_OFFSET
	check(screen_origin.is_equal_approx(screen_origin.round()),"world origin snaps to screen pixels")
	g.mode="chapter"
	g.story_member=4
	g.state.active_mission="dori"
	g.state.chapter_steps.dori=1
	g.state.marked_actions.append("dori")
	g.scene_started=10.0
	g.clock=10.0
	check(not g._ete_field_pose().walking,"story walk starts with neutral pose")
	var r=g.dori_rubbing
	g.clock=12.0
	check(not r.held_by_ete(g) and g._ete_walk_pos()==r.ETE_START,"Ete waits while Dori sleeps")
	g.state.dori_notes.append("print1")
	r.lifted_at=g.clock
	g.clock+=.6
	check(g._ete_field_pose().walking and not r.held_by_ete(g),"Ete walks up with empty hands")
	g.clock+=.7
	check(r.held_by_ete(g) and not g._ete_field_pose().walking,"Ete stops to lift the same stone")
	g.clock+=1.3
	var halfway: Dictionary = g._ete_field_pose()
	check(halfway.walking and halfway.direction=="left" and halfway.distance>100,"Dori story uses actual direction and travel")
	g.clock+=1
	check(not g._ete_field_pose().walking and g._ete_field_pose().direction=="down","Ete holds still for Doldori")
	var finish := g._ete_walk_pos()
	g.clock=30.0
	check(g._ete_walk_pos()==finish and not g._ete_field_pose().walking,"no footsteps in place after arrival")
	g.queue_free()
	await process_frame
	print("Directional movement checks: ",checks,"; failures: ",failures,". Player save untouched.")
	quit(1 if failures else 0)
