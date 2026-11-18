extends RefCounted

const PLACES := {
	"yato":Vector2(235,660), "danming":Vector2(345,660), "kubby":Vector2(455,660),
	"yune":Vector2(565,660), "dori":Vector2(675,660), "fuwa":Vector2(785,660)
}

static func wear(g, stage: int) -> void:
	# Worn patches on the floor are flat so that the empty hall stays traversable.
	var patches := [Vector2(267,421),Vector2(773,573),Vector2(560,307),Vector2(326,573),Vector2(621,639),Vector2(827,347)]
	for i in range(stage,patches.size()):
		var p: Vector2 = patches[i]
		g.draw_polyline(PackedVector2Array([p+Vector2(-28,-4),p+Vector2(-9,-4),p,p+Vector2(14,-5),p+Vector2(26,-5)]),Color("504943"),2)
		for j in range(6):
			g.draw_rect(Rect2(p+Vector2(j*7-21,7+(j*7)%9),Vector2(3+j%3,2)),Color("978b76"))
	if stage < 2:
		var corner := Vector2(61,153)
		for end in [Vector2(55,7),Vector2(41,28),Vector2(20,45),Vector2(4,59)]:
			g.draw_line(corner,corner+end,Color("948e7f"),1)
		for size in [0.4,0.7,1.0]:
			g.draw_polyline(PackedVector2Array([corner+Vector2(53,7)*size,corner+Vector2(35,23)*size,corner+Vector2(18,41)*size,corner+Vector2(4,54)*size]),Color("908e80"),1)

static func furnishing(g, id: String) -> void:
	var p: Vector2 = PLACES[id]
	# A small fan should stay legible as it passes directly behind the exhibit.
	var behind: float = p.y-g.player_pos.y
	var overlap := 0.0
	if behind>=0 and g.mode=="play":
		overlap=(1.0-smoothstep(25,54,absf(p.x-g.player_pos.x)))*(1.0-smoothstep(37,80,behind))
	g.draw_ellipse_shadow(p+Vector2(2,3),Vector2(30,6))
	g.Pixels.sprite(g,"keepsake_"+id,p,2.0,Color(1,1,1,1.0-.65*overlap))
