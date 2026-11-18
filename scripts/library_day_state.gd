extends RefCounted

# Fictional library activities, separate from debut records and real broadcasts.
const BOOKS := [
	{"title":"숲의 작은 하루","mark":"잎","color":"76a78a","shelf":Vector2(376,328)},
	{"title":"별빛 산책","mark":"별","color":"8f8fca","shelf":Vector2(744,328)}
]
var day := 0
var returned: Array[int] = []
var carried: Array[int] = []
var dirty: Array[int] = []
var direct: Dictionary = {}
var tidied := 0
var guided := 0
var recommended := 0
var noise_used := false
var shelved: Array[int] = [0,0]
const GRIME_INTERVAL := 90.0
const ETE_WARNING_AFTER := 120.0
var grime: Array[int] = [0,0,0,0,0,0,0,0]
var soil_seconds := 0.0
var neglect_seconds := 0.0
var ete_warned := false

func unfiled() -> int:
	return returned.size()+carried.size()

func has_mess() -> bool:
	return unfiled()>0 or not dirty.is_empty()

func advance_care(seconds: float) -> bool:
	if not is_finite(seconds) or seconds<=0: return false
	var delta:=minf(seconds,1.0)
	if unfiled()==0:
		neglect_seconds=0.0;ete_warned=false
	elif unfiled()>=4:
		neglect_seconds=minf(ETE_WARNING_AFTER,neglect_seconds+delta)
	if not has_mess(): soil_seconds=0.0;return false
	soil_seconds+=delta
	if soil_seconds<GRIME_INTERVAL: return false
	soil_seconds-=GRIME_INTERVAL
	# Spread out before darkening. Bounded patches never block movement.
	var lowest: int=grime.min()
	if lowest>=3: return false
	grime[grime.find(lowest)]+=1
	return true

func clean_floor(index: int) -> void:
	if index<0 or index>=grime.size() or grime[index]==0: return
	grime[index]=0;tidied+=1

func ensure(today: int) -> void:
	if day==today: return
	day=today
	# Books, seats and floor stains now persist overnight, within fixed caps.
	tidied=0;guided=0;recommended=0;noise_used=false
	shelved.assign([0,0])

func completed_reading(state, visitor: Dictionary) -> void:
	ensure(state.day)
	var book: int=int(visitor.get("feature",int(visitor.uid)%2))
	if returned.size()+carried.size()<6: returned.append(book)
	var seat: int=int(visitor.slot)%2
	if seat not in dirty: dirty.append(seat)

func returned_loan(state, visitor: Dictionary) -> void:
	ensure(state.day)
	if returned.size()+carried.size()<6: returned.append(int(visitor.get("feature",int(visitor.uid)%2)))

func take_books() -> int:
	if not carried.is_empty() or returned.is_empty(): return 0
	var book:=returned[0]
	for i in range(returned.size()-1,-1,-1):
		if returned[i]==book and carried.size()<3:
			carried.append(book);returned.remove_at(i)
	return carried.size()

func shelve(book: int) -> int:
	if carried.is_empty() or carried[0]!=book: return 0
	var count:=carried.size()
	carried.clear();tidied+=count
	if unfiled()==0: neglect_seconds=0.0;ete_warned=false
	shelved[book]=mini(12,shelved[book]+count)
	return count

func data() -> Dictionary:
	return {"version":2,"day":day,"returned":returned.duplicate(),"carried":carried.duplicate(),"dirty":dirty.duplicate(),"direct":direct.duplicate(true),"tidied":tidied,"guided":guided,"recommended":recommended,"noise_used":noise_used,"shelved":shelved.duplicate(),"grime":grime.duplicate(),"soil_seconds":soil_seconds,"neglect_seconds":neglect_seconds,"ete_warned":ete_warned}

static func count_value(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=0 and value<=maximum

static func point_valid(value: Variant) -> bool:
	if not value is Array or value.size()!=2: return false
	for n in value:
		if (not n is int and not n is float) or not is_finite(float(n)): return false
	return value[0]>=0 and value[0]<=2560 and value[1]>=0 and value[1]<=800

func restore(raw: Variant, residents: Array, today: int) -> bool:
	if not raw is Dictionary or (raw.get("version")!=1 and raw.get("version")!=2): return false
	if not count_value(raw.get("day"),today): return false
	for key in ["returned","carried","dirty"]:
		if not raw.get(key) is Array or raw[key].size()>(6 if key=="returned" else 3 if key=="carried" else 2): return false
		for book in raw[key]:
			if not count_value(book,1): return false
	if raw.returned.size()+raw.carried.size()>6: return false
	if not raw.carried.is_empty():
		for book in raw.carried:
			if book!=raw.carried[0]: return false
	if raw.dirty.size()==2 and raw.dirty[0]==raw.dirty[1]: return false
	for key in ["tidied","guided","recommended"]:
		if not count_value(raw.get(key),100000): return false
	if not raw.get("noise_used") is bool: return false
	var placed: Variant=raw.get("shelved",[0,0])
	if not placed is Array or placed.size()!=2: return false
	for n in placed:
		if not count_value(n,12): return false
	var stains: Variant=raw.get("grime",[0,0,0,0,0,0,0,0])
	if not stains is Array or stains.size()!=8: return false
	for n in stains:
		if not count_value(n,3): return false
	for key in ["soil_seconds","neglect_seconds"]:
		var seconds: Variant=raw.get(key,0.0)
		if (not seconds is float and not seconds is int) or not is_finite(float(seconds)) or seconds<0: return false
		if (key=="soil_seconds" and seconds>=GRIME_INTERVAL) or (key=="neglect_seconds" and seconds>ETE_WARNING_AFTER): return false
	if not raw.get("ete_warned",false) is bool: return false
	# Accept older saves, but discard the removed post-visit dialogue records.
	var legacy_memories: Variant=raw.get("memories",{})
	if not legacy_memories is Dictionary or legacy_memories.size()>6: return false
	for id in legacy_memories:
		var memo: Variant=legacy_memories[id]
		if id not in residents or not memo is Dictionary: return false
		if not count_value(memo.get("book"),1) or not count_value(memo.get("day"),today): return false
		if not memo.get("helped") is bool or not memo.get("seen") is bool: return false
	if not raw.get("direct") is Dictionary: return false
	var session: Dictionary=raw.direct
	if not session.is_empty():
		if session.get("member") not in residents or not count_value(session.get("topic"),2) or not count_value(session.get("stage"),2) or not count_value(session.get("book"),1): return false
		if session.get("facing") not in ["up","down","left","right"]: return false
		if not point_valid(session.get("origin")) or not point_valid(session.get("position")): return false
		if not count_value(session.get("campaign"),1000000000) or session.campaign==0: return false
	day=int(raw.day);returned.assign(raw.returned);carried.assign(raw.carried);dirty.assign(raw.dirty)
	direct=session.duplicate(true)
	tidied=int(raw.tidied);guided=int(raw.guided);recommended=int(raw.recommended);noise_used=raw.noise_used
	shelved.assign(placed)
	grime.assign(stains);soil_seconds=float(raw.get("soil_seconds",0.0));neglect_seconds=float(raw.get("neglect_seconds",0.0));ete_warned=raw.get("ete_warned",false)
	return true
