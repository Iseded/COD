class_name Player
extends CharacterBody3D

signal health_changed(hp: int, max_hp: int)
signal ammo_changed(mag: int, reserve: int, wname: String)
signal died

const WALK := 5.0
const SPRINT := 8.2
const CROUCH := 2.6
const JUMP := 5.6
const SENS := 0.0022

var max_health := 100
var health := 100
var gravity := 18.0
var alive := true

# Механика кровотечения и регенерации (как в MW2)
var is_bleeding := false
var bleeding_damage := 2.0
var time_since_last_damage := 0.0
const REGEN_DELAY := 4.0 # секунд без урона до начала восстановления
const REGEN_RATE := 6.0 # HP в секунду

var camera: Camera3D
var viewmodel: WeaponViewmodel
var pitch := 0.0
var recoil := 0.0
var crouching := false

# Оставляем только АК-12
var weapons := [
	{"name": "AK-12", "dmg": 28, "mag_max": 30, "reserve": 120, "rate": 0.1, "auto": true, "spread": 0.015}
]
var weapon_index := 0
var mag := 0
var reserve := 0
var can_fire := true
var reloading := false

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 80
	add_child(camera)

	viewmodel = WeaponViewmodel.new()
	add_child(viewmodel)
	viewmodel.setup(camera)
	VisualFX.register_camera(camera)

	_equip(0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, max_health)

func _unhandled_input(event: InputEvent) -> void:
	if not alive: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		pitch = clamp(pitch - event.relative.y * SENS, deg_to_rad(-85), deg_to_rad(85))
		viewmodel.add_sway(event.relative)

func _process(delta: float) -> void:
	if not alive: return

	camera.rotation.x = pitch + recoil
	recoil = lerp(recoil, 0.0, delta * 12.0)

	crouching = Input.is_action_pressed("crouch")
	var target_h := 1.15 if crouching else 1.65
	camera.position.y = lerp(camera.position.y, target_h, delta * 12.0)

	viewmodel.set_ads(Input.is_action_pressed("aim"))
	viewmodel.set_movement(Vector2(velocity.x, velocity.z).length())

	if Input.is_action_just_pressed("reload"):
		_reload()
	
	# Убрали переключение на второе оружие (weapon_2)

	var w: Dictionary = weapons[weapon_index]
	if w.auto:
		if Input.is_action_pressed("fire"):
			_shoot()
	else:
		if Input.is_action_just_pressed("fire"):
			_shoot()

func _physics_process(delta: float) -> void:
	if not alive: return

	# Кровотечение: постоянная потеря здоровья
	time_since_last_damage += delta
	if is_bleeding:
		health = max(0, health - bleeding_damage * delta)
		health_changed.emit(int(health), max_health)
		if health <= 0:
			_die()
			return
	# Регенерация (как в MW2): через 4 секунды без урона, если не истекаем кровью
	elif time_since_last_damage >= REGEN_DELAY and health < max_health:
		health = min(max_health, health + REGEN_RATE * delta)
		health_changed.emit(int(health), max_health)

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	var speed := WALK
	if crouching:
		speed = CROUCH
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		velocity.y = JUMP

	move_and_slide()

func _equip(i: int) -> void:
	if reloading: return
	weapon_index = i
	var w: Dictionary = weapons[i]
	mag = w.mag_max
	reserve = w.reserve
	can_fire = true
	viewmodel.switch_to(i)
	ammo_changed.emit(mag, reserve, w.name)

func _reload() -> void:
	if reloading: return
	var w: Dictionary = weapons[weapon_index]
	if mag >= int(w.mag_max) or reserve <= 0: return
	reloading = true
	AudioFX.play_reload(global_position)
	await get_tree().create_timer(1.3).timeout
	var need := int(w.mag_max) - mag
	var take: int = min(need, reserve) # Исправлено для Godot 4.7
	mag += take
	reserve -= take
	reloading = false
	ammo_changed.emit(mag, reserve, w.name)

