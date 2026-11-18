extends RefCounted

# Each portrait is registered to a 64 x 90 grid. Shoulder height, left/right
# shoulder span, hand span/height, sleeve half-width, and visible leg start.
const CUTS := {
	"yato_idle":[28,6.1,13.4,47,2.8,51], "yato_hood":[30,6.3,12.1,47.5,2.6,50],
	"yato_headset":[27,6.4,13.6,46,3.8,54],"yato_bunny":[25,5.5,12.5,46.5,1.6,46],
	"yato_knit":[27,6.7,12.8,47,3.2,49],"yato_track":[24,5.9,12.6,46,2.8,48],
	"odanming_idle":[24,6.3,15.8,47,3.3,51],"danming_origin":[24,6.1,15.5,47,3.1,50],
	"danming_racing":[24,5.6,14.5,47,2.8,46],"hamkubby_idle":[25,5.8,13.3,47.5,3.2,51],
	"kubby_origin":[25,6.1,13.8,48,4.5,51],"amiha_yune_idle":[25,5.6,11.5,46,1.9,54],
	"yune_unveiled":[26,5.7,13,46.5,2,52],"shokoko_dori_idle":[29,7,14.1,51,3.4,59],
	"hakuten_fuwa_idle":[28,6.1,13.8,48.5,3.7,63]
}
const HIP := Vector2(32,50)
const RES := 2
var skins := {}
const PRESENTER_ATLAS=preload("res://assets/characters/yard/broadcast_parts.png")
const PRESENTER_JOINTS=preload("res://assets/characters/yard/broadcast_joints.json")
var presenter_texture: CanvasTexture

func shoulder_height(key: String) -> float:
	var data: Dictionary=PRESENTER_JOINTS.data[key]
	return float(data.hip_y)-float(data.arms[0][0][1])

func _presenter(g, key: String, pose, origin: Vector2, zoom: float) -> void:
	if presenter_texture==null:
		presenter_texture=CanvasTexture.new()
		presenter_texture.diffuse_texture=PRESENTER_ATLAS
		presenter_texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var data: Dictionary=PRESENTER_JOINTS.data[key]
	var row:=int(data.row)*112
	var desk_hip:=Vector2(48,data.hip_y)
	var torso_size:=Vector2(96,desk_hip.y+1)
	var stage:=Transform2D(0,Vector2.ONE*zoom,0,origin.round())
	g.draw_set_transform_matrix(stage*Transform2D(pose.lean,pose.hip))
	g.draw_texture_rect_region(presenter_texture,Rect2(-desk_hip,torso_size),Rect2(Vector2(0,row),torso_size))
	for i in range(2):
		var source:=PackedVector2Array()
		for pin in data.arms[i]: source.append(Vector2(pin[0],pin[1]))
		var shoulder: Vector2=pose.hip+(source[0]-desk_hip).rotated(pose.lean)
		var upper:=source[0].distance_to(source[1])
		var forearm:=source[1].distance_to(source[2])
		var reach: Vector2=pose.hands[i]-shoulder
		var direction:=reach.normalized() if reach.length_squared()>.0001 else Vector2.DOWN
		var length:=clampf(reach.length(),absf(upper-forearm)+.001,upper+forearm-.001)
		var along: float=(upper*upper-forearm*forearm+length*length)/(2.0*length)
		var normal:=direction.orthogonal()
		if (pose.elbows[i]-shoulder).dot(normal)<0: normal=-normal
		var elbow:=shoulder+direction*along+normal*sqrt(maxf(0,upper*upper-along*along))
		var hand:=shoulder+direction*length
		pose.hands[i]=hand # The matching envelope, bell or pen follows this wrist.
		var joints:=PackedVector2Array([shoulder,elbow,hand])
		for part in range(2):
			var angle: float=(joints[part+1]-joints[part]).angle()-(source[part+1]-source[part]).angle()
			g.draw_set_transform_matrix(stage*Transform2D(angle,joints[part]).translated_local(-source[part]))
			g.draw_texture_rect_region(presenter_texture,Rect2(0,0,96,112),Rect2((1+2*i+part)*96,row,96,112))
	g._transform()

