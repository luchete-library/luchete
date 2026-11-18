extends "res://tests/story_reader_polish.gd"
const ReviewGame=preload("res://tests/visual_review/game.gd")

func capture(name: String) -> void:
	await repaint()
	shot+=1
	# Save milestones; all remaining frames still render and receive real input.
	if name in ["intro","end"] or name.ends_with("_4_result"):
		check(root.get_texture().get_image().save_png("res://artifacts/visual_review_20261118/play_"+name+".png")==OK,"milestone image: "+name)

func run() -> void:
	var save_paths: Array=[Production.State.SAVE_PATH,Production.PRODUCTION_SAVE,Production.PREVIEW_SAVE]
	var originals: Array=[]
	for path: String in save_paths: originals.append(snapshot_file(path))
	root.size=Vector2i(1280,800)
	game=ReviewGame.new();game.persist=false;game.refined=true
	game.save_path="res://artifacts/visual_review_20261118/unused_review_save.json"
	game.legacy_save_path="res://artifacts/visual_review_20261118/unused_review_legacy.json"
	root.add_child(game);game.set_process(false);game.audio_enabled=false
	game.save_available=false
	await repaint();await button("new");await capture("intro")
	for line in range(12):
		if game.mode!="dialog": break
		await button("next")
	for index in [4,3,1,2,0,5]:
		await play_book(index)
		if failures>0: break
	await capture("end")
	for i in range(save_paths.size()): check(snapshot_file(save_paths[i])==originals[i],"player save unchanged: "+save_paths[i])
	print("PROPOSAL REAL INPUT: ",checks," checks; ",failures," failures; ",shot," rendered milestones")
	FileAccess.open("res://artifacts/visual_review_20261118/playthrough_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rendered_milestones":shot,"save_unchanged":true},"\t"))
	game.free();quit(1 if failures else 0)
