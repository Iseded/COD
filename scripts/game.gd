extends Node

const MISSIONS := [
	{
		"name": "МИССИЯ 1 — ПРОРЫВ",
		"brief": "Порт Каспийска, 04:40. Отряд «Кремень» высаживается на пирс.\nЗачистите причал от патруля противника.",
		"type": "eliminate",
		"enemies": 4,
		"waves": 1,
	},
	{
		"name": "МИССИЯ 2 — ТИХИЙ ПРОХОД",
		"brief": "Складской район. Охрана прикрывает груз.\nУничтожьте всех и доберитесь до зоны эвакуации.",
		"type": "extract",
		"enemies": 6,
		"waves": 1,
	},
	{
		"name": "МИССИЯ 3 — ПОСЛЕДНИЙ РУБЕЖ",
		"brief": "Мост через пролив. Подкрепление противника идёт волнами.\nУдержите позицию — три волны.",
		"type": "survive",
		"enemies": 3,
		"waves": 3,
	},
]

var completed := 0

func _enter_tree() -> void:
	_bind_input()
	_load()

func _bind_input() -> void:
	_key("move_forward", KEY_W)
	_key("move_back",    KEY_S)
	_key("move_left",    KEY_A)
	_key("move_right",   KEY_D)
	_key("jump",         KEY_SPACE)
	_key("sprint",       KEY_SHIFT)
	_key("crouch",       KEY_CTRL)
	_key("reload",       KEY_R)
	_key("weapon_1",     KEY_1)
	_key("weapon_2",     KEY_2)
	_key("pause",        KEY_ESCAPE)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim",  MOUSE_BUTTON_RIGHT)

func _key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "completed", completed)
	cfg.save("user://progress.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		completed = int(cfg.get_value("progress", "completed", 0))