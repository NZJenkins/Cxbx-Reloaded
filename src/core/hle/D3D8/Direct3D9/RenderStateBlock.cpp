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
#define uint UINT

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
    arr(Texture, float4x4, 4); // 2, 3, 4, 5
    arr(World, float4x4, 4); // 6, 7, 8, 9
};

#pragma pack 4
// See D3DLIGHT
struct Light {
    float4 Diffuse;
    float4 Specular;
    float4 Ambient;
    // 16 bytes
    float3 Position;
    float Range;
    // 16 bytes
    float3 Direction;
    uint Type; // 1=Point, 2=Spot, 3=Directional
    //
    float Falloff;
    float Attenuation0;
    float Attenuation1;
    float Attenuation2;
    //
    float Theta;
    float Phi;
};

#pragma pack 4
struct Modes {
    int Lighting;
    int VertexBlend;
};

#pragma pack 16
struct RenderStateBlock {
    Transforms Transforms;
    arr(Lights, Light, 8);
    Modes Modes;
};
