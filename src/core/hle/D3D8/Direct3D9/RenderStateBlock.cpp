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
#define float3 alignas(16) D3DVECTOR
#define float2 alignas(16) D3DXVECTOR2
#define arr(name, type, length) std::array<type, length> name
#define uint alignas(16) UINT
#define int alignas(16) int

#else
// HLSL
#define arr(name, type, length) type name[length]
#define alignas(x)

#endif //  __cplusplus

// Shared HLSL structures
// Taking care with packing rules
// i.e. vectors cannot cross a 16 byte boundary

#pragma pack_matrix(row_major)
struct Transforms {
    float4x4 View; // 0
    float4x4 Projection; // 1
    arr(Texture, float4x4, 4); // 2, 3, 4, 5
    arr(World, float4x4, 4); // 6, 7, 8, 9
};

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

struct Material {
    float4 Diffuse;
    float4 Ambient;
    float4 Specular;
    float4 Emissive;
    float Power;
};

struct Modes {
    float4 Ambient;

    uint AmbientMaterialSource;
    uint DiffuseMaterialSource;
    uint EmissiveMaterialSource;
    uint SpecularMaterialSource;

    int Lighting;
    int ColorVertex;

    int VertexBlend;
};

struct RenderStateBlock {
    alignas(16) Transforms Transforms;
    alignas(16) Modes Modes;
    alignas(16) Material Material;
    alignas(16) arr(Lights, Light, 8);
};


#undef float4x4
#undef float4
#undef float3
#undef float2
#undef arr
#undef uint
#undef int
