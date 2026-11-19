class_name Textures
extends RefCounted

static var _cache: Dictionary = {}

static func concrete() -> StandardMaterial3D:
	if _cache.has("concrete"): return _cache["concrete"]
	var m := _make_mat(
		_noise_color(Color("2a3038"), Color("434c55"), 4),
		_normal_from_bumps(64, 0.6, 5),
		_noise_gray(0.75, 0.95, 5))
	_cache["concrete"] = m
	return m

static func metal() -> StandardMaterial3D:
	if _cache.has("metal"): return _cache["metal"]
	var m := _make_mat(
		_noise_color(Color("333b42"), Color("5a636c"), 6),
		_normal_from_scratch(64, 0.4),
		_noise_gray(0.25, 0.45, 6))
	m.metallic = 0.75
	_cache["metal"] = m
	return m

static func rust() -> StandardMaterial3D:
	if _cache.has("rust"): return _cache["rust"]
	var m := _make_mat(
		_noise_color(Color("6b2a10"), Color("8b4a1e"), 8),
		_normal_from_bumps(64, 0.8, 8),
		_noise_gray(0.6, 0.95, 8))
	m.metallic = 0.3
	_cache["rust"] = m
	return m

static func container(hue: Color) -> StandardMaterial3D:
	var key := "container_%s" % hue.to_html()
	if _cache.has(key): return _cache[key]
	var m := _make_mat(
		_noise_color(hue.darkened(0.15), hue.lightened(0.10), 6),
		_normal_from_scratch(64, 0.3),
		_noise_gray(0.55, 0.85, 6))
	m.metallic = 0.4
	_cache[key] = m
	return m

static func floor() -> StandardMaterial3D:
	if _cache.has("floor"): return _cache["floor"]
	var m := _make_mat(
		_noise_color(Color("171c22"), Color("232a32"), 6),
		_normal_from_bumps(64, 0.5, 6),
		_noise_gray(0.7, 0.95, 6))
	_cache["floor"] = m
	return m

static func _make_mat(albedo: Texture2D, normal: Texture2D, rough: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.normal_enabled = true
	m.normal_texture = normal
	m.normal_scale = 1.2
	m.roughness_texture = rough
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_scale = Vector3(3, 3, 3)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func _noise_color(c1: Color, c2: Color, octaves: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.02
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.2
	noise.fractal_gain = 0.55
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var c := c1.lerp(c2, n)
			var grain := randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(
				clampf(c.r + grain, 0, 1),
				clampf(c.g + grain, 0, 1),
				clampf(c.b + grain, 0, 1), 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _noise_gray(min_v: float, max_v: float, octaves: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.03
	noise.fractal_octaves = octaves
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var v := lerpf(min_v, max_v, n)
			img.set_pixel(x, y, Color(v, v, v, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _normal_from_bumps(size: int, strength: float, octaves: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.6
	var h := PackedFloat32Array()
	h.resize(size * size)
	for y in size:
		for x in size:
			h[y * size + x] = (noise.get_noise_2d(x, y) + 1.0) * 0.5
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var hl := h[y * size + max(0, x - 1)]
			var hr := h[y * size + min(size - 1, x + 1)]
			var hu := h[max(0, y - 1) * size + x]
			var hd := h[min(size - 1, y + 1) * size + x]
			var n := Vector3(-(hr - hl) * strength, -(hd - hu) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _normal_from_scratch(size: int, strength: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 1, 1))
	for i in 30:
		var x0 := randi() % size
		var y0 := randi() % size
		var ln := randi_range(4, 20)
		var dx := randi_range(-2, 2)
		var dir := 1 if randf() > 0.5 else -1
		for l in ln:
			var px := posmod(x0 + dx * l, size)
			var py := posmod(y0 + l, size)
			img.set_pixel(px, py, Color(0.5 + 0.15 * dir * strength, 0.5, 1, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)