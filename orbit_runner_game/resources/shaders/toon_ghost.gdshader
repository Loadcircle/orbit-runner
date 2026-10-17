shader_type spatial;
// Translucent variant for collectibles already owned from an earlier run.
render_mode cull_back, blend_mix, depth_draw_opaque, shadows_disabled;

#define TOON_GHOST
#include "res://resources/shaders/toon_core.gdshaderinc"
