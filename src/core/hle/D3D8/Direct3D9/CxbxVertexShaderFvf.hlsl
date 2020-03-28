#include "RenderStateBlock.cpp"

RenderStateBlock state : register(c214);

// Output registers
struct VS_INPUT
{
	// Position
	// BlendWeight
	// Normal
	// Diffuse
	// Spec
	// Fog
	// Unused?
	// Backface Diffuse
	// Backface Specular
	// TexCoord 0 - 3
    float4 pos : POSITION;
    float4 bw : BLENDWEIGHT;
    float3 color[2] : COLOR;
    float4 normal : NORMAL;
    float4 texcoord[4] : TEXCOORD;
	
};

// Output registers
struct VS_OUTPUT
{
	float4 oPos : POSITION;  // Homogeneous clip space position
	float4 oD0  : COLOR0;    // Primary color (front-facing)
	float4 oD1  : COLOR1;    // Secondary color (front-facing)
	float  oFog : FOG;       // Fog coordinate
	float  oPts : PSIZE;	 // Point size
	float4 oB0  : TEXCOORD4; // Back-facing primary colorrow_major
	float4 oB1  : TEXCOORD5; // Back-facing secondary color
	float4 oT0  : TEXCOORD0; // Texture coordinate set 0
	float4 oT1  : TEXCOORD1; // Texture coordinate set 1
	float4 oT2  : TEXCOORD2; // Texture coordinate set 2
	float4 oT3  : TEXCOORD3; // Texture coordinate set 3
};

VS_OUTPUT main(const VS_INPUT xIn)
{
	VS_OUTPUT xOut;

    float4 worldPos = mul(xIn.pos, state.Transforms.World);
    float4 cameraPos = mul(worldPos, state.Transforms.View);
    xOut.oPos = mul(cameraPos, state.Transforms.Projection);

	//xOut.oPos = xIn.v[0];

    xOut.oD0 = saturate(float4(xIn.color[0], 1)); //xIn.v[3]);
    xOut.oD1 = saturate(float4(xIn.color[1], 1)); //xIn.v[4]);

	xOut.oFog = 0;

	xOut.oPts = 0;

	// In D3D we need to be in the pixel shader to determine if we're using the backface or frontface
    xOut.oB0 = 0; // saturate(xIn.v[7]);
    xOut.oB1 = 0; // saturate(xIn.v[8]);

	// TODO scale with rendertarget
	xOut.oT0 = xIn.texcoord[0];
    xOut.oT1 = xIn.texcoord[1];
    xOut.oT2 = xIn.texcoord[2];
    xOut.oT3 = xIn.texcoord[3];

	return xOut;
}
