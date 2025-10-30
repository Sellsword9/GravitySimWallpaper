extends Node2D

var add_body = 0
var BODY_COUNT = 2

# Feel free to fine tune this values if you want
const Greal = 6.67430e-1   # Gravitational constant
const G = Greal * 80
const DISINTEGRATION_CONSTANT_LOWER_LIMIT = 3
const DISINTEGRATION_CONSTANT_UPPER_LIMIT = 1e6/4
const MAX_MASS = 500.0
const MIN_MASS = 50.0
const MASS_TO_SIZE_RATIO = 1.5
const SPAWN_RADIUS = 300.0
const MAX_INITIAL_SPEED = 2
const TRAIL_LENGTH = 900  
const RESET_INTERVAL = 99 #(Max, true depends on if the bodies collide or not)

var center = get_viewport_rect().size / 2

var camera = null
var label = null
var label_ellapsed = null

var reset_cause = "First simulation"
var time_ellapsed = 0.0

const MAX_SPEED = 900

class Body:
	var pos: Vector2
	var vel: Vector2
	var mass: float
	var color: Color
	var trail: Line2D
	var size: float

	func _init(p: Vector2, v: Vector2, m: float, c: Color, t: Line2D, s: float):
		pos = p
		vel = v
		mass = m
		color = c
		trail = t
		size = s

var bodies: Array[Body] = []

func _ready():
	camera = self.get_child(0)
	label = camera.get_child(1)
	label_ellapsed = camera.get_child(2)
	
	randomize()
	camera.global_position = center
	camera.make_current()
	_reset_simulation()
	
	# create and start the timer for resets
	var timer := Timer.new()
	timer.wait_time = RESET_INTERVAL
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_simulation_timeout)

func _simulation_timeout() -> void:
	reset_cause = "Timeout"
	if bodies.size() != 3:
		_reset_simulation()

func _reset_simulation() -> void:
	# remove old trails
	time_ellapsed = 0
	for b in bodies:
		if b.trail and b.trail.is_inside_tree():
			b.trail.queue_free()
	bodies.clear()

	if randf() > 0.5:
		add_body = 1
	else:
		add_body = 0
	BODY_COUNT = 2 + add_body
	label.text = "Reason last simulation died: " + reset_cause + ". Now simulating: " + str(BODY_COUNT) + " bodies. "
	for i in range(BODY_COUNT):
		var angle = randf() * PI * 2
		var radius = randf() * SPAWN_RADIUS
		var pos = Vector2(cos(angle), sin(angle)) * radius
		var vel = Vector2(
			randf_range(-MAX_INITIAL_SPEED, MAX_INITIAL_SPEED),
			randf_range(-MAX_INITIAL_SPEED, MAX_INITIAL_SPEED)
		)
		var mass = randf_range(MIN_MASS, MAX_MASS)
		var color = Color.from_rgba8(233, 233, 242, 255)
		var size = ((mass**MASS_TO_SIZE_RATIO) * 1/(MAX_MASS-MIN_MASS))+1

		var trail := Line2D.new()
		trail.width = 1
		trail.default_color = color
		trail.gradient = Gradient.new()
		trail.gradient.colors = [color, color.blend(Color.from_rgba8(0, 0, 0, 0))]
		add_child(trail)

		bodies.append(Body.new(pos, vel, mass, color, trail, size))

func _physics_process(delta: float) -> void:
	var biggerBody = bodies.reduce(func(x, y): return x if x.mass > y.mass else y)
	camera.global_position = biggerBody.pos + center
	for i in range(bodies.size()):
		var a
		if i >= bodies.size():
			a = null
		else:
			a = bodies[i]
		var acc = Vector2.ZERO
		if a:
			for j in range(bodies.size()):
				if i == j:
					continue
				var b = null
				if j >= bodies.size():
					b = null
				else:
					b = bodies[j]
				if b:
					var dir = b.pos - a.pos
					var r2 = dir.length_squared()
					if r2 < DISINTEGRATION_CONSTANT_LOWER_LIMIT + (b.size*(PI**2)):
						reset_cause = "Bodies collapsed"
						_reset_simulation()
					elif r2 > (DISINTEGRATION_CONSTANT_UPPER_LIMIT * (bodies.size() * bodies.size())):
						reset_cause = "Max distance between bodies reached"
						_reset_simulation()
					acc += (G * b.mass / r2) * dir.normalized()
				else:
					continue
			a.vel += acc * delta
			a.vel = limit_speed(a.vel)
		else:
			continue

	for body in bodies:
		#print(body.vel)
		body.pos += body.vel
		_update_trail(body)

	queue_redraw()

func _update_trail(body: Body) -> void:
	var point = center + body.pos
	body.trail.add_point(point)
	if body.trail.get_point_count() > TRAIL_LENGTH:
		body.trail.remove_point(0)
func _process(delta: float) -> void:
	time_ellapsed += delta
	label_ellapsed.text = "Time ellapsed: " + str(time_ellapsed).left(4) + "s"
	if Input.is_physical_key_pressed(KEY_SPACE):
		_reset_simulation()
func _draw():
	for body in bodies:
		draw_circle(center + body.pos, body.size, body.color)

func limit_speed(speed) -> Vector2:
	if speed.y >= 0:
		speed.y = min(speed.y, MAX_SPEED)
	else:
		speed.y = max(speed.y, -MAX_SPEED)
		
	if speed.x >= 0:
		speed.x = min(speed.x, MAX_SPEED)
	else:
		speed.x = max(speed.x, -MAX_SPEED)
		
	return speed
