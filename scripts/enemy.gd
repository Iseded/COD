class_name Enemy
extends CharacterBody3D

signal killed

const SIGHT := 34.0
const STOP_DIST := 9.0
const GRAVITY := 18.0
const MODEL_PATH := "res://assets/models/enemy_soldier.glb"
const WEAPON_PATH := "res://assets/models/weapons/ak12.glb"

var max_health := 60
var health := 60
var speed := 3.2
var player: Node3D
var model_instance: Node3D
var weapon_instance: Node3D
var muzzle_point: Node3D
var anim_player: AnimationPlayer
var fire_cd := 0.0
var dead := false
var is_leg_wounded := false # враг ранен в ногу — будет хромать (скорость -50%)
var _last_shot_from := Vector3.ZERO
var _anim_names := {}
var _cur_anim := ""

## Вложенный мини-класс зоны урона (аналог отдельного Hitbox.gd,
## чтобы не создавать новых файлов): навешивается на каждую Area3D
## и хранит limb_name и damage_multiplier как обычные свойства.
class _Hitbox extends Area3D:
	var limb_name := "body"
	var damage_multiplier := 1.0

	func _init(limb: String, multiplier: float) -> void:
		limb_name = limb
		damage_multiplier = multiplier

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

	_build_hitboxes() # система зон урона (хитбоксов) как в Bodycam / Ready or Not

	_build_model()
	_attach_weapon_to_hand()

	fire_cd = randf_range(0.5, 1.4)

## Создаёт три Area3D-зоны урона: голова, тело, ноги.
## Каждая зона хранит limb_name и damage_multiplier; при попадании пули
## (collision_layer = 8 — слой пуль) зона передаёт урон через take_damage.
func _build_hitboxes() -> void:
	_add_hitbox("head", Vector3(0, 1.6, 0), Vector3(0.4, 0.4, 0.4), 3.0)
	_add_hitbox("body", Vector3(0, 1.0, 0), Vector3(0.6, 0.8, 0.4), 1.0)
	_add_hitbox("legs", Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.3), 0.5)

## Вспомогательная функция создания одной зоны урона (Area3D + BoxShape3D).
func _add_hitbox(limb: String, pos: Vector3, size: Vector3, multiplier: float) -> void:
	var area := _Hitbox.new(limb, multiplier)
	area.name = "Hitbox_" + limb.capitalize()
	area.position = pos
	# Зона не влияет на физику и не перекрывается телом врага:
	# слой 4 отключён из маски, слой 8 (пули) — оставлен для future-proofing
	area.collision_layer = 0
	area.collision_mask = 8
	area.monitorable = true
	# Каждой зоне присвоены limb_name и damage_multiplier (свойства скрипта зоны + meta)
	area.set_meta("limb_name", limb)
	area.set_meta("damage_multiplier", multiplier)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)

	area.input_event.connect(_on_hitbox_input_event.bind(limb, multiplier))

## Обработка попадания луча/мыши в зону урона (стандартный путь Area3D.input_event).
func _on_hitbox_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, limb: String, multiplier: float) -> void:
	if dead:
		return
	# Клик мышью по зоне — условный «выстрел» базовым уроном 25 с множителем зоны
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		take_damage(ceili(25.0 * multiplier), limb)

## Возвращает имя зоны урона ("head"/"body"/"legs"), содержащей мировую точку
## hit_pos; если точка вне зон — определяет лимб по высоте (запасной вариант).
func get_limb_at(hit_pos: Vector3) -> String:
	var hb := _hitbox_at(hit_pos)
	if hb != null:
		return hb.limb_name
	var local_y := (global_transform.affine_inverse() * hit_pos).y
	if local_y > 1.4: return "head"
	if local_y < 0.8: return "legs"
	return "body"

## Возвращает зону урона (унаследованную Area3D-скрипт _Hitbox), содержащую
## мировую точку hit_pos, или null. Приоритет: голова > тело > ноги.
func _hitbox_at(hit_pos: Vector3) -> _Hitbox:
	for limb in ["head", "body", "legs"]:
		var area := get_node_or_null("Hitbox_" + limb.capitalize()) as _Hitbox
		if area == null:
			continue
		var shape_node := area.get_node_or_null(^"CollisionShape3D")
		if shape_node == null:
			continue
		var box := shape_node.shape as BoxShape3D
		if box == null or box.volume <= 0.0:
			continue
		# переводим точку в локальные координаты зоны и проверяем принадлежность боксу
		var local := area.global_transform.affine_inverse() * hit_pos
		if AABB(-box.size * 0.5, box.size).has_point(local):
			return area
	return null

