extends RefCounted

# Fan-game visitor temperaments, not traits of LISTELLA members.
# IDs stay private; players infer a preference from the visitor's own words.
const TEMPERAMENTS := [
	{"id":"observer","book":0,"hint":"작은 발자국이나 숨은 그림을 찾으면 끝까지 살펴보게 돼요.","reaction":"그림 속 작은 흔적부터 하나씩 짚어 봐요."},
	{"id":"naturalist","book":0,"hint":"나무나 동물이 나오는 이야기는 자꾸 다시 펼치게 돼요.","reaction":"나뭇잎 그림이 있는 페이지를 소중하게 펼쳐요."},
	{"id":"dreamer","book":1,"hint":"밤하늘을 보면 이런저런 상상이 떠올라요. 그런 이야기가 좋아요.","reaction":"별이 그려진 페이지를 보며 잠깐 상상에 잠겨요."},
	{"id":"wanderer","book":1,"hint":"낯선 밤길을 천천히 걷는 이야기를 읽고 싶어요.","reaction":"산책길 그림을 따라 책장을 천천히 넘겨요."}
]
const BONUS_GOLD := 5
const BONUS_LIGHT := 2

static func goal_for(temperament: int, today: int, uid: int) -> int:
	var usual: int=TEMPERAMENTS[temperament].book
	return 1-usual if posmod(today+uid,3)==0 else usual

static func wanted(visitor: Dictionary) -> int:
	return int(visitor.get("reading_goal",profile(visitor).book))

static func hint(visitor: Dictionary) -> String:
	if wanted(visitor)==int(profile(visitor).book): return profile(visitor).hint
	return "평소 취향과 달리 오늘은 숲의 작은 흔적을 찾아보며 쉬고 싶어요." if wanted(visitor)==0 else "오늘은 다른 기분이에요. 별이 있는 밤길을 상상하며 쉬고 싶어요."

static func for_uid(uid: int) -> int:
	return posmod(uid*5+1,TEMPERAMENTS.size())

static func profile(visitor: Dictionary) -> Dictionary:
	return TEMPERAMENTS[clampi(int(visitor.get("temperament",for_uid(int(visitor.get("uid",1))))),0,TEMPERAMENTS.size()-1)]

static func matched(visitor: Dictionary) -> bool:
	# Older recommendations gain no retroactive bonus after migration.
	return visitor.has("temperament") and visitor.get("helped",false) and int(visitor.get("feature",-1))==wanted(visitor)

static func response(visitor: Dictionary) -> String:
	if not matched(visitor): return "새로운 분위기의 책도 읽어 보겠다며 받아 들어요."
	return "오늘 찾던 숲 이야기라며 작은 그림부터 즐겁게 살펴봐요." if wanted(visitor)==0 else "오늘 찾던 밤하늘 이야기라며 별이 있는 페이지를 펼쳐요."
