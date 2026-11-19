class_name Enemy
extends CharacterBody3D

signal killed

const SIGHT := 34.0
const STOP_DIST := 9.0
const GRAVITY := 18.0
const MODEL_PATH := "res://assets/models/enemy_soldier.glb"

var max_health := 60
var health := 60
var speed := 3.2
var player: Node3D
var model_instance: Node3D
var anim_player: AnimationPlayer
var fire_cd := 0.0
var dead := false
var _last_shot_from := Vector3.ZERO

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	if ResourceLoader.exists(MODEL_PATH):
		var scene: PackedScene = load(MODEL_PATH)
		model_instance = scene.instantiate()
		
		# === НАСТРОЙКИ МОДЕЛИ ВРАГА ===
		# Если солдат слишком большой - попробуй 0.1. Если маленький - 1.0
		model_instance.scale = Vector3(1, 1, 1) 
		# Разворачиваем лицом к игроку
		model_instance.rotation_degrees = Vector3(0, 180, 0) 
		
		add_child(model_instance)
		
		# Ищем анимации
		var anims = model_instance.find_children("*", "AnimationPlayer", true, false)
		if anims.size() > 0:
			anim_player = anims[0]
			var anims_list = anim_player.get_animation_list()
			
			# ВАЖНО: Проверь в Godot, как называются твои анимации (Idle, Walk, Death)
			# и впиши их сюда, если они называются иначе!
			if "Idle" in anims_list: 
				anim_player.play("Idle")
			elif anims_list.size() > 0: 
				anim_player.play(anims_list[0])
	else:
		print("ОШИБКА: Модель врага не найдена по пути ", MODEL_PATH)

	fire_cd = randf_range(0.5, 1.4)

func _physics_process(delta: float) -> void:
	if dead: return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not is_on_floor(): velocity.y -= GRAVITY * delta
	else: velocity.y = 0.0

	if player and is_instance_valid(player) and player.get("alive") == true:
		var to := player.global_position - global_position
		to.y = 0
		var dist := to.length()
		
		if dist < SIGHT:
			if dist > STOP_DIST:
				var d := to.normalized()
				velocity.x = d.x * speed
				velocity.z = d.z * speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), delta * 6.0)
			_try_shoot(dist, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

func _try_shoot(dist: float, delta: float) -> void:
	fire_cd -= delta
	if fire_cd > 0.0: return
	fire_cd = randf_range(0.75, 1.6)

	var acc := clampf(1.0 - dist / 40.0, 0.35, 0.92)
	if randf() > acc: return

	AudioFX.play_enemy_shot(global_position)

	var from := global_position + Vector3(0, 1.2, 0)
	var to := player.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider == player:
		player.take_damage(randi_range(7, 12))

func is_headshot(hit_pos: Vector3) -> bool:
	var local := global_transform.affine_inverse() * hit_pos
	return local.y > 1.55

func register_hit_from(pos: Vector3) -> void:
	_last_shot_from = pos

func take_damage(amount: int) -> void:
	if dead: return
	health -= amount
	if health <= 0: _die()

func _die() -> void:
	dead = true
	collision_layer = 0
	remove_from_group("enemy")
	killed.emit()
	AudioFX.play_hit(global_position)
	Effects.blood(get_parent(), global_position + Vector3(0, 1.0, 0), Vector3.UP)
	
	if anim_player:
		var anims_list = anim_player.get_animation_list()
		if "Death" in anims_list:
			anim_player.play("Death")
			get_tree().create_timer(2.5).timeout.connect(queue_free)
			return
	queue_free()
