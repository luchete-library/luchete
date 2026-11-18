extends RefCounted

# One logical coordinate system. The second area is viewed through a camera
# offset; visits continue to use the public library while it is off screen.
const VERSION := 1
const HOME_OFFSET := Vector2(1280,0)
const ENTRY := Vector2(560,720)
const ETE := Vector2(224,528)
const PUBLIC_DOOR := Vector2(1192,224)
const HOME_DOOR := Vector2(1744,364)
const HOMES := [Vector2(1592,272),Vector2(1952,216),Vector2(2304,208),Vector2(1560,656),Vector2(1920,632),Vector2(2336,632)]
const PUBLIC_SPOTS := [Vector2(552,352),Vector2(840,688),Vector2(312,592),Vector2(880,216),Vector2(1152,544),Vector2(1120,688)]
const FURNITURE := {"chair":Vector2(1152,672),"tea":Vector2(992,688),"mat":Vector2(768,688),"camera":Vector2(400,656)}
const VISITOR_DOOR := Vector2(560,752)
const VISITOR_SHELVES := [Vector2(376,328),Vector2(656,328),Vector2(472,328),Vector2(744,328),Vector2(552,232)]
const VISITOR_READ := [Vector2(944,448),Vector2(1024,448),Vector2(880,360),Vector2(1104,360),Vector2(1168,448)]
const VISITOR_DESK := Vector2(256,528)
const VISITOR_EXHIBIT := Vector2(672,216)
const VISITOR_RECORD := Vector2(176,288)
const STACKS := [Rect2(326,214,194,101),Rect2(604,214,202,101),Rect2(326,329,194,108),Rect2(604,329,202,108),Rect2(326,446,194,115),Rect2(604,446,202,115)]
const ROOM_AREAS := [Rect2(25,190,360,132),Rect2(467,150,370,163),Rect2(895,145,353,212),Rect2(27,550,342,183),Rect2(446,578,381,159),Rect2(923,580,330,159)]
const PASSAGES := [Rect2(380,376,46,377),Rect2(842,422,52,317)]
const THRESHOLDS := [Rect2(358,592,72,61),Rect2(813,610,80,50),Rect2(883,610,63,50)]
const WORK_OFFSET := {"corridor":Vector2(-5,55),"shelves":Vector2(0,-26),"reading":Vector2(292,-16)}

static func private_point(p: Vector2) -> bool:
	return p.x>=1280

static func work_point(task: String,p: Vector2) -> Vector2:
	return p+WORK_OFFSET.get(task,Vector2.ZERO)

static func fixed_obstacles() -> Array[Rect2]:
	var result: Array[Rect2]=[Rect2(18,230,211,52),Rect2(176,267,100,108),Rect2(24,431,239,83),Rect2(256,434,54,57),Rect2(60,636,165,40),Rect2(234,582,38,140),Rect2(852,279,267,135),Rect2(855,505,265,124),Rect2(1148,291,82,149),Rect2(1140,455,66,72),Rect2(1198,548,43,75)]
	for rect in STACKS: result.append(Rect2(rect.position.x+8,rect.end.y-31,rect.size.x-16,30))
	# Furniture bases, not entire tall sprite rectangles, block the feet.
	var room_blocks=[Rect2(55,267,124,53),Rect2(246,166,113,43),Rect2(274,221,61,18),Rect2(557,245,175,46),Rect2(755,120,71,73),Rect2(937,259,139,43),Rect2(1090,211,151,73),Rect2(44,572,142,62),Rect2(291,604,59,31),Rect2(105,674,166,57),Rect2(477,530,62,78),Rect2(703,574,114,58),Rect2(494,675,178,61),Rect2(1122,586,118,59),Rect2(996,692,143,48)]
	for rect in room_blocks: result.append(Rect2(rect.position+HOME_OFFSET,rect.size))
	return result

static func floor_contains(p: Vector2) -> bool:
	if not private_point(p):
		return Rect2(28,194,1215,546).has_point(p) or Rect2(532,723,75,65).has_point(p) or Rect2(1138,148,100,82).has_point(p)
	var q:=p-HOME_OFFSET
	if Rect2(246,316,1003,75).has_point(q) or Rect2(421,374,507,48).has_point(q): return true
	for area in ROOM_AREAS+PASSAGES+THRESHOLDS:
		if area.has_point(q): return true
	# The upper rooms open directly onto the shared landing.
	for area in [Rect2(276,290,101,51),Rect2(604,286,98,58),Rect2(935,325,101,61)]:
		if area.has_point(q): return true
	return false

