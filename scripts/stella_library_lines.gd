extends RefCounted

# Newly authored fan-game dialogue, not quotations or inferred real-life traits.
# Basis: assets/story/debut_records.json (previously checked official narratives).
# Current source accessibility and limits are recorded in the planning document.
const BOOK_LINES := {
	"yato":["토끼 가족이랑 지내던 숲이 생각나네. 이 그림은 누구 눈높이에서 보느냐에 따라 다르겠다.","처음 산 아래로 내려갔을 때도 낯선 게 많았어. 이 산책길에서는 뭘 만나게 될까?"],
	"danming":["작은 흔적부터 살펴보자. 화살 손질할 때도 그냥 지나치면 안 되는 부분이 있었거든.","같은 밤하늘을 봐도 느끼는 마음은 다를 수 있잖아. 너는 이 장면을 누구에게 보여 주고 싶어?"],
	"kubby":["작은 동물이라고 안 놀라는 건 아니더라. 나도 햄스터한테 놀란 적 있거든! 이 친구는 뭘 보고 있을까?", "무섭기도 하고 궁금하기도 한 밤인가 봐. 한 가지 마음만 있는 건 아니구나. 다음 장도 보자!"],
	"yune":["꿈에서 이런 숲을 걸었다면 어떤 장면이 남을까? 잊기 전에 마음에 드는 그림 하나 골라 봐.","꿈은 깨고 나면 흐릿해지기도 하잖아. 이 별빛을 보고 떠오른 느낌 하나만 기억해 줄래?"],
	"dori":["탐정 지망생의 눈에는 이 발자국이 그냥 지나칠 수 없는 단서인데? 앞 장 그림이랑 비교해 보자!", "밤길을 걸은 흔적부터 따라가 볼까? 아직 결론 내리긴 일러. 다음 그림도 확인해 보자!"],
	"fuwa":["수련할 때처럼 작은 부분부터 차근차근! 첫 장에 있던 이 무늬, 다음 장에도 있는지 같이 찾아보자.","눈산에서 길을 찾던 때가 생각나. 여기서는 서두르지 말고, 별이 비추는 길부터 따라가 볼까?"]
}

static func promotion(member: String,book: int) -> String:
	return BOOK_LINES.get(member,BOOK_LINES.dori)[clampi(book,0,1)]
