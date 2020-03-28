#include "RenderStateBlock.cpp"

RenderStateBlock state; // : register(c214);

// TODO just use texcoord for everything
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
	float4 oB0  : TEXCOORD4; // Back-facing primary color
	float4 oB1  : TEXCOORD5; // Back-facing secondary color
	float4 oT0  : TEXCOORD0; // Texture coordinate set 0
	float4 oT1  : TEXCOORD1; // Texture coordinate set 1
	float4 oT2  : TEXCOORD2; // Texture coordinate set 2
	float4 oT3  : TEXCOORD3; // Texture coordinate set 3
};

struct ColorsOutput
{
    float4 Diffuse;
    float4 Specular;
    float4 BackDiffuse;
    float4 BackSpecular;
};

ColorsOutput CalcLighting(float3 worldNormal, float3 worldPos, float3 cameraPos)
{
    ColorsOutput output = (ColorsOutput) 0.0;

    // TODO everything
    
    for (int i = 0; i < 8; i++)
    {
        // DX11 FixedFuncEmu code
        Light cur = state.Lights[i];
        float3 toLight = cur.Position.xyz - worldPos;
        float lightDist = length(toLight);
        float fAtten = 1.0 / dot(cur.Attenuation0, float4(1, lightDist, lightDist * lightDist, 0));
        float3 lightDir = normalize(toLight);
        float3 halfAngle = normalize(normalize(-cameraPos) + lightDir);
        
        output.Diffuse += max(0, dot(lightDir, worldNormal) * cur.Diffuse * fAtten) + cur.Ambient;
        output.Specular += max(0, pow(dot(halfAngle, worldNormal), 64) * cur.Specular * fAtten);
    }

    output.BackDiffuse = output.BackSpecular = float4(1, 1, 1, 1);
    
    return output;
}

VS_OUTPUT main(const VS_INPUT xIn)
{
	VS_OUTPUT xOut;

    float4 worldPos = mul(xIn.pos, state.Transforms.World);
    float4 cameraPos = mul(worldPos, state.Transforms.View);
    xOut.oPos = mul(cameraPos, state.Transforms.Projection);

    // Vertex lighting
    if (false)
    {
        float3 worldNormal = normalize(mul(xIn.normal.xyz, (float3x3) state.Transforms.World));
        // output.wNorm = worldNormal;
        ColorsOutput cOut = CalcLighting(worldNormal, worldPos.xyz, cameraPos.xyz);
        xOut.oD0 = cOut.Diffuse;
        xOut.oD1 = cOut.Specular;
        // TODO backface calcs
        xOut.oD0 = cOut.BackDiffuse;
        xOut.oD1 = cOut.BackSpecular;
    }
    else
    {
        xOut.oD0 = xOut.oB0 = float4(1, 1, 1, 1);
        xOut.oD1 = xOut.oB1 = float4(0, 0, 0, 0);

    }
    // TODO fog and fog state
	xOut.oFog = 0;


    // TODO point stuff
	xOut.oPts = 0;


	// TODO reverse scaling for linear textures
	xOut.oT0 = xIn.texcoord[0];
    xOut.oT1 = xIn.texcoord[1];
    xOut.oT2 = xIn.texcoord[2];
    xOut.oT3 = xIn.texcoord[3];

	return xOut;
}
