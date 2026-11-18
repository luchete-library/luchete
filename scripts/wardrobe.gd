extends RefCounted

# The first costume of each member is the default for new and older saves.
const COSTUMES := {
	"yato": {
		"yato_hood": ["토끼 후드", preload("res://assets/characters/yato_hood.png")],
		"yato_idle": ["흰 망토", preload("res://assets/characters/yato_idle.png"), preload("res://assets/characters/field/yato.png")],
		"yato_headset": ["헤드셋 재킷", preload("res://assets/characters/yato_headset.png")],
		"yato_bunny": ["블랙 무대복", preload("res://assets/characters/yato_bunny.png")],
		"yato_knit": ["오프숄더 니트", preload("res://assets/characters/yato_knit.png")],
		"yato_track": ["트레이닝복", preload("res://assets/characters/yato_track.png")]
	},
	"danming": {
		"danming_origin": ["달빛 요정", preload("res://assets/characters/danming_origin.png")],
		"odanming_idle": ["서큐버스", preload("res://assets/characters/odanming_idle.png"), preload("res://assets/characters/field/danming.png")],
		"danming_racing": ["레이싱", preload("res://assets/characters/danming_racing.png")]
	},
	"kubby": {
		"kubby_origin": ["도깨비", preload("res://assets/characters/kubby_origin.png")],
		"hamkubby_idle": ["베레모 교복", preload("res://assets/characters/hamkubby_idle.png"), preload("res://assets/characters/field/kubby.png")]
	},
	"yune": {
		"amiha_yune_idle": ["베일 드레스", preload("res://assets/characters/amiha_yune_idle.png"), preload("res://assets/characters/field/yune.png")]
	},
	"dori": {
		"shokoko_dori_idle": ["탐정 케이프", preload("res://assets/characters/shokoko_dori_idle.png"), preload("res://assets/characters/field/dori.png")]
	},
	"fuwa": {
		"hakuten_fuwa_idle": ["눈꽃 의상", preload("res://assets/characters/hakuten_fuwa_idle.png"), preload("res://assets/characters/field/fuwa.png")]
	}
}

static func equipped(id: String, selected: String) -> String:
	var options: Dictionary = COSTUMES[id]
	return selected if options.has(selected) else options.keys()[0]
