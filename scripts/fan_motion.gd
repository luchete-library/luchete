extends RefCounted

# Updated once by the player simulation, never by drawing menu thumbnails.
const DATA = preload("res://assets/characters/fans/manifest.json")
const Field = preload("res://scripts/field_sprites.gd")
const START_SECONDS := 0.10
const STOP_SECONDS := 0.16
var member := ""
var context := ""
var phase := "idle"
var age := 0.0
var cycle := 0.0
var distance := 0.0
var direction := "down"

func advance(id: String, place: String, delta: float, travelled: float, running: bool, enabled: bool = true, displacement: Vector2 = Vector2.ZERO) -> void:
	if id != member or place != context:
		member = id
		context = place
		phase = "idle"
		age = 0.0
		cycle = 0.0
		distance = 0.0
		direction = "down"
	if not DATA.data.members.has(id): return
	if not enabled:
		phase = "idle"
		age = 0.0
		return
	var dt := maxf(0.0,delta)
	if travelled > 0.001:
		# Use resolved movement so sliding along a wall faces the actual route.
		# Normalize before the field helper's dead zone for frame-rate independence.
		if displacement.length_squared() > 0.000001:
			direction = Field.direction_for(displacement.normalized()*8.0,direction)
		var gait := "run" if running else "walk"
		if phase in ["idle","stop"]:
			phase = "start"
			age = 0.0
			cycle = 0.0
		else:
			age += dt
			if phase != "start" or age >= START_SECONDS: phase = gait
		var motion: Dictionary = DATA.data.members[id].motion
		var rate: float = float(motion[gait+"_fps"])
		# Flying fans retain their original eight-beat wing cycle; frame_for
		# samples its sixteen poses. Grounded fans follow actual distance.
		cycle = fposmod(cycle + (dt*rate/8.0 if rate > 0 else travelled/float(motion[gait+"_stride"])),1.0)
		distance += travelled
	else:
		if phase in ["start","walk","run"]:
			phase = "stop"
			age = 0.0
		else:
			age += dt
			if phase == "stop" and age >= STOP_SECONDS:
				phase = "idle"
				age = 0.0

func facing_for(id: String) -> String:
	return direction if id == member else "down"

func frame_for(id: String) -> int:
	if id != member or not DATA.data.members.has(id): return 0
	if phase == "idle": return idle_frame(id,age)
	var sequence: Array = DATA.data.animations[phase]
	if phase in ["start","stop"]:
		var duration := START_SECONDS if phase == "start" else STOP_SECONDS
		return int(sequence[mini(int(age/duration*sequence.size()),sequence.size()-1)])
	return int(sequence[mini(int(floor(cycle*sequence.size())),sequence.size()-1)])

static func idle_frame(id: String, time: float) -> int:
	var offset: float = float(["yato","danming","kubby","yune","dori","fuwa"].find(id))*0.37
	var t := fposmod(time+offset,5.2)
	if t > 4.96: return 1
	if id in ["danming","kubby"]:
		return 18 + posmod(int(floor(time*(12.0 if id=="danming" else 3.5))),6)
	return 18 + mini(int(t*5.0),5) if t < 1.2 else 0
