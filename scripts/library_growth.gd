extends RefCounted

# Preview balance, not final prices or an official outfit inventory.
const VERSION := 2
const DAYS_PER_SEASON := 7
const SEASONS := ["봄","여름","가을","겨울"]
const PHASES := ["recruiting","rebuilding","ready","open"]
const TASKS := ["corridor","shelves","reading"]
const LIGHT_THRESHOLDS := [0,30,100,250]
const RANK_NAMES := ["첫 손님을 맞는 도서관","기억이 모이는 도서관","이야기가 퍼지는 도서관","별빛으로 이어진 도서관"]
const MAX_VALUE := 999999999
const RECEIPT_LIMIT := 4096
const MEMBERS := ["yato","danming","kubby","yune","dori","fuwa"]
const FURNITURE_ACTIONS := {"chair":"read","tea":"tea","mat":"yoga","camera":"stream"}
const FURNITURE := {
	"chair":{"id":"chair","label":"기본 독서 의자","kind":"chair","action":"read","price":0,"rank":0,"starter":true},
	"tea":{"id":"tea","label":"티 테이블","kind":"tea","action":"tea","price":60,"rank":0},
	"mat":{"id":"mat","label":"요가 매트","kind":"mat","action":"yoga","price":80,"rank":1},
	"camera":{"id":"camera","label":"방송 세트","kind":"camera","action":"stream","price":120,"rank":1}
}
const UPGRADES := {
	"reading_lamp":{"id":"reading_lamp","label":"포근한 독서등","price":80,"rank":1,"description":"잉크의 독서 시간이 13초에서 9초로 줄어듭니다."},
	"welcome_desk":{"id":"welcome_desk","label":"방문 안내 개선","price":120,"rank":1,"description":"한 번에 맞이할 수 있는 잉크가 2명에서 4명으로 늘어납니다."},
	"lending_desk":{"id":"lending_desk","label":"대출 서비스 개선","price":90,"rank":2,"description":"책 대여료가 15골드에서 20골드로 오릅니다."}
}

var gold := 0
var memory_light := 0
var phase := "recruiting"
var completed_tasks: Array = []
var upgrades: Dictionary = {}
var owned_furniture: Array = []
var owned_costumes: Array = []
var recent_events: Array = []
var income_total := 0
var spent_total := 0
var rank_floor := 0 # Preserve previously earned unlocks when balance changes.
# Source verification belongs to the authored catalogue, never to saved data.
var costume_catalog: Dictionary = {}

static func calendar(absolute_day: int) -> Dictionary:
	var day := maxi(1,absolute_day)-1
	var year := floori(day/float(DAYS_PER_SEASON*4))+1
	var season_index := floori(day/float(DAYS_PER_SEASON))%4
	var in_season := day%DAYS_PER_SEASON+1
	return {"absolute_day":maxi(1,absolute_day),"year":year,"year_index":year,"season_index":season_index,"season_label":SEASONS[season_index],"day_in_season":in_season,
		"label":"재건 %d년차 · %s %d일" % [year,SEASONS[season_index],in_season]}

func rank() -> int:
	var result := rank_floor
	for i in range(LIGHT_THRESHOLDS.size()):
		if memory_light>=LIGHT_THRESHOLDS[i]: result=maxi(result,i)
	return result

func rank_name() -> String:
	return RANK_NAMES[rank()]

func next_threshold() -> int:
	return LIGHT_THRESHOLDS[rank()+1] if rank()+1<LIGHT_THRESHOLDS.size() else -1

func begin_rebuild(resident_count: int) -> bool:
	if phase!="recruiting" or resident_count<6: return false
	phase="rebuilding"
	return true

func complete_task(id: String) -> bool:
	if phase!="rebuilding" or id not in TASKS or id in completed_tasks: return false
	if id!="corridor" and "corridor" not in completed_tasks: return false
	completed_tasks.append(id)
	if completed_tasks.size()==TASKS.size():
		phase="ready"
		if "chair" not in owned_furniture: owned_furniture.append("chair")
	return true

func open_library() -> bool:
	if phase!="ready" or completed_tasks.size()!=TASKS.size(): return false
	phase="open"
	return true

func reward(event_id: String, gold_delta: int, light_delta: int) -> bool:
	# A promotion choice is not a reward event. Call only after an actual
	# paid admission, completed reading/loan or completed daily broadcast.
	if phase!="open" or not _valid_id(event_id,160) or event_id in recent_events: return false
	if gold_delta<0 or light_delta<0 or (gold_delta==0 and light_delta==0): return false
	if gold_delta>MAX_VALUE-gold or light_delta>MAX_VALUE-memory_light or gold_delta>MAX_VALUE-income_total: return false
	gold+=gold_delta
	memory_light+=light_delta
	income_total+=gold_delta
	recent_events.append(event_id)
	if recent_events.size()>RECEIPT_LIMIT: recent_events.pop_front()
	return true

func has_upgrade(id: String) -> bool:
	return upgrades.get(id,false)==true

func entrance_fee() -> int:
	return 10

func loan_fee() -> int:
	return 20 if has_upgrade("lending_desk") else 15

func rental_fee() -> int:
	return loan_fee()

func reading_seconds() -> float:
	return 9.0 if has_upgrade("reading_lamp") else 13.0

func visitor_capacity() -> int:
	return mini(5,(4 if has_upgrade("welcome_desk") else 2)+(1 if rank()==3 else 0))

static func furniture_usable(item: Dictionary) -> bool:
	var kind: Variant=item.get("kind",null)
	return kind is String and FURNITURE_ACTIONS.has(kind) and item.get("action","")==FURNITURE_ACTIONS[kind]

