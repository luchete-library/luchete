extends SceneTree
const Layout=preload("res://scripts/library_world_layout.gd")
var failures:=0
var checks:=0
func verify(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize() -> void:
	var nav:=Layout.navigation()
	for p in [Layout.ETE,Layout.PUBLIC_DOOR,Layout.VISITOR_DESK,Layout.VISITOR_RECORD,Vector2(648,208),Vector2(112,360),Vector2(176,720)]+Layout.VISITOR_READ+Layout.VISITOR_SHELVES+Layout.PUBLIC_SPOTS:
		verify(not Layout.path(nav,Layout.ENTRY,p).is_empty(),"public route "+str(p))
	for p in Layout.HOMES:
		verify(Layout.walkable(p,Layout.fixed_obstacles()),"home clear "+str(p))
		verify(not Layout.path(nav,Layout.HOME_DOOR,p).is_empty(),"private route "+str(p))
	var placed: Array=[]
	for kind in Layout.FURNITURE:
		var p: Vector2=Layout.FURNITURE[kind]
		var reason:=Layout.placement_error(placed,kind,p)
		verify(reason=="","furniture "+kind+": "+reason)
		placed.append({"kind":kind,"x":p.x,"y":p.y,"enabled":true})
	verify(Layout.path(nav,Layout.ENTRY,Layout.HOME_DOOR).is_empty(),"no cross-map path")
	print("WORLD_LAYOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
