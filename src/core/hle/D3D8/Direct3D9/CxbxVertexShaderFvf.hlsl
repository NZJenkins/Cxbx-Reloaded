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
    float4 color[2] : COLOR;
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

struct LightingOutput
{
    float4 Ambient;
    float4 Diffuse;
    float4 Specular;
    float4 BackDiffuse;
    float4 BackSpecular;
};

// useful reference https://drivers.amd.com/misc/samples/dx9/FixedFuncShader.pdf

LightingOutput DoPointLight(Light l, float3 worldNormal, float3 worldPos)
{
    LightingOutput o;
    o.Ambient = l.Ambient;
    o.Diffuse = o.BackDiffuse = float4(0, 0, 0, 0);
    o.Specular = o.BackSpecular= float4(0, 0, 0, 0);
    
    float3 toLight = worldPos - l.Position;
    float lightDist = length(toLight);
    // A(Constant) + A(Linear) * dist + A(Exp) * dist^2
    float attenuation =
        1 / (l.Attenuation0
        + l.Attenuation1 * lightDist
        + l.Attenuation2 * lightDist * lightDist);

    float NdotL = dot(worldNormal, normalize(toLight));
    float lightDiffuse = abs(NdotL * attenuation) * l.Diffuse;;

    if (NdotL >= 0.f)
        o.Diffuse = lightDiffuse;
    else
        o.BackDiffuse = lightDiffuse;

    // TODO specular

    return o;
}

LightingOutput DoDirectionalLight(Light l, float3 worldNormal)
{
    LightingOutput o;
    o.Ambient = l.Ambient;
    o.Diffuse = o.BackDiffuse = float4(0, 0, 0, 0);
    o.Specular = o.BackSpecular = float4(0, 0, 0, 0);

    // Intensity from N . L
    float NdotL = dot(worldNormal, -normalize(l.Direction));
    float lightDiffuse = abs(NdotL * l.Diffuse.rgb);

    // Apply light contribution to front or back face
    // as the case may be
    if (NdotL >= 0)
        o.Diffuse += lightDiffuse;
    else
        o.BackDiffuse += lightDiffuse;

    // TODO specular

    return o;
}


LightingOutput CalcLighting(float3 worldNormal, float3 worldPos, float3 cameraPos)
{
    const int LIGHT_TYPE_NONE        = 0;
    const int LIGHT_TYPE_POINT       = 1;
    const int LIGHT_TYPE_SPOT        = 2;
    const int LIGHT_TYPE_DIRECTIONAL = 3;

    LightingOutput totalLightOutput;
    totalLightOutput.Ambient = float4(0, 0, 0, 0);
    totalLightOutput.Diffuse = float4(0, 0, 0, 0);
    totalLightOutput.BackDiffuse = float4(0, 0, 0, 0);
    totalLightOutput.Specular = float4(0, 0, 0, 0);
    totalLightOutput.BackSpecular = float4(0, 0, 0, 0);
    
    
    for (uint i = 0; i < 8; i++)
    {
        const Light currentLight = state.Lights[i];
        LightingOutput currentLightOutput;

        if(currentLight.Type == LIGHT_TYPE_POINT)
            currentLightOutput = DoPointLight(currentLight, worldNormal, worldPos);
        else if(currentLight.Type == LIGHT_TYPE_SPOT)
            continue;
        else if (currentLight.Type == LIGHT_TYPE_DIRECTIONAL)
            currentLightOutput = DoDirectionalLight(currentLight, worldNormal);
        else
            continue;

        totalLightOutput.Ambient += currentLightOutput.Ambient;
        totalLightOutput.Diffuse += currentLightOutput.Diffuse;
        totalLightOutput.BackDiffuse += currentLightOutput.BackDiffuse;
        totalLightOutput.Specular += currentLightOutput.Specular;
        totalLightOutput.BackSpecular += currentLightOutput.BackSpecular;
    }

    return totalLightOutput;
}

struct WorldTransformOutput
{
    float4 Position;
    float3 Normal;
};

