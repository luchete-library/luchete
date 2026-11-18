extends SceneTree
const OUT:="res://artifacts/visual_review_20261118/"
class Board:
	extends Node2D
	var page:=0
	var font:=SystemFont.new()
	var pictures: Dictionary={}
	func _init() -> void:
		font.font_names=PackedStringArray(["Malgun Gothic"])
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func label(p: Vector2,s: String,size: int=22,c: Color=Color("e3d5ba")) -> void:
		draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,c)
	func picture(name: String,r: Rect2) -> void:
		if not pictures.has(name): pictures[name]=ImageTexture.create_from_image(Image.load_from_file(OUT+name+".png"))
		draw_rect(r.grow(1),Color("8b7758"));draw_texture_rect(pictures[name],r,false)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(get_viewport_rect().size)),Color("272b2a"))
		match page:
			0:
				label(Vector2(24,36),"이야기 구도 비교 · 왼쪽 현재 / 오른쪽 제안",27)
				label(Vector2(24,66),"같은 순간의 실제 게임 화면 · 원본 인물 비율 유지 · 본게임 미반영",18,Color("aeb6ac"))
				var rows: Array=[["danming","단밍 · 작업대와 두 화살을 함께 크게"],["yune","유네 · 드림캐처와 꿈빛 변화를 화면 중심으로"]]
				for i in range(2):
					var y:=96+i*446
					label(Vector2(24,y),rows[i][1])
					picture(rows[i][0]+"_focus_before",Rect2(24,y+14,624,390))
					picture(rows[i][0]+"_focus_proposal",Rect2(672,y+14,624,390))
			1:
				label(Vector2(24,36),"여섯 이야기 · 장면별 시선 집중 제안",27)
				label(Vector2(24,66),"내용·대사·캐릭터 원본 유지 / 구도 조정 및 쿠비 장면의 배경 명도 보강 / 본게임 미반영",18,Color("aeb6ac"))
				var items: Array=[["dori","도리 · 돌돌이의 탁본"],["yune","유네 · 몽치와 드림캐처"],["danming","단밍 · 버리의 화살 관찰"],["kubby","쿠비 · 햄님과 작은 햄스터"],["yato","야토 · 가족의 고백"],["fuwa","후와 · 텐비와 결계 수련"]]
				for i in range(6):
					var p:=Vector2(24+(i%3)*520,102+(i/3)*363)
					label(p,items[i][1],21)
					picture(items[i][0]+"_focus_proposal",Rect2(p+Vector2(0,16),Vector2(500,312.5)))
			2:
				label(Vector2(24,36),"도서관 업무 소품 · 왼쪽 현재 / 오른쪽 제안",27)
				label(Vector2(24,66),"같은 최대 방치 상태 비교 · 책의 두께와 제본 / 따뜻한 흙먼지 색 / 본게임 미반영",18,Color("aeb6ac"))
				picture("care_level_3_before",Rect2(24,86,624,390))
				picture("care_level_3_proposal",Rect2(672,86,624,390))
				label(Vector2(24,520),"떨어진 책 · 현재",22)
				label(Vector2(672,520),"제안 · 표지·책등·종이·책갈피",22)
				for x in [24,672]: draw_rect(Rect2(x,540,624,200),Color("494e49"))
				picture("books_before",Rect2(132,540,384,192))
				picture("books_proposal",Rect2(780,540,384,192))
				label(Vector2(24,778),"얼룩 발생 속도·정리 보상은 동일. 깨끗한 상태와 방치 상태의 차이는 유지.",21)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	# This contact sheet is a separate rendering surface; it is not an in-game menu.
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	var b:=Board.new();root.add_child(b)
	var names: Array=["comparison_story","gallery_six","comparison_care"]
	var sizes: Array=[Vector2i(1320,972),Vector2i(1584,824),Vector2i(1320,806)]
	for i in range(3):
		root.size=sizes[i];b.page=i;b.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var im:=root.get_texture().get_image()
		assert(im.get_size()==sizes[i]);assert(im.save_png(OUT+names[i]+".png")==OK)
	print("REVIEW BOARDS: 3 rendered")
	b.free();quit()
