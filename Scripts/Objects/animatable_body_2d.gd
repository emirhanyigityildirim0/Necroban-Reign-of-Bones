extends AnimatableBody2D

@export var move_offset = Vector2(0, -200) # Ne kadar uzağa gitsin? (x, y)
@export var duration = 3.0 # Ne kadar sürede gitsin? (Saniye)

func _ready():
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	

	tween.tween_property(self, "position", position + move_offset, duration)
	
	tween.tween_interval(1.0)
	
	tween.tween_property(self, "position", position, duration)
	
	tween.tween_interval(1.0)
