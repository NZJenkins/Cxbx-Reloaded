#include "RenderStateBlock.cpp"

// todo rename Fvf => FixedFunc

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

// useful reference https://drivers.amd.com/misc/samples/dx9/FixedFuncShader.pdf

ColorsOutput DoPointLight(Light l)
{
    
}

ColorsOutput DoDirectionalLight(Light l, float3 worldNormal)
{
    ColorsOutput o;
    o.Diffuse = l.Ambient;
    o.BackDiffuse = l.Ambient;
    o.Specular = 0;
    o.BackSpecular = 0;

    // Intensity from N . L
    float intensity = dot(worldNormal, -normalize(l.Direction));
    float lightDiffuse = intensity * l.Diffuse;

    // Apply light contribution to front or back face
    // as the case may be
    if(intensity > 0)
        o.Diffuse += lightDiffuse;
    else if (intensity < 0)
        o.BackDiffuse += lightDiffuse;

    // TODO specular

    return o;
}

        // DX11 FixedFuncEmu code
//Light cur = state.Lights[i];
//float3 toLight = cur.Position.xyz - worldPos;
//float lightDist = length(toLight);
//float fAtten = 1.0 / dot(cur.Attenuation0, float4(1, lightDist, lightDist * lightDist, 0));
//float3 lightDir = normalize(toLight);
//float3 halfAngle = normalize(normalize(-cameraPos) + lightDir);
        
//        output.Diffuse += max(0, dot(lightDir, worldNormal) * cur.Diffuse * fAtten) + cur.
//Ambient;
//        output.Specular += max(0, pow(dot(halfAngle, worldNormal), 64) * cur.Specular * fAtten);

ColorsOutput CalcLighting(float3 worldNormal, float3 worldPos, float3 cameraPos)
{
    const uint LIGHT_TYPE_NONE        = 0;
    const uint LIGHT_TYPE_POINT       = 1;
    const uint LIGHT_TYPE_SPOT        = 2;
    const uint LIGHT_TYPE_DIRECTIONAL = 3;

    ColorsOutput todo;
    todo.Diffuse = float4(1, 0, 0, 1);
    todo.Specular = float4(0, 1, 0, 1);
    todo.BackDiffuse = float4(0, 0, 1, 1);
    todo.BackSpecular = float4(1, 1, 0, 1);

    ColorsOutput totalLightOutput;
    totalLightOutput.Diffuse = float4(0, 0, 0, 1);
    totalLightOutput.BackDiffuse = float4(0, 0, 0, 1);
    totalLightOutput.Specular = float4(0, 0, 0, 0);
    totalLightOutput.BackSpecular = float4(0, 0, 0, 0);
    
    for (uint i = 0; i < 8; i++)
    {
        const Light currentLight = state.Lights[i];
        ColorsOutput currentLightOutput;
        bool isLight = true;

        switch (currentLight.Type)
        {
            case LIGHT_TYPE_NONE:
                isLight = false;
                break;
            case LIGHT_TYPE_POINT:
                currentLightOutput = todo; //DoPointLight(currentLight, worldNormal);
                break;
            case LIGHT_TYPE_SPOT:
                currentLightOutput = todo; //DoSpot(currentLight);
                break;
            case LIGHT_TYPE_DIRECTIONAL:
                currentLightOutput = DoDirectionalLight(currentLight, worldNormal);
                break;
        }

        if (!isLight)
            continue;
        
        totalLightOutput.Diffuse += currentLightOutput.Diffuse;
        totalLightOutput.BackDiffuse += currentLightOutput.BackDiffuse;
        totalLightOutput.Specular += currentLightOutput.Specular;
        totalLightOutput.BackSpecular += currentLightOutput.BackSpecular;
    }

    return totalLightOutput;
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
        xOut.oB0 = cOut.BackDiffuse;
        xOut.oB1 = cOut.BackSpecular;
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