# Split the existing costume art once. Adjacent joints share a narrow seam so
# bent sleeves and stockings still meet. Hair, wings and trains stay on the core.
func _skin(key: String, texture: Texture2D) -> Array:
	if skins.has(key): return skins[key]
	var source := texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	source.resize(64*RES,90*RES,Image.INTERPOLATE_LANCZOS)
	var layers: Array[Image] = []
	for i in range(9): layers.append(Image.create_empty(64*RES,90*RES,false,Image.FORMAT_RGBA8))
	var cut: Array = CUTS[key]
	var arms := [_arm(cut,-1),_arm(cut,1)]
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var color := source.get_pixel(x,y)
			if color.a < 0.025: continue
			var p := (Vector2(x,y)+Vector2(0.5,0.5))/RES
			var i := 0 if p.x < HIP.x else 1
			var arm: PackedVector2Array = arms[i]
			var layer := 0
			if p.y >= cut[0]-1 and p.y <= cut[3]+3.8:
				var u := clampf(inverse_lerp(cut[0],cut[3],p.y),0,1)
				var radius := float(cut[4])+0.75*sin(PI*u)
				if u > 0.86: radius = lerpf(radius,3.2,(u-0.86)/0.14)
				var near := Geometry2D.get_closest_point_to_segment(p,arm[0],arm[1]) if p.y < arm[1].y else Geometry2D.get_closest_point_to_segment(p,arm[1],arm[2])
				if p.distance_to(near) <= radius:
					layer = 1+i*2+(1 if p.y > arm[1].y else 0)
					if absf(p.y-arm[1].y) < 1.15: layers[1+i*2+(0 if p.y > arm[1].y else 1)].set_pixel(x,y,color)
					# Leave a shoulder cap under the pivot; otherwise raising the
					# arm exposes a triangular gap in the neckline.
					if p.y < cut[0]+5.5 and absf(p.x-HIP.x) < cut[1]+1.25:
						layers[0].set_pixel(x,y,color)
			if layer == 0 and p.y >= cut[5] and absf(p.x-HIP.x) < (8.1 if key == "yato_knit" else 6.8):
				layer = 5+i*2+(1 if p.y > 65.0 else 0)
				if absf(p.y-65) < 1.2: layers[5+i*2+(0 if p.y > 65 else 1)].set_pixel(x,y,color)
			layers[layer].set_pixel(x,y,color)
	var parts := []
	for layer in layers:
		var rect := layer.get_used_rect()
		parts.append([ImageTexture.create_from_image(layer.get_region(rect)),Rect2(rect.position/float(RES),rect.size/float(RES))])
	skins[key] = parts
	return parts

static func _arm(cut: Array, side: int) -> PackedVector2Array:
	var shoulder := Vector2(32+side*cut[1],cut[0])
	var hand := Vector2(32+side*cut[2],cut[3])
	return PackedVector2Array([shoulder,shoulder.lerp(hand,0.51),hand])

static func _limb(g, part: Array, src: Vector2, src_end: Vector2, dest: Vector2, dest_end: Vector2, stage: Transform2D) -> void:
	var bone := src_end-src
	var placed := dest_end-dest
	var local := Transform2D(placed.angle(),dest).scaled_local(Vector2(placed.length()/bone.length(),1))
	local = local.rotated_local(-bone.angle()).translated_local(-src)
	g.draw_set_transform_matrix(stage*local)
	g.draw_texture_rect(part[0],part[1],false)

func draw(g, member: String, pose, origin: Vector2, zoom: float, at_desk: bool = false) -> void:
	var key: String = g._costume_key(member)
	if at_desk:
		_presenter(g,key,pose,origin,zoom)
		return
	var costume: Texture2D = g.Wardrobe.COSTUMES[member][key][1]
	var parts := _skin(key,costume)
	var stage := Transform2D(0,Vector2.ONE*zoom,0,origin.round())
	var core := stage*Transform2D(pose.lean,pose.hip)
	var body: Array = parts[0]
	var region: Rect2 = body[1]
	# The lower panel includes coat tails and long skirts. It drapes onto the
	# mat when seated instead of hanging below the floor.
	var split := HIP.y-region.position.y
	var top := Rect2(Vector2.ZERO,Vector2(region.size.x,split))
	if not at_desk:
		for i in range(2):
			var side := -1 if i == 0 else 1
			var thigh := Vector2(32+side*3.1,50)
			var knee := Vector2(32+side*3.4,65)
			var ankle := Vector2(32+side*3.9,86)
			_limb(g,parts[5+i*2],thigh,knee,pose.hip+Vector2(side*3.1,0),pose.knees[i],stage)
			_limb(g,parts[6+i*2],knee,ankle,pose.knees[i],pose.ankles[i],stage)
		g.draw_set_transform_matrix(core)
		var bottom := Rect2(0,split,region.size.x,region.size.y-split)
		var drape := minf(1,(-pose.hip.y-1)/maxf(1,bottom.size.y))
		g.draw_texture_rect_region(body[0],Rect2(Vector2(region.position.x-HIP.x,0),bottom.size*Vector2(1,drape)),Rect2(bottom.position*RES,bottom.size*RES))
		if pose.seated:
			# A fold of the equipped costume spreads across the thighs on the mat.
			var lap := PackedVector2Array([Vector2(-6,-2),Vector2(6,-2),Vector2(13,8),Vector2(6,11),Vector2(-6,11),Vector2(-13,8)])
			var uv := PackedVector2Array()
			for pt in lap: uv.append(Vector2((32+pt.x*0.38)/64.0,(44+pt.y*0.45)/90.0))
			g.draw_polygon(lap,PackedColorArray([Color.WHITE]),uv,costume)
			_limb(g,parts[6],Vector2(28.6,65),Vector2(28.1,86),pose.knees[0],pose.ankles[0],stage)
	g.draw_set_transform_matrix(core)
	g.draw_texture_rect_region(body[0],Rect2(region.position-HIP,top.size),Rect2(top.position*RES,top.size*RES))
	for i in range(2):
		var arm := _arm(CUTS[key],-1 if i == 0 else 1)
		_limb(g,parts[1+i*2],arm[0],arm[1],pose.shoulders[i],pose.elbows[i],stage)
		_limb(g,parts[2+i*2],arm[1],arm[2],pose.elbows[i],pose.hands[i],stage)
	g._transform()
