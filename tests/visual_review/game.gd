extends "res://scripts/growth_game.gd"
const Composition=preload("res://tests/visual_review/composition.gd")
const RefinedCare=preload("res://tests/visual_review/care_art.gd")
var refined:=false

func _save() -> void: pass
func _story_camera_override() -> Vector3:
	return Composition.view(self) if refined else Vector3.ZERO
func _draw_objects() -> void:
	if refined: Composition.underlay(self)
	super._draw_objects()

func _draw_world_frame() -> void:
	if not refined: super._draw_world_frame();return
	buttons.clear();ui_regions.clear();chapter_signs.clear()
	in_world=true;_transform()
	world.draw_background(self)
	for i in range(state.library_day.grime.size()): RefinedCare.draw_stain(self,RefinedCare.Base.FLOOR_POINTS[i],state.library_day.grime[i],i)
	_draw_objects()
	in_world=false;_transform()
	world.draw_hud(self)
	library_day_flow.draw_bubbles(self)
	if mode=="play": world.draw_hints(self)
	else: _draw_overlay()

func _draw_before_characters() -> void:
	if not refined: super._draw_before_characters();return
	var d=state.library_day
	if not d.returned.is_empty(): RefinedCare.draw_returned_books(self,library_day_flow.CART,d.returned)
	for seat in d.dirty: RefinedCare.draw_used_seat(self,library_day_flow.SEATS[seat],seat)
