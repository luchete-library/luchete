extends RefCounted

# Column zero is neutral. Each of the five original poses is eight samples on.
const STEPS := 8

static func transition(a: int, b: int, t: float) -> int:
	return roundi(lerpf(a*STEPS,b*STEPS,smoothstep(0.0,1.0,t)))

static func gesture(durations: Array, elapsed: float, travel_seconds: Array = []) -> int:
	for i in range(durations.size()):
		var hold: float = durations[i]
		if elapsed < hold:
			var travel: float = minf(.38,hold*.83) if travel_seconds.is_empty() else float(travel_seconds[i])
			return transition(i,i+1,elapsed/travel)
		elapsed -= hold
	return 5*STEPS

static func furniture(action: String, elapsed: float, total: float) -> int:
	var remaining := total-elapsed
	if remaining <= .35: return transition(4,5,1.0-remaining/.35)
	if remaining <= 1.05: return transition(3,4,(1.05-remaining)/.70)
	if elapsed < .45: return transition(0,1,elapsed/.45)
	if elapsed < 1.0: return transition(1,2,(elapsed-.45)/.55)
	if elapsed < 1.35: return transition(2,3,(elapsed-1.0)/.35)
	if action == "yoga": return 3*STEPS
	# Raise/lower a cup, turn a page or wave. Arrive back at the held pose
	# before recovery, even if the caller assigns a shorter workout session.
	var beat := fmod(elapsed-1.35,2.55)/2.55
	var reach := sin(PI*beat)*sin(PI*beat)*smoothstep(1.05,1.55,remaining)
	return transition(3,2,reach)
