extends SceneTree

const Growth = preload("res://scripts/library_growth.gd")
var checks:=0
var failures:=0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func opened():
	var g:=Growth.new()
	g.begin_rebuild(6)
	g.complete_task("corridor")
	g.complete_task("shelves")
	g.complete_task("reading")
	g.open_library()
	return g

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g:=Growth.new()
	check(not g.begin_rebuild(5),"no rebuilding before all six return")
	check(not g.reward("promo:1",10,3),"no preopening income")
	check(not g.complete_task("corridor"),"no unstarted work")
	check(g.begin_rebuild(6) and not g.begin_rebuild(6),"begin first reconstruction once")
	check(not g.complete_task("reading"),"corridor precedes room work")
	check(g.complete_task("corridor") and not g.complete_task("corridor"),"work is idempotent")
	check(g.complete_task("reading") and g.complete_task("shelves"),"reading and shelves can finish in either order")
	check(g.phase=="ready" and g.gold==0 and g.memory_light==0 and g.owned_furniture==["chair"],"first reconstruction uses no economy grind")
	check(g.open_library() and not g.open_library(),"player opens prepared library once")
	check(g.reward("admission:1",10,0) and not g.reward("admission:1",10,0),"admission cannot pay twice")
	check(g.gold==10 and g.memory_light==0,"admission is money, not automatic memory")
	check(g.reward("read:1",0,2) and g.gold==10 and g.memory_light==2,"reading earns persistent light")
	var before:=g.data()
	check(not g.reward("negative",-1,5) and not g.reward("empty",0,0) and g.data()==before,"invalid rewards are atomic")
	check(g.purchase("furniture","tea")!="" and g.gold==10,"insufficient gold does not spend")
	check(g.purchase("costume","invented_outfit")!="","unverified clothing is not sold")
	check(g.reward("test:operating-income",400,28) and g.rank()==1,"threshold 30 opens stage two")
	var light:=g.memory_light
	check(g.purchase("furniture","tea")=="" and "tea" in g.owned_furniture and g.memory_light==light,"buy interactive furniture with gold only")
	var after_tea:=g.gold
	check(g.purchase("furniture","tea")!="" and g.gold==after_tea,"owned furniture is not charged twice")
	check(g.purchase("upgrade","welcome_desk")=="" and g.visitor_capacity()==4,"capacity upgrade changes live visitor limit")
	check(g.purchase("upgrade","reading_lamp")=="" and g.reading_seconds()==9.0,"reading upgrade changes actual duration")
	check(g.purchase("upgrade","lending_desk")!="" and g.loan_fee()==15,"rank gates lending upgrade")
	check(g.reward("broadcast:day:one",0,70) and g.rank()==2,"broadcast memory can unlock next rank")
	check(g.purchase("upgrade","lending_desk")=="" and g.loan_fee()==20,"lending upgrade changes actual fee")
	check(g.memory_light==100 and g.income_total==410 and g.spent_total==350,"light is never spent and financial ledger balances")
	check(g.reward("late:read",0,150) and g.rank()==3 and g.next_threshold()==-1 and g.visitor_capacity()==5,"last rank retains capped capacity")
	for id in Growth.FURNITURE:
		check(Growth.furniture_usable(Growth.FURNITURE[id]),"every listed furniture has a matching animation: "+id)
	check(not Growth.furniture_usable({"kind":"mat","action":"dance"}),"unsupported furniture action is not sellable")
	var catalog: Dictionary={"verified_fixture":{"verified":true,"additional":true,"member":"yato","label":"검사 전용 항목","source":"https://example.invalid/official-test-fixture","price":25,"rank":1}}
	check(g.set_costume_catalog(catalog),"explicitly verified additional catalogue contract")
	catalog.verified_fixture.verified=false
	check(not g.set_costume_catalog(catalog) and g.costume_catalog.verified_fixture.verified,"rejected catalogue is atomic and detached from caller")
	check(g.purchase("costume","verified_fixture",5)!="","all-six condition applies to clothing")
	check(g.purchase("costume","verified_fixture")=="" and "verified_fixture" in g.owned_costumes,"only registered clothing can be bought")
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(g.data()))
	var reloaded:=Growth.new()
	check(reloaded.restore(snapshot) and reloaded.data()==g.data(),"JSON save round trip")
	check(reloaded.costume_catalog.is_empty(),"saved file cannot invent verified sale catalogue")
	check(not reloaded.reward("admission:1",10,0),"receipt survives reload")
	var stable:=reloaded.data()
	for field in ["gold","memory_light","income_total","spent_total"]:
		var malformed: Dictionary=snapshot.duplicate(true)
		malformed[field]=-1
		check(not reloaded.restore(malformed) and reloaded.data()==stable,"negative field restore atomic: "+field)
	var mutations: Array=[{"phase":"ready","completed_tasks":[]},{"owned_furniture":["chair","chair"]},{"recent_events":["same","same"]},{"gold":1.5},{"upgrades":{"unknown":true}},{"version":3},{"completed_tasks":["reading"]},{"phase":"ready","owned_furniture":[]},{"rank_floor":4}]
	for patch in mutations:
		var malformed: Dictionary=snapshot.duplicate(true)
		for field in patch: malformed[field]=patch[field]
		check(not reloaded.restore(malformed) and reloaded.data()==stable,"malformed snapshot is rejected without partial state")
	for sample in [[1,1,0,1],[7,1,0,7],[8,1,1,1],[14,1,1,7],[15,1,2,1],[21,1,2,7],[22,1,3,1],[28,1,3,7],[29,2,0,1],[56,2,3,7],[57,3,0,1]]:
		var date: Dictionary=Growth.calendar(sample[0])
		check(date.absolute_day==sample[0] and date.year==sample[1] and date.season_index==sample[2] and date.day_in_season==sample[3],"calendar boundary: "+str(sample[0]))
	var bounded=opened()
	for i in range(Growth.RECEIPT_LIMIT+3): bounded.reward("read:"+str(i),0,1)
	check(bounded.recent_events.size()==Growth.RECEIPT_LIMIT and not bounded.reward("read:"+str(Growth.RECEIPT_LIMIT+2),0,1),"receipt cache bounded and current events deduplicated")
	print("Library growth checks: ",checks,"; failures: ",failures,". No game save touched.")
	quit(1 if failures else 0)
