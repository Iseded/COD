class_name SoldierRig
extends Node3D

const PALETTES := {
	"enemy": {
		"uniform": Color("3a4a2a"), "pants":   Color("2d3a1e"),
		"helmet":  Color("1f2a14"), "vest":    Color("151515"),
		"boots":   Color("0f0f0f"), "gloves":  Color("252525"),
		"skin":    Color("d9a066"), "goggles": Color("1a2a3a"),
		"gun":     Color("1a1a1a"),
	},
	"friendly": {
		"uniform": Color("2f4256"), "pants":   Color("243444"),
		"helmet":  Color("1a2a3a"), "vest":    Color("101820"),
		"boots":   Color("0a0a0a"), "gloves":  Color("1a1a1a"),
		"skin":    Color("d9a066"), "goggles": Color("203040"),
		"gun":     Color("15181c"),
	},
}

const BONES := {
	"Root":       ["",           Vector3( 0.00,  0.00, 0)],
	"Hips":       ["Root",       Vector3( 0.00,  1.00, 0)],
	"Spine":      ["Hips",       Vector3( 0.00,  0.08, 0)],
	"Chest":      ["Spine",      Vector3( 0.00,  0.18, 0)],
	"Neck":       ["Chest",      Vector3( 0.00,  0.20, 0)],
	"Head":       ["Neck",       Vector3( 0.00,  0.09, 0)],
	"L_Shoulder": ["Chest",      Vector3( 0.19,  0.13, 0)],
	"L_UpperArm": ["L_Shoulder", Vector3( 0.10,  0.00, 0)],
	"L_LowerArm": ["L_UpperArm", Vector3( 0.00, -0.28, 0)],
	"L_Hand":     ["L_LowerArm", Vector3( 0.00, -0.25, 0)],
	"R_Shoulder": ["Chest",      Vector3(-0.19,  0.13, 0)],
	"R_UpperArm": ["R_Shoulder", Vector3(-0.10,  0.00, 0)],
	"R_LowerArm": ["R_UpperArm", Vector3( 0.00, -0.28, 0)],
	"R_Hand":     ["R_LowerArm", Vector3( 0.00, -0.25, 0)],
	"L_UpperLeg": ["Hips",       Vector3( 0.11, -0.02, 0)],
	"L_LowerLeg": ["L_UpperLeg", Vector3( 0.00, -0.44, 0)],
	"L_Foot":     ["L_LowerLeg", Vector3( 0.00, -0.44, 0)],
	"R_UpperLeg": ["Hips",       Vector3(-0.11, -0.02, 0)],
	"R_LowerLeg": ["R_UpperLeg", Vector3( 0.00, -0.44, 0)],
	"R_Foot":     ["R_LowerLeg", Vector3( 0.00, -0.44, 0)],
}

var skel: Skeleton3D
var colors: Dictionary
var muzzle_point: Node3D
var fire_flash: OmniLight3D
var move_speed := 0.0
var walk_phase := 0.0
var dead := false

func setup(kind: String = "enemy") -> void:
	colors = PALETTES.get(kind, PALETTES.enemy)
	_build_skeleton()
	_build_body()
	_build_weapon()
	_apply_aim_pose()

func set_move_speed(s: float) -> void:
	move_speed = s

func shoot_flash() -> void:
	fire_flash.light_energy = 4.0
	var t := create_tween()
	t.tween_property(fire_flash, "light_energy", 0.0, 0.08)

func get_muzzle() -> Node3D:
	return muzzle_point

func die() -> void:
	if dead: return
	dead = true
	var t := create_tween()
	t.tween_method(_die_step, 0.0, 1.0, 0.7)

func _build_skeleton() -> void:
	skel = Skeleton3D.new()
	add_child(skel)
	for b in BONES:
		skel.add_bone(b)
	for b in BONES:
		var info: Array = BONES[b]
		var idx := skel.find_bone(b)
		if info[0] != "":
			skel.set_bone_parent(idx, skel.find_bone(info[0]))
		var rest := Transform3D(Basis(), info[1])
		skel.set_bone_rest(idx, rest)
		skel.set_bone_pose(idx, rest)

