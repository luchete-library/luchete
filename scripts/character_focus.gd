extends RefCounted

# A temporary lens samples the SAME cel that is currently drawn in the room.
# Nothing is redrawn, smoothed, stretched independently or replaced by a portrait.
const Interactions = preload("res://scripts/stella_interactions.gd")
const Field = preload("res://scripts/field_sprites.gd")
const AREA := Rect2(20,638,1240,144)
var textures := {}
var last_sample := {}

func draw(g) -> void:
	last_sample.clear()
	var world: bool=g.world_map_active()
	if g.mode!="play" or (not g.split_view() and not world) or g.character_touch.dragging: return
	if world and g.get_window().size.x>=1152: return
	if g.character_touch.reactions.is_empty(): return
	var keys: Array=g.character_touch.reactions.keys()
	var id: String=keys.back()
	var reaction: Dictionary=g.character_touch.reactions[id]
	if not reaction.get("authored",false): return
	var item: Dictionary=Interactions.definition(id,reaction.id)
	if item.is_empty(): return
	var costume: String=g._costume_key(id)
	var column: int=Interactions.Samples.gesture(item.durations,reaction.elapsed,item.get("travel_seconds",[]))
	var face: Array=Field.FACE_REGIONS.data[costume].region
	var crop := Rect2(16+float(face[0])-3,14+float(face[1])-3,float(face[2])+6,float(face[3])+6)
	crop.position+=Vector2(column*96,int(item.row)*112)
	if not textures.has(costume):
		var tex := CanvasTexture.new()
		tex.diffuse_texture=Interactions.sheet_for(id,costume)
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[costume]=tex
	var screen_scale: float=g.get_window().size.x/1280.0
	if world:
		var magnify:=maxi(1,floori(84*screen_scale/crop.size.y))
		var visible: Vector2=crop.size*float(magnify)/screen_scale
		var aligned: Vector2=((Vector2(1114,659)-visible*.5)*screen_scale).round()/screen_scale
		var destination:=Rect2(aligned,visible)
		var panel:=Rect2(1038,588,224,145)
		g._panel(panel,g.PAPER);g.ui_regions.append(panel)
		g.draw_texture_rect_region(textures[costume],destination,crop)
		g._text(Vector2(1170,633),g.MEMBERS[g._mission_index_for(id)].short,18)
		g._text(Vector2(1054,720),"지금 보여 주는 표정",15,g.MUTED)
		last_sample={"member":id,"costume":costume,"column":column,"row":int(item.row),"source":crop,"destination":destination,"physical_pixel_scale":magnify}
		return
	var magnification := maxi(1,floori(118*screen_scale/crop.size.y))
	var size: Vector2=crop.size*float(magnification)/screen_scale
	var position: Vector2=(Vector2(106,710)-size*.5)*screen_scale
	position=position.round()/screen_scale
	# This card replaces only the footer; underlying map targets stay accessible.
	for i in range(g.buttons.size()-1,-1,-1):
		if AREA.intersects(g.buttons[i].rect): g.buttons.remove_at(i)
	g.ui_regions.append(AREA)
	g._panel(AREA,Color("f0dfb6"))
	g._panel(Rect2(36,650,148,118),Color("c8bfa9"))
	g.draw_texture_rect_region(textures[costume],Rect2(position,size),crop)
	var name: String=g.MEMBERS[g._mission_index_for(id)].short
	g._text(Vector2(209,675),name+" · "+item.label,21)
	var greeting: String=reaction.get("greeting","지금 도서관에서 보여 주는 표정이에요.")
	g._text_block(Vector2(209,710),greeting,818,19,g.CREAM)
	g._text(Vector2(209,760),"인사가 끝나면 운영 안내로 돌아가요. 다른 스텔라도 눌러 보세요.",16,g.MUTED)
	g._button(Rect2(1081,736,159,31),"방송 기록 책장","growth_archive")
	last_sample={"member":id,"costume":costume,"column":column,"row":int(item.row),"source":crop,"destination":Rect2(position,size),"physical_pixel_scale":magnification}
