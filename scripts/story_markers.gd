extends RefCounted

# Approved story footplate. Drawing and pointer hit areas use the same logical
# screen coordinates, so browser scaling cannot separate a label from its tap.
const INK=Color("273042")
const GOLD=Color("ffd36e")
const FONT_SIZE=23

static func label_rect(font: Font,p: Vector2,label: String) -> Rect2:
	var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x+28
	return Rect2(p.round()+Vector2(-width/2,26),Vector2(width,38))

static func hit(font: Font,p: Vector2,label: String,pointer: Vector2) -> bool:
	return Rect2(p.round()+Vector2(-46,-36),Vector2(92,62)).has_point(pointer) or label_rect(font,p,label).grow(8).has_point(pointer)

static func draw_marker(g,p: Vector2,label: String) -> void:
	p=p.round()
	var shape:=PackedVector2Array([Vector2(-36,0),Vector2(-22,-12),Vector2(22,-12),Vector2(36,0),Vector2(22,12),Vector2(-22,12),Vector2(-36,0)])
	for i in range(shape.size()): shape[i]+=p
	g.draw_colored_polygon(shape,Color("55452bd9"))
	g.draw_polyline(shape,INK,9);g.draw_polyline(shape,GOLD,4)
	var chevron:=PackedVector2Array([p+Vector2(-8,-24),p+Vector2(0,-16),p+Vector2(8,-24)])
	g.draw_polyline(chevron,INK,9);g.draw_polyline(chevron,Color("fff3ce"),4)
	var box:=label_rect(g.font,p,label)
	g.draw_rect(box.grow(2),INK);g.draw_rect(box,Color("f6d58c"))
	g.draw_string(g.font,box.position+Vector2(14,27),label,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE,Color("302b32"))
