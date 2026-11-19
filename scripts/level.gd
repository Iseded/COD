class_name Level
extends Node3D

signal enemy_killed
signal all_enemies_dead
signal mission_complete

const ARENA := 32.0

const SPAWNS := [
	Vector3(-15, 0.4, -15), Vector3(15, 0.4, -15), Vector3(0, 0.4, -20),
	Vector3(-20, 0.4, 0),   Vector3(20, 0.4, 0),   Vector3(-10, 0.4, -8),
	Vector3(10, 0.4, -8),   Vector3(0, 0.4, -10),  Vector3(-18, 0.4, 10),
	Vector3(18, 0.4, 10),
]

var mission: Dictionary
var player_spawn := Vector3(0, 1.2, 22)
var enemies_alive := 0
var killed := 0
var total := 0
var wave := 0
var extraction_pos := Vector3(0, 0.2, -24)
var extraction_active := false
var extraction_marker: Node3D
var finished := false
var _spawn_cursor := 0

func build(m: Dictionary) -> void:
	mission = m
	_setup_environment()
	_build_arena()
	_build_decor()
	_build_cover()
	_build_extraction()
	_spawn_wave()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("0a1018")
	sky_mat.sky_horizon_color = Color("38495a")
	sky_mat.ground_bottom_color = Color("050708")
	sky_mat.ground_horizon_color = Color("182028")
	sky_mat.sun_angle_max = 15.0
	sky_mat.sun_curve = 0.15
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.ambient_light_sky_contribution = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.fog_enabled = true
	env.fog_light_color = Color("1c2a35")
	env.fog_light_energy = 0.5
	env.fog_density = 0.014
	env.fog_sky_affect = 0.4
	env.fog_aerial_perspective = 0.5

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color("8ea8bd")
	env.volumetric_fog_emission = Color("0a1218")
	env.volumetric_fog_emission_energy = 0.1
	env.volumetric_fog_gi_inject = 0.3
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_length = 64.0

	env.sdfgi_enabled = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_energy = 1.1

	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.6
	env.ssao_power = 1.5
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 1.4

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0

	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.9
	env.adjustment_color_correction = _cod_grade()

	

	

	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -55, 0)
	sun.light_color = Color("b8c8d8")
	sun.light_energy = 1.3
	sun.light_volumetric_fog_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.5
	add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 145, 0)
	rim.light_color = Color("3a6080")
	rim.light_energy = 0.45
	add_child(rim)

	var spots := [
		{"pos": Vector3(-12, 6, -20), "target": Vector3(-8, 0, 10),  "color": Color("a8c4e0"), "energy": 8.0, "angle": 24.0, "range": 34.0},
		{"pos": Vector3( 12, 6, -20), "target": Vector3( 8, 0, 10),  "color": Color("a8c4e0"), "energy": 8.0, "angle": 24.0, "range": 34.0},
		{"pos": Vector3(  0, 8,  22), "target": Vector3( 0, 0,  0),  "color": Color("ffb878"), "energy": 6.0, "angle": 30.0, "range": 30.0},
		{"pos": Vector3(-22, 5,   0), "target": Vector3(-8, 0,  0),  "color": Color("ff7050"), "energy": 5.0, "angle": 28.0, "range": 26.0},
		{"pos": Vector3( 22, 5,   0), "target": Vector3( 8, 0,  0),  "color": Color("70d0ff"), "energy": 5.0, "angle": 28.0, "range": 26.0},
	]
	for s in spots:
		var sp := SpotLight3D.new()
		sp.position = s.pos
		sp.look_at_from_position(s.pos, s.target, Vector3.UP)
		sp.light_color = s.color
		sp.light_energy = s.energy
		sp.spot_angle = s.angle
		sp.spot_range = s.range
		sp.spot_attenuation = 1.2
		sp.light_volumetric_fog_energy = 3.0
		sp.shadow_enabled = true
		add_child(sp)

	var lamps := [
		[Vector3(-18, 3.5, -14), Color("ff7030"), 2.5],
		[Vector3( 18, 3.5, -14), Color("ff7030"), 2.5],
		[Vector3(-18, 3.5,  14), Color("40a0ff"), 2.5],
		[Vector3( 18, 3.5,  14), Color("40a0ff"), 2.5],
		[Vector3(  0, 4.5,   0), Color("ffd080"), 2.0],
		[Vector3(-10, 3.0,  20), Color("50ff80"), 1.8],
		[Vector3( 10, 3.0,  20), Color("ff3080"), 1.8],
	]
	for l in lamps:
		var om := OmniLight3D.new()
		om.position = l[0]
		om.light_color = l[1]
		om.light_energy = l[2]
		om.omni_range = 12.0
		om.omni_attenuation = 1.6
		om.light_volumetric_fog_energy = 2.5
		add_child(om)

