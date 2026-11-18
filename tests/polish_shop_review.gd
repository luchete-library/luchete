extends SceneTree
const OUT := "res://artifacts/polish_20261118/"
class ReviewGame:
	extends "res://scripts/growth_game.gd"
	func _save() -> void: pass
var g: Node2D
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	g=ReviewGame.new()
	g.persist=false
	g.save_path=OUT+"no_user_save.json"
	g.legacy_save_path=OUT+"no_legacy_save.json"
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g._new_game()
	while g.mode=="dialog": g._action("next")
	for member in g.MEMBERS:
		g.state.residents.append(member.id)
		g.state.chapter_steps[member.id]=3
	g.growth.begin_rebuild(6)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g._action("growth_open")
	g._setup_map()
	g.mode="growth_shop"
	g.growth.gold=500
	g.growth.memory_light=250
	g.toast_time=0
	root.size=Vector2i(960,600)
	var original_furniture: Array=g.state.furniture.duplicate(true)
	var original_costumes: Dictionary=g.state.costumes.duplicate(true)
	var grid := Image.create(326*4,233*6,false,Image.FORMAT_RGB8)
	g._action("growth_tab_furniture")
	for index in range(6):
		g._action("polish_member_%d"%index)
		for kind in g.Furniture.ORDER:
			g._action("polish_item_"+kind)
			g.shop_preview.started=0
			var member: String=g.MEMBERS[index].id
			var animation: String=g.Furniture.ITEMS[kind].action
			var item: Dictionary=g.StellaInteractions.definition(member,animation)
			check(not item.is_empty(),"each furniture has an authored action for "+member)
			var columns: Array=[]
			for elapsed in [.25,2.1,7.5]:
				g.clock=elapsed
				await frame()
				columns.append(g.StellaInteractions.Samples.furniture(animation,elapsed,8))
				if elapsed==2.1:
					var card := root.get_texture().get_image().get_region(Rect2i(514,224,326,233))
					card.convert(Image.FORMAT_RGB8)
					grid.blit_rect(card,Rect2i(Vector2i.ZERO,card.get_size()),Vector2i(g.Furniture.ORDER.find(kind)*326,index*233))
			check(columns[0]!=columns[1] and columns[1]!=columns[2],"preview includes preparation, use, recovery "+member+"/"+kind)
			for button in g.buttons:
				if button.id.begins_with("polish_item_"):
					for other in g.buttons:
						if other.id.begins_with("growth_buy_"): check(not button.rect.intersects(other.rect),"inspect does not steal a buy click")
	grid.save_png(OUT+"shop_furniture_all_members.png")
	g._action("growth_tab_costume")
	for id in g.growth.catalogue("costume"):
		g._action("polish_item_"+id)
		g.clock=1.2
		await frame()
		var item: Dictionary=g.growth.catalogue("costume")[id]
		check(item.verified and g.StellaInteractions.sheet_for(item.member,id)!=null,"only verified actual costume sheets are previewed")
	check(g.state.furniture==original_furniture,"preview never places or moves live furniture")
	check(g.state.costumes==original_costumes,"preview never equips an outfit")
	check(g.growth.gold==500,"preview never spends gold")
	print("POLISH SHOP: ",checks," checks, ",failures," failures. 24 furniture/member pairings across prep/use/recovery; three verified costumes; no world state mutation.")
	quit(1 if failures else 0)
