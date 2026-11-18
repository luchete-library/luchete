extends RefCounted

# Shared grid and sampling for the garden, story scenery and fan transformations.
const MANIFEST = preload("res://assets/world_pixels/manifest.json")
static var textures := {}

static func texture(id: String) -> CanvasTexture:
	if not textures.has(id):
		var tex := CanvasTexture.new()
		tex.diffuse_texture=load("res://assets/world_pixels/"+id+".png")
		tex.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		textures[id]=tex
	return textures[id]

static func sprite(g, id: String, position: Vector2, scale_factor: float = 2.0, tint: Color = Color.WHITE) -> void:
	var data: Dictionary=MANIFEST.data.sprites[id]
	var anchor := Vector2(data.anchor[0],data.anchor[1])
	var size := Vector2(data.size[0],data.size[1])
	g.draw_texture_rect(texture(id),Rect2((position-anchor*scale_factor).round(),size*scale_factor),false,tint)

static func background(g, id: String) -> void:
	sprite(g,id,Vector2(32,140))

static func prop(g, id: String, position: Vector2, scale_factor: float) -> bool:
	if not MANIFEST.data.sprites.has("prop_"+id): return false
	sprite(g,"prop_"+id,position,1.3*scale_factor)
	return true
