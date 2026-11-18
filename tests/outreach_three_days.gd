extends "res://tests/completeness_three_days.gd"
func fresh() -> void:
	super.fresh()
	g.state.ink_visits.planned_day=0
	g.state.ink_visits.plan_day(g.state,g.state.operating.opening_rank)
func run() -> void:
	var results: Array=[]
	for policy in ["assigned_only","help_all","no_promotion"]:
		results.append(simulate(policy));print("OUTREACH_POLICY ",JSON.stringify(results.back()))
	var f:=FileAccess.open("res://artifacts/outreach_20261118/three_days.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	check(results[0].days[2].visitors>results[2].days[2].visitors*2,"promotion creates substantially more actual visits")
	check(results[2].days[2].visitors>=3 and results[2].days[2].light>0,"no promotion is slower but never stalls completely")
	check(results[1].days[2].visitors>results[0].days[2].visitors,"good service creates extra return visits")
	check(results[1].days[2].light>results[0].days[2].light,"good service increases remembered stories")
	print("OUTREACH THREE DAYS: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
