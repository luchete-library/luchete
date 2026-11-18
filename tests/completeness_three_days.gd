extends "res://tests/library_day_flow.gd"
const DEST:="res://artifacts/completeness_20261118/"
const Preferences=preload("res://scripts/ink_reading_preferences.gd")

func simulate(policy: String) -> Dictionary:
	fresh();g.state.minutes=540;g.state.operating.begin(g.state)
	var elapsed:=0.0
	var task_seconds:=0.0
	var choice_count:=0
	var rows: Array=[]
	var day_start:=0.0
	var day_tasks:=0.0
	for tick in range(22000):
		if g.mode=="growth_summary":
			rows.append({"day":g.state.day,"seconds":snappedf(elapsed-day_start,.1),"task_seconds":snappedf(task_seconds-day_tasks,.1),"gold":g.growth.gold,"light":g.growth.memory_light,"visitors":g.state.ink_visits.total,"rank":g.growth.rank()+1,"recommended":g.state.library_day.recommended,"tidied":g.state.library_day.tidied,"grime":g.state.library_day.grime.duplicate(),"unfiled":g.state.library_day.unfiled()})
			if rows.size()==3: break
			g._action("growth_next_day");day_start=elapsed;day_tasks=task_seconds
		if g.mode=="play":
			var slot: int=g.state.operating.slot(g.state.minutes)
			if policy!="no_promotion" and slot>=0 and slot not in g.state.operating.used_slots:
				g.mode="promotion";g.library_day_flow.topic=0 if slot==0 else 2
				g._action("day_assign");g.mode="play"
			if policy=="help_all" and g.pending_object=="" and g.route.is_empty():
				var target: Dictionary={}
				for obj in g.objects:
					if obj.get("type")=="day_target" and obj.get("kind")=="request": target=obj;break
				if target.is_empty() and not g.state.library_day.carried.is_empty(): target=g._find_object("day_shelf")
				if target.is_empty() and g.state.library_day.returned.size()>=2: target=g._find_object("day_cart")
				if target.is_empty():
					for obj in g.objects:
						if obj.get("type")=="day_target" and obj.get("kind") in ["quiet","seat","floor"]: target=obj;break
				if not target.is_empty(): g._go_to(target)
		elif g.mode=="day_choice" and policy=="help_all":
			var pick: int=Preferences.wanted(g.library_day_flow.guest(g)) if g.library_day_flow.choice=="request" else 0
			g._action("day_pick_%d"%pick);choice_count+=1
		if g.mode=="day_action" or g.pending_object.begins_with("day_"): task_seconds+=.1
		g._process(.1);elapsed+=.1
	check(rows.size()==3,"three naturally timed days finish: "+policy)
	return {"policy":policy,"days":rows,"simulation_seconds":snappedf(elapsed,.1),"task_seconds":snappedf(task_seconds,.1),"task_share":snappedf(task_seconds/maxf(1,elapsed),.001),"choices":choice_count,"notes":"Normal .1-second game updates, no time jumps. Choices instantaneous; no conversations or decorating. Task share is not a claim that the remaining time has nothing to do."}

func run() -> void:
	var results: Array=[]
	for policy in ["assigned_only","help_all","no_promotion"]:
		results.append(simulate(policy));print("THREE_DAY_POLICY ",JSON.stringify(results.back()))
	var f:=FileAccess.open(DEST+"three_day_density.json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"\t"));f.close()
	print("COMPLETENESS THREE DAYS: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
