uniform vec4 color2;
uniform int fill_type;
uniform float mix_factor;

uniform float g_angle;
uniform float g_radius;
uniform float g_boxsize;
uniform vec2 g_scale;
uniform vec2 g_shift;

uniform float t_angle;
uniform vec2 t_scale;
uniform vec2 t_shift;
uniform int t_mix;
uniform int t_flip;
uniform float t_opacity;
uniform int xraymode;
uniform int sort;
uniform float obj_zdepth;

uniform sampler2D myTexture;
uniform int t_clamp;

/* keep this list synchronized with list in DNA_brush_types.h */
#define SOLID 0
#define GRADIENT 1
#define RADIAL 2
#define CHESS 3
#define TEXTURE 4
#define PATTERN 5

#define GP_XRAY_FRONT 0
#define GP_XRAY_3DSPACE 1
#define GP_XRAY_BACK  2

#define ZFIGHT_LIMIT_MID 15.0
#define ZFIGHT_LIMIT_HIG 5.0
#define ZFIGHT_SHIFT_LOW 0.00000001
#define ZFIGHT_SHIFT_MID 0.0000001
#define ZFIGHT_SHIFT_HIG 0.000001

in vec4 finalColor;
in vec2 texCoord_interp;
out vec4 fragColor;
#define texture2D texture

void set_color(in vec4 color, in vec4 color2, in vec4 tcolor, in float mixv, in float factor, 
			   in int tmix, in int flip, out vec4 ocolor)
{
	/* full color A */
	if (mixv == 1.0) {
		if (tmix == 1) {
			if (flip == 0) {
				ocolor = color;
			}
			else {
				ocolor = tcolor;
			}
		}
		else {
			if (flip == 0) {
				ocolor = color;
			}
			else {
				ocolor = color2;
			}
		}
	}
	/* full color B */
	else if (mixv == 0.0) {
		if (tmix == 1) {
			if (flip == 0) {
				ocolor = tcolor;
			}
			else {
				ocolor = color;
			}
		}
		else {
			if (flip == 0) {
				ocolor = color2;
			}
			else {
				ocolor = color;
			}
		}
	}
	/* mix of colors */
	else {
		if (tmix == 1) {
			if (flip == 0) {
				ocolor = mix(color, tcolor, factor);
			}
			else {
				ocolor = mix(tcolor, color, factor);
			}
		}
		else {
			if (flip == 0) {
				ocolor = mix(color, color2, factor);
			}
			else {
				ocolor = mix(color2, color, factor);
			}
		}
	}
}

void main()
{
	vec2 t_center = vec2(0.5, 0.5);
	mat2 matrot_tex = mat2(cos(t_angle), -sin(t_angle), sin(t_angle), cos(t_angle));
	vec2 rot_tex = (matrot_tex * (texCoord_interp - t_center)) + t_center + t_shift;
	vec4 tmp_color;
	if (t_clamp == 0) {
		tmp_color = texture2D(myTexture, rot_tex * t_scale);
	}
	else {
		tmp_color = texture2D(myTexture, clamp(rot_tex * t_scale, 0.0, 1.0));
	}
	vec4 text_color = vec4(tmp_color[0], tmp_color[1], tmp_color[2], tmp_color[3] * t_opacity);
	vec4 chesscolor;

	/* solid fill */
	if (fill_type == SOLID) {
		if (t_mix == 1) {
			fragColor = mix(finalColor, text_color, mix_factor);
		}
		else {
			fragColor = finalColor;
		}
	}
	else {
		vec2 center = vec2(0.5, 0.5) + g_shift;
		mat2 matrot = mat2(cos(g_angle), -sin(g_angle), sin(g_angle), cos(g_angle));
		vec2 rot = (((matrot * (texCoord_interp - center)) + center) * g_scale) + g_shift;
		/* gradient */
		if (fill_type == GRADIENT) {
			set_color(finalColor, color2, text_color, mix_factor, rot.x - mix_factor + 0.5, t_mix, t_flip, fragColor);
		}
		/* radial gradient */
		if (fill_type == RADIAL) {
			float in_rad = g_radius * mix_factor;
			float ex_rad = g_radius - in_rad;
			float intensity = 0;
			float distance = length((center - texCoord_interp) * g_scale);
			if (distance > g_radius) {
				discard;
			}
			if (distance > in_rad) {
				intensity = clamp(((distance - in_rad) / ex_rad), 0.0, 1.0);
			}
			set_color(finalColor, color2, text_color, mix_factor, intensity, t_mix, t_flip, fragColor);
		}
		/* chessboard */
		if (fill_type == CHESS) {
			vec2 pos = rot / g_boxsize;
			if ((fract(pos.x) < 0.5 && fract(pos.y) < 0.5) || (fract(pos.x) > 0.5 && fract(pos.y) > 0.5)) {
				if (t_flip == 0) {
					chesscolor = finalColor;
				}
				else {
					chesscolor = color2;
				}
			}
			else {
				if (t_flip == 0) {
					chesscolor = color2;
				}
				else {
					chesscolor = finalColor;
				}
			}
			/* mix with texture */
			if (t_mix == 1) {
				fragColor = mix(chesscolor, text_color, mix_factor);
			}
			else {
				fragColor = chesscolor;
			}
		}
		/* texture */
		if (fill_type == TEXTURE) {
			fragColor = text_color;
		}
		/* pattern */
		if (fill_type == PATTERN) {
			/* normalize texture color */
			float nvalue = 1.0 - ((text_color.x + text_color.y + text_color.z) / 3.0);
			fragColor = mix(vec4(0.0, 0.0, 0.0, 0.0), finalColor, nvalue);
		}
	}

	/* set zdepth */
	if (xraymode == GP_XRAY_FRONT) {
		gl_FragDepth = 0.0;
	}
	if (xraymode == GP_XRAY_3DSPACE) {
		float factor;
		if (obj_zdepth < ZFIGHT_LIMIT_HIG) {
			factor = ZFIGHT_SHIFT_HIG;
		}
		else if (obj_zdepth < ZFIGHT_LIMIT_MID) {
			factor = ZFIGHT_SHIFT_MID;
		}
		else {
			factor = ZFIGHT_SHIFT_LOW;
		}
		gl_FragDepth = gl_FragCoord.z - (sort * factor);
	}
	if  (xraymode == GP_XRAY_BACK) {
		gl_FragDepth = 1.0;
	}
}
