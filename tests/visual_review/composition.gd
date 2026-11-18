extends RefCounted

# Preview only: no production script preloads this module.
const MAP:=Rect2(32,140,904,578)
const SCREEN_CENTER:=Vector2(640,414)

static func view(g) -> Vector3:
	if g.mode!="chapter": return Vector3.ZERO
	var id: String=g.MEMBERS[g.story_member].id
	var scene: int=g._chapter_progress().debut_scene(id)
	# A fixed scene anchor avoids a camera jump when the nearest clue changes.
	var anchor: Vector2=g.Chapters.BOOKS[id].points[scene]
	var wide_focus: Vector2=g.player_pos.lerp(anchor,.30)-Vector2(0,55)
	var wide_scale:=1.55
	var wide_offset:=clamped(wide_focus,wide_scale)
	var amount:=0.0
	var close_focus:=wide_focus
	var close_scale:=wide_scale
	match id:
		"danming":
			amount=g.danming_workshop.lens.camera
			close_focus=Vector2(330,275);close_scale=2.5
		"yune":
			amount=g.yune_dream.nights.camera
			close_focus=Vector2(535,301);close_scale=2.15
		"kubby":
			amount=g.kubby_embers.village.camera
			close_focus=Vector2(536,384);close_scale=2.5
		"yato":
			amount=g.yato_forest.storehouse.camera
			var family: bool=g.yato_forest.storehouse.phase==g.YatoForest.Storehouse.Phase.FAMILY
			close_focus=Vector2(563,408) if family else Vector2(293,405)
			close_scale=2.25 if family else 2.5
		"fuwa":
			amount=g.fuwa_snow.practice.camera
			close_focus=Vector2(548,445);close_scale=2.15
		"dori":
			amount=g.dori_rubbing.camera
			close_focus=g.dori_rubbing.camera_at+Vector2(0,10)
			close_scale=2.4
	var scale:=lerpf(wide_scale,close_scale,amount)
	var offset: Vector2=wide_offset.lerp(clamped(close_focus,close_scale),amount).round()
	return Vector3(offset.x,offset.y,scale)

static func clamped(focus: Vector2, scale: float) -> Vector2:
	return (SCREEN_CENTER-focus*scale).clamp(Vector2(1280,800)-MAP.end*scale,-MAP.position*scale)

static func underlay(g) -> void:
	if g.mode!="chapter" or g.MEMBERS[g.story_member].id!="kubby" or g._chapter_progress().debut_scene("kubby")!=1: return
	# Static stepped reflected light behind the original actor, not on its face.
	var p:=Vector2(550,379)
	for band in range(5):
		var rx:=60-band*9
		var ry:=48-band*7
		for y in range(-ry,ry+1,2):
			var width:=floori(rx*sqrt(maxf(0.0,1.0-pow(float(y)/ry,2))))
			g.draw_rect(Rect2((p+Vector2(-width,y)).round(),Vector2(width*2,2)),Color(.61,.48,.34,.018))
