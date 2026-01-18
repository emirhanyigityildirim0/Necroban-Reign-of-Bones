extends Area2D

# Pickup sound (Safe access using get_node_or_null)
@onready var sfx_pickup = get_node_or_null("SfxPickup")

func _ready():
	# Connect the signal via code to ensure it works automatically
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if the colliding body is in the "oyuncu" (player) group
	if body.is_in_group("oyuncu"):
		print("Contact detected! Body: ", body.name)
		
		# Global script check
		if not Global: return
		
		# Check if flask inventory is full
		if Global.current_flasks < Global.max_flasks:
			collect_potion()
		else:
			print("Inventory full! (", Global.current_flasks, "/", Global.max_flasks, ")")

func collect_potion():
	print("✅ Potion collected! +1 Flask")
	
	# 1. Increase potion count
	Global.current_flasks += 1
	
	# 2. Update HUD (Notify the UI group)
	get_tree().call_group("hud_group", "update_hud")
	
	# 3. Play sound if available
	if sfx_pickup:
		sfx_pickup.play()
		# Make invisible and disable monitoring so the player can't trigger it again while sound plays
		visible = false 
		set_deferred("monitoring", false) 
		
		# Wait for the sound to finish
		await sfx_pickup.finished
	
	# 4. Remove object from the world
	queue_free()