func _shoot() -> void:
	if reloading: return
	if not can_fire: return
	if mag <= 0:
		_reload()
		return

	var w: Dictionary = weapons[weapon_index]
	can_fire = false
	mag -= 1
	ammo_changed.emit(mag, reserve, w.name)
	get_tree().create_timer(w.rate).timeout.connect(func(): can_fire = true)

	viewmodel.flash()
	viewmodel.add_kick(0.06)
	recoil += 0.010
	VisualFX.shake(0.35, 10.0)

	AudioFX.play_rifle(global_position)

	var muzzle_pos: Vector3 = viewmodel.muzzle.global_position
	var dir_fwd := -camera.global_transform.basis.z
	Effects.muzzle_smoke(get_parent(), muzzle_pos, dir_fwd)
	
	# Гильза
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	Effects.shell(get_parent(), muzzle_pos - dir_fwd * 0.3, right + up * 0.6)

	var spread: float = w.spread * (0.35 if Input.is_action_pressed("aim") else 1.0)
	var dir := dir_fwd
	dir += camera.global_transform.basis.x * randf_range(-spread, spread)
	dir += camera.global_transform.basis.y * randf_range(-spread, spread)
	dir = dir.normalized()

	var from := camera.global_position
	var to := from + dir * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var hit_pos: Vector3 = hit.position
		var hit_normal: Vector3 = hit.normal
		if hit.collider and hit.collider.has_method("take_damage"):
			var is_head: bool = hit.collider.has_method("is_headshot") and hit.collider.is_headshot(hit_pos)
			if hit.collider.has_method("register_hit_from"):
				hit.collider.register_hit_from(from)
			hit.collider.take_damage(int(w.dmg))
			Effects.blood(get_parent(), hit_pos, dir)
			if is_head:
				AudioFX.play_headshot(hit_pos)
			else:
				AudioFX.play_hit(hit_pos)
			var hud: Node = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("hitmarker"):
				hud.hitmarker(is_head)
		else:
			Effects.sparks(get_parent(), hit_pos, hit_normal)
			Effects.dust(get_parent(), hit_pos, hit_normal)
			AudioFX.play_impact(hit_pos)

	# Механика подавления (suppression): если луч не попал во врага напрямую,
	# но пролетел рядом с ним (враг в радиусе 2 м от линии огня) — враг
	# «прижимается к укрытию»: Enemy.get_suppressed().
	_apply_suppression(from, dir)

## Радиус подавления: расстояние от линии выстрела до врага, при котором
## враг считается подавленным и прячется.
const SUPPRESSION_RADIUS := 2.0

## Ищет ближайшего к линии выстрела живого врага и вызывает у него
## get_suppressed(), если дистанция от луча до врага <= SUPPRESSION_RADIUS.
func _apply_suppression(shot_from: Vector3, shot_dir: Vector3) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D):
			continue
		if not e.has_method("get_suppressed"):
			continue
		if e.get("dead") == true:
			continue
		# Проекция вектора «начало луча -> враг» на направление полёта пули
		var to_enemy: Vector3 = (e as Node3D).global_position - shot_from
		var along := to_enemy.dot(shot_dir)
		if along < 0.0 or along > 200.0:
			continue # враг позади стрелка или дальше дальности полёта пули
		# Кратчайшее расстояние от линии огня до позиции врага
		var perp := (to_enemy - shot_dir * along).length()
		if perp <= SUPPRESSION_RADIUS:
			e.get_suppressed()

func take_damage(amount: int, limb := "body") -> void:
	if not alive: return
	health = max(0, health - amount)
	time_since_last_damage = 0.0
	# Ранение ног: с вероятностью 50% игрок начинает истекать кровью
	if limb == "legs" and randf() > 0.5:
		is_bleeding = true
	health_changed.emit(health, max_health)
	VisualFX.flash_damage(0.85)
	VisualFX.shake(1.4, 4.0)
	if health <= 0:
		_die()

func _die() -> void:
	if not alive: return
	alive = false
	is_bleeding = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	died.emit()
