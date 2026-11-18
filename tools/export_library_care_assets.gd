extends SceneTree
const Art=preload("res://scripts/library_care_art.gd")
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/library_care")
	var errors: Array=[Art.stain_sheet().save_png("res://assets/library_care/floor_grime.png"),Art.warning_sheet().save_png("res://assets/library_care/ete_warning.png"),Art.book_sheet().save_png("res://assets/library_care/fallen_books.png")]
	print("LIBRARY_CARE_ASSETS: ",errors)
	quit(0 if errors==[OK,OK,OK] else 1)