func _build_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		push_error("ОШИБКА: Модель врага не найдена по пути " + MODEL_PATH)
		return

	var scene: PackedScene = load(MODEL_PATH)
	model_instance = scene.instantiate()

	# === НАСТРОЙКИ МОДЕЛИ ВРАГА ===
	model_instance.scale = Vector3(1, 1, 1)
	# Разворачиваем лицом к игроку
	model_instance.rotation_degrees = Vector3(0, 180, 0)

	add_child(model_instance)

	# Ищем AnimationPlayer внутри загруженной модели
	var anims := model_instance.find_children("*", "AnimationPlayer", true, false)
	if anims.is_empty():
		# Некоторые glTF-файлы импортируются с AnimationTree вместо AnimationPlayer
		var trees := model_instance.find_children("*", "AnimationTree", true, false)
		if trees.size() > 0:
			anim_player = trees[0].get("animation_player")
		if anim_player == null:
			push_warning("В модели врага не найден AnimationPlayer — анимации будут пропущены")
			return

	_collect_anim_names()
	# Если клипа Idle не найдено — играем первый доступный анимационный клип модели
	if _anim_names.has("idle"):
		_play_anim(_anim_names["idle"])
	else:
		var all_anims := anim_player.get_animation_list()
		if all_anims.size() > 0:
			_play_anim(all_anims[0])

## Прикрепляет 3D-модель автомата к правой руке (кости Hand_R) скелета врага,
## чтобы оружие двигалось вместе со скелетными анимациями.
func _attach_weapon_to_hand() -> void:
	if model_instance == null:
		return
	if not ResourceLoader.exists(WEAPON_PATH):
		push_error("ОШИБКА: Модель оружия врага не найдена по пути " + WEAPON_PATH)
		return

	var hand := _find_hand_bone()

	weapon_instance = load(WEAPON_PATH).instantiate()

	# === НАСТРОЙКИ МОДЕЛИ АВТОМАТА ===
	weapon_instance.scale = Vector3(0.65, 0.65, 0.65)
	# Поворот/наклон: ствол смотрит вперёд (-Z) и слегка вверх — поза «готовности»
	weapon_instance.rotation_degrees = Vector3(-12.0, 90.0, 0.0)
	weapon_instance.position = Vector3(0.08, -0.06, 0.12)

	if hand != null:
		# Оружие — дочерний узел кости: наследует её трансформацию в анимации
		hand.add_child(weapon_instance)
	else:
		# Запасной вариант: кость Hand_R не найдена — крепим к яме-точке у правого плеча
		push_warning("Кость Hand_R не найдена в скелете врага — автомат прикреплён к яме-точке")
		var socket := Node3D.new()
		socket.name = "WeaponSocket"
		socket.position = Vector3(-0.3, 1.35, -0.15) # справа, на уровне груди, немного вперёд
		model_instance.add_child(socket)
		socket.add_child(weapon_instance)
		hand = socket

	# Точка дула на конце ствола — используется для выстрелов врага
	muzzle_point = Node3D.new()
	muzzle_point.name = "MuzzlePoint"
	muzzle_point.position = _find_muzzle_offset(weapon_instance)
	hand.add_child(muzzle_point)

## Ищет кость правой руки в скелете модели (Skeleton3D / BoneAttachment3D).
## Возвращает BoneAttachment3D — узел, который следует за костью во время анимаций,
## или null, если подходящей кости нет.
func _find_hand_bone() -> Node3D:
	# 1. Готовые BoneAttachment3D-узлы (если экспортированы в сцену glTF)
	var candidates := ["Hand_R", "hand_r", "right_hand", "RightHand", "handR", "mixamorigRightHand"]
	for cand in candidates:
		for att in model_instance.find_children(cand, "BoneAttachment3D", true, false):
			return att
	# 2. Ищем кость по имени внутри Skeleton3D и создаём BoneAttachment3D
	for skel_node in model_instance.find_children("*", "Skeleton3D", true, false):
		var skel := skel_node as Skeleton3D
		for i in skel.get_bone_count():
			var bone_name := skel.get_bone_name(i)
			var low := bone_name.to_lower()
			if not ("hand" in low or "arm" in low):
				continue
			# только ПРАВАЯ рука: суффикс _r / Right, но не Left / _l
			var is_right := low.ends_with("_r") or low.ends_with("right") or "_right" in low
			var is_left := "left" in low or low.ends_with("_l")
			if is_right and not is_left:
				var att := BoneAttachment3D.new()
				att.name = "HandR_Attachment"
				att.bone_name = bone_name
				skel.add_child(att)
				return att
	return null

## Вычисляет смещение до конца ствола (самая дальняя вперёд точка AABB оружия
## относительно его центра) — локальная позиция узла MuzzlePoint.
func _find_muzzle_offset(weapon: Node3D) -> Vector3:
	var aabb_total := AABB()
	var found := false
	for mi in weapon.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var local_aabb := m.transform * m.aabb
		if not found:
			aabb_total = local_aabb
			found = true
		else:
			aabb_total = aabb_total.merge(local_aabb)
	if not found:
		return Vector3(0, 0.02, -0.45) # запасное значение: конец ствола ~45 см вперёд
	var c := aabb_total.get_center()
	# конец ствола — минимальная Z (дальше всего вперёд) и средняя X/Y бокса
	return Vector3(c.x, c.y + 0.02, aabb_total.position.z)

