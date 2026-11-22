extends Node3D
## Building.gd
## Управляет целостностью всего здания: пока целы стены, здание «живёт».
## Когда building_health падает до нуля — все стены разрушаются (_shatter()),
## в центре здания появляется облако пыли (CPUParticles3D) и играет звук обвала.

@export var walls: Array[Node3D] = []   # стены (DestructibleWall), добавляются в редакторе или кодом
var building_health := 500.0            # «общее здоровье» здания
var _collapsed := false                 # защита от повторного обвала


func take_damage(amount: float) -> void:
	if _collapsed:
		return
	building_health -= amount
	if building_health <= 0.0:
		_collapse()


func _collapse() -> void:
	if _collapsed:
		return
	_collapsed = true

	# --- 1. Разрушаем все стены -------------------------------------------
	for wall in walls:
		if wall == null or not is_instance_valid(wall):
			continue
		if wall.has_method("_shatter"):
			wall.call("_shatter")
		elif wall.has_method("take_damage"):
			# Фолбэк: если у стены нет _shatter(), пробиваем её уроном-взрывом
			wall.call("take_damage", building_health, true)

	# --- 2. Облако пыли в центре здания -----------------------------------
	_spawn_dust_cloud()

	# --- 3. Громкий звук обвала --------------------------------------------
	# В проекте нет Game.play_sound(); автозагрузка AudioFX (scripts/audiofx.gd)
	# содержит самый близкий по смыслу метод — «impact» (громкий удар взрыва).
	if has_node("/root/AudioFX"):
		get_node("/root/AudioFX").play_impact(global_position)
	else:
		push_warning("Building: аудио-автозагрузка AudioFX не найдена, звук обвала пропущен")


func _spawn_dust_cloud() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "CollapseDust"

	# Огромное облако: форма — сфера, радиус охватывает здание
	var shape := SphereShape3D.new()
	shape.radius = 12.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	dust.emission_sphere_radius = shape.radius

	dust.amount = 600                 # умеренно для слабых ПК (CPU-частицы)
	dust.lifetime = 4.0
	dust.one_off = true               # один залп, без непрерывной эмиссии
	dust.explosiveness = 1.0          # выбросить всё сразу
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 90.0                # во все стороны
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 8.0
	dust.gravity = Vector3(0, -2.0, 0)  # пыль оседает медленно
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 4.0

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.5, 0.45, 0.35)  # серо-рыжая полупрозрачная пыль
	dust.material_override = mat

	add_child(dust)
	dust.global_position = global_position

	# Пыль не должна висеть вечно — чистим за собой
	get_tree().create_timer(dust.lifetime + 1.0).timeout.connect(dust.queue_free)
