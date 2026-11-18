extends RefCounted

# The checked official event records remain untouched. These tasks, coordinates
# and timings stage those events for play; they do not add new canonical causes.
const RECORDS=preload("res://assets/story/debut_records.json")
const NAMES={"dori":"도리","yune":"유네","danming":"단밍","kubby":"쿠비","yato":"야토"}
const COSTUMES={"dori":"shokoko_dori_idle","yune":"amiha_yune_idle","danming":"danming_origin","kubby":"kubby_origin","yato":"yato_hood"}
# background, record, mechanic, heading, objective, interaction feet
const CHAPTERS={
	"dori":[
		[0,0,"disguise","돌로만 변하는 탐정","연습 자리에서 E로 둔갑술을 써 보자.",[Vector2(440,345)]],
		[1,1,"watch","골목에서의 잠복","두 자리에서 E로 돌이 되어 살피자. E로 풀어야 움직일 수 있다.",[Vector2(320,345),Vector2(625,265)]],
		[1,1,"sleep","기다림 끝에","마지막 잠복 자리에서 돌로 둔갑해 기다리자.",[Vector2(610,330)]],
		[2,2,"carry","에테가 발견한 돌","에테가 애완돌로 착각한 도리를 데려간다.",[]],
		[3,3,"deduce","처음 얻은 인정","에테에게 다가가 E로 상황을 설명하자.",[Vector2(530,360)]],
		[3,3,"ending","도리 · 루체테에 합류","자신감을 얻은 도리가 리스텔라에 합류한다.",[]]
	],
	"yune":[
		[0,0,"birth","소망이 담긴 드림캐처","드림캐처 곁에서 E로 꿈의 세계를 살펴보자.",[Vector2(450,310)]],
		[1,1,"dreams","꿈과 현실 사이의 수호자","검은 악몽 곁에서 E를 누르고 먹자. 밝은 꿈은 그대로 지켜진다.",[Vector2(300,320),Vector2(540,270),Vector2(645,410)]],
		[2,2,"fading","꿈꾸지 않는 밤","옅어지는 꿈빛 사이를 지나 반대편으로 가자.",[Vector2(645,280)]],
		[2,3,"follow","어둠 속에서 부르는 빛","먼저 나타난 빛을 따라가자.",[Vector2(350,390),Vector2(490,315),Vector2(650,245)]],
		[3,3,"door","리스텔라의 문 앞","문 앞에서 E를 눌러 안으로 들어가자.",[Vector2(590,280)]],
		[3,3,"ending","유네 · 다시 머물 곳","유네가 도서관에 도착한다.",[]]
	],
	"danming":[
		[0,0,"workdoor","어렵게 얻은 일자리","일터로 들어가 단밍의 하루를 시작하자.",[Vector2(595,290)]],
		[1,1,"arrows","사랑의 화살 손질","작업대에 다가가 E. 화살을 닦고 흐트러진 깃을 정돈하자.",[Vector2(450,345)]],
		[2,2,"weary","반복되는 일상","마지막 화살을 정돈한 뒤 작업대에서 물러나자.",[Vector2(450,345),Vector2(550,440)]],
		[3,3,"called","뜻밖의 부름","어느 날 뜻밖의 일이 찾아왔다. E로 이야기를 이어가자.",[]],
		[3,3,"ending","단밍 · 낯선 세계","단밍이 리스텔라에 도착한다.",[]]
	],
	"kubby":[
		[0,0,"village","공포를 구하러","아랫마을로 이어지는 길을 따라가자.",[Vector2(620,280)]],
		[1,1,"hamster","쿠비가 무서워한 것","바구니 곁에서 움직이는 작은 동물을 찾아 다가가자.",[Vector2(540,340)]],
		[1,1,"takehome","공포 대신 데려온 햄스터","햄스터 곁에서 E로 데려가고, 왔던 길로 돌아가자.",[Vector2(540,340),Vector2(245,445)]],
		[2,2,"punishment","함께 변한 모습","쿠비가 벌을 받고, 햄스터도 도깨비불로 변한다.",[]],
		[3,3,"nightwalk","새로운 감정을 찾아","도깨비불과 함께 한밤중의 길을 걸어가자.",[Vector2(350,400),Vector2(480,315),Vector2(655,235)]],
		[3,3,"meeting","여행 도중 만난 리스텔라","여행길 끝에서 E로 이야기를 이어가자.",[Vector2(655,300)]],
		[3,3,"ending","쿠비 · 새로운 감정","쿠비가 도서관에 도착한다.",[]]
	],
	"yato":[
		[0,0,"family","토끼들과 자란 야토","숲의 가족 곁으로 다가가 E로 인사하자.",[Vector2(480,350)]],
		[1,1,"food","줄어든 식량","곳간의 바구니를 열어보고, 토끼 가족 곁으로 가자.",[Vector2(380,310),Vector2(590,350)]],
		[2,2,"mountain","산 아래로","숲에서 산 아래 마을까지 이어지는 길을 걸어가자.",[Vector2(330,405),Vector2(490,320),Vector2(660,250)]],
		[2,2,"cold","마을의 차가운 반응","마을의 두 문 앞에서 사람들의 반응을 살펴보자.",[Vector2(300,290),Vector2(635,290)]],
		[3,3,"light","나는 누구일까","빈터에서 E를 누르고 야토의 마음에 집중하자.",[Vector2(480,365)]],
		[3,3,"ending","야토 · 빛 뒤의 책갈피","이야기의 끝에서 도서관으로 장면이 이어진다.",[]]
	]
}
static func clean(id: String,raw: Variant) -> Dictionary:
	if not CHAPTERS.has(id) or not raw is Dictionary or raw.get("version")!=1: return {}
	for key in ["stage","x","y","done","clock"]:
		if (not raw.get(key) is int and not raw.get(key) is float) or not is_finite(float(raw[key])): return {}
	if raw.stage!=int(raw.stage) or raw.stage<0 or raw.stage>=CHAPTERS[id].size(): return {}
	if raw.done!=int(raw.done) or raw.done<0 or raw.done>7: return {}
	var kind: String=CHAPTERS[id][int(raw.stage)][2]
	var mask: int=7 if kind in ["arrows","dreams","follow","nightwalk","mountain"] else 3 if kind in ["watch","food","cold"] else 1 if kind in ["takehome","weary"] else 0
	if (int(raw.done)&mask)!=int(raw.done): return {}
	if raw.x<24 or raw.x>880 or raw.y<170 or raw.y>545 or raw.clock<0: return {}
	if raw.get("phase") not in ["play","arrived"]: return {}
	if raw.phase=="arrived" and int(raw.stage)!=CHAPTERS[id].size()-1: return {}
	return {"version":1,"stage":int(raw.stage),"x":float(raw.x),"y":float(raw.y),"done":int(raw.done),"clock":fmod(float(raw.clock),630),"phase":raw.phase,"intro":raw.get("intro",true)==true}
