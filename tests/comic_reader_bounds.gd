extends SceneTree

const Game=preload("res://scripts/growth_game.gd")
const OUT="res://artifacts/comic_bounds_20261119/"
var g
var checks:=0
var failures:=0
var measurements: Array=[]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func frame() -> void:
	g.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
func click(id: String) -> bool:
	for b in g.buttons:
		if b.id==id:
			var event:=InputEventMouseButton.new()
			event.position=b.rect.get_center();event.pressed=true;event.button_index=MOUSE_BUTTON_LEFT
			g._unhandled_input(event)
			return true
	return false
func run() -> void:
	g=Game.new();g.persist=false;g.save_path=OUT+"never_saved.json";g.legacy_save_path=OUT+"no_legacy.json"
	root.add_child(g);g.set_process(false);g.audio_enabled=false;g.background_paused=false
	for member in g.MEMBERS: g.state.chapter_steps[member.id]=3
	root.min_size=Vector2i(200,200)
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	var native_font=g.font
	var browser_font:=SystemFont.new()
	browser_font.allow_system_fallback=false
	var korean:=FontVariation.new()
	korean.base_font=preload("res://assets/fonts/NotoSansKR.ttf")
	korean.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):400.0}
	browser_font.fallbacks=[korean,preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf"),ThemeDB.fallback_font]
	for font_mode in ["native","browser"]:
		g.font=native_font if font_mode=="native" else browser_font
		for spec in [["small",Vector2i(844,390)],["portrait",Vector2i(390,844)],["hidpi",Vector2i(1688,780)],["desktop",Vector2i(960,600)]]:
			root.size=spec[1]
			for index in range(g.MEMBERS.size()):
				g.mode="story";g.story_member=index;g.story_page=0;g._action("comic_play")
				var id: String=g.MEMBERS[index].id
				g.comic_player.held=g.Comics.duration(id);g.comic_player.paused=true
				var saved: Dictionary=g.state.to_data()
				for focused in [false,true]:
					g.comic_player.enlarged=focused;await frame()
					var plan: Dictionary=g.Comics.layout(g)
					var prefix: String=font_mode+" "+spec[0]+" "+id+" "+str(focused)
					check(plan.boxes.size()==(1 if focused else 4),prefix+" retains the existing panel count")
					for b in g.buttons:
						if b.id.begins_with("comic_"): check(Rect2(0,0,1280,800).encloses(b.rect),prefix+" button inside: "+b.id)
					for j in range(plan.panels.size()):
						check(Rect2(0,0,1280,800).encloses(g.Comics.ui_rect(plan.panels[j].grow(3),plan)),prefix+" frame inside")
						check(is_equal_approx(plan.boxes[j].size.x/plan.boxes[j].size.y,228.0/110.0),prefix+" art aspect ratio unchanged")
					for cut in range(4):
						var width: float=(plan.panels[0].size.x-plan.caption_left-plan.caption_right)*plan.unit/plan.scale
						for lines in [plan.full_lines[cut],plan.first_lines[cut]]:
							for line in lines: check(g.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,plan.caption_font).x<=width+.01,prefix+" caption stays in column")
							check(plan.caption_baseline+(lines.size()-1)*plan.caption_line+2<=plan.caption,prefix+" caption baselines inside strip")
						var original: String=g.Comics.PROFILES.data[id].captions[cut].replace("\n","").replace(" ","")
						check("".join(plan.full_lines[cut]).replace(" ","")==original,prefix+" full caption preserved")
					var footer: Rect2
					for b in g.buttons:
						if b.id=="comic_close": footer=b.rect
					for panel in plan.panels: check(g.Comics.ui_rect(panel.grow(3),plan).end.y<=footer.position.y+.1,prefix+" captions do not cover footer")
					check(click("comic_pause"),prefix+" pause clickable")
					check(not g.comic_player.paused,prefix+" pause control resumes")
					g.comic_player.held=g.Comics.duration(id);g.comic_player.paused=true
					if not focused and spec[0] in ["small","portrait","desktop"]:
						await frame();root.get_texture().get_image().save_png(OUT+font_mode+"_"+spec[0]+"_"+id+".png")
					measurements.append({"font":font_mode,"screen":spec[0],"member":id,"focused":focused,"art_scale":plan.factor*plan.unit,"caption_font_pixels":plan.caption_font*plan.scale,"caption_height":plan.caption*plan.unit})
				check(click("comic_close") and g.comic_started<0,font_mode+" "+spec[0]+" "+id+" close clickable")
				check(g.state.to_data()==saved,id+" reader never changes saved progress")
	FileAccess.open(OUT+"bounds.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"screens":measurements},"\t"))
	print("COMIC BOUNDS: ",checks," checks; ",failures," failures; six books, native/browser fonts, four windows, both existing views; no player save written.")
	g.free();quit(1 if failures else 0)