func set_costume_catalog(raw: Dictionary) -> bool:
	var verified: Dictionary={}
	for id in raw:
		var item: Variant=raw[id]
		if not _valid_id(id,80) or not item is Dictionary: return false
		if item.get("verified",false)!=true or item.get("additional",false)!=true: return false
		if item.get("member","") not in MEMBERS: return false
		if not _count(item.get("price",null),MAX_VALUE) or int(item.price)<=0: return false
		if not _count(item.get("rank",null),LIGHT_THRESHOLDS.size()-1): return false
		if not item.get("source",null) is String or not item.source.begins_with("https://"): return false
		if not item.get("label",null) is String or item.label.strip_edges().is_empty(): return false
		verified[id]=item.duplicate(true)
		verified[id]["id"]=id
	costume_catalog=verified
	return true

func catalogue(kind: String) -> Dictionary:
	match kind:
		"furniture": return FURNITURE.duplicate(true)
		"upgrade": return UPGRADES.duplicate(true)
		"costume": return costume_catalog.duplicate(true)
	return {}

func purchase_error(kind: String, id: String, resident_count: int=6) -> String:
	if phase!="open": return "첫 재건을 마치고 도서관을 연 뒤 이용할 수 있어요."
	if resident_count<6: return "여섯 스텔라가 모두 모인 뒤 이용할 수 있어요."
	var items:=catalogue(kind)
	if not items.has(id): return "아직 판매가 확인되지 않은 항목이에요."
	var item: Dictionary=items[id]
	if kind=="furniture" and not furniture_usable(item): return "스텔라 상호작용이 준비되지 않은 가구예요."
	if (kind=="furniture" and id in owned_furniture) or (kind=="costume" and id in owned_costumes) or (kind=="upgrade" and has_upgrade(id)):
		return "이미 보유하고 있어요."
	if rank()<int(item.rank): return "기억의 빛을 더 모아 도서관 단계를 높여 주세요."
	if gold<int(item.price): return "골드가 부족해요."
	return ""

func purchase(kind: String, id: String, resident_count: int=6) -> String:
	var error:=purchase_error(kind,id,resident_count)
	if error!="": return error
	var item: Dictionary=catalogue(kind)[id]
	var price:=int(item.price)
	if spent_total>MAX_VALUE-price: return "구매 기록의 저장 범위를 넘었어요."
	gold-=price
	spent_total+=price
	match kind:
		"furniture": owned_furniture.append(id)
		"costume": owned_costumes.append(id)
		"upgrade": upgrades[id]=true
	return ""

func data() -> Dictionary:
	return {"version":VERSION,"gold":gold,"memory_light":memory_light,"phase":phase,"completed_tasks":completed_tasks.duplicate(),
		"upgrades":upgrades.duplicate(),"owned_furniture":owned_furniture.duplicate(),"owned_costumes":owned_costumes.duplicate(),
		"recent_events":recent_events.duplicate(),"income_total":income_total,"spent_total":spent_total,"rank_floor":rank_floor}

static func _count(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=0 and value<=maximum

static func _valid_id(value: Variant, maximum: int) -> bool:
	return value is String and value.length()>0 and value.length()<=maximum and value.strip_edges()==value and not "\n" in value and not "\r" in value

static func _string_list(value: Variant, maximum: int, allowed: Array=[]) -> bool:
	if not value is Array or value.size()>maximum: return false
	var seen: Dictionary={}
	for item in value:
		if not _valid_id(item,160) or seen.has(item) or (not allowed.is_empty() and item not in allowed): return false
		seen[item]=true
	return true

func restore(raw: Variant) -> bool:
	# Validate the complete snapshot before changing a single live field.
	if not raw is Dictionary or (raw.get("version",null)!=1 and raw.get("version",null)!=VERSION): return false
	if raw.version==VERSION and not _count(raw.get("rank_floor"),3): return false
	for key in ["gold","memory_light","income_total","spent_total"]:
		if not _count(raw.get(key,null),MAX_VALUE): return false
	if raw.get("phase",null) not in PHASES: return false
	if not _string_list(raw.get("completed_tasks",null),3,TASKS): return false
	if not _string_list(raw.get("owned_furniture",null),FURNITURE.size(),FURNITURE.keys()): return false
	if not _string_list(raw.get("owned_costumes",null),256): return false
	if not _string_list(raw.get("recent_events",null),RECEIPT_LIMIT): return false
	if not raw.get("upgrades",null) is Dictionary or raw.upgrades.size()>UPGRADES.size(): return false
	for id in raw.upgrades:
		if id not in UPGRADES or raw.upgrades[id]!=true: return false
	var tasks: Array=raw.completed_tasks
	if not tasks.is_empty() and "corridor" not in tasks: return false
	if raw.phase=="recruiting" and not tasks.is_empty(): return false
	if raw.phase=="rebuilding" and tasks.size()>=TASKS.size(): return false
	if raw.phase in ["ready","open"] and (tasks.size()!=TASKS.size() or "chair" not in raw.owned_furniture): return false
	gold=int(raw.gold)
	memory_light=int(raw.memory_light)
	phase=raw.phase
	completed_tasks=tasks.duplicate()
	upgrades=raw.upgrades.duplicate()
	owned_furniture=raw.owned_furniture.duplicate()
	owned_costumes=raw.owned_costumes.duplicate()
	recent_events=raw.recent_events.duplicate()
	income_total=int(raw.income_total)
	spent_total=int(raw.spent_total)
	rank_floor=int(raw.rank_floor) if raw.version==VERSION else 0
	if raw.version==1:
		for i in range(4):
			if memory_light>=[0,15,45,100][i]: rank_floor=i
	return true
