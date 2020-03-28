// C++ / HLSL shared state block for fixed function support
#pragma once
#ifdef  __cplusplus

// #include <DirectXMath.h>
#include <d3d9.h>
#include <d3d9types.h> // for D3DFORMAT, D3DLIGHT9, etc
#include <d3dx9math.h> // for D3DXVECTOR4, etc
#include <array>

#define float4x4 D3DMATRIX
#define float4 D3DXVECTOR4
#define float3 D3DVECTOR
#define float2 D3DXVECTOR2
#define arr(name, type, length) std::array<type, length> name

#else
// HLSL
#define arr(name, type, length) type name[length]

#endif //  __cplusplus

// Shared HLSL structures
// Taking care with packing rules
// i.e. vectors cannot cross a 16 byte boundary

#pragma pack_matrix(row_major)
#pragma pack 16
struct Transforms {
    float4x4 View; // 0
    float4x4 Projection; // 1
    float4x4 Texture0; // 2
    float4x4 Texture1; // 3
    float4x4 Texture2; // 4
    float4x4 Texture3; // 5
    float4x4 World; // 6
    float4x4 World1; // 7
    float4x4 World2; // 8
    float4x4 World3; // 9
};

#pragma pack 4
// See D3DLIGHT
struct Light {
    float4 Diffuse;
    float4 Specular;
    float4 Ambient;
    // 16 bytes
    float3 Position;
    float Enabled;
    // 16 bytes
    float3 Direction;
    float Type; // 1=Point, 2=Spot, 3=Directional
    //
    float Range;
    float Falloff;
    float Attenuation0;
    float Attenuation1;
    //
    float Attenuation2;
    float Theta;
    float Phi;
};

#pragma pack 16
struct RenderStateBlock {
    Transforms Transforms;
    arr(Lights, Light, 8);
};
