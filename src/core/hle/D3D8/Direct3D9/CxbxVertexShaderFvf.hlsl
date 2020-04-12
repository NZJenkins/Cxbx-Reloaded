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

// Vertex lighting
// Both frontface and backface lighting can be calculated
struct LightingInfo
{
    float4 Front;
    float4 Back;
};

// Final lighting output
struct LightingOutput
{
    float4 Ambient;
    LightingInfo Diffuse;
    LightingInfo Specular;
};

LightingInfo DoSpecular(float3 toLightWorld, float3 vNormWorld, float3 toViewerView, float2 powers, float4 lightSpecular)
{
    LightingInfo o;
    o.Front = o.Back = float4(0, 0, 0, 0);
    
    // Specular
    if (state.Modes.SpecularEnable)
    {
        // Blinn-Phong
        // https://learnopengl.com/Advanced-Lighting/Advanced-Lighting
        // TODO do everytihng in same coordinate space so it might actually work
        toLightWorld = normalize(toLightWorld);
        float3 halfway = normalize(toViewerView + toLightWorld);
        float NdotH = dot(vNormWorld, halfway);

        float4 frontSpecular = pow(abs(NdotH), powers[0]) * lightSpecular;
        float4 backSpecular = pow(abs(NdotH), powers[1]) * lightSpecular;
        
        if (NdotH >= 0)
            o.Front = frontSpecular;
        else
            o.Back = backSpecular;
    }

    return o;
}

// useful reference https://drivers.amd.com/misc/samples/dx9/FixedFuncShader.pdf

LightingOutput DoPointLight(Light l, float3 vNormWorld, float3 vPosWorld, float3 toViewerView, float2 powers)
{
    LightingOutput o;
    o.Ambient = l.Ambient;
    o.Diffuse.Front = o.Diffuse.Back = float4(0, 0, 0, 0);
    o.Specular.Front = o.Specular.Back = float4(0, 0, 0, 0);

    // Diffuse
    float3 toLightWorld = vPosWorld - l.Position;
    float lightDist = length(toLightWorld);
    // A(Constant) + A(Linear) * dist + A(Exp) * dist^2
    float attenuation =
        1 / (l.Attenuation0
        + l.Attenuation1 * lightDist
        + l.Attenuation2 * lightDist * lightDist);

    float NdotL = dot(vNormWorld, normalize(toLightWorld)); // should we normalize?
    float4 lightDiffuse = abs(NdotL * attenuation) * l.Diffuse;;

    if (NdotL >= 0.f)
        o.Diffuse.Front = lightDiffuse;
    else
        o.Diffuse.Back = lightDiffuse;

    // Specular
    o.Specular = DoSpecular(toLightWorld, vNormWorld, toViewerView, powers, l.Specular);

    return o;
}

LightingOutput DoDirectionalLight(Light l, float3 vNormWorld, float3 toViewerView, float2 powers)
{
    LightingOutput o;
    o.Ambient = l.Ambient;
    o.Diffuse.Front = o.Diffuse.Back = float4(0, 0, 0, 0);
    o.Specular.Front = o.Specular.Back = float4(0, 0, 0, 0);

    // Diffuse

    // Intensity from N . L
    float3 toLightWorld = -normalize(l.Direction); // should we normalize?
    float NdotL = dot(vNormWorld, toLightWorld);
    float4 lightDiffuse = abs(NdotL * l.Diffuse);

    // Apply light contribution to front or back face
    // as the case may be
    if (NdotL >= 0)
        o.Diffuse.Front = lightDiffuse;
    else
        o.Diffuse.Back = lightDiffuse;

    // Specular
    o.Specular = DoSpecular(toLightWorld, vNormWorld, toViewerView, powers, l.Specular);

    return o;
}


