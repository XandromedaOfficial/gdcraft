shader_type spatial;

uniform sampler2D texture_atlas;
uniform float atlas_columns = 16.0;
uniform float atlas_rows = 16.0;

void fragment() {
    // Calculate which tile to use from the atlas
    vec2 tile_size = vec2(1.0/atlas_columns, 1.0/atlas_rows);
    vec2 tile_pos = floor(UV * vec2(atlas_columns, atlas_rows));
    vec2 tile_uv = mod(UV * vec2(atlas_columns, atlas_rows), vec2(1.0));
    
    // Sample texture with nearest neighbor filtering
    vec4 color = texture(texture_atlas, tile_pos * tile_size + tile_uv * tile_size);
    ALBEDO = color.rgb;
    ALPHA = color.a;
}