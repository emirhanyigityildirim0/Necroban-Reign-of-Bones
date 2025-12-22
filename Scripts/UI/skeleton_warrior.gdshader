shader_type canvas_item;

uniform float dissolve_value : hint_range(0,1) = 0.0; // 0: Normal, 1: Tamamen Yok
uniform sampler2D noise_texture; // Erimenin şeklini belirleyen desen
uniform vec4 burn_color : source_color = vec4(0.2, 0.2, 0.2, 1.0); // Kül rengi (Koyu Gri)

void fragment(){
    vec4 main_texture = texture(TEXTURE, UV);
    float noise = texture(noise_texture, UV).r;
    
    // Eğer piksel şeffafsa işlem yapma
    if (main_texture.a <= 0.0) {
        discard;
    }
    
    // Erime mantığı
    if (dissolve_value > noise){
        discard; // Pikseli sil (Kül oldu)
    }
    
    // Yanık Kenar Efekti (Silinmeden hemen önce rengi değiştir)
    if (dissolve_value + 0.05 > noise){
        COLOR = burn_color;
    } else {
        COLOR = main_texture;
    }
}