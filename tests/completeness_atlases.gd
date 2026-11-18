extends SceneTree
# Geometry checks only; this cannot judge expression or animation quality.
const OUT := "res://artifacts/completeness_20261118/atlas_geometry.json"
var rows: Array=[]
var alerts: Array=[]
func _initialize() -> void: call_deferred("run")
func scan(directory: String, cell: Vector2i) -> void:
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".png") or file=="yune_unveiled.png": continue
		var path: String=directory+"/"+file
		var im:=Image.load_from_file(path)
		if im==null: alerts.append({"file":path,"kind":"load_failed"});continue
		var size:=im.get_size()
		if size.x%cell.x or size.y%cell.y:
			alerts.append({"file":path,"kind":"nondivisible","size":[size.x,size.y]});continue
		var empty: Array=[]
		var edges: Array=[]
		var cells:=0
		for r in range(size.y/cell.y):
			for c in range(size.x/cell.x):
				var bounds:=im.get_region(Rect2i(Vector2i(c,r)*cell,cell)).get_used_rect()
				cells+=1
				if bounds.size==Vector2i.ZERO: empty.append([c,r])
				elif bounds.position.x==0 or bounds.position.y==0 or bounds.end.x==cell.x or bounds.end.y==cell.y:
					edges.append([c,r,[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]])
		rows.append({"file":path,"size":[size.x,size.y],"cells":cells,"empty_cells":empty,"edge_contacts":edges})
func run() -> void:
	for dir in ["interactions/motion","directional"]: scan("res://assets/characters/"+dir,Vector2i(96,112))
	for dir in ["fans","visitors"]: scan("res://assets/characters/"+dir,Vector2i(64,64))
	var playback: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/comics/playback.json"))
	for member in playback.books:
		var path: String="res://assets/comics/%s.png"%member
		var im:=Image.load_from_file(path)
		var expected:=Vector2i(int(playback.columns)*228,int(playback.rows_per_cut)*4*110)
		if im.get_size()!=expected: alerts.append({"file":path,"kind":"comic_dimensions"})
		var empty: Array=[]
		for cut in range(4):
			for frame in range(int(playback.frames)):
				var c: int=frame%int(playback.columns)
				var r: int=cut*int(playback.rows_per_cut)+frame/int(playback.columns)
				if im.get_region(Rect2i(c*228,r*110,228,110)).get_used_rect().size==Vector2i.ZERO: empty.append([cut,frame])
		rows.append({"file":path,"size":[im.get_width(),im.get_height()],"cells":4*int(playback.frames),"empty_cells":empty,"edge_contacts":[]})
	var cells:=0
	var empty:=0
	var edges:=0
	for row in rows:
		cells+=row.cells;empty+=row.empty_cells.size();edges+=row.edge_contacts.size()
	var data: Dictionary={"images":rows.size(),"cells":cells,"empty_cells":empty,"edge_contacts":edges,"dimension_alerts":alerts,"atlases":rows,"scope":"Geometry only; allocated empty slots and edge contacts need interpretation. Does not prove artistic quality."}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("ATLAS GEOMETRY: images=",rows.size()," cells=",cells," empty=",empty," edges=",edges," dimensions=",alerts.size())
	quit()