WorldTransformOutput DoWorldTransform(float4 position, float3 normal, float4 blendWeights)
{
    WorldTransformOutput output;

    // D3D
    const int _BLEND_OFF = 0;
    const int _1WEIGHT_2MAT = 1;
    const int _2WEIGHT_3MAT = 3;
    const int _3WEIGHT_4MAT = 5;
    // Xbox
    const int _2WEIGHT_2MAT = 2;
    const int _3WEIGHT_3MAT = 4;
    const int _4WEIGHT_4MAT = 6;

    if (state.Modes.VertexBlend == _BLEND_OFF) {
        output.Position = mul(position, state.Transforms.World[0]);
        output.Normal = mul(normal, (float3x3)state.Transforms.World[0]);
        return output;
    }
    
    // The number of matrices to blend
    int mats = floor((state.Modes.VertexBlend - 1) / 2 + 2);
    // If we have to calculate the last blend value
    bool calcLastBlend = fmod(state.Modes.VertexBlend, 2) == 1;

    float lastBlend = 1;
    for (int i = 0; i < mats - 1; i++)
    {
        output.Position += mul(position, state.Transforms.World[i]) * blendWeights[i];
        output.Normal += mul(normal, (float3x3) state.Transforms.World[i]) * blendWeights[i];
        lastBlend -= blendWeights[i];
    }

    if (calcLastBlend)
    {
        output.Position += mul(position, state.Transforms.World[mats-1]) * lastBlend;
        output.Normal += mul(normal, (float3x3) state.Transforms.World[mats-1]) * lastBlend;
    }
    else
    {
        output.Position += mul(position, state.Transforms.World[mats-1]) * blendWeights[mats-1];
        output.Normal += mul(normal, (float3x3) state.Transforms.World[mats-1]) * blendWeights[mats-1];
    }

    return output;
}

VS_OUTPUT main(const VS_INPUT xIn)
{
	VS_OUTPUT xOut;

    // World transform with vertex blending
    WorldTransformOutput world = DoWorldTransform(xIn.pos, xIn.normal.xyz, xIn.bw);

    float4 worldPos = world.Position;
    float4 cameraPos = mul(worldPos, state.Transforms.View);
    xOut.oPos = mul(cameraPos, state.Transforms.Projection);

    // Vertex lighting
    LightingOutput lighting;
    if (state.Modes.Lighting)
    {
        float3 worldNormal = normalize(world.Normal);
        lighting = CalcLighting(worldNormal, worldPos.xyz, cameraPos.xyz);
    }
    else
    {
        lighting.Ambient = float4(0, 0, 0, 0);
        lighting.Diffuse = lighting.BackDiffuse = float4(1, 1, 1, 1);
        lighting.Specular = lighting.BackSpecular = float4(0, 0, 0, 1);
    }

    // Colours
    Material material;
    if (state.Modes.ColorVertex)
    {
        const int SRC_MATERIAL = 0;
        const int SRC_COLOR1 = 1;
        const int SRC_COLOR2 = 2;

        // FIXME "If either AMBIENTMATERIALSOURCE option is used, and the vertex color is not provided, then the material ambient color is used."
        if(state.Modes.AmbientMaterialSource == SRC_MATERIAL)
            material.Ambient = state.Material.Ambient;
        else if(state.Modes.AmbientMaterialSource == SRC_COLOR1)
            material.Ambient = xIn.color[0];
        else
            material.Ambient = xIn.color[1];

        if (state.Modes.AmbientMaterialSource == SRC_MATERIAL)
            material.Diffuse = state.Material.Diffuse;
        else if (state.Modes.DiffuseMaterialSource == SRC_COLOR1)
            material.Diffuse = xIn.color[0];
        else
            material.Diffuse = xIn.color[1];

        if (state.Modes.SpecularMaterialSource == SRC_MATERIAL)
            material.Specular = state.Material.Specular;
        else if (state.Modes.SpecularMaterialSource == SRC_COLOR1)
            material.Specular = xIn.color[0];
        else
            material.Specular = xIn.color[1];

        if (state.Modes.EmissiveMaterialSource == SRC_MATERIAL)
            material.Emissive = state.Material.Emissive;
        else if (state.Modes.EmissiveMaterialSource == SRC_COLOR1)
            material.Emissive = xIn.color[0];
        else
            material.Emissive = xIn.color[1];
    }
    else
    {
        material.Ambient = state.Material.Ambient;
        material.Diffuse = state.Material.Diffuse;
        material.Specular = state.Material.Specular;
        material.Emissive = state.Material.Emissive;
    }

    // TODO implement material backface diffuse & specular
    float4 ambient = material.Ambient * (state.Modes.Ambient + lighting.Ambient);
    float4 diffuse = material.Diffuse * lighting.Diffuse;
    float4 backDiffuse = float4(1, 1, 1, 1) * lighting.BackDiffuse;
    float4 specular = material.Specular * lighting.Specular;
    float4 backSpecular = float4(0, 0, 0, 0) * lighting.BackSpecular;
    float4 emissive = material.Emissive;

    xOut.oD0 = saturate(ambient + diffuse + emissive);
    xOut.oD1 = saturate(specular);
    // TODO backface colours
    xOut.oB0 = saturate(ambient + backDiffuse + emissive);
    xOut.oB1 = saturate(backSpecular);

    // TODO fog and fog state
	xOut.oFog = 0;

    // TODO point stuff
	xOut.oPts = 0;

    // xOut.oD0 = float4(world.Normal, 1);

	// TODO reverse scaling for linear textures
	xOut.oT0 = xIn.texcoord[0];
    xOut.oT1 = xIn.texcoord[1];
    xOut.oT2 = xIn.texcoord[2];
    xOut.oT3 = xIn.texcoord[3];

	return xOut;
}
