class_name HUD
extends CanvasLayer

var player_ref: Node
var root: Control
var crosshair: Control
var hp_bar: ProgressBar
var hp_label: Label
var ammo_big: Label
var weapon_label: Label
var obj_label: Label
var msg_label: Label
var banner: Label
var killfeed: VBoxContainer
var damage_vignette: ColorRect
var hitmarker_node: Control
var compass: Label
var _hm_timer := 0.0

func setup(p: Player, lvl: Level, mission: Dictionary) -> void:
	add_to_group("hud")
	player_ref = p
	_build()
	p.health_changed.connect(_on_health)
	p.ammo_changed.connect(_on_ammo)
	lvl.enemy_killed.connect(_on_kill)
	lvl.all_enemies_dead.connect(_on_all_dead)
	_update_objective(mission)
	_show_banner(mission.name)

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	damage_vignette = ColorRect.new()
	damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette.color = Color(0.55, 0.0, 0.0, 0.0)
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_vignette)

	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)

	hitmarker_node = Control.new()
	hitmarker_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	hitmarker_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmarker_node.draw.connect(_draw_hitmarker)
	root.add_child(hitmarker_node)

	hp_label = Label.new()
	hp_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_label.position = Vector2(30, -100)
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color("a8bccc"))
	hp_label.text = "ЗДОРОВЬЕ"
	root.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_bar.position = Vector2(30, -74)
	hp_bar.custom_minimum_size = Vector2(280, 12)
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	root.add_child(hp_bar)

	ammo_big = Label.new()
	ammo_big.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_big.position = Vector2(-260, -110)
	ammo_big.custom_minimum_size = Vector2(240, 60)
	ammo_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_big.add_theme_font_size_override("font_size", 46)
	ammo_big.add_theme_color_override("font_color", Color("ffffff"))
	ammo_big.text = "12 / 96"
	root.add_child(ammo_big)

	weapon_label = Label.new()
	weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_label.position = Vector2(-260, -58)
	weapon_label.custom_minimum_size = Vector2(240, 22)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.add_theme_color_override("font_color", Color("7a94a8"))
	root.add_child(weapon_label)

	obj_label = Label.new()
	obj_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	obj_label.position = Vector2(-440, 22)
	obj_label.custom_minimum_size = Vector2(420, 24)
	obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	obj_label.add_theme_font_size_override("font_size", 15)
	obj_label.add_theme_color_override("font_color", Color("cfdce8"))
	root.add_child(obj_label)

	compass = Label.new()
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-120, 16)
	compass.custom_minimum_size = Vector2(240, 20)
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_theme_font_size_override("font_size", 13)
	compass.add_theme_color_override("font_color", Color("a0b4c4"))
	compass.text = "С"
	root.add_child(compass)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-500, -140)
	banner.custom_minimum_size = Vector2(1000, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 38)
	banner.add_theme_color_override("font_color", Color("ffffff"))
	banner.modulate.a = 0.0
	root.add_child(banner)

	killfeed = VBoxContainer.new()
	killfeed.position = Vector2(30, 22)
	killfeed.custom_minimum_size = Vector2(400, 200)
	root.add_child(killfeed)

	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_CENTER)
	msg_label.position = Vector2(-500, 130)
	msg_label.custom_minimum_size = Vector2(1000, 120)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", Color("e8f1f8"))
	msg_label.modulate.a = 0.0
	root.add_child(msg_label)

func _draw_crosshair() -> void:
	var c: Vector2 = crosshair.size * 0.5
	var col := Color(1, 1, 1, 0.9)
	crosshair.draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), col, 2.0)
	crosshair.draw_line(c + Vector2(4, 0), c + Vector2(10, 0), col, 2.0)
	crosshair.draw_line(c + Vector2(0, -10), c + Vector2(0, -4), col, 2.0)
	crosshair.draw_line(c + Vector2(0, 4), c + Vector2(0, 10), col, 2.0)
	crosshair.draw_arc(c, 0.8, 0, TAU, 12, Color(1, 1, 1, 0.35), 1.0)

func _draw_hitmarker() -> void:
	if _hm_timer <= 0.0: return
	var c: Vector2 = hitmarker_node.size * 0.5
	var a := clampf(_hm_timer / 0.15, 0.0, 1.0)
	var col := Color(1, 1, 1, a)
	hitmarker_node.draw_line(c + Vector2(-12, -12), c + Vector2(-5, -5), col, 2.5)
	hitmarker_node.draw_line(c + Vector2(5, -5),  c + Vector2(12, -12), col, 2.5)
	hitmarker_node.draw_line(c + Vector2(-12, 12), c + Vector2(-5, 5),   col, 2.5)
	hitmarker_node.draw_line(c + Vector2(5, 5),   c + Vector2(12, 12),  col, 2.5)

func _process(delta: float) -> void:
	if _hm_timer > 0.0:
		_hm_timer = max(0.0, _hm_timer - delta)
		hitmarker_node.queue_redraw()
	damage_vignette.color.a = VisualFX.damage_vignette * 0.55
	if player_ref and is_instance_valid(player_ref):
		var yaw := rad_to_deg(player_ref.rotation.y)
		compass.text = _compass_str(yaw)

func hitmarker(_headshot := false) -> void:
	_hm_timer = 0.15
	hitmarker_node.queue_redraw()

func _on_health(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "ЗДОРОВЬЕ %d" % hp
	hp_bar.modulate = Color(1, 0.5, 0.5) if hp < 30 else Color(1, 1, 1)

func _on_ammo(mag: int, reserve: int, wname: String) -> void:
	ammo_big.text = "%d / %d" % [mag, reserve]
	weapon_label.text = wname
	ammo_big.modulate = Color(1, 0.55, 0.55) if mag <= 5 else Color(1, 1, 1)

func _on_kill() -> void:
	var l := Label.new()
	l.text = "▶ ЦЕЛЬ УСТРАНЕНА"
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color("e8b55c"))
	killfeed.add_child(l)
	if killfeed.get_child_count() > 5:
		killfeed.get_child(0).queue_free()
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)

func _on_all_dead() -> void:
	show_message("ЦЕЛИ УНИЧТОЖЕНЫ", 2.5)

func _update_objective(mission: Dictionary) -> void:
	match String(mission.get("type", "")):
		"eliminate":
			obj_label.text = "ЦЕЛЬ · уничтожить %d" % int(mission.enemies)
		"extract":
			obj_label.text = "ЦЕЛЬ · зачистить склад (%d)" % int(mission.enemies)
		"survive":
			obj_label.text = "ЦЕЛЬ · продержаться %d волны" % int(mission.waves)

func _show_banner(text: String) -> void:
	banner.text = text
	var t := create_tween()
	t.tween_property(banner, "modulate:a", 1.0, 0.4)
	t.tween_interval(2.2)
	t.tween_property(banner, "modulate:a", 0.0, 0.8)

func show_message(text: String, time: float) -> void:
	msg_label.text = text
	var t := create_tween()
	t.tween_property(msg_label, "modulate:a", 1.0, 0.25)
	t.tween_interval(time)
	t.tween_property(msg_label, "modulate:a", 0.0, 0.6)

func _compass_str(yaw: float) -> String:
	var dirs := ["С","СВ","В","ЮВ","Ю","ЮЗ","З","СЗ"]
	var i := int(fposmod((yaw + 22.5) / 45.0, 8.0))
	return dirs[i]