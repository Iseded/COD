extends Node

enum State { MENU, PLAYING, PAUSED, OVER }

const TEST_MAP_SCRIPT := "res://scripts/TestMap.gd"

var state: State = State.MENU
var world: Node3D
var level: Node3D # тестовая карта TestMap (или Level) — сигналы совпадают
var player: Player
var hud: HUD
var menu: CanvasLayer
var pause_menu: CanvasLayer
var end_screen: CanvasLayer
var current_mission := 0
var mission_result := ""

func _ready() -> void:
	show_menu()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			set_paused(true)
		elif state == State.PAUSED:
			set_paused(false)

func _kill(node: Node) -> void:
	if is_instance_valid(node):
		if node.get_parent():
			node.get_parent().remove_child(node)
		node.queue_free()

func _clear_all() -> void:
	_kill(world); _kill(hud); _kill(menu); _kill(pause_menu); _kill(end_screen)
	world = null; hud = null; menu = null; pause_menu = null; end_screen = null
	level = null; player = null

func show_menu() -> void:
	state = State.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_all()

	menu = CanvasLayer.new()
	add_child(menu)

	var bg := ColorRect.new()
	bg.color = Color("080c10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	var title := Label.new()
	title.text = "ОПЕРАЦИЯ: ХОЛОДНЫЙ ФРОНТ"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("d7e3ee"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(1280, 60)
	menu.add_child(title)

	var sub := Label.new()
	sub.text = "тактический FPS · оригинальный сюжет · отряд «Кремень»"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("6f8ea8"))
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(0, 150)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size = Vector2(1280, 30)
	menu.add_child(sub)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-230, -140)
	box.custom_minimum_size = Vector2(460, 360)
	box.add_theme_constant_override("separation", 12)
	menu.add_child(box)

	for i in Game.MISSIONS.size():
		var m: Dictionary = Game.MISSIONS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(460, 56)
		b.add_theme_font_size_override("font_size", 18)
		var locked: bool = i > Game.completed
		b.text = m.name + ("   🔒" if locked else "")
		b.disabled = locked
		b.pressed.connect(func(): start_mission(i))
		box.add_child(b)

	var credits := Button.new()
	credits.text = "КРЕДИТЫ"
	credits.custom_minimum_size = Vector2(460, 44)
	credits.pressed.connect(show_credits)
	box.add_child(credits)

	var quit := Button.new()
	quit.text = "ВЫХОД"
	quit.custom_minimum_size = Vector2(460, 44)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	var hint := Label.new()
	hint.text = "WASD — движение · ЛКМ — огонь · ПКМ — прицел · R — перезарядка · 1/2 — оружие · Shift — бег · Ctrl — присесть · Esc — пауза"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("4a637a"))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-620, -30)
	hint.custom_minimum_size = Vector2(1240, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(hint)

func show_credits() -> void:
	_kill(menu)
	menu = CanvasLayer.new()
	add_child(menu)

	var bg := ColorRect.new()
	bg.color = Color("080c10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.position = Vector2(60, 40)
	scroll.custom_minimum_size = Vector2(1160, 620)
	menu.add_child(scroll)

	var text := Label.new()
	text.text = FileAccess.get_file_as_string("res://CREDITS.txt")
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("cfdce8"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(1120, 0)
	scroll.add_child(text)

	var back := Button.new()
	back.text = "НАЗАД"
	back.position = Vector2(560, 650)
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(show_menu)
	menu.add_child(back)

func start_mission(index: int) -> void:
	_clear_all()
	current_mission = index
	state = State.PLAYING
	mission_result = ""

	world = Node3D.new()
	add_child(world)

	# Тестовая карта вместо старой генерации арены: навмеш, укрытия,
	# разрушаемые стены, спавн врагов, свет и туман.
	level = load(TEST_MAP_SCRIPT).new()
	level.build(world)

	player = Player.new()
	world.add_child(player)
	player.global_position = Vector3(0, 1, 20)

	hud = HUD.new()
	add_child(hud)
	hud.setup(player, level, Game.MISSIONS[index])

	player.died.connect(_on_player_died)
	level.mission_complete.connect(_on_mission_complete)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message(Game.MISSIONS[index].brief, 5.0)

func set_paused(p: bool) -> void:
	if p:
		state = State.PAUSED
		if world: world.process_mode = Node.PROCESS_MODE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_build_pause_menu()
	else:
		state = State.PLAYING
		if world: world.process_mode = Node.PROCESS_MODE_INHERIT
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_kill(pause_menu); pause_menu = null

func _build_pause_menu() -> void:
	pause_menu = CanvasLayer.new()
	add_child(pause_menu)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-150, -90)
	box.custom_minimum_size = Vector2(300, 180)
	box.add_theme_constant_override("separation", 12)
	pause_menu.add_child(box)

	var t := Label.new()
	t.text = "ПАУЗА"
	t.add_theme_font_size_override("font_size", 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	var resume := Button.new()
	resume.text = "ПРОДОЛЖИТЬ"
	resume.custom_minimum_size = Vector2(300, 46)
	resume.pressed.connect(func(): set_paused(false))
	box.add_child(resume)

	var restart := Button.new()
	restart.text = "НАЧАТЬ ЗАНОВО"
	restart.custom_minimum_size = Vector2(300, 46)
	restart.pressed.connect(func():
		set_paused(false)
		start_mission(current_mission))
	box.add_child(restart)

	var menu_btn := Button.new()
	menu_btn.text = "В ГЛАВНОЕ МЕНЮ"
	menu_btn.custom_minimum_size = Vector2(300, 46)
	menu_btn.pressed.connect(func():
		if world: world.process_mode = Node.PROCESS_MODE_INHERIT
		show_menu())
	box.add_child(menu_btn)

func _on_player_died() -> void:
	if state == State.OVER: return
	state = State.OVER
	mission_result = "ПРОВАЛ"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world: world.process_mode = Node.PROCESS_MODE_DISABLED
	_build_end_screen()

func _on_mission_complete() -> void:
	if state == State.OVER: return
	state = State.OVER
	mission_result = "УСПЕХ"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world: world.process_mode = Node.PROCESS_MODE_DISABLED
	if current_mission + 1 > Game.completed:
		Game.completed = current_mission + 1
		Game.save_progress()
	_build_end_screen()

func _build_end_screen() -> void:
	end_screen = CanvasLayer.new()
	add_child(end_screen)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_screen.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -110)
	box.custom_minimum_size = Vector2(440, 240)
	box.add_theme_constant_override("separation", 14)
	end_screen.add_child(box)

	var ok := mission_result == "УСПЕХ"
	var t := Label.new()
	t.text = "МИССИЯ ВЫПОЛНЕНА" if ok else "ОТРЯД УНИЧТОЖЕН"
	t.add_theme_font_size_override("font_size", 38)
	t.add_theme_color_override("font_color", Color("7ddc8a") if ok else Color("e05a5a"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	if ok and current_mission < Game.MISSIONS.size() - 1:
		var nb := Button.new()
		nb.text = "СЛЕДУЮЩАЯ МИССИЯ"
		nb.custom_minimum_size = Vector2(440, 50)
		nb.pressed.connect(func(): start_mission(current_mission + 1))
		box.add_child(nb)

	var rb := Button.new()
	rb.text = "ПОВТОРИТЬ"
	rb.custom_minimum_size = Vector2(440, 50)
	rb.pressed.connect(func(): start_mission(current_mission))
	box.add_child(rb)

	var mb := Button.new()
	mb.text = "В ГЛАВНОЕ МЕНЮ"
	mb.custom_minimum_size = Vector2(440, 50)
	mb.pressed.connect(show_menu)
	box.add_child(mb)