uniform float weather_wetness = 0.0;
// One stage-wide value: roofs, camera bounds and mesh tiles never partition wetness.
float weather_surface_wetness(vec3 world) {
    return clamp(weather_wetness, 0.0, 1.0);
}
