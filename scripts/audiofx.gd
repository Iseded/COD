extends Node

const SR := 22050.0

var _cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func play_rifle(pos: Vector3) -> void:
	_play("rifle", pos, -4.0, randf_range(0.94, 1.06))

func play_pistol(pos: Vector3) -> void:
	_play("pistol", pos, -6.0, randf_range(0.95, 1.05))

func play_reload(pos: Vector3) -> void:
	_play("reload", pos, -10.0, 1.0)

func play_enemy_shot(pos: Vector3) -> void:
	_play("rifle", pos, -12.0, randf_range(0.85, 0.95))

func play_hit(pos: Vector3) -> void:
	_play("hit", pos, -8.0, randf_range(0.95, 1.05))

func play_headshot(pos: Vector3) -> void:
	_play("headshot", pos, -5.0, 1.0)

func play_impact(pos: Vector3) -> void:
	_play("impact", pos, -14.0, randf_range(0.9, 1.1))

func _play(key: String, pos: Vector3, db: float, pitch: float) -> void:
	if not _cache.has(key):
		_cache[key] = _generate(key)

	var p := AudioStreamPlayer3D.new()
	p.stream = _cache[key]
	p.volume_db = db
	p.pitch_scale = pitch
	p.max_distance = 60.0
	p.unit_size = 8.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.position = pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _generate(key: String) -> AudioStreamWAV:
	match key:
		"rifle":    return _make_wav(_gen_rifle())
		"pistol":   return _make_wav(_gen_pistol())
		"reload":   return _make_wav(_gen_reload())
		"hit":      return _make_wav(_gen_hit())
		"headshot": return _make_wav(_gen_headshot())
		"impact":   return _make_wav(_gen_impact())
	return _make_wav(_gen_rifle())

func _gen_rifle() -> PackedFloat32Array:
	var dur := 0.45
	var n := int(SR * dur)
	var buf := PackedFloat32Array(); buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := i / SR
		var env := exp(-t * 22.0)
		var body := exp(-t * 55.0)
		var noise := randf() * 2.0 - 1.0
		var low := sin(TAU * 70.0 * t) * exp(-t * 30.0)
		lp = lp * 0.85 + noise * 0.15
		var s := noise * env * 0.55 + low * body * 0.9 + lp * env * 0.4
		if t < 0.004: s += (randf() * 2.0 - 1.0) * 1.5
		buf[i] = clampf(s, -1.0, 1.0)
	return buf

func _gen_pistol() -> PackedFloat32Array:
	var dur := 0.30
	var n := int(SR * dur)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in n:
		var t := i / SR
		var env := exp(-t * 32.0)
		var noise := randf() * 2.0 - 1.0
		var body := sin(TAU * 110.0 * t) * exp(-t * 40.0)
		buf[i] = clampf(noise * env * 0.5 + body * 0.7, -1.0, 1.0)
	return buf

func _gen_reload() -> PackedFloat32Array:
	var dur := 0.5
	var n := int(SR * dur)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in n:
		var t := i / SR
		var s := 0.0
		if t > 0.05 and t < 0.10:
			s += (randf() * 2.0 - 1.0) * exp(-(t - 0.05) * 60.0) * 0.7
		if t > 0.25 and t < 0.32:
			var lt := t - 0.25
			s += sin(TAU * 900.0 * lt) * exp(-lt * 40.0) * 0.5
		if t > 0.42 and t < 0.47:
			s += (randf() * 2.0 - 1.0) * exp(-(t - 0.42) * 80.0) * 0.6
		buf[i] = clampf(s, -1.0, 1.0)
	return buf

func _gen_hit() -> PackedFloat32Array:
	var dur := 0.08
	var n := int(SR * dur)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in n:
		var t := i / SR
		var s := sin(TAU * 1200.0 * t) * exp(-t * 60.0) * 0.6
		s += (randf() * 2.0 - 1.0) * exp(-t * 80.0) * 0.3
		buf[i] = s
	return buf

func _gen_headshot() -> PackedFloat32Array:
	var dur := 0.18
	var n := int(SR * dur)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in n:
		var t := i / SR
		var s := sin(TAU * 1800.0 * t) * exp(-t * 40.0) * 0.55
		s += sin(TAU * 900.0 * t) * exp(-t * 30.0) * 0.4
		s += (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.2
		buf[i] = s
	return buf

func _gen_impact() -> PackedFloat32Array:
	var dur := 0.15
	var n := int(SR * dur)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in n:
		var t := i / SR
		var s := (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.6
		s += sin(TAU * 220.0 * t) * exp(-t * 35.0) * 0.35
		buf[i] = s
	return buf

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SR)
	wav.stereo = false
	wav.data = bytes
	return wav