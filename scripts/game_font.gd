extends RefCounted

# Web browsers cannot read Windows fonts; keep native typography and provide
# the redistributable Korean font as the browser fallback.
static func create() -> SystemFont:
	var result:=SystemFont.new()
	result.font_names=PackedStringArray(["Malgun Gothic","맑은 고딕","Noto Sans CJK KR"])
	if OS.has_feature("web"):
		result.allow_system_fallback=false
		var korean:=FontVariation.new()
		korean.base_font=preload("res://assets/fonts/NotoSansKR.ttf")
		korean.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):400.0}
		result.fallbacks=[korean,preload("res://assets/fonts/NotoSansSymbols2-Regular.ttf"),ThemeDB.fallback_font]
	return result
