#version 330

in vec3 vertNormal;
in vec2 texCoords;
// Own-model sampler: deliberately uses the non-vehicle material binding path.
uniform sampler2D Texture;
uniform vec3 TintColour;
uniform vec3 AmbientColour;
uniform vec3 Light0Direction;
uniform vec3 Light0Colour;
uniform vec3 Light1Direction;
uniform vec3 Light1Colour;
uniform vec3 Light2Direction;
uniform vec3 Light2Colour;
uniform vec3 Light3Direction;
uniform vec3 Light3Colour;
uniform vec3 Light4Direction;
uniform vec3 Light4Colour;
uniform float Alpha;
out vec4 fragColour;

vec3 lightContribution(vec3 n, vec3 direction, vec3 colour)
{
    // Unused native lights have a zero direction; keep their result finite.
    float strength = max(dot(n, direction * inversesqrt(max(dot(direction, direction), 0.000001))), 0.0);
    return colour * strength;
}

void main()
{
    vec3 n = vertNormal * inversesqrt(max(dot(vertNormal, vertNormal), 0.000001));
    vec3 lighting = AmbientColour;
    lighting += lightContribution(n, Light0Direction, Light0Colour);
    lighting += lightContribution(n, Light1Direction, Light1Colour);
    lighting += lightContribution(n, Light2Direction, Light2Colour);
    lighting += lightContribution(n, Light3Direction, Light3Colour);
    lighting += lightContribution(n, Light4Direction, Light4Colour);
    float grey = dot(TintColour, vec3(0.299, 0.587, 0.114));
    vec3 tint = mix(TintColour, vec3(grey), 0.3);
    fragColour = vec4(texture(Texture, texCoords).rgb * clamp(lighting, 0.0, 1.0) * tint, Alpha * texture(Texture, texCoords).a);
}
