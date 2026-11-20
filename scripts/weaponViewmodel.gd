class_name WeaponViewmodel
extends Node3D

var weapons_data := [
	{"name": "AK-12", "type": "rifle", "ads_fov": 50.0, "path": "res://assets/models/weapons/ak12.glb"}
]

var camera: Camera3D
var base_pos := Vector3(0.22, -0.22, -0.45)
var ads_pos := Vector3(0.0, -0.09, -0.32)
var is_ads := false
var ads_t := 0.0
var bob_t := 0.0
var bob_amount := 0.0
var kick := Vector3.ZERO
var sway := Vector2.ZERO
var muzzle: Node3D
var muzzle_light: OmniLight3D
var muzzle_sprite: Sprite3D
var model_instance: Node3D

func setup(cam: Camera3D) -> void:
	camera = cam
	camera.add_child(self)
	position = base_pos
	switch_to(0)

func switch_to(i: int) -> void:
	if model_instance: model_instance.queue_free()
	_build_weapon(i)

func set_movement(speed: float) -> void:
	bob_amount = clampf(speed / 6.0, 0.0, 1.0)

func set_ads(active: bool) -> void:
	is_ads = active

func add_kick(amount: float) -> void:
	kick.z += amount

func add_sway(mouse_delta: Vector2) -> void:
	sway.x = clampf(sway.x - mouse_delta.x * 0.0006, -0.03, 0.03)
	sway.y = clampf(sway.y - mouse_delta.y * 0.0006, -0.03, 0.03)

func flash() -> void:
	if muzzle_light: muzzle_light.light_energy = 6.0
	if muzzle_sprite: muzzle_sprite.visible = true
	var t := create_tween()
	if muzzle_light: t.tween_property(muzzle_light, "light_energy", 0.0, 0.05)
	if muzzle_sprite: t.tween_callback(func(): muzzle_sprite.visible = false).set_delay(0.02)

func _process(delta: float) -> void:
	ads_t = lerp(ads_t, 1.0 if is_ads else 0.0, delta * 10.0)
	bob_t += delta * 8.0

	var target_pos := base_pos.lerp(ads_pos, ads_t)
	var bob_x := sin(bob_t) * 0.012 * bob_amount * (1.0 - ads_t * 0.85)
	var bob_y := absf(cos(bob_t)) * 0.014 * bob_amount * (1.0 - ads_t * 0.85)
	target_pos += Vector3(bob_x, bob_y, 0) + Vector3(sway.x, sway.y, 0)

	kick = kick.lerp(Vector3.ZERO, delta * 14.0)
	target_pos.z += kick.z

	position = position.lerp(target_pos, delta * 18.0)
	sway = sway.lerp(Vector2.ZERO, delta * 8.0)
	rotation.x = lerp(rotation.x, kick.z * 2.5, delta * 16.0)

	if camera:
		var target_fov: float = weapons_data[0].ads_fov if is_ads else 80.0
		camera.fov = lerp(camera.fov, target_fov, delta * 12.0)

func _build_weapon(_i: int) -> void:
	var path: String = weapons_data[_i].path if _i < weapons_data.size() else weapons_data[0].path

	# Загрузка 3D-модели оружия вместо процедурных кубов
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		model_instance = scene.instantiate()
		# Масштаб модели
		model_instance.scale = Vector3(1, 1, 1)
		# Разворот стволом вперёд (от камеры)
		model_instance.rotation_degrees = Vector3(0, 180, 0)
		add_child(model_instance)
	else:
		push_error("ОШИБКА: Не найден файл модели %s" % path)
		return

	# Узел Muzzle на конце ствола — точка вылета пули и вспышки
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = _find_muzzle_position()
	add_child(muzzle)

	# Свет и спрайт вспышки
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color("ffb04a")
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 8.0
	muzzle.add_child(muzzle_light)

	muzzle_sprite = Sprite3D.new()
	muzzle_sprite.texture = _flash_texture()
	muzzle_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	muzzle_sprite.pixel_size = 0.008
	muzzle_sprite.visible = false
	muzzle_sprite.no_depth_test = true
	muzzle.add_child(muzzle_sprite)

func _find_muzzle_position() -> Vector3:
	# Автоматически находим конец ствола по границам (AABB) загруженной модели.
	# Ствол направлен в -Z, поэтому берём самую дальнюю точку по оси Z.
	if model_instance:
		var mi := _find_mesh_instance(model_instance)
		if mi:
			var m_aabb: AABB = mi.global_transform * mi.aabb
			var rel: AABB = global_transform.affine_inverse() * m_aabb
			return Vector3(rel.position.x + rel.size.x * 0.5, rel.position.y + rel.size.y * 0.5, rel.position.z)
	# Запасная позиция, если границы не удалось вычислить
	return Vector3(0, 0.02, -0.4)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var res := _find_mesh_instance(child)
		if res:
			return res
	return null

func _flash_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 32:
		for y in 32:
			var d := Vector2(x - 16, y - 16).length()
			if d < 14.0:
				var a := clampf(1.0 - d / 14.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.7 + 0.3 * a, 0.3 + 0.4 * a, a))
	return ImageTexture.create_from_image(img)
