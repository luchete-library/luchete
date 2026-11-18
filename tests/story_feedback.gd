extends SceneTree
const Art=preload("res://scripts/stella_adventure/art.gd")
const Field=preload("res://scripts/field_sprites.gd")
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void:
	var stone:=Vector2(535,365)
	var previous:=Art.librarian_carry_pose(stone,0)
	for frame in range(1,361):
		var pose:=Art.librarian_carry_pose(stone,frame/60.0)
		var displacement: Vector2=pose.position-previous.position
		# Vector2 uses single precision; tolerate <0.001 world units of rounding.
		check(absf(pose.distance-previous.distance-displacement.length())<.001,"gait follows actual displacement at frame "+str(frame))
		if displacement.length_squared()>.001:
			var facing: Vector2={"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN}[pose.direction]
			check(facing.dot(displacement)>0,"librarian faces travel, not backwards")
		previous=pose
	for elapsed in [2.4,2.6,2.8,2.9,6.0,7.0]:
		check(not Art.librarian_carry_pose(stone,elapsed).walking,"no stepping during pickup or after arrival")
	check(Art.librarian_carry_pose(stone,6).position==Vector2(690,260),"same story destination")
	check(Field.CARRY_PROFILES.get_size()==Vector2(1536,224),"both authored profile rows are available")
	var atlas:=Field.CARRY_PROFILES.get_image()
	for row in range(2):
		for col in range(16):
			var used:=atlas.get_region(Rect2i(col*96,row*112,96,112)).get_used_rect()
			check(used.position.x>0 and used.end.x<96 and used.position.y>0 and used.end.y==104,"intact carry silhouette and shared floor anchor")
	print("STORY FEEDBACK: ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