static func obstacles(furniture: Array) -> Array[Rect2]:
	var result:=fixed_obstacles()
	for item in furniture:
		if item.kind!="mat": result.append(Rect2(Vector2(item.x-28,item.y-20),Vector2(56,25)))
	return result

static func walkable(p: Vector2,blocks: Array) -> bool:
	if not floor_contains(p): return false
	for block in blocks:
		if block.grow(7).has_point(p): return false
	return true

static func navigation(furniture: Array=[]) -> AStarGrid2D:
	var nav:=AStarGrid2D.new()
	nav.region=Rect2i(0,0,160,50)
	nav.cell_size=Vector2(16,16)
	nav.offset=Vector2(8,8)
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	var blocks:=obstacles(furniture)
	for x in range(160):
		for y in range(50): nav.set_point_solid(Vector2i(x,y),not walkable(Vector2(x*16+8,y*16+8),blocks))
	return nav

static func nearest(nav: AStarGrid2D,p: Vector2) -> Vector2i:
	var best:=Vector2i(-1,-1)
	var distance:=INF
	var cell:=Vector2i(p/16)
	for dx in range(-8,9):
		for dy in range(-8,9):
			var q:=cell+Vector2i(dx,dy)
			if not nav.is_in_boundsv(q) or nav.is_point_solid(q): continue
			var pos:=nav.get_point_position(q)
			if private_point(pos)!=private_point(p): continue
			var d:=pos.distance_squared_to(p)
			if d<distance: distance=d;best=q
	return best

static func path(nav: AStarGrid2D,a: Vector2,b: Vector2) -> PackedVector2Array:
	if private_point(a)!=private_point(b): return PackedVector2Array()
	var first:=nearest(nav,a)
	var last:=nearest(nav,b)
	if first.x<0 or last.x<0: return PackedVector2Array()
	return nav.get_point_path(first,last)

static func placement_error(layout: Array,kind: String,p: Vector2,player: Vector2=Vector2.INF) -> String:
	if not FURNITURE.has(kind): return "알 수 없는 가구예요."
	if private_point(p) or not Rect2(310,580,895,147).has_point(p): return "공용 도서관 아래쪽의 비어 있는 공간에 놓아 주세요."
	if not floor_contains(p+Vector2(0,40)): return "가구 앞에 드나들 바닥이 필요해요."
	if p.x>520 and p.x<610: return "가운데 출입 통로는 비워 두어요."
	var area:=Rect2(p-Vector2(39,29),Vector2(78,80))
	for block in fixed_obstacles():
		if area.intersects(block.grow(7)): return "서가·책상과 조금 떨어뜨려 놓아 주세요."
	var proposed: Array=[]
	for item in layout:
		if item.kind==kind: continue
		if area.intersects(Rect2(item.x-39,item.y-29,78,80)): return "가구 사이에 드나들 틈을 남겨 주세요."
		proposed.append(item)
	if player.is_finite() and area.has_point(player): return "플레이어 자리에서 조금 떨어뜨려 놓아 주세요."
	proposed.append({"kind":kind,"x":p.x,"y":p.y,"enabled":true})
	var nav:=navigation(proposed)
	for target in [ETE,PUBLIC_DOOR,VISITOR_DESK,VISITOR_RECORD]+VISITOR_READ+VISITOR_SHELVES:
		if path(nav,ENTRY,target).is_empty(): return "손님과 스텔라가 지나갈 길이 막혀요."
	for item in proposed:
		if path(nav,ENTRY,Vector2(item.x,item.y+40)).is_empty(): return "가구 앞에 드나들 자리가 필요해요."
	return ""

static func visible_patches(growth) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	var rank: int=growth.rank() if growth.phase=="open" else -1
	if "shelves" in growth.completed_tasks:
		result.append(Rect2(500,24,335,170))
		result.append_array([stack_patch(0),stack_patch(1)])
	if "corridor" in growth.completed_tasks: result.append(Rect2(16,283,290,238))
	if "reading" in growth.completed_tasks:
		result.append_array([Rect2(824,233,306,270),Rect2(854,20,277,169),Rect2(0,525,294,242)])
	if rank>=1:
		result.append_array([stack_patch(2),stack_patch(3),Rect2(15,95,212,188),Rect2(229,0,288,190)])
	if rank>=2:
		result.append_array([stack_patch(4),stack_patch(5),Rect2(849,495,285,154),Rect2(1135,270,110,260)])
	if rank>=3: return [Rect2(0,0,1280,800)]
	return result

static func stack_patch(index: int) -> Rect2:
	# Include foliage above the shelf without revealing the next row early.
	var shelf: Rect2=STACKS[index]
	return Rect2(shelf.position+Vector2(-8,-18),shelf.size+Vector2(16,22))
