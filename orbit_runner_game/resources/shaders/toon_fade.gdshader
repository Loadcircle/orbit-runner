shader_type spatial;
// Decoration variant: dithers out near the camera so props never hide the route.
render_mode cull_back, depth_draw_opaque;

#define TOON_FADE
#include "res://resources/shaders/toon_core.gdshaderinc"
