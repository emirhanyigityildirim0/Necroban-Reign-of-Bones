extends Area2D
var aktif = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if not aktif and body.is_in_group("oyuncu"):
		aktif = true
		GameManager.last_checkpoint_pos = global_position
		print("🚩 Checkpoint GameManager'a Kaydedildi!")
		modulate = Color(0, 1, 0) # Rengi yeşil yap
