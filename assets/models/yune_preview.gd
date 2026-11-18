extends Node3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		$Yune.rotate_y(event.relative.x * 0.012)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera.size = maxf(0.68, $Camera.size / 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera.size = minf(2.8, $Camera.size * 1.12)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: $Yune.rotate_y(-PI / 12.0)
			KEY_RIGHT: $Yune.rotate_y(PI / 12.0)
			KEY_HOME:
				$Yune.rotation = Vector3.ZERO
				$Camera.size = 1.91
