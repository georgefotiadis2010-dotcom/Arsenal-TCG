shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.08, 0.04, 0.08, 1.0);
uniform vec4 color_mid : source_color = vec4(0.04, 0.06, 0.12, 1.0);
uniform vec4 color_bot : source_color = vec4(0.03, 0.07, 0.14, 1.0);
uniform vec2 resolution = vec2(1280.0, 800.0);

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * resolution;

	// Vertical arena gradient (crimson-tinted top -> deep slate mid -> cyan-tinted bottom)
	vec3 bg = mix(color_top.rgb, color_mid.rgb, smoothstep(0.0, 0.48, uv.y));
	bg = mix(bg, color_bot.rgb, smoothstep(0.48, 1.0, uv.y));

	// Subtle tactical grid
	float grid_x = step(0.975, fract(px.x / 48.0));
	float grid_y = step(0.975, fract(px.y / 48.0));
	float grid = max(grid_x, grid_y) * 0.045;

	// Soft radial spotlight in center of arena
	float dist_center = length((uv - vec2(0.40, 0.42)) * vec2(1.4, 1.0));
	float spotlight = smoothstep(0.75, 0.0, dist_center) * 0.10;

	// Subtle horizontal arena divider glow at y = 0.37
	float divider_dist = abs(uv.y - 0.37);
	float divider_glow = exp(-divider_dist * 65.0) * 0.18;

	// Edge vignette
	float vig = smoothstep(0.95, 0.25, length(uv - vec2(0.5)));

	vec3 final_col = bg + vec3(0.18, 0.45, 0.78) * (grid + spotlight + divider_glow);
	final_col *= mix(0.65, 1.0, vig);

	COLOR = vec4(final_col, 1.0);
}
