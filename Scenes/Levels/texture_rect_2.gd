extends TextureRect

var zaman = 0.0
var baslangic_y = 0.0

func _ready():
	
	baslangic_y = position.y 

func _process(delta):
	zaman += delta
	
	position.x += 15 * delta
	
	position.y = baslangic_y + sin(zaman * 2) * 5.0
