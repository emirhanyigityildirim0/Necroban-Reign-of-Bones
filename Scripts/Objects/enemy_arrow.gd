extends Area2D

@export var speed: float = 400.0
@export var damage: int = 15
var direction: int = 1

func _ready():
	# If arrow leaves the screen, destroy it
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Move in a straight line
	position.x += speed * direction * delta

func _on_body_entered(body):
	# Ignore the enemy that shot the arrow
	if body.is_in_group("dusman"): return
	
	if body.is_in_group("oyuncu"):
		if body.has_method("hasar_al"):
			body.hasar_al(damage)
		queue_free() # Destroy arrow on hit
	
	# Destroy arrow if it hits a wall/floor (TileMap)
	# Note: Ensure your TileMap is on a collision layer that Area2D detects
	elif body is TileMap or body is StaticBody2D:
		queue_free()
