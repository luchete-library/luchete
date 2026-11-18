extends "res://tests/library_day_flow.gd"
const Preferences=preload("res://scripts/ink_reading_preferences.gd")

func reader(origin: String="promotion", matched: bool=true) -> Dictionary:
	var v: Dictionary=g.state.ink_visits._guest(0,"read","dori")
	v.origin=origin;v.source=0;v.temperament=0;v.reading_goal=1
	v.feature=1 if matched else 0;v.helped=true
	v.admitted=true;v.phase="read"
	return v

func run() -> void:
	fresh()
	var visits=g.state.ink_visits
	visits.planned_day=0;visits.plan_day(g.state,0)
	check(visits.appointments.size()==1 and visits.appointments[0].origin=="natural","first rank has one organic visitor")
	visits.plan_day(g.state,0)
	check(visits.appointments.size()==1,"daily planning is idempotent")
	check(g.growth.gold==0 and g.growth.memory_light==0,"booking never pays a reward")
	for rank in range(4): check(visits.Outreach.natural_count(rank)==[1,2,4,4][rank],"organic growth schedule: "+str(rank))
	# Actual existing celebration -> Ete dialogue -> current promotion menu.
	g.mode="ending";g.state.minutes=540;g._action("close")
	check(g.mode=="dialog" and g.dialogue_name==g.AETHE_SPEAKER,"Ete explains promotion after reopening")
	for i in range(6):
		if g.mode=="dialog": g._action("next")
	check(g.mode=="promotion","tutorial leads to actionable promotion menu")
	g._action("growth_promotion_wait")
	check(g.state.minutes==600 and g.mode=="promotion","first promotion can reach opening time")
	for temperament in range(4):
		var goals: Array=[]
		for day in range(1,4):
			var v: Dictionary={"uid":7,"temperament":temperament,"helped":true,"reading_goal":Preferences.goal_for(temperament,day,7)}
			goals.append(v.reading_goal);v.feature=v.reading_goal
			check(Preferences.matched(v) and not Preferences.hint(v).is_empty(),"spoken daily clue maps to correct book")
			v.feature=1-int(v.reading_goal)
			check(not Preferences.matched(v),"other book never receives matching reward")
		check(0 in goals and 1 in goals,"same temperament has understandable daily variation")
	fresh();visits=g.state.ink_visits
	var first:=reader()
	visits._finish_reading(g,first)
	check(g.growth.gold==5 and g.growth.memory_light==4,"reading plus matching rewards only on completion")
	check(visits.appointments.size()==1 and visits.appointments[0].origin=="revisit" and visits.appointments[0].reason=="recommendation","good recommendation earns next-day revisit")
	check(visits.appointments[0].day==g.state.day+1,"revisit is a future physical visitor")
	check(visits.outreach.income.promotion==5 and visits.outreach.light.promotion==4,"earned rewards attributed to original promotion")
	var before: Dictionary=g.state.to_data().duplicate(true)
	visits._finish_reading(g,first)
	check(before==g.state.to_data(),"repeat completion cannot duplicate rewards or appointments")
	var decoded:=Adapter.new()
	check(decoded.apply_data(JSON.parse_string(JSON.stringify(before))),"new outreach state round-trips through JSON")
	check(decoded.ink_visits.outreach.revisits_booked==1,"revisit daily limit survives reload")
	var invalid: Dictionary=before.duplicate(true)
	invalid.growth_visitors.outreach.revisits_booked=3
	check(not Adapter.new().apply_data(invalid),"invalid revisit quota rejected")
	invalid=before.duplicate(true);invalid.growth_visitors.appointments[0].origin="unknown"
	check(not Adapter.new().apply_data(invalid),"unknown source rejected")
	invalid=before.duplicate(true);invalid.growth_visitors.outreach.day=g.state.day+1
	check(not Adapter.new().apply_data(invalid),"future daily statistics rejected")
	var legacy: Dictionary=before.duplicate(true);legacy.growth_visitors.erase("outreach")
	for a in legacy.growth_visitors.appointments:
		a.erase("origin");a.erase("reason")
	check(Adapter.new().apply_data(legacy),"old saves without outreach still load")
	for i in range(4): visits._finish_reading(g,reader())
	check(visits.outreach.revisits_booked==2 and visits.appointments.size()==2,"satisfaction appointments capped at two per day")
	fresh();visits=g.state.ink_visits
	visits._finish_reading(g,reader("revisit"))
	check(visits.appointments.is_empty(),"revisit cannot recursively recruit more revisits")
	fresh();visits=g.state.ink_visits
	g.state.library_day.tidied=2
	var tidy_guest:=reader("natural",false)
	visits._finish_reading(g,tidy_guest)
	check(visits.appointments.size()==1 and visits.appointments[0].reason=="care","clean maintained space earns revisit without correct recommendation")
	check(g.growth.gold==0 and g.growth.memory_light==2,"care books visitor rather than minting immediate money")
	fresh();visits=g.state.ink_visits
	g.state.library_day.tidied=2;g.state.library_day.grime.fill(3)
	visits._finish_reading(g,reader("natural",false))
	check(visits.appointments.is_empty(),"neglected floor does not claim tidy-space reward")
	check(g.growth.memory_light==2,"neglect never removes normal reading reward")
	fresh();visits=g.state.ink_visits
	g.state.library_day.tidied=2;g.state.library_day.dirty.assign([0])
	visits._finish_reading(g,reader("natural",false))
	check(visits.appointments.is_empty(),"dirty used seat does not count as maintained")
	var initial=visits.outreach.data()
	visits.outreach.ensure(g.state.day)
	check(visits.outreach.data()==initial,"reading summary does not reset same-day stats")
	visits.outreach.ensure(g.state.day+1)
	check(visits.outreach.revisits_booked==0 and visits.outreach.light.natural==0,"next day resets daily stats only")
	print("OUTREACH GROWTH: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
