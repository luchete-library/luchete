extends SceneTree

const Seasons=preload("res://scripts/library_seasons.gd")
var checks:=0
var failures:=0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var snapshots: Dictionary={}
	for season in range(4):
		var image:=Seasons.scene_image(season,"clear")
		check(image.get_size()==Vector2i(96,96),"native registration")
		snapshots[hash(image.get_data())]=true
		var paint_count:=0
		var safe:=true
		for y in range(96):
			for x in range(96):
				var alpha:=image.get_pixel(x,y).a
				if alpha>0:
					paint_count+=1
					safe=safe and Seasons.inside_glass(Vector2i(x,y)) and alpha==1
		check(safe and paint_count>1500,"window frame and curtains remain untouched")
		check(image.get_data()==Seasons.scene_image(season,"clear").get_data(),"stable pixels after reloading")
		for day in range(1,29):
			var weather:=Seasons.weather_for(day,season)
			check(weather==Seasons.weather_for(day,season),"weather stable for calendar date")
			for t in [0.0,2.75,24.125]:
				var points:=Seasons.particles(season,weather,t)
				var bounded:=true
				for point in points: bounded=bounded and Seasons.inside_glass(point.pos)
				check(bounded,"precipitation clipped to actual glass")
	check(snapshots.size()==4,"four distinct seasonal landscapes")
	check(Seasons.season_index({"season":"겨울"})==3,"Korean calendar name")
	check(Seasons.season_index({"season_index":2})==2,"numeric calendar index")
	check(Seasons.label({"year":2,"season_index":0,"day_in_season":1})=="재건 2년차 · 봄 1일","year and season display")
	check(Seasons.weather_for(1,3)=="snow","winter includes snow")
	check(Seasons.weather_for(2,1)=="rain","summer includes rain")
	var directory:="res://artifacts/growth_20261116"
	DirAccess.make_dir_recursive_absolute(directory)
	var ignored:=FileAccess.open(directory+"/.gdignore",FileAccess.WRITE)
	ignored.close()
	var frame: Image=load("res://assets/library_pixels/window_clear.png").get_image()
	var sheet:=Image.create(96*4,96,false,Image.FORMAT_RGBA8)
	for season in range(4):
		var panel:=frame.duplicate()
		var weather: String=["breeze","rain","wind","snow"][season]
		panel.blend_rect(Seasons.scene_image(season,weather),Rect2i(0,0,96,96),Vector2i.ZERO)
		for point in Seasons.particles(season,weather,2.75): panel.set_pixelv(point.pos,point.ink)
		panel.blend_rect(Seasons.sill_image(season),Rect2i(0,0,96,96),Vector2i.ZERO)
		sheet.blit_rect(panel,Rect2i(0,0,96,96),Vector2i(season*96,0))
	sheet.resize(1536,384,Image.INTERPOLATE_NEAREST)
	check(sheet.save_png(directory+"/season_windows.png")==OK,"saved native-window comparison")
	print("SEASONS: ",checks," checks; ",failures," failures; frame/pane masks and deterministic weather verified.")
	quit(1 if failures else 0)
