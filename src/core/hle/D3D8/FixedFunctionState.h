#ifndef FIXEDFUNCTIONSTATE_H
#define FIXEDFUNCTIONSTATE_H

#include "XbD3D8Types.h"
#include <array>

class D3D8LightState {
public:
    std::array<xbox::X_D3DLIGHT8, 4096> Lights;

    // The indices of last 8 enabled lights
    // From least recently to most recently enabled
    // -1 represents empty light slots
    // which always appear after enabled lights
    std::array<int, 8> EnabledLights;

    D3D8LightState();

    // Enable a light
    void EnableLight(int index, bool enable);
};

#endif
