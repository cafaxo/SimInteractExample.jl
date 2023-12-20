#version 330 core

const vec2 positions[4] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0,  1.0)
);

layout(location = 0) in vec2 center;

out vec2 pos_vert;

uniform vec2 camera_offset;
uniform vec2 camera_scale;

void main() {
    vec2 pos = positions[gl_VertexID];

    pos_vert = pos;

    pos = center + pos;
    pos = camera_offset + camera_scale * pos;
    gl_Position = vec4(pos.x, pos.y, 0.0, 1.0);
}
