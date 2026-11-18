extends RefCounted

static func clean(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("version")!=1: return {}
	if raw.get("stage") not in ["trail","clearing","reunion","arrived"]: return {}
	for key in ["x","y","clock","spot"]:
		if (not raw.get(key) is int and not raw.get(key) is float) or not is_finite(float(raw[key])): return {}
	if raw.spot!=int(raw.spot) or raw.spot<0 or raw.spot>2: return {}
	if raw.x<0 or raw.x>904 or raw.y<0 or raw.y>578 or raw.clock<0: return {}
	return {"version":1,"stage":raw.stage,"x":float(raw.x),"y":float(raw.y),"clock":fmod(float(raw.clock),630),"spot":int(raw.spot),"assist":raw.get("assist",false)==true}
