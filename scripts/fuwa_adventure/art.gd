extends RefCounted

# Code-native prototype scenery. These shadows are unnamed gameplay obstacles,
# not new canonical yokai designs. Character atlases are never modified.
static func rock(g,p: Vector2,r: Vector2) -> void:
	g.draw_ellipse_shadow(p+Vector2(0,5),r*Vector2(1.12,.37))
	var outline:=PackedVector2Array([p+Vector2(-r.x,0),p+Vector2(-r.x*.83,-r.y),p+Vector2(-r.x*.34,-r.y*1.65),p+Vector2(r.x*.4,-r.y*1.5),p+Vector2(r.x,-r.y*.6),p+Vector2(r.x*.91,5),p+Vector2(-r.x*.6,7)])
	# Rasterized on a fixed two-pixel grid so edges and snow stay pixel-shaped.
	var snowline:=PackedVector2Array([outline[2]+Vector2(-9,2),outline[2]+Vector2(5,-4),outline[3]+Vector2(2,-4),outline[4]+Vector2(3,-3),p+Vector2(r.x*.45,-r.y*.57),p+Vector2(-r.x*.1,-r.y*.75),outline[1]])
	for y in range(-ceili(r.y*1.8),8,2):
		for x in range(-ceili(r.x)-2,ceili(r.x)+4,2):
			var q: Vector2=(p+Vector2(x,y)).round()
			var in_snow:=Geometry2D.is_point_in_polygon(q,snowline)
			if not in_snow and not Geometry2D.is_point_in_polygon(q,outline): continue
			var speck:=posmod(x*31+y*17+int(p.x),13)
			var color:=Color("6c7e9b") if x<0 else Color("485d7d")
			if y>1: color=Color("354760")
			elif speck<3: color=color.lightened(.18)
			elif speck==6: color=color.darkened(.23)
			if absf(x+12+y*.24)<2 and y>-r.y*.8: color=Color("354760")
			if in_snow:
				color=Color("e5edf7") if speck>3 else Color("c4d6eb")
				if speck==12: color=Color("f4f5fc")
			g.draw_rect(Rect2(q,Vector2(2,2)),color)

static func yokai(g,p: Vector2,warning: float) -> void:
	var bob:=roundf(sin(g.clock*2.8)*2)
	var at: Vector2=(p+Vector2(-20,-53+bob)).round()
	var rows: Array=["    aa    ","   abba   ","  abccba  "," abccccba ","abccccccba","abccddccba","abccccccba"," abccccba ","  abccba  "," abccccba ","abcaccacba"," ab aa ba "]
	var palette: Dictionary={"a":Color("29364dd9"),"b":Color("465571df"),"c":Color("647491ca"),"d":Color("ffd09c") if warning<.2 else Color("ff9578")}
	g.draw_ellipse_shadow(p+Vector2(0,4),Vector2(24,6))
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var key: String=rows[y][x]
			if palette.has(key): g.draw_rect(Rect2(at+Vector2(x*4,y*4),Vector2(4,4)),palette[key])
	for i in range(3):
		var q: Vector2=(p+Vector2(sin(g.clock*1.2+i*2.0)*29,-23-i*12)).round()
		g.draw_rect(Rect2(q,Vector2(3,3)),Color("acb6d17d"))

static func danger(g,p: Vector2,radius: float,warning: float) -> void:
	# The ground-only ring communicates reach without painting over faces.
	var color:=Color("d59ea435") if warning<.15 else Color("e69b7c58")
	g.draw_circle(p,radius,color)
	for i in range(20):
		var a:=TAU*i/20
		g.draw_arc(p,radius,a,a+.12,4,Color("d2afbba0"),1.2)

static func snow(g,wind: float) -> void:
	for i in range(72):
		var x:=fposmod(i*97.13+g.clock*(9+wind*24),904)
		var y:=fposmod(i*51.7+g.clock*(12+i%5*2),578)
		g.draw_rect(Rect2(Vector2(x,y).round(),Vector2(2+int(wind>0.6),2)),Color(0.88,.95,1.0,.18+.18*wind))
	if wind>.45:
		for i in range(8):
			var y:=fposmod(i*83.0+g.clock*18,578)
			g.draw_line(Vector2(0,y),Vector2(904,y-45),Color(.78,.89,.98,.035*wind),8)