LightingOutput CalcLighting(float3 vNormWorld, float3 vPosWorld, float3 vPosView, float2 powers)
{
    const int LIGHT_TYPE_NONE        = 0;
    const int LIGHT_TYPE_POINT       = 1;
    const int LIGHT_TYPE_SPOT        = 2;
    const int LIGHT_TYPE_DIRECTIONAL = 3;

    LightingOutput totalLightOutput;
    totalLightOutput.Ambient = float4(0, 0, 0, 1);
    totalLightOutput.Diffuse.Front = float4(0, 0, 0, 1);
    totalLightOutput.Diffuse.Back = float4(0, 0, 0, 1);
    totalLightOutput.Specular.Front = float4(0, 0, 0, 1);
    totalLightOutput.Specular.Back = float4(0, 0, 0, 1);

    float3 toViewerView = float3(0, 0, 1);
    if (state.Modes.LocalViewer)
        toViewerView = normalize(-vPosView);
    
    
    for (uint i = 0; i < 8; i++)
    {
        const Light currentLight = state.Lights[i];
        LightingOutput currentLightOutput;

        if(currentLight.Type == LIGHT_TYPE_POINT)
            currentLightOutput = DoPointLight(currentLight, vNormWorld, vPosWorld, toViewerView, powers);
        else if(currentLight.Type == LIGHT_TYPE_SPOT)
            continue;
        else if (currentLight.Type == LIGHT_TYPE_DIRECTIONAL)
            currentLightOutput = DoDirectionalLight(currentLight, vNormWorld, toViewerView, powers);
        else
            continue;

        totalLightOutput.Ambient += currentLightOutput.Ambient;
        totalLightOutput.Diffuse.Front += currentLightOutput.Diffuse.Front;
        totalLightOutput.Diffuse.Back += currentLightOutput.Diffuse.Back;
        totalLightOutput.Specular.Front += currentLightOutput.Specular.Front;
        totalLightOutput.Specular.Back += currentLightOutput.Specular.Back;
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

Material DoMaterial(int index, float4 color0, float4 color1)
{
    Material stateMat = state.Materials[index];

    Material runtimeMat;
    if (state.Modes.ColorVertex)
    {
        const int SRC_MATERIAL = 0;
        const int SRC_COLOR1 = 1;
        const int SRC_COLOR2 = 2;

        // FIXME "If either AMBIENTMATERIALSOURCE option is used, and the vertex color is not provided, then the material ambient color is used."
        if (state.Modes.AmbientMaterialSource == SRC_MATERIAL)
            runtimeMat.Ambient = stateMat.Ambient;
        else if (state.Modes.AmbientMaterialSource == SRC_COLOR1)
            runtimeMat.Ambient = color0;
        else
            runtimeMat.Ambient = color1;

        if (state.Modes.AmbientMaterialSource == SRC_MATERIAL)
            runtimeMat.Diffuse = stateMat.Diffuse;
        else if (state.Modes.DiffuseMaterialSource == SRC_COLOR1)
            runtimeMat.Diffuse = color0;
        else
            runtimeMat.Diffuse = color1;

        if (state.Modes.SpecularMaterialSource == SRC_MATERIAL)
            runtimeMat.Specular = stateMat.Specular;
        else if (state.Modes.SpecularMaterialSource == SRC_COLOR1)
            runtimeMat.Specular = color0;
        else
            runtimeMat.Specular = color1;

        if (state.Modes.EmissiveMaterialSource == SRC_MATERIAL)
            runtimeMat.Emissive = stateMat.Emissive;
        else if (state.Modes.EmissiveMaterialSource == SRC_COLOR1)
            runtimeMat.Emissive = color0;
        else
            runtimeMat.Emissive = color1;
    }
    else
    {
        runtimeMat.Ambient = stateMat.Ambient;
        runtimeMat.Diffuse = stateMat.Diffuse;
        runtimeMat.Specular = stateMat.Specular;
        runtimeMat.Emissive = stateMat.Emissive;
    }

    runtimeMat.Power = stateMat.Power;

    return runtimeMat;
}

float DoFog(float4 vPosView)
{
    const int D3DFOG_NONE = 0;
    const int D3DFOG_EXP = 1;
    const int D3DFOG_EXP2 = 2;
    const int D3DFOG_LINEAR = 3;

    // Early exit if fog is disabled
    //if (!state.Fog.Enable || state.Fog.TableMode == D3DFOG_NONE)
    //    return 0;

    // We're doing some fog
    float depth = state.Fog.RangeFogEnable ? length(vPosView.xyz) : abs(vPosView.z);

    // We just need to output the depth in oFog (?)
    
    return depth;

    /*
    float density = state.Fog.Density;
    float fogStart = state.Fog.Start;
    float fogEnd = state.Fog.End;

    if (state.Fog.TableMode == D3DFOG_EXP)
    {
        return 1 / exp(density * depth);
    }
    else if (state.Fog.TableMode == D3DFOG_EXP2)
    {
        return 1 / exp(pow(density * depth, 2));
    }
    else if (state.Fog.TableMode == D3DFOG_LINEAR)
    {
        return saturate((fogEnd - depth) / (fogEnd - fogStart));
    }

    return 0;
*/
}

float4 DoTexCoord(int stage, float4 texCoords[4], float3 vNormView, float4 vPosView)
{
    // Texture transform flags
    // https://docs.microsoft.com/en-gb/windows/win32/direct3d9/d3dtexturetransformflags
    const int D3DTTFF_DISABLE = 0;
    const int D3DTTFF_COUNT1  = 1;
    const int D3DTTFF_COUNT2  = 2;
    const int D3DTTFF_COUNT3  = 3;
    const int D3DTTFF_COUNT4  = 4;
    const int D3DTTFF_PROJECTED = 256; // This is the only real flag

    // https://docs.microsoft.com/en-us/windows/win32/direct3d9/d3dtss-tci
    // Pre-shifted
    const int TCI_PASSTHRU = 0;
    const int TCI_CAMERASPACENORMAL = 1;
    const int TCI_CAMERASPACEPOSITION = 2;
    const int TCI_CAMERASPACEREFLECTIONVECTOR = 3;
    const int TCI_OBJECT = 4; // Xbox
    const int TCI_SPHERE = 5; // Xbox

    const TextureState tState = state.TextureStates[stage];
    
    // Extract transform flags
    int countFlag = fmod(tState.TextureTransformFlags, D3DTTFF_PROJECTED);
    bool projected = tState.TextureTransformFlags > D3DTTFF_PROJECTED;

    // Something in this function is wrong
    // Test case: JSRF graffiti bottle pickups

    // Get texture coordinates
    // Coordinates are either from the vertex texcoord data
    // Or generated
    float4 texCoord = float4(0, 0, 0, 0);
    if (tState.TexCoordIndexGen == TCI_PASSTHRU)
    {
        // Get from vertex data
        int texCoordIndex = tState.TexCoordIndex;
        texCoord = texCoords[texCoordIndex];
    }
    else
    {   
        // Generate texture coordinates
        float3 reflected = reflect(normalize(vPosView.xyz), vNormView);
        
        if (tState.TexCoordIndexGen == TCI_CAMERASPACENORMAL)
            texCoord.xyz = vNormView;
        else if (tState.TexCoordIndexGen == TCI_CAMERASPACEPOSITION)
            texCoord = vPosView;
        else if (tState.TexCoordIndexGen == TCI_CAMERASPACEREFLECTIONVECTOR)
            texCoord.xyz = reflected;
        // else if TCI_OBJECT TODO is this just model position?
        else if (tState.TexCoordIndexGen == TCI_SPHERE)
        {
            // TODO verify
            // http://www.bluevoid.com/opengl/sig99/advanced99/notes/node177.html
            float3 R = reflected;
            float p = sqrt(pow(R.x, 2) + pow(R.y, 2) + pow(R.z + 1, 2));
            texCoord.x = R.x / 2 * p + 0.5;
            texCoord.y = R.y / 2 * p + 0.5;
        }
    }

    // Determine if we need to transform the texture coordinates
    if (countFlag == D3DTTFF_DISABLE)
        return texCoord; // No transforms, just return it

    // Transform the coordinates
    float4 transformedCoords = mul(texCoord, state.Transforms.Texture[stage]);
    
    if (projected)
    {
        // Projected coordinates are divided by the last coordinate index
        int lastCoordIndex = countFlag - 1;
        transformedCoords /= transformedCoords[lastCoordIndex];
    }

    return transformedCoords;
}

VS_OUTPUT main(const VS_INPUT xIn)
{
	VS_OUTPUT xOut;

    // World transform with vertex blending
    WorldTransformOutput world = DoWorldTransform(xIn.pos, xIn.normal.xyz, xIn.bw);

    float4 vPosWorld = world.Position;
    float4 vPosView = mul(vPosWorld, state.Transforms.View);
    xOut.oPos = mul(vPosView, state.Transforms.Projection);

    float3 vNormWorld = normalize(world.Normal);
    float3 vNormView = mul(vNormWorld, (float3x3) state.Transforms.View);

    float3 cameraPosWorld = -state.Transforms.View[3].xyz;

    // Vertex lighting
    if (state.Modes.Lighting)
    {
        // Materials
        Material material = DoMaterial(0, xIn.color[0], xIn.color[1]);
        Material backMaterial = DoMaterial(1, xIn.color[0], xIn.color[1]);
        
        float2 powers = float2(material.Power, backMaterial.Power);

        LightingOutput lighting = CalcLighting(vNormWorld, vPosWorld.xyz, vPosView.xyz, powers);

        if (!state.Modes.TwoSidedLighting)
        {
            lighting.Diffuse.Back = float4(1, 1, 1, 1);
            lighting.Specular.Back = float4(0, 0, 0, 1);
        }

        // Compute each lighting component
        float4 ambient = material.Ambient * (state.Modes.Ambient + lighting.Ambient);
        float4 backAmbient = backMaterial.Ambient * (state.Modes.BackAmbient + lighting.Ambient);
    
        float4 diffuse = material.Diffuse * lighting.Diffuse.Front;
        float4 backDiffuse = backMaterial.Diffuse * lighting.Diffuse.Back;
    
        float4 specular = material.Specular * lighting.Specular.Front;
        float4 backSpecular = backMaterial.Specular * lighting.Specular.Back;
    
        float4 emissive = material.Emissive;
        float4 backEmissive = backMaterial.Emissive;

        // Frontface
        xOut.oD0 = float4(saturate(ambient + diffuse + emissive).rgb, material.Diffuse.a);
        xOut.oD1 = saturate(specular);
        // Backface
        xOut.oB0 = float4(saturate(backAmbient + backDiffuse + backEmissive).rgb, backMaterial.Diffuse.a);
        xOut.oB1 = saturate(backSpecular);
    }
    else
    {
        // Use default values. Materials aren't used
        xOut.oD0 = xOut.oB0 = state.Modes.ColorVertex ? xIn.color[0] : float4(1, 1, 1, 1);
        xOut.oD1 = xOut.oB1 = state.Modes.ColorVertex ? xIn.color[1] : float4(0, 0, 0, 0);
    }

    float fog = DoFog(vPosView);
    xOut.oFog = fog;

    // TODO point stuff
	xOut.oPts = 0;

    // xOut.oD0 = float4(world.Normal, 1);

	// TODO reverse scaling for linear textures
    xOut.oT0 = DoTexCoord(0, xIn.texcoord, vNormView, vPosView);
    xOut.oT1 = DoTexCoord(1, xIn.texcoord, vNormView, vPosView);
    xOut.oT2 = DoTexCoord(2, xIn.texcoord, vNormView, vPosView);
    xOut.oT3 = DoTexCoord(3, xIn.texcoord, vNormView, vPosView);

	return xOut;
}
