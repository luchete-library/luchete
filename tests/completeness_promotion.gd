extends "res://tests/library_day_flow.gd"
const DEST:="res://artifacts/completeness_20261118/"
var peak:=0
func frame() -> void:
	g.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
func click(id: String) -> bool:
	await frame()
	for b in g.buttons:
		if b.id!=id: continue
		var e:=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=b.rect.get_center()
		g._unhandled_input(e)
		return true
	return false
func drain() -> void:
	for tick in range(3000):
		step(.1);peak=maxi(peak,g.state.ink_visits.guests.size())
		if g.state.ink_visits.topic<0 and g.state.ink_visits.guests.is_empty() and g.state.ink_visits.return_queue.is_empty() and g.state.ink_visits.reservations_for(g.state.day)==0: return
	check(false,"visits and campaign finish within five simulated minutes")
func run() -> void:
	fresh()
	var v=g.state.ink_visits
	v._book_appointment(g.state,"read",3,g.state.day,600);step(4)
	check(not v.guests.is_empty(),"reader entered before campaign")
	if v.guests.is_empty(): g.free();quit(1);return
	var uid: int=v.guests[0].uid
	g._action("promotion")
	check(await click("day_topic_0"),"current broadcast topic is clickable")
	check(await click("day_member_0"),"current host selector is clickable")
	check(await click("day_assign"),"current assignment button accepts occupied library")
	check(g.mode=="play" and v.topic==0,"assignment starts and returns control")
	check(v.guests.any(func(guest): return guest.uid==uid),"existing guest survives assignment")
	check(g.state.operating.used_slots==[0],"morning slot charged once")
	var loaded:=Adapter.new()
	check(loaded.apply_data(JSON.parse_string(JSON.stringify(g.state.to_data()))),"occupied campaign JSON restores")
	check(loaded.ink_visits.guests[0].uid==uid and loaded.operating.used_slots==[0],"restored guest and slot preserved")
	drain()
	check(v.total==4 and g.growth.gold==55 and g.growth.memory_light==12,"original reader and broadcast settle exactly once")
	check(not v.start(g.state,2),"second morning campaign rejected")
	g.state.minutes=840;g._action("promotion")
	check(await click("day_topic_2") and await click("day_assign"),"afternoon different topic starts with current buttons")
	drain()
	check(g.state.operating.used_slots==[0,1] and not v.start(g.state,1),"two per day limit remains")
	check(peak<=v.capacity(),"overlapping visits respect capacity")
	check(g.growth.gold==105 and g.growth.memory_light==22,"afternoon totals unchanged without recommendations")
	g.state.request_day_close()
	check(g.state.finish_operating_day(),"day can close after guests leave")
	g.state.minutes=600;g.mode="play"
	check(v.return_queue.size()==1,"borrowed book queued next day")
	g._action("promotion");check(await click("day_topic_1"),"magazine topic available next day")
	check(await click("day_assign") and v.return_queue.size()==1,"new assignment preserves pending return")
	drain()
	check(v.loans[0].returned,"return finishes during new campaign")
	check(g.growth.gold==115 and g.growth.memory_light==24,"return pays no duplicated fees; next day's natural reader earns 10G and two light")
	check(v.reservations_for(g.state.day+1)==4,"magazine schedules four future visitors")
	print("COMPLETENESS PROMOTION: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
