extends StaticBody3D
## DestructibleWall.gd
## Разрушаемая стена: при получении урона (или взрыве) разбивается на
## кубики-RigidBody3D. Количество кубиков ограничено (<= 100), чтобы
## не нагружать слабые процессоры.

const MAX_CHUNKS := 100          # жёсткий лимит на количество кубиков
const CHUNK_LIFETIME := 5.0      # секунды, через которые кубики удаляются
const EXPLOSION_IMPULSE := 8.0   # базовая сила импульса при разрушении

@export var health := 100.0                 # прочность стены
@export var chunk_size := 0.5               # желаемый размер кубика (метры)

var _chunks: Array[RigidBody3D] = []        # все созданные кубики
var _cleanup_timer: SceneTreeTimer = null   # ссылка, чтобы таймер жил до срабатывания
var _shattered := false                     # стена уже разрушена (защита от двойного вызова)


func _ready() -> void:
	# Кубики-обломки должны взаимодействовать со статичным миром (layer_1 "world")
	collision_layer = 1
	collision_mask = 1


func take_damage(amount: float, is_explosion: bool = false) -> void:
	if _shattered:
		return  # защита от повторного разрушения за один кадр
	health -= amount
	if is_explosion or health <= 0.0:
		_shattered = true
		_shatter()


func _shatter() -> void:
	# --- 1. Получаем размеры стены из её коллизии/меша -------------------
	var wall_size := Vector3.ONE
	var mesh_instance := get_node_or_null("Mesh") as MeshInstance3D

	if mesh_instance and mesh_instance.mesh:
		wall_size = mesh_instance.mesh.get_aabb().size
	else:
		# Фолбэк: берём размер из CollisionShape3D, если меша нет
		for child in get_children():
			if child is CollisionShape3D:
				var cshape := (child as CollisionShape3D).shape as BoxShape3D
				if cshape:
					wall_size = cshape.size
					break

	# --- 2. Удаляем текущую модель и коллизию стены ----------------------
	if mesh_instance:
		mesh_instance.queue_free()
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()

	# --- 3. Считаем реальный размер кубика, чтобы их было не больше 100 --
	# Количество кубиков = ceil(size / step) по каждой оси.
	# Если при заданном chunk_size кубиков получается больше MAX_CHUNKS,
	# увеличиваем шаг (кубики становятся крупнее).
	var step := _fit_chunk_size(wall_size, chunk_size)

	# Центры кубиков раскладываем относительно центра стены
	# (предполагаем, что стена выровнена по своему pivot-у).
	var half := wall_size * 0.5

	# --- 4. Заполняем объём стены кубиками RigidBody3D -------------------
	var nx := maxi(1, int(ceil(wall_size.x / step)))
	var ny := maxi(1, int(ceil(wall_size.y / step)))
	var nz := maxi(1, int(ceil(wall_size.z / step)))

	var chunk_mesh := BoxMesh.new()
	chunk_mesh.size = Vector3(step, step, step)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.48)  # нейтральный «бетонный» цвет

	for x in nx:
		for y in ny:
			for z in nz:
				var pos := Vector3(
					-half.x + step * (float(x) + 0.5),
					-half.y + step * (float(y) + 0.5),
					-half.z + step * (float(z) + 0.5)
				)
				_spawn_chunk(pos, step, chunk_mesh, mat)

	# --- 5. Таймер на удаление обломков ----------------------------------
	# ВАЖНО: таймер создаётся НЕ дочерним узлом стены, иначе queue_free()
	# стены остановил бы его до срабатывания. create_timer() возвращает
	# однократный SceneTreeTimer, который переживёт удаление стены.
	var timer := get_tree().create_timer(CHUNK_LIFETIME)
	timer.timeout.connect(_free_chunks)
	_cleanup_timer = timer

	# Саму стену тоже убираем — она уже «разрушена»
	queue_free()


## Подбирает размер кубика так, чтобы общее число кубиков не превышало
## MAX_CHUNKS. Если стена большая — кубики увеличиваются.
func _fit_chunk_size(size: Vector3, desired: float) -> float:
	var step := maxf(desired, 0.05)
	while true:
		var count := 1.0
		count *= maxf(1.0, ceil(size.x / step))
		count *= maxf(1.0, ceil(size.y / step))
		count *= maxf(1.0, ceil(size.z / step))
		if count <= float(MAX_CHUNKS) or step >= minf(size.x, minf(size.y, size.z)):
			break
		step += 0.05  # плавно укрупняем, пока не влезем в лимит
	return step


## Создаёт один кубик-обломок со случайным импульсом от центра стены.
func _spawn_chunk(local_pos: Vector3, step: float, mesh: BoxMesh, mat: StandardMaterial3D) -> void:
	var body := RigidBody3D.new()
	body.position = local_pos  # локально относительно стены (её pivot = центр)

	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(step, step, step)
	shape_node.shape = box
	body.add_child(shape_node)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	get_parent().add_child(body)
	body.global_position = global_transform.origin + local_pos

	# Случайный импульс «от центра взрыва» (центр стены) + лёгкий подлёт вверх
	var dir := local_pos.normalized() if local_pos.length_squared() > 0.0001 \
		else Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
	var impulse := dir * EXPLOSION_IMPULSE * randf_range(0.6, 1.4)
	impulse += Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.0), randf_range(-1.5, 1.5))
	body.apply_impulse(impulse)

	_chunks.append(body)


## Удаляет все кубики по истечении таймера.
func _free_chunks() -> void:
	for chunk in _chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunks.clear()
