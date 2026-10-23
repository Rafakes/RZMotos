#version 330

// B42 ImportedStaticMesh packs position, normal, then UV0 (no tangent).
layout(location = 0) in vec3 vertex;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 uv;

uniform mat4 ModelViewProjection;
uniform mat4 transform;
uniform float targetDepth = 0.5;
out vec3 vertNormal;
out vec2 texCoords;

void main()
{
    texCoords = uv;
    vertNormal = mat3(transform) * normal;
    vec4 position = ModelViewProjection * transform * vec4(vertex, 1.0);
    // Match the native model renderer's isometric depth adjustment.
    position.z += 2.0 * (targetDepth - 0.5);
    gl_Position = position;
}
