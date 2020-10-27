#define LOG_PREFIX CXBXR_MODULE::D3D8

#include "FixedFunctionState.h"
#include "Logging.h"

D3DCOLORVALUE colorValue(float r, float g, float b, float a) {
    auto value = D3DCOLORVALUE();
    value.r = r;
    value.g = g;
    value.b = b;
    value.a = a;
    return value;
}

D3DVECTOR toVector(float x, float y, float z) {
    auto value = D3DVECTOR();
    value.x = x;
    value.y = y;
    value.z = z;
    return value;
}

D3D8LightState::D3D8LightState() {
    // Define the default light
    // When unset lights are enabled, they're set to the default light
    auto defaultLight = xbox::X_D3DLIGHT8();
    defaultLight.Type = D3DLIGHT_DIRECTIONAL;
    defaultLight.Diffuse = colorValue(1, 1, 1, 0);
    defaultLight.Specular = colorValue(0, 0, 0, 0);
    defaultLight.Ambient = colorValue(0, 0, 0, 0);
    defaultLight.Position = toVector(0, 0, 0);
    defaultLight.Direction = toVector(0, 0, 1);
    defaultLight.Range = 0;
    defaultLight.Falloff = 0;
    defaultLight.Attenuation0 = 0;
    defaultLight.Attenuation1 = 0;
    defaultLight.Attenuation2 = 0;
    defaultLight.Theta = 0;
    defaultLight.Phi = 0;

    // We'll just preset every light to the default light
    Lights.fill(defaultLight);
    EnabledLights.fill(-1);
}

void D3D8LightState::EnableLight(int index, bool enable) {
    // Check to see if the light is already enabled
    // Disable it if so
    for (size_t i = 0; i < EnabledLights.size(); i++) {

        // If the light is already in the enabled lights
        if (EnabledLights[i] == index) {
            // If enabling, make the light the most recently enabled
            if (enable) {
                EmuLog(LOG_LEVEL::INFO, "Enabled light %d but it was already enabled", index);
                // Move the enabled light to the front
                std::rotate(std::begin(EnabledLights), std::begin(EnabledLights) + i, std::begin(EnabledLights) + i + 1);
            }
            else {
                // Otherwise, disable the light
                EnabledLights[i] = -1;
                // Move the disabled light to the end
                std::rotate(std::begin(EnabledLights) + i, std::begin(EnabledLights) + i + 1, std::end(EnabledLights));
            }
            return;
        }

        // If we hit the empty light slots
        if (EnabledLights[i] == -1) {
            if (enable) {
                EnabledLights[i] = index;
                return;
            }

            EmuLog(LOG_LEVEL::INFO, "Attempted to disable light %d but it was not enabled", index);
            return;
        }
    }

    // Replace the oldest element and move to end
    EnabledLights[0] = index;
    std::rotate(std::begin(EnabledLights), std::begin(EnabledLights) + 1, std::end(EnabledLights));
    return;
}