func _cod_grade() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.10, 0.16))
	g.set_color(1, Color(1.00, 0.96, 0.90))
	g.add_point(0.35, Color(0.30, 0.38, 0.46))
	g.add_point(0.65, Color(0.75, 0.78, 0.82))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _box_m(pos: Vector3, size: Vector3, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		add_child(body)

func _build_arena() -> void:
	_box_m(Vector3(0, -0.5, 0), Vector3(ARENA * 2, 1, ARENA * 2), Textures.floor())
	var h := 6.0
	var w := ARENA
	var walls := [
		[Vector3(0, h / 2, -w), Vector3(w * 2, h, 1), Textures.concrete()],
		[Vector3(0, h / 2,  w), Vector3(w * 2, h, 1), Textures.concrete()],
		[Vector3(-w, h / 2, 0), Vector3(1, h, w * 2), Textures.rust()],
		[Vector3( w, h / 2, 0), Vector3(1, h, w * 2), Textures.concrete()],
	]
	for wd in walls:
		_box_m(wd[0], wd[1], wd[2])
	var mt := Textures.metal()
	for z in [-w + 0.6, w - 0.6]:
		_box_m(Vector3(0, 1.2, z), Vector3(w * 2, 0.15, 0.15), mt)
	for x in [-w + 0.6, w - 0.6]:
		_box_m(Vector3(x, 1.2, 0), Vector3(0.15, 0.15, w * 2), mt)
	for i in 4:
		var py := 4.5 + i * 0.3
		_box_m(Vector3(0, py, -w + 1.0 + i * 0.4), Vector3(w * 2, 0.15, 0.15), mt, false)

func _build_decor() -> void:
	var containers := [
		[Vector3(-14, 1.3, -18), Vector3(6, 2.6, 2.4), Color("8b3a1e")],
		[Vector3( 14, 1.3, -18), Vector3(6, 2.6, 2.4), Color("2a5a2a")],
		[Vector3(-14, 1.3,  18), Vector3(6, 2.6, 2.4), Color("1e3a6b")],
		[Vector3( 14, 1.3,  18), Vector3(6, 2.6, 2.4), Color("6b4a1e")],
	]
	for c in containers:
		_box_m(c[0], c[1], Textures.container(c[2]))

	var wood_mat := _simple_mat(Color("6b4a20"), 0.0, 0.9)
	var crate_spots := [
		[Vector3(-6, 0.4, 20), 1], [Vector3(-6, 1.2, 20), 0],
		[Vector3(-5.2, 0.4, 20), 0], [Vector3(7, 0.4, 18), 1],
		[Vector3(7, 1.2, 18), 0], [Vector3(22, 0.4, -6), 1],
		[Vector3(-22, 0.4, -6), 1], [Vector3(20, 0.4, 6), 1],
		[Vector3(-20, 0.4, 8), 1],
	]
	for cs in crate_spots:
		_box_m(cs[0], Vector3(0.8, 0.8, 0.8), wood_mat, cs[1] == 1)

	var barrel_colors := [Color("a02a1a"), Color("a02a1a"), Color("1a3a6b"), Color("a07a1a")]
	var barrel_spots := [
		Vector3(-10, 0.45, 22), Vector3(-9.2, 0.45, 22.4), Vector3(-9.6, 0.45, 23.2),
		Vector3(12, 0.45, 20),  Vector3(13, 0.45, 20.5),
		Vector3(-24, 0.45, 4),  Vector3(-23, 0.45, 4.5),  Vector3(-24, 1.35, 4.2),
		Vector3(24, 0.45, -4),  Vector3(23, 0.45, -4.5),
		Vector3(6, 0.45, -22),  Vector3(7, 0.45, -22.2),
	]
	for i in barrel_spots.size():
		_barrel(barrel_spots[i], barrel_colors[i % barrel_colors.size()])

	var sand_mat := _simple_mat(Color("8a7a52"), 0.0, 0.95)
	var sandbags := [
		Vector3(-4, 0.35, 8), Vector3(-3.4, 0.35, 8), Vector3(-2.8, 0.35, 8),
		Vector3(-4, 0.75, 8), Vector3(-3.4, 0.75, 8),
		Vector3(10, 0.35, -8), Vector3(10.6, 0.35, -8), Vector3(11.2, 0.35, -8),
		Vector3(10.4, 0.75, -8),
		Vector3(-16, 0.35, -8), Vector3(-16, 0.75, -8),
	]
	for sb in sandbags:
		_box_m(sb, Vector3(0.6, 0.35, 0.6), sand_mat, true)

	var tire_mat := _simple_mat(Color("0a0a0a"), 0.0, 0.95)
	for t in [Vector3(-20, 0.25, 20), Vector3(-19, 0.25, 20.5), Vector3(20, 0.25, 20), Vector3(-20, 0.65, 20)]:
		_tire(t, tire_mat)

	_pole_with_lamp(Vector3(-25, 0, -10), Color("ff6020"))
	_pole_with_lamp(Vector3( 25, 0, -10), Color("ff6020"))
	_pole_with_lamp(Vector3(-25, 0,  10), Color("4080ff"))
	_pole_with_lamp(Vector3( 25, 0,  10), Color("4080ff"))

	_sign(Vector3(0, 3.5, -31.4), "ОПАСНАЯ ЗОНА", Color("c02020"), Color("ffffff"))
	_sign(Vector3(-31.4, 3.5, 0), "ВЫХОД", Color("207020"), Color("ffffff"))
	_sign(Vector3( 31.4, 3.5, 0), "СТОП", Color("c0a020"), Color("101010"))

	_graffiti(Vector3(-15, 2.5, -31.35), Vector3(3, 2, 0.05), Color("c02040"))
	_graffiti(Vector3( 12, 2.5, -31.35), Vector3(4, 2, 0.05), Color("2040c0"))
	_graffiti(Vector3(-31.35, 2.5, 5),   Vector3(0.05, 2, 4), Color("c0a020"))
	_graffiti(Vector3( 31.35, 2.5, -8),  Vector3(0.05, 2, 3), Color("20c040"))

func _simple_mat(color: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m

func _barrel(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35; cyl.bottom_radius = 0.35; cyl.height = 0.9
	mi.mesh = cyl
	mi.material_override = _simple_mat(color, 0.4, 0.6)
	mi.position = pos
	add_child(mi)
	for y in [-0.3, 0.0, 0.3]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34; torus.outer_radius = 0.37
		torus.rings = 12; torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = _simple_mat(Color("101010"), 0.6, 0.5)
		ring.position = pos + Vector3(0, y, 0)
		add_child(ring)
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35; shape.height = 0.9
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _tire(pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25; torus.outer_radius = 0.5
	torus.rings = 16; torus.ring_segments = 8
	mi.mesh = torus
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.x = 90
	add_child(mi)

func _pole_with_lamp(pos: Vector3, light_color: Color) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08; cyl.bottom_radius = 0.12; cyl.height = 4.0
	pole.mesh = cyl
	pole.material_override = _simple_mat(Color("2a2a2a"), 0.6, 0.7)
	pole.position = pos + Vector3(0, 2.0, 0)
	add_child(pole)

	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25; sphere.height = 0.5
	lamp.mesh = sphere
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = light_color
	lamp_mat.emission_enabled = true
	lamp_mat.emission = light_color
	lamp_mat.emission_energy_multiplier = 3.0
	lamp.material_override = lamp_mat
	lamp.position = pos + Vector3(0, 4.2, 0)
	add_child(lamp)

	var om := OmniLight3D.new()
	om.position = pos + Vector3(0, 4.2, 0)
	om.light_color = light_color
	om.light_energy = 2.5
	om.omni_range = 8.0
	om.light_volumetric_fog_energy = 3.0
	add_child(om)

func _sign(pos: Vector3, text: String, bg: Color, fg: Color) -> void:
	var plane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 0.7)
	plane.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = bg
	mat.emission_enabled = true
	mat.emission = bg
	mat.emission_energy_multiplier = 0.6
	plane.material_override = mat
	plane.position = pos
	add_child(plane)

	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.modulate = fg
	label.position = pos + Vector3(0, 0, 0.01)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)

func _graffiti(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_color.a = 0.75
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

func _build_cover() -> void:
	var covers := [
		[Vector3(-8, 1, 4), Vector3(4, 2, 2)],
		[Vector3(9, 1, -2), Vector3(3, 2, 6)],
		[Vector3(0, 0.75, -4), Vector3(6, 1.5, 2)],
		[Vector3(-14, 1.25, -10), Vector3(5, 2.5, 3)],
		[Vector3(14, 1, 8), Vector3(4, 2, 4)],
		[Vector3(-3, 1.5, 12), Vector3(2, 3, 6)],
		[Vector3(4, 0.5, -16), Vector3(8, 1, 2)],
		[Vector3(-20, 1, 16), Vector3(3, 2, 3)],
	]
	var mat := Textures.rust()
	for c in covers:
		_box_m(c[0], c[1], mat)

func _build_extraction() -> void:
	if mission.get("type", "") != "extract":
		return
	extraction_marker = Node3D.new()
	extraction_marker.position = extraction_pos
	add_child(extraction_marker)

	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0; cyl.bottom_radius = 3.0; cyl.height = 0.15
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("2f8fff")
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	extraction_marker.add_child(mi)

	var beam := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 2.4; bcyl.bottom_radius = 2.4; bcyl.height = 9.0
	beam.mesh = bcyl
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.2, 0.6, 1.0, 0.12)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bmat
	beam.position.y = 4.5
	extraction_marker.add_child(beam)

	extraction_marker.visible = false

func _spawn_wave() -> void:
	var per_wave: int = int(mission.get("enemies", 4))
	total += per_wave
	for i in per_wave:
		_spawn_one()

func _spawn_one() -> void:
	var pos: Vector3 = SPAWNS[_spawn_cursor % SPAWNS.size()]
	_spawn_cursor += 1
	pos += Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	var e := Enemy.new()
	e.position = pos
	add_child(e)
	e.killed.connect(_on_enemy_killed)
	enemies_alive += 1

func _on_enemy_killed() -> void:
	enemies_alive -= 1
	killed += 1
	enemy_killed.emit()
	if enemies_alive > 0:
		return

	all_enemies_dead.emit()
	var mtype: String = mission.get("type", "eliminate")

	if mtype == "survive":
		wave += 1
		if wave >= int(mission.get("waves", 3)):
			_finish()
		else:
			await get_tree().create_timer(2.0).timeout
			_spawn_wave()
	elif mtype == "extract":
		extraction_active = true
		if extraction_marker:
			extraction_marker.visible = true
	else:
		_finish()

func _finish() -> void:
	if finished: return
	finished = true
	mission_complete.emit()

func _process(_delta: float) -> void:
	if not extraction_active or finished:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null: return
	if p.global_position.distance_to(extraction_pos) < 3.0:
		_finish()
