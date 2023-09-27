extends CharacterBody3D

# to still allow the player to jump 2/10 of a second after stepping off an edge
# a bit of forgiveness on platforms
@export var OffGroundTimer: Timer

@onready var doubletap_timer = doubletap_delay

const walk_speed = 10.0
const run_speed = 20.0
const max_jump_walking = 10.0
const max_jump_running = 13.0
const weight = 2.5
const movement_acceleration = 0.1
const default_impulse = 1.0
const jump_multiplier = 1.25
const invertion_limit = 90
const doubletap_delay: float = 0.25
const lower_limit = -12.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera_forward = Vector3.ZERO
var direction = Vector3.ZERO

var SPEED = 8.0
var jump_impulse = 1.0
var max_jump_impulse = 8.0

var last_keycode = 0

var dash = false
var jumped = false
var can_jump = false


func _input(event):
	double_tap_check(event)


func _ready():
	GameEvents.cameraForward.connect(self.get_camera_forward)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	doubletap_timer -= delta
	movement(delta)
	on_collision()
	if position.y <= lower_limit:
		get_tree().reload_current_scene()

func movement(delta):
	GameEvents.emit_signal("playerPositionSignal", position)
	
	if is_on_floor():
		if Input.is_action_pressed("run") or dash:
			dash = true
			SPEED = run_speed
			max_jump_impulse = max_jump_running
		else:
			SPEED = walk_speed
			max_jump_impulse = max_jump_walking
		# prevent consecutive jumps while holding jump button
		if Input.is_action_pressed("jump") == false:
			can_jump = true
			jumped = false
			jump_impulse = default_impulse
		OffGroundTimer.stop()
	# Add the gravity.
	else:
		if OffGroundTimer.is_stopped() and jumped == false and can_jump:
			OffGroundTimer.start()
		velocity.y -= gravity * weight * delta
		if Input.is_action_pressed("jump") == false or jump_impulse >= max_jump_impulse:
			can_jump = false
		if jumped == false and OffGroundTimer.time_left > 0.0:
			can_jump = true
	if Input.is_anything_pressed() == false:
		dash = false
		
	# Handle Jump. the longer is pressed the higher is the impulse
	if Input.is_action_pressed("jump") and can_jump:
		if OffGroundTimer.is_stopped() == false:
			OffGroundTimer.stop()
		jump()
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("move_right", "move_left", "move_backward", "move_forward")
	
	var direction_to_lerp = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# check camera direction to use as reference
	# the input forward is equivalent to the world's forward
	var angle_to_camera_forward = Vector3.FORWARD.angle_to(camera_forward)
	# the angle will always be positive so it needs a reference
	var rotation_orientation = rad_to_deg(Vector3.RIGHT.angle_to(camera_forward))
	# values less than 90 degrees should be negative
	if rotation_orientation < invertion_limit:
		angle_to_camera_forward = -angle_to_camera_forward
	# rotate the input vector towards the camera forward
	direction_to_lerp = direction_to_lerp.rotated(Vector3.UP, angle_to_camera_forward)
	
	# add inertia to the movement
	if is_on_floor():
		direction = direction.lerp(direction_to_lerp, movement_acceleration)
	else:
		if input_dir == Vector2.ZERO:
			direction = direction.lerp(direction_to_lerp, movement_acceleration ** 2)
		else:
			direction = direction.lerp(direction_to_lerp, movement_acceleration)
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()



func jump(max_jump = false, jump_direction = Vector3.ZERO):
	jumped = true
	# for jump effects like springs or stepping over enemies
	if max_jump:
		jump_impulse = max_jump_running
	else:
		jump_impulse *= jump_multiplier
		jump_impulse = clamp(jump_impulse, default_impulse, max_jump_impulse)
	velocity.y = jump_impulse
	# for walljump impulse off the wall
	if jump_direction != Vector3.ZERO:
		velocity = jump_direction
		# if you add this move_and_slide() here, on_collision() will start getting nullreference errors
		#move_and_slide()


func walljump(jump_direction):
	jump_direction.y = 10.0
	jump(true, jump_direction)


func on_collision():
	var collision_count = get_slide_collision_count()
	if collision_count > 0:
		var collision_normal = get_slide_collision(0).get_normal(0)
		for index in range(collision_count):
			var collision = get_slide_collision(index)
			
			var dot_product = Vector3.UP.dot(collision_normal)
			if dot_product > -0.1 and dot_product < 0.1 and Input.is_action_just_pressed("jump") and is_on_floor() == false:
				walljump(velocity.reflect(collision_normal))
			
			if collision.get_collider().is_in_group("enemy"):
				#var mob = collision.get_collider()
				print("enemy")


func get_camera_forward(forward: Vector3):
	# keep it planar
	forward.y = 0.0
	camera_forward = forward


func _on_off_ground_timer_timeout():
	can_jump = false
	OffGroundTimer.stop()


func double_tap_check(event):
	if event is InputEventKey and event.is_pressed():
		if last_keycode == event.keycode and doubletap_timer >= 0:
			if is_on_floor() and Input.is_action_just_pressed("move_forward"):
				dash = true
				last_keycode = 0
		else:
			last_keycode = event.keycode
		doubletap_timer = doubletap_delay
