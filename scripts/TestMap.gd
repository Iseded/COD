extends Node3D
## TestMap.gd — тестовая карта для проверки ИИ (подавление/прятки в укрытия),
## светошума и разрушаемых стен. Строится полностью кодом: пол + навмеш,
## ящики-укрытия, стена из 5 разрушаемых сегментов, спавн врагов, свет и туман.
## Наследует сигналы Level (enemy_killed / all_enemies_dead), чтобы HUD работал
## без изменений; сам игровой код TestMap не содержит.

signal enemy_killed
signal all_enemies_dead
signal mission_complete # заглушка: TestMap не управляет миссиями, но Main.gd подключает этот сигнал

const FLOOR_SIZE := 60.0            # размер пола 60x60
const ENEMY_SCRIPT_PATH := "res://scripts/enemy.gd"
const DESTRUCTIBLE_WALL_SCRIPT := "res://scripts/DestructibleWall.gd"

var enemies_alive := 0
var killed := 0

func build(parent: Node3D) -> void:
	parent.add_child(self)
	_setup_environment()
	_build_nav_floor()
	_build_crate_covers()
	_build_destructible_wall()
	_spawn_enemies()

## Освещение: DirectionalLight3D + WorldEnvironment с лёгким туманом,
## чтобы карта не была чёрной.
func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1c2733")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8fa6b8")
	env.ambient_light_energy = 0.7

	env.fog_enabled = true
	env.fog_light_color = Color("2a3a48")
	env.fog_density = 0.012
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

## Пол (60x60) внутри NavigationRegion3D + запечённый навмеш,
## чтобы враги могли ходить по карте.
func _build_nav_floor() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavFloor"
	add_child(region)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	region.add_child(floor_body)

	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.33, 0.31)
	mat.roughness = 0.95
	mi.material_override = mat
	floor_body.add_child(mi)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(FLOOR_SIZE, 0.4, FLOOR_SIZE)
	cs.shape = shape
	cs.position = Vector3(0, -0.2, 0)
	floor_body.add_child(cs)

	# Навмеш пекается только после попадания узла в дерево (нужен global_transform).
	if is_inside_tree():
		_bake_region(region, mi)
	else:
		tree_entered.connect(_bake_region.bind(region, mi), CONNECT_ONE_SHOT)

func _bake_region(region: NavigationRegion3D, source: MeshInstance3D) -> void:
	# Небольшое смещение источника вверх, чтобы навмеш легла поверх пола.
	source.position = Vector3(0, 0.05, 0)
	region.navigation_mesh = NavigationMesh.new()
	var nm := region.navigation_mesh as NavigationMesh
	nm.cell_size = 0.25
	nm.agent_radius = 0.4
	nm.filter_baking_aabb = AABB(Vector3(-FLOOR_SIZE * 0.5, 0.0, -FLOOR_SIZE * 0.5),
		Vector3(FLOOR_SIZE, 4.0, FLOOR_SIZE))
	region.bake_navigation_mesh(false)

## Укрытия для ИИ: обычные ящики StaticBody3D + CollisionShape3D + MeshInstance3D.
func _build_crate_covers() -> void:
	var positions := [
		Vector3(-8, 0.6, 6),
		Vector3(7, 0.6, 2),
		Vector3(-3, 0.6, -8),
		Vector3(12, 0.6, -12),
		Vector3(-14, 0.6, -4),
		Vector3(2, 0.6, 14),
	]
	for p in positions:
		_make_crate(p, Vector3(1.2, 1.2, 1.2), randf_range(0.0, PI))

func _make_crate(pos: Vector3, size: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.name = "CrateCover"
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.36, 0.22)
	mat.roughness = 0.85
	mi.material_override = mat
	body.add_child(mi)

## Разрушаемая стена для C4/гранат: длинная стена из 5 нод DestructibleWall.gd.
func _build_destructible_wall() -> void:
	var wall_script := load(DESTRUCTIBLE_WALL_SCRIPT)
	var seg_size := Vector3(2.0, 2.5, 0.4)
	var z := -18.0
	for i in 5:
		var wall: StaticBody3D = wall_script.new()
		wall.name = "DestructibleWall_%d" % (i + 1)
		wall.position = Vector3(-4.0 + i * 2.0, seg_size.y * 0.5, z)
		add_child(wall)

		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = seg_size
		cs.shape = box
		wall.add_child(cs)

		var mi := MeshInstance3D.new()
		mi.name = "Mesh" # DestructibleWall._shatter() ищет дочерний узел "Mesh"
		var mesh := BoxMesh.new()
		mesh.size = seg_size
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.52, 0.48)
		mat.roughness = 0.9
		mi.material_override = mat
		wall.add_child(mi)

## Спавн врагов: 4 ноды Enemy через load("res://scripts/Enemy.gd").new()
## в разных концах карты. Учёт killed/enemies_alive нужен только для того,
## чтобы HUD (сигналы enemy_killed / all_enemies_dead) работал без изменений.
func _spawn_enemies() -> void:
	var enemy_script := load(ENEMY_SCRIPT_PATH)
	var spawn_points := [
		Vector3(-18, 0.4, -18),
		Vector3(18, 0.4, -18),
		Vector3(-18, 0.4, 12),
		Vector3(16, 0.4, 10),
	]
	for p in spawn_points:
		var e: CharacterBody3D = enemy_script.new()
		e.name = "TestEnemy"
		add_child(e)
		e.global_position = p
		e.killed.connect(_on_enemy_killed)
		enemies_alive += 1

func _on_enemy_killed() -> void:
	enemies_alive -= 1
	killed += 1
	enemy_killed.emit()
	if enemies_alive <= 0:
		all_enemies_dead.emit()
