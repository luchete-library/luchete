extends RefCounted

# Joint positions in a 64 × 90 pixel figure, relative to the floor between the feet.
var hip := Vector2(0,-40)
var lean := 0.0
var shoulders := [Vector2.ZERO,Vector2.ZERO]
var elbows := [Vector2.ZERO,Vector2.ZERO]
var hands := [Vector2.ZERO,Vector2.ZERO]
var knees := [Vector2.ZERO,Vector2.ZERO]
var ankles := [Vector2.ZERO,Vector2.ZERO]
var seated := false
var pulse := 0.0
var cycle := 0.0
var turn := 1
var gesture := ""

func build(activity: String, clock: float, repetitions: int, shoulder_height: float, id: String, reply: int) -> void:
	# Held frames keep limbs and their props on the same pixel-animation beat.
	var time := floorf(maxf(clock,0)*12.0)/12.0
	var beats := time*repetitions/6.0
	cycle = fmod(beats,1.0)
	pulse = (1.0-cos(TAU*cycle))*0.5
	turn = -1 if floori(beats)%2 == 0 else 1
	seated = activity == "yoga"
	var jump := 0.0
	match activity:
		"pilates":
			hip += Vector2(turn*4*pulse,6*pulse)
			lean = turn*0.18*pulse
		"yoga":
			hip = Vector2(0,-17-pulse*1.5)
			lean = -0.035*pulse
		"gym":
			hip.x = turn*pulse
			lean = turn*0.055*pulse
		"rope":
			jump = 11*smoothstep(0.18,0.67,pulse)
			hip.y += 6*(1-pulse)-jump
		"stream":
			gesture = "wave" if reply < 0 and time < 1.8 else "listen"
			if reply >= 0:
				gesture = SHOW_GESTURES[id][reply]
			hip.y += 2
			lean = 0.09 if gesture == "listen" else 0.025*sin(time*3)
		"signoff":
			gesture = "wave"
			lean = sin(time*3)*0.055
	for i in range(2):
		var side := -1 if i == 0 else 1
		var sh := hip+Vector2(side*6.2,-shoulder_height).rotated(lean)
		var elbow := sh+Vector2(side*3,11)
		var hand := elbow+Vector2(side*2,10)
		var knee := Vector2(side*4,-22)
		var ankle := Vector2(side*4,-3)
		match activity:
			"pilates":
				elbow = sh+Vector2(side*9,-1+turn*side*3*pulse)
				hand = elbow+Vector2(side*4,3+turn*side*3*pulse)
				knee += Vector2(side*(2+4*pulse),2*pulse)
				ankle.x = side*11
			"yoga":
				knee = hip+Vector2(side*14,8)
				ankle = hip+Vector2(-side*3,15-i*2)
				elbow = sh+Vector2(side*(6+3*pulse),8)
				hand = elbow+Vector2(side*(4-15*pulse),8-16*pulse)
			"gym":
				var curl := pulse if side == turn else 0.0
				elbow = sh+Vector2(side*5,11)
				hand = elbow+Vector2(side*(4+5*sin(curl*PI)),9-19*curl)
				knee.x = side*6
				ankle.x = side*7
			"rope":
				elbow = sh+Vector2(side*6,8)
				hand = elbow+Vector2(side*(5+2*cos(TAU*cycle)),4+4*sin(TAU*cycle))
				knee += Vector2(side*(5+3*pulse),4*(1-pulse)-jump)
				ankle += Vector2(side*2,-jump-3*pulse)
			"stream","signoff":
				var beat := sin(time*5.5)
				match gesture:
					"wave":
						if side == 1:
							elbow = sh+Vector2(9,-3)
							hand = elbow+Vector2(4+4*beat,-9)
					"listen":
						if side == 1:
							elbow = sh+Vector2(6,7)
							hand = sh+Vector2(1,-3+beat*0.6)
					"clap","fold":
						elbow = sh+Vector2(side*6,7)
						hand = hip+Vector2(side*(1.7+(1+beat)*(4 if gesture == "clap" else 1.4)),-shoulder_height+5)
					"sing","ring","chime":
						if side == 1:
							elbow = sh+Vector2(8,6)
							hand = sh+Vector2(3+beat*2,-4+beat*2)
					"draw","write","draw_moon","stamp","match","snow":
						elbow = sh+Vector2(side*6,8)
						hand = hip+Vector2(side*4,-shoulder_height+7) if gesture != "snow" else sh+Vector2(side*4,7)
						if side == 1:
							match gesture:
								"draw","write","draw_moon": hand += Vector2(beat*1.5,cos(time*5.5)*1.5)
								"stamp": hand.y += beat*4
								"match": hand += Vector2(-4*beat,-3)
								"snow": hand.y += beat*3
						elif gesture == "snow": hand.y -= beat*3
		shoulders[i] = sh
		elbows[i] = elbow
		hands[i] = hand
		knees[i] = knee
		ankles[i] = ankle

const SHOW_GESTURES := {
	"yato":["draw","stamp"],"danming":["write","draw_moon"],"kubby":["clap","sing"],
	"yune":["chime","fold"],"dori":["stamp","match"],"fuwa":["snow","ring"]
}
