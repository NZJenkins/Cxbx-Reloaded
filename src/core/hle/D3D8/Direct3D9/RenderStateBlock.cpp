// C++ / HLSL shared state block for fixed function support
#pragma once
#ifdef  __cplusplus

// #include <DirectXMath.h>
#include <d3d9.h>
#include <d3d9types.h> // for D3DFORMAT, D3DLIGHT9, etc
#include <d3dx9math.h> // for D3DXVECTOR4, etc

#define float4x4 D3DMATRIX

#endif //  __cplusplus

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

#pragma pack 16
struct RenderStateBlock {
    Transforms Transforms;
};
