extends SceneTree
const OUT:="res://artifacts/visual_review_20261118/"

class DetailBoard:
	extends Node2D
	var font:=SystemFont.new()
	var textures: Dictionary={}
	func _init() -> void:
		font.font_names=PackedStringArray(["Malgun Gothic"])
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func label(p: Vector2,s: String,size: int=22,color: Color=Color("eee1c8")) -> void:
		draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	func crop(name: String,source: Rect2,destination: Rect2) -> void:
		if not textures.has(name): textures[name]=ImageTexture.create_from_image(Image.load_from_file(OUT+name+".png"))
		draw_texture_rect_region(textures[name],destination,source)
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,762),Color("272b2a"))
		label(Vector2(20,34),"실제 차이 · 같은 화면 영역과 같은 배율로 비교",26)
		label(Vector2(20,68),"현재",22)
		label(Vector2(492,68),"지난 시안",22)
		# Identical screen coordinates and display scale: the size difference is
		# the actual proposed camera change, not a different crop magnification.
		crop("danming_focus_before",Rect2(330,170,500,360),Rect2(20,82,450,324))
		crop("danming_focus_proposal",Rect2(330,170,500,360),Rect2(492,82,450,324))
		label(Vector2(20,438),"단밍 장면: 같은 그림을 25% 크게 표시. 캐릭터·화살 도트는 그대로.",21)
		label(Vector2(20,484),"바닥 책 · 현재",22)
		label(Vector2(492,484),"바닥 책 · 지난 시안",22)
		for x in [20,492]: draw_rect(Rect2(x,500,450,196),Color("4b504b"))
		crop("books_before",Rect2(0,0,32,24),Rect2(117,502,256,192))
		crop("books_proposal",Rect2(0,0,32,24),Rect2(589,502,256,192))
		label(Vector2(20,734),"바닥 책: 눕힌 원근으로 다시 그림. 작은 책등·금박·종이 층 추가.",21)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,762)
	var board:=DetailBoard.new();root.add_child(board)
	await process_frame;await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image()
	assert(result.get_size()==Vector2i(960,762))
	assert(result.save_png(OUT+"difference_detail.png")==OK)
	print("Difference explanation rendered from unchanged before/proposal captures.")
	board.free();quit()
