extends RefCounted

const VERSION:=1
const START:=540
const OPEN:=600
const LAST_ENTRY:=1200
const END:=1320
const SECONDS_PER_TICK:=8.0
var day:=0
var fraction:=0.0
var calendar_offset:=0
var closing:=false
var used_slots: Array[int]=[]
var used_topics: Array[int]=[]
var opening_rank:=0
var start_income:=0
var start_spent:=0
var start_light:=0
var start_visitors:=0
var last_summary: Dictionary={}

func begin(state) -> void:
	day=state.day
	fraction=0.0
	closing=state.minutes>=END
	used_slots.clear()
	used_topics.clear()
	opening_rank=state.growth.rank()
	start_income=state.growth.income_total
	start_spent=state.growth.spent_total
	start_light=state.growth.memory_light
	start_visitors=state.ink_visits.total
	state.ink_visits.plan_day(state,opening_rank)
	if state.minutes>=LAST_ENTRY: state.ink_visits.defer_waiting(state.day+1)

func ensure(state) -> void:
	if day!=state.day: begin(state)

func slot(minutes: int) -> int:
	if minutes>=600 and minutes<780: return 0
	if minutes>=840 and minutes<1020: return 1
	return -1

func promotion_error(state, topic: int) -> String:
	if closing: return "오늘은 마감 중이에요. 다음 날 새 홍보를 맡겨 주세요."
	var current:=slot(state.minutes)
	if current<0:
		return "오전 10~13시, 오후 14~17시에 홍보를 맡길 수 있어요."
	if current in used_slots: return "이 시간대 홍보를 이미 맡겼어요. 다음 홍보 시간을 기다려 주세요."
	if topic in used_topics: return "같은 홍보는 하루에 한 번이에요. 다른 주제를 골라 주세요."
	return ""

func reserve(state, topic: int) -> bool:
	ensure(state)
	if promotion_error(state,topic)!="": return false
	used_slots.append(slot(state.minutes))
	used_topics.append(topic)
	return true

func advance(state, seconds: float) -> bool:
	ensure(state)
	if closing or not is_finite(seconds) or seconds<=0: return false
	fraction+=minf(seconds,1.0)
	var ticks:=floori((fraction+0.00000001)/SECONDS_PER_TICK)
	if ticks<=0: return false
	fraction=maxf(0.0,fraction-ticks*SECONDS_PER_TICK)
	state.minutes=mini(END,state.minutes+ticks*10)
	if state.minutes>=LAST_ENTRY: state.ink_visits.defer_waiting(state.day+1)
	if state.minutes>=END: closing=true
	return true

func summary(state) -> Dictionary:
	return {"day":state.day,"calendar":state.library_calendar().label,"income":maxi(0,state.growth.income_total-start_income),
		"spent":maxi(0,state.growth.spent_total-start_spent),"light":maxi(0,state.growth.memory_light-start_light),
		"visitors":maxi(0,state.ink_visits.total-start_visitors),"promotions":used_slots.size(),"gold":state.growth.gold,
		"next_reservations":state.ink_visits.reservations_for(state.day+1),"rank":state.growth.rank()+1,
		"outreach":state.ink_visits.outreach.data(),
		"next_revisits":state.ink_visits.appointments.filter(func(a): return a.day==state.day+1 and a.get("origin","")=="revisit").size()}

func data() -> Dictionary:
	return {"version":VERSION,"day":day,"fraction":fraction,"calendar_offset":calendar_offset,"closing":closing,
		"used_slots":used_slots.duplicate(),"used_topics":used_topics.duplicate(),"opening_rank":opening_rank,
		"start_income":start_income,"start_spent":start_spent,"start_light":start_light,"start_visitors":start_visitors,"last_summary":last_summary.duplicate(true)}

func restore(raw: Variant, state_day: int) -> bool:
	if not raw is Dictionary or raw.get("version")!=VERSION: return false
	for key in ["day","opening_rank","start_income","start_spent","start_light","start_visitors"]:
		if not _integer(raw.get(key),0,999999999): return false
	if (raw.day!=0 and raw.day!=state_day) or raw.opening_rank>3: return false
	if not _integer(raw.get("calendar_offset"),-999999999,999999999) or state_day+raw.calendar_offset<1: return false
	if not raw.get("fraction") is float and not raw.get("fraction") is int: return false
	if not is_finite(float(raw.fraction)) or raw.fraction<0 or raw.fraction>=SECONDS_PER_TICK: return false
	if not raw.get("closing") is bool or not raw.get("used_slots") is Array or not raw.get("used_topics") is Array: return false
	if raw.used_slots.size()!=raw.used_topics.size() or raw.used_slots.size()>2: return false
	var slots: Array[int]=[];var topics: Array[int]=[]
	for value in raw.used_slots:
		if not _integer(value,0,1) or int(value) in slots: return false
		slots.append(int(value))
	for value in raw.used_topics:
		if not _integer(value,0,2) or int(value) in topics: return false
		topics.append(int(value))
	if not raw.get("last_summary") is Dictionary: return false
	if not raw.last_summary.is_empty():
		for key in ["day","income","spent","light","visitors","promotions","gold","next_reservations","rank"]:
			if not _integer(raw.last_summary.get(key),0,999999999): return false
		if raw.last_summary.day<1 or raw.last_summary.day>=state_day or raw.last_summary.rank<1 or raw.last_summary.rank>4 or raw.last_summary.promotions>2: return false
		if not raw.last_summary.get("calendar") is String or raw.last_summary.calendar.length()>100: return false
	day=int(raw.day);fraction=float(raw.fraction);calendar_offset=int(raw.calendar_offset);closing=raw.closing
	used_slots=slots;used_topics=topics;opening_rank=int(raw.opening_rank)
	start_income=int(raw.start_income);start_spent=int(raw.start_spent);start_light=int(raw.start_light);start_visitors=int(raw.start_visitors)
	last_summary=raw.last_summary.duplicate(true)
	return true

static func _integer(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=lo and value<=hi
