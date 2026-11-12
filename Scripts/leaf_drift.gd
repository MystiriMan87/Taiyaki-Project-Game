extends GPUParticles2D

@export var leaf_color := Color(0.35, 0.65, 0.3)

func _ready() -> void:
	amount = 3
	lifetime = 6.0
	explosiveness = 0.0
	randomness = 1.0
	local_coords = false
	position = Vector2(0, -24)
	z_index = 5
	
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(leaf_color)
	texture = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(14, 6, 0)
	m.direction = Vector3(1, 1, 0)
	m.spread = 25.0
	m.gravity = Vector3(6, 14, 0)
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 8.0
	m.angular_velocity_min = -90.0
	m.angular_velocity_max = 90.0
	m.scale_min = 1.0
	m.scale_max = 2.0
	m.color = Color(1, 1, 1, 1)
	process_material = m
	emitting = true