func _attach(bone: String, offset: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = offset
	att.add_child(mi)
	return mi

func _build_body() -> void:
	var c := colors
	_attach("Hips",  Vector3(0, -0.05, 0),     Vector3(0.36, 0.24, 0.22), c.pants)
	_attach("Hips",  Vector3(0,  0.00, 0),     Vector3(0.38, 0.08, 0.24), c.vest)
	_attach("Spine", Vector3(0,  0.05, 0),     Vector3(0.40, 0.20, 0.24), c.uniform)
	_attach("Chest", Vector3(0,  0.08, 0),     Vector3(0.46, 0.34, 0.26), c.uniform)
	_attach("Chest", Vector3(0,  0.02, 0.14),  Vector3(0.42, 0.32, 0.06), c.vest)
	_attach("Chest", Vector3(0, -0.08, 0.15),  Vector3(0.28, 0.10, 0.04), c.vest)
	_attach("Chest", Vector3(0,  0.05,-0.16),  Vector3(0.32, 0.28, 0.10), c.pants)
	_attach("Neck",  Vector3(0,  0.05, 0),     Vector3(0.10, 0.10, 0.10), c.skin)
	_attach("Head",  Vector3(0,  0.10, 0),     Vector3(0.22, 0.24, 0.22), c.skin)
	_attach("Head",  Vector3(0,  0.24, 0),     Vector3(0.28, 0.16, 0.28), c.helmet)
	_attach("Head",  Vector3(0,  0.14, 0.11),  Vector3(0.22, 0.05, 0.02), c.goggles)
	for side in ["L", "R"]:
		_attach("%s_UpperArm" % side, Vector3(0, -0.14, 0),    Vector3(0.13, 0.28, 0.13), c.uniform)
		_attach("%s_LowerArm" % side, Vector3(0, -0.13, 0),    Vector3(0.11, 0.26, 0.11), c.uniform)
		_attach("%s_LowerArm" % side, Vector3(0,  0.05, 0.06), Vector3(0.12, 0.06, 0.04), c.vest)
		_attach("%s_Hand" % side,     Vector3(0, -0.06, 0),    Vector3(0.09, 0.11, 0.09), c.gloves)
		_attach("%s_UpperLeg" % side, Vector3(0, -0.22, 0),    Vector3(0.18, 0.44, 0.18), c.pants)
		_attach("%s_LowerLeg" % side, Vector3(0, -0.22, 0),    Vector3(0.16, 0.42, 0.16), c.pants)
		_attach("%s_LowerLeg" % side, Vector3(0,  0.00, 0.08), Vector3(0.15, 0.10, 0.05), c.vest)
		_attach("%s_Foot" % side,     Vector3(0, -0.05, 0.06), Vector3(0.16, 0.12, 0.30), c.boots)

func _build_weapon() -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "Chest"
	skel.add_child(att)
	var root := Node3D.new()
	root.position = Vector3(0.10, 0.08, -0.35)
	att.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colors.gun
	mat.roughness = 0.6
	mat.metallic = 0.4
	var body_mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.06, 0.10, 0.35)
	body_mi.mesh = bm
	body_mi.material_override = mat
	root.add_child(body_mi)
	var barrel := MeshInstance3D.new()
	var brm := BoxMesh.new(); brm.size = Vector3(0.035, 0.035, 0.30)
	barrel.mesh = brm
	barrel.position = Vector3(0, 0.02, -0.32)
	barrel.material_override = mat
	root.add_child(barrel)
	var mag := MeshInstance3D.new()
	var mm := BoxMesh.new(); mm.size = Vector3(0.05, 0.16, 0.08)
	mag.mesh = mm
	mag.position = Vector3(0, -0.13, 0.05)
	mag.material_override = mat
	root.add_child(mag)
	var stock := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.04, 0.10, 0.18)
	stock.mesh = sm
	stock.position = Vector3(0, 0, 0.24)
	stock.material_override = mat
	root.add_child(stock)
	muzzle_point = Node3D.new()
	muzzle_point.position = Vector3(0, 0.02, -0.48)
	root.add_child(muzzle_point)
	fire_flash = OmniLight3D.new()
	fire_flash.light_color = Color("ffbb55")
	fire_flash.light_energy = 0.0
	fire_flash.omni_range = 4.0
	muzzle_point.add_child(fire_flash)

func _apply_aim_pose() -> void:
	_set_rot("R_UpperArm", Vector3(1.55, 0, 0))
	_set_rot("R_LowerArm", Vector3(0.35, 0, 0))
	_set_rot("L_UpperArm", Vector3(1.55, 0.30, 0))
	_set_rot("L_LowerArm", Vector3(0.55, 0, 0))
	_set_rot("Head",       Vector3(-0.12, 0, 0))

func _set_rot(bone: String, euler: Vector3) -> void:
	var idx := skel.find_bone(bone)
	skel.set_bone_pose_rotation(idx, Quaternion.from_euler(euler))

func _process(delta: float) -> void:
	if dead: return
	if move_speed > 0.1:
		walk_phase += delta * move_speed * 2.2
	else:
		walk_phase = lerp(walk_phase, 0.0, delta * 5.0)
	var amp := clampf(move_speed / 4.0, 0.0, 1.0)
	var swing := sin(walk_phase) * 0.55 * amp
	var counter := sin(walk_phase + PI) * 0.55 * amp
	_set_rot("L_UpperLeg", Vector3(swing, 0, 0))
	_set_rot("R_UpperLeg", Vector3(counter, 0, 0))
	_set_rot("L_LowerLeg", Vector3(maxf(0, -swing) * 1.2, 0, 0))
	_set_rot("R_LowerLeg", Vector3(maxf(0, -counter) * 1.2, 0, 0))
	var bob := absf(sin(walk_phase)) * 0.03 * amp
	var hips_idx := skel.find_bone("Hips")
	var rest := skel.get_bone_rest(hips_idx)
	skel.set_bone_pose_position(hips_idx, rest.origin + Vector3(0, bob, 0))

func _die_step(t: float) -> void:
	var hips_idx := skel.find_bone("Hips")
	var rest := skel.get_bone_rest(hips_idx)
	var p := rest.origin
	p.y = maxf(0.25, 1.0 - t * 0.75)
	skel.set_bone_pose_position(hips_idx, p)
	skel.set_bone_pose_rotation(hips_idx, Quaternion.from_euler(Vector3(t * PI * 0.5, 0, 0)))

func modulate(color: Color) -> void:
	for att in skel.get_children():
		if att is BoneAttachment3D:
			for mi in att.get_children():
				if mi is MeshInstance3D and mi.material_override:
					mi.material_override.albedo_color = color