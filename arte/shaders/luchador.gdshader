shader_type canvas_item;
// Shader de los luchadores del combate.
// - destello: pinta el sprite de un color sólido (golpe = blanco, caída = rojo).
// - respiracion / flotar: animación en reposo. Los pies del sprite están en y = 0,
//   así que al "respirar" el cuerpo se estira hacia arriba sin despegarse del suelo.

uniform float destello : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_destello : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float respiracion = 0.025;
uniform float flotar = 0.0;
uniform float velocidad = 3.2;
uniform float fase = 0.0;

void vertex() {
	float s = sin(TIME * velocidad + fase);
	VERTEX.y *= 1.0 + s * respiracion;
	VERTEX.y += round(s * flotar);
}

void fragment() {
	// COLOR ya trae el color de la textura multiplicado por modulate
	COLOR.rgb = mix(COLOR.rgb, color_destello.rgb, destello);
}
