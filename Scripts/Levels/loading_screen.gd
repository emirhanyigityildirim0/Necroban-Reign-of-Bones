extends Control

# Yüklenecek sahnenin yolu (Dosya adını değiştirdiysen burayı güncelle!)
const TARGET_SCENE_PATH = "res://Scenes/Levels/MainLevel.tscn" 

var loading_status = 0
var progress = []

func _ready():
	# Arka planda yükleme işlemini başlat
	ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)

func _process(_delta):
	# Yükleme durumunu kontrol et
	loading_status = ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH, progress)
	
	# İlerleme çubuğunu güncelle (progress[0] 0 ile 1 arasıdır, 100 ile çarparız)
	if progress.size() > 0:
		$ProgressBar.value = progress[0] * 100
	
	# Yükleme tamamlandı mı?
	if loading_status == ResourceLoader.THREAD_LOAD_LOADED:
		# Yüklenen sahneyi al
		var new_scene = ResourceLoader.load_threaded_get(TARGET_SCENE_PATH)
		# Sahneye geçiş yap
		get_tree().change_scene_to_packed(new_scene)
