extends RefCounted

# Fan-game operating rules, never an official character setting.
const ORIGINS := ["natural","promotion","revisit"]
const REVISITS_PER_DAY := 2
var day := 0
var arrivals := {"natural":0,"promotion":0,"revisit":0}
var income := {"natural":0,"promotion":0,"revisit":0}
var light := {"natural":0,"promotion":0,"revisit":0}
var revisits_booked := 0
var completed_campaigns := 0

static func natural_count(rank_at_open: int) -> int:
	return 4 if rank_at_open>=2 else 2 if rank_at_open>=1 else 1

static func origin(visitor: Dictionary) -> String:
	return visitor.get("origin","natural")

func ensure(today: int) -> void:
	if day==today: return
	day=today
	for key in ORIGINS: arrivals[key]=0;income[key]=0;light[key]=0
	revisits_booked=0;completed_campaigns=0

func entered(today: int, visitor: Dictionary) -> void:
	ensure(today);arrivals[origin(visitor)]+=1

func paid(today: int, visitor: Dictionary, gold: int, memory: int) -> void:
	ensure(today);income[origin(visitor)]+=gold;light[origin(visitor)]+=memory

func data() -> Dictionary:
	return {"day":day,"arrivals":arrivals.duplicate(),"income":income.duplicate(),"light":light.duplicate(),"revisits_booked":revisits_booked,"completed_campaigns":completed_campaigns}

func restore(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	for key in ["day","revisits_booked","completed_campaigns"]:
		if not integer(raw.get(key)): return false
	if raw.revisits_booked>REVISITS_PER_DAY or raw.completed_campaigns>2: return false
	for key in ["arrivals","income","light"]:
		if not raw.get(key) is Dictionary or raw[key].size()!=ORIGINS.size(): return false
		for kind in ORIGINS:
			if not integer(raw[key].get(kind)): return false
	day=int(raw.day)
	for kind in ORIGINS:
		arrivals[kind]=int(raw.arrivals[kind]);income[kind]=int(raw.income[kind]);light[kind]=int(raw.light[kind])
	revisits_booked=int(raw.revisits_booked);completed_campaigns=int(raw.completed_campaigns)
	return true

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=0 and value<=999999999
