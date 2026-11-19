class_name Effects
extends RefCounted

static func sparks(parent: Node, pos: Vector3, normal: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 12; p.lifetime = 0.5; p.one_shot = true; p.explosiveness = 0.95
	p.direction = normal; p.spread = 45.0
	p.initial_velocity_min = 3.0; p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.02; p.scale_amount_max = 0.04
	p.color = Color(1.0, 0.75, 0.35)
	var mesh := BoxMesh.new(); mesh.size = Vector3.ONE
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

static func blood(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 18; p.lifetime = 0.6; p.one_shot = true; p.explosiveness = 1.0
	p.direction = dir; p.spread = 55.0
	p.initial_velocity_min = 2.0; p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.04; p.scale_amount_max = 0.09
	var mesh := SphereMesh.new(); mesh.radius = 1.0; mesh.height = 2.0
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.02, 0.02)
	mat.roughness = 0.4
	p.material_override = mat
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

static func dust(parent: Node, pos: Vector3, normal: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 8; p.lifetime = 0.7; p.one_shot = true
	p.direction = normal; p.spread = 60.0
	p.initial_velocity_min = 0.5; p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, -0.3, 0)
	p.scale_amount_min = 0.05; p.scale_amount_max = 0.12
	var mesh := BoxMesh.new(); mesh.size = Vector3.ONE
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.6, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

static func shell(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 0
	rb.mass = 0.02
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008; cyl.bottom_radius = 0.008; cyl.height = 0.025
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.25)
	mat.metallic = 0.9; mat.roughness = 0.3
	mi.material_override = mat
	rb.add_child(mi)
	parent.add_child(rb)
	rb.global_position = pos
	rb.linear_velocity = dir * randf_range(1.5, 2.5) + Vector3(randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5))
	rb.angular_velocity = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))
	parent.get_tree().create_timer(3.0).timeout.connect(rb.queue_free)

static func muzzle_smoke(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 5; p.lifetime = 1.0; p.one_shot = true; p.explosiveness = 0.8
	p.direction = dir; p.spread = 20.0
	p.initial_velocity_min = 1.0; p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.05; p.scale_amount_max = 0.15
	var mesh := SphereMesh.new(); mesh.radius = 1.0; mesh.height = 2.0
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.7, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.material_override = mat
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)