extends Camera3D

@export var CameraPivot: Node3D
@export var Camera: Camera3D

var playerPosition = Vector3.ZERO
var cameraOffsetDistance = Vector3.ZERO

# should be an external parameter accessible for the player to change
var mouse_sensibility: float = 0.08
var min_camera_angle = -60
var max_camera_angle = 60
var camera_distance: float = -10.0

func _input(event):
	orbit_camera(event)


func _ready():
	GameEvents.playerPositionSignal.connect(self.get_player_position)
	cameraOffsetDistance = Vector3.UP + (Vector3.FORWARD * camera_distance)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	follow_player()


func get_player_position(position: Vector3):
	playerPosition = position


func keep_distance_from_camera_pivot():
	CameraPivot.position = playerPosition
	Camera.position = cameraOffsetDistance


func follow_player():
	if playerPosition:
		keep_distance_from_camera_pivot()
		look_at(CameraPivot.position)
		GameEvents.emit_signal("cameraForward", get_global_transform().basis.z)


func orbit_camera(event: InputEvent):
	var mouse_movement = event as InputEventMouseMotion
	if mouse_movement:
		CameraPivot.rotation_degrees.y -= mouse_movement.relative.x * mouse_sensibility
		
		var current_tilt: float = CameraPivot.rotation_degrees.x
		current_tilt -= mouse_movement.relative.y * mouse_sensibility
		
		CameraPivot.rotation_degrees.x = clamp(current_tilt, min_camera_angle, max_camera_angle)
	
