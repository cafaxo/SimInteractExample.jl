#version 330 core

in vec2 pos_vert;

out vec4 FragColor;

void main() {
    float dist = dot(pos_vert, pos_vert);
    FragColor = step(dist, 1.0) * vec4(1.0, 1.0, 1.0, 0.8);
}