## Собираем подходящие клипы по именам (Idle / Walk / Death),
## регистр и варианты написания не важны.
func _collect_anim_names() -> void:
	for name_str in anim_player.get_animation_list():
		var low := name_str.to_lower()
		if _anim_names.has("death") == false and ("death" in low or "die" in low or "dying" in low):
			_anim_names["death"] = name_str
		elif _anim_names.has("walk") == false and ("walk" in low or "run" in low):
			_anim_names["walk"] = name_str
		elif _anim_names.has("idle") == false and ("idle" in low):
			_anim_names["idle"] = name_str

func _play_anim(anim_name: String) -> void:
	if anim_player == null or anim_name == "" or _cur_anim == anim_name:
		return
	if not anim_player.has_animation(anim_name):
		return
	anim_player.play(anim_name)
	_cur_anim = anim_name

## Вызывается каждый кадр из _physics_process: ходьба при движении, покой при остановке.
func _update_locomotion_animation(is_moving: bool) -> void:
	if dead or anim_player == null:
		return
	_play_anim(_anim_names.get("walk" if is_moving else "idle", ""))

func _physics_process(delta: float) -> void:
	if dead: return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not is_on_floor(): velocity.y -= GRAVITY * delta
	else: velocity.y = 0.0

	var moving := false
	if player and is_instance_valid(player) and player.get("alive") == true:
		var to := player.global_position - global_position
		to.y = 0
		var dist := to.length()
		
		if dist < SIGHT:
			# Ранение в ногу — враг хромает: скорость передвижения уменьшена на 50%
			var current_speed := speed
			if is_leg_wounded:
				current_speed = speed * 0.5
			if dist > STOP_DIST:
				var d := to.normalized()
				velocity.x = d.x * current_speed
				velocity.z = d.z * current_speed
				moving = true
			else:
				velocity.x = 0.0
				velocity.z = 0.0
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), delta * 6.0)
			_try_shoot(dist, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# Ходьба при движении, покой при остановке
	_update_locomotion_animation(moving)

func _try_shoot(dist: float, delta: float) -> void:
	fire_cd -= delta
	if fire_cd > 0.0: return
	fire_cd = randf_range(0.75, 1.6)

	var acc := clampf(1.0 - dist / 40.0, 0.35, 0.92)
	if randf() > acc: return

	AudioFX.play_enemy_shot(global_position)

	var from := global_position + Vector3(0, 1.2, 0)
	# Выстрел из дула автомата в руке (если узел MuzzlePoint найден)
	if muzzle_point != null and is_instance_valid(muzzle_point):
		from = muzzle_point.global_position
	var to := player.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider == player:
		player.take_damage(randi_range(7, 12))

func is_headshot(hit_pos: Vector3) -> bool:
	# Определяем зону урона по мировой точке попадания (хитбоксы Head/Body/Legs)
	var hb := _hitbox_at(hit_pos)
	if hb != null:
		return hb.limb_name == "head"
	# Запасная проверка по высоте, если точка не попала ни в одну зону
	var local := global_transform.affine_inverse() * hit_pos
	return local.y > 1.55

func register_hit_from(pos: Vector3) -> void:
	_last_shot_from = pos

## Нанесение урона с учётом зоны (лимба) попадания:
## head — урон x3.0, legs — враг начинает хромать (is_leg_wounded = true).
## amount может быть int или float (совместимость со старым вызовом из player.gd).
func take_damage(amount, limb: String = "body") -> void:
	if dead: return
	var dmg := float(amount)
	match limb:
		"head":
			dmg *= 3.0 # множитель урона головы
		"legs":
			is_leg_wounded = true # попадание в ногу — враг хромает (-50% скорости)
		"body":
			pass
		_:
			# неизвестная зона — урон без модификатора
			push_warning("Enemy.take_damage: неизвестная зона '%s', урон без модификатора" % limb)
	health -= int(round(dmg))
	if health <= 0: _die()

func _die() -> void:
	dead = true
	collision_layer = 0
	remove_from_group("enemy")
	velocity = Vector3.ZERO
	killed.emit()
	AudioFX.play_hit(global_position)
	Effects.blood(get_parent(), global_position + Vector3(0, 1.0, 0), Vector3.UP)

	# Анимация смерти (health <= 0): играем клип и удаляем тело после его проигрывания
	var death_anim := String(_anim_names.get("death", ""))
	if anim_player != null and death_anim != "" and anim_player.has_animation(death_anim):
		_play_anim(death_anim)
		var sec := 2.5
		var clip: Animation = anim_player.get_animation(death_anim)
		if clip:
			sec = maxf(clip.length + 0.3, 0.5)
		get_tree().create_timer(sec).timeout.connect(queue_free)
	else:
		queue_free()
