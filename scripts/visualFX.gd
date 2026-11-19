extends Node

var shake_amount := 0.0
var shake_decay := 6.0
var shake_freq := 22.0
var _t := 0.0

var damage_vignette := 0.0
var damage_decay := 1.8

var camera: Camera3D
var base_offset := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_camera(cam: Camera3D) -> void:
	camera = cam
	base_offset = cam.position

func shake(amount: float, decay := 6.0) -> void:
	shake_amount = max(shake_amount, amount)
	shake_decay = decay

func flash_damage(amount := 1.0) -> void:
	damage_vignette = clamp(damage_vignette + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta

	if camera and is_instance_valid(camera):
		if shake_amount > 0.001:
			var k := shake_amount
			var ox := sin(_t * shake_freq) * k * 0.03
			var oy := cos(_t * shake_freq * 1.3) * k * 0.03
			camera.position = base_offset + Vector3(ox, oy, 0)
			shake_amount = max(0.0, shake_amount - shake_decay * delta)
		else:
			camera.position = camera.position.lerp(base_offset, delta * 12.0)

	damage_vignette = max(0.0, damage_vignette - damage_decay * delta)