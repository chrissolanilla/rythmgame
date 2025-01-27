shader_type canvas_item;
uniform vec4 fill_color = vec4(0.0, 0.0, 0.0, 1.0); // black by default, rgba
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 tex_color = texture(TEXTURE, UV);
	// Check if the pixel is not transparent
	if (tex_color.a > 0.1) {
		// Apply the fill color to the inside of the arrow
		COLOR = fill_color;
	} else {
		// Keep transparent parts intact
		discard;
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
