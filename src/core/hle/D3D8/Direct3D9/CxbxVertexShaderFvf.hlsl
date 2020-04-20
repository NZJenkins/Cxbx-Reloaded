#include "RenderStateBlock.cpp"

// todo rename Fvf => FixedFunc

// Default values for vertex registers, and whether to use them
uniform float4 vRegisterDefaultValues[16] : register(c192); // Matches CXBX_D3DVS_ATTRDATA_BASE
uniform float4 vRegisterDefaultFlagsPacked[4] : register(c208); // Matches CXBX_D3DVS_ATTRFLAG_BASE

//uniform float4 xboxViewportScale   : register(c212); // Matches CXBX_D3DVS_VIEWPORT_MIRROR_SCALE_BASE
//uniform float4 xboxViewportOffset  : register(c213); // Matches CXBX_D3DVS_VIEWPORT_MIRROR_OFFSET_BASE

uniform RenderStateBlock state : register(c214); // Matches CXBX_D3DVS_FIXEDFUNCSTATE_BASE


// TODO just use texcoord for everything
// Input registers
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
    float4 backColor[2] : TEXCOORD4;
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

struct TransformInfo
{
    float4 Position;
    float3 Normal;
};

static TransformInfo World;
static TransformInfo View;

// Vertex lighting
// Both frontface and backface lighting can be calculated
struct LightingInfo
{
    float3 Front;
    float3 Back;
};

// Final lighting output
struct LightingOutput
{
    float3 Ambient;
    LightingInfo Diffuse;
    LightingInfo Specular;
};

LightingInfo DoSpecular(float3 lightDirWorld, float3 toViewerView, float2 powers, float4 lightSpecular)
{
    LightingInfo o;
    o.Front = o.Back = float3(0, 0, 0);
    
    // Specular
    if (state.Modes.SpecularEnable)
    {
        // Blinn-Phong
        // https://learnopengl.com/Advanced-Lighting/Advanced-Lighting
        float3 lightDirView = mul(lightDirWorld, (float3x3) state.Transforms.View); // Premultiply?
        float3 halfway = normalize(toViewerView + lightDirView);
        float NdotH = dot(View.Normal, halfway);

        float3 frontSpecular = pow(abs(NdotH), powers[0]) * lightSpecular.rgb;
        float3 backSpecular = pow(abs(NdotH), powers[1]) * lightSpecular.rgb;
        
        if (NdotH >= 0)
            o.Front = frontSpecular;
        else
            o.Back = backSpecular;
    }

    return o;
}

// useful reference https://drivers.amd.com/misc/samples/dx9/FixedFuncShader.pdf

LightingOutput DoPointLight(Light l, float3 toViewerView, float2 powers)
{
    LightingOutput o;
    o.Ambient = l.Ambient.rgb;
    o.Diffuse.Front = o.Diffuse.Back = float3(0, 0, 0);
    o.Specular.Front = o.Specular.Back = float3(0, 0, 0);

    // Diffuse
    float3 toLightWorld = World.Position.xyz - l.Position;
    float3 lightDirWorld = normalize(toLightWorld);
    float lightDist = length(toLightWorld);
    // A(Constant) + A(Linear) * dist + A(Exp) * dist^2
    float attenuation =
        1 / (l.Attenuation[0]
        + l.Attenuation[1] * lightDist
        + l.Attenuation[2] * lightDist * lightDist);

    float NdotL = dot(World.Normal, lightDirWorld);
    float3 lightDiffuse = abs(NdotL * attenuation) * l.Diffuse.rgb;

    if (NdotL >= 0.f)
        o.Diffuse.Front = lightDiffuse;
    else
        o.Diffuse.Back = lightDiffuse;

    // Specular
    o.Specular = DoSpecular(lightDirWorld, toViewerView, powers, l.Specular);

    return o;
}

LightingOutput DoSpotLight(Light l, float3 toViewerView, float2 powers)
{
	LightingOutput o;
	o.Ambient = l.Ambient.rgb;
	o.Diffuse.Front = o.Diffuse.Back = float3(0, 0, 0);
	o.Specular.Front = o.Specular.Back = float3(0, 0, 0);
	return o;
}

LightingOutput DoDirectionalLight(Light l, float3 toViewerView, float2 powers)
{
    LightingOutput o;
    o.Ambient = l.Ambient.rgb;
    o.Diffuse.Front = o.Diffuse.Back = float3(0, 0, 0);
    o.Specular.Front = o.Specular.Back = float3(0, 0, 0);

    // Diffuse

    // Intensity from N . L
    float3 toLightWorld = -normalize(l.Direction); // should we normalize?
    float NdotL = dot(World.Normal, toLightWorld);
    float3 lightDiffuse = abs(NdotL * l.Diffuse.rgb);

    // Apply light contribution to front or back face
    // as the case may be
    if (NdotL >= 0)
        o.Diffuse.Front = lightDiffuse;
    else
        o.Diffuse.Back = lightDiffuse;

    // Specular
    o.Specular = DoSpecular(toLightWorld, toViewerView, powers, l.Specular);

    return o;
}


LightingOutput CalcLighting(float2 powers)
{
    const int LIGHT_TYPE_NONE        = 0;
    const int LIGHT_TYPE_POINT       = 1;
    const int LIGHT_TYPE_SPOT        = 2;
    const int LIGHT_TYPE_DIRECTIONAL = 3;

    LightingOutput totalLightOutput;
    totalLightOutput.Ambient = float3(0, 0, 0);
    totalLightOutput.Diffuse.Front = float3(0, 0, 0);
    totalLightOutput.Diffuse.Back = float3(0, 0, 0);
    totalLightOutput.Specular.Front = float3(0, 0, 0);
    totalLightOutput.Specular.Back = float3(0, 0, 0);

    float3 toViewerView = float3(0, 0, 1);
    if (state.Modes.LocalViewer)
        toViewerView = normalize(-View.Position.xyz);
    
    for (uint i = 0; i < 8; i++)
    {
        const Light currentLight = state.Lights[i];
        LightingOutput currentLightOutput;

        if(currentLight.Type == LIGHT_TYPE_POINT)
            currentLightOutput = DoPointLight(currentLight, toViewerView, powers);
        else if(currentLight.Type == LIGHT_TYPE_SPOT)
            currentLightOutput = DoSpotLight(currentLight, toViewerView, powers);
        else if (currentLight.Type == LIGHT_TYPE_DIRECTIONAL)
            currentLightOutput = DoDirectionalLight(currentLight, toViewerView, powers);
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

TransformInfo DoWorldTransform(float4 position, float3 normal, float4 blendWeights)
{
    TransformInfo output;
    output.Position = float4(0, 0, 0, 0);
    output.Normal = float3(0, 0, 0);

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

        // TODO verify correct behaviour when COLORVERTEX is true but no vertex colours are provided
        // Do we use the material value like D3D9? Or the default colour value (which you can set on Xbox)
        // In D3D9 "If either AMBIENTMATERIALSOURCE option is used, and the vertex color is not provided, then the material ambient color is used."
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

float DoFog()
{
    const int D3DFOG_NONE = 0;
    const int D3DFOG_EXP = 1;
    const int D3DFOG_EXP2 = 2;
    const int D3DFOG_LINEAR = 3;

    // Early exit if fog is disabled
    //if (!state.Fog.Enable || state.Fog.TableMode == D3DFOG_NONE)
    //    return 0;

    // We're doing some fog
    float depth = state.Fog.RangeFogEnable ? length(View.Position.xyz) : abs(View.Position.z);

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

float4 DoTexCoord(int stage, float4 texCoords[4])
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
    int countFlag = tState.TextureTransformFlagsCount;
    bool projected = tState.TextureTransformFlagsProjected;

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
        float3 reflected = reflect(normalize(View.Position.xyz), View.Normal);
        
        if (tState.TexCoordIndexGen == TCI_CAMERASPACENORMAL)
            texCoord.xyz = View.Normal;
        else if (tState.TexCoordIndexGen == TCI_CAMERASPACEPOSITION)
            texCoord = View.Position;
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

VS_OUTPUT main(VS_INPUT xIn)
{
	VS_OUTPUT xOut;

	// Unpack 16 flags from 4 float4 constant registers
    float vRegisterDefaultFlags[16] = (float[16]) vRegisterDefaultFlagsPacked;

    // TODO make sure this goes fast
    // TODO ditch semantics, use texcoord inputs
    // TODO translate FVFs to vertex declarations
    // TODO make sure register default flags are actually set properly
    // Map default color values
    if (vRegisterDefaultFlags[0]) xIn.pos = vRegisterDefaultValues[0];
    if (vRegisterDefaultFlags[1]) xIn.bw = vRegisterDefaultValues[1]; // TODO : Is index 1 correct?
    if (vRegisterDefaultFlags[2]) xIn.normal = vRegisterDefaultValues[2];
    if (vRegisterDefaultFlags[3]) xIn.color[0] = vRegisterDefaultValues[3];
    if (vRegisterDefaultFlags[4]) xIn.color[1] = vRegisterDefaultValues[4];
    // if (vRegisterDefaultFlags[5]) xIn.fog = vRegisterDefaultValues[5];
	if (vRegisterDefaultFlags[7]) xIn.backColor[0] = vRegisterDefaultValues[7];
	if (vRegisterDefaultFlags[8]) xIn.backColor[1] = vRegisterDefaultValues[8];
	if (vRegisterDefaultFlags[9]) xIn.texcoord[0] = vRegisterDefaultValues[9];
	if (vRegisterDefaultFlags[10]) xIn.texcoord[1] = vRegisterDefaultValues[10];
    if (vRegisterDefaultFlags[11]) xIn.texcoord[2] = vRegisterDefaultValues[11];
	if (vRegisterDefaultFlags[12]) xIn.texcoord[3] = vRegisterDefaultValues[12];

    // World transform with vertex blending
    World = DoWorldTransform(xIn.pos, xIn.normal.xyz, xIn.bw);

    // View transform
    View.Position = mul(World.Position, state.Transforms.View);
    View.Normal = mul(World.Normal, (float3x3) state.Transforms.View);

    // Optionally normalize camera-space normals
    // TODO what about world normals? Or move all lighting to camera space like d3d?
    if (state.Modes.NormalizeNormals)
        View.Normal = normalize(View.Normal);

    // Projection transform - final position
    xOut.oPos = mul(View.Position, state.Transforms.Projection);

    float3 cameraPosWorld = -state.Transforms.View[3].xyz;

    // Vertex lighting
    if (state.Modes.Lighting || state.Modes.TwoSidedLighting)
    {
        // Materials
        Material material = DoMaterial(0, xIn.color[0], xIn.color[1]);
        Material backMaterial = DoMaterial(1, xIn.backColor[0], xIn.backColor[1]);
        
        float2 powers = float2(material.Power, backMaterial.Power);

        LightingOutput lighting = CalcLighting(powers);

        // Compute each lighting component
        float3 ambient = material.Ambient.rgb * (state.Modes.Ambient.rgb + lighting.Ambient);
        float3 backAmbient = backMaterial.Ambient.rgb * (state.Modes.BackAmbient.rgb + lighting.Ambient);
    
        float3 diffuse = material.Diffuse.rgb * lighting.Diffuse.Front;
        float3 backDiffuse = backMaterial.Diffuse.rgb * lighting.Diffuse.Back;
    
        float3 specular = material.Specular.rgb * lighting.Specular.Front;
        float3 backSpecular = backMaterial.Specular.rgb * lighting.Specular.Back;
    
        float3 emissive = material.Emissive.rgb;
        float3 backEmissive = backMaterial.Emissive.rgb;

        // Frontface
        xOut.oD0 = float4(ambient + diffuse + emissive, material.Diffuse.a);
        xOut.oD1 = float4(specular, 0);
        // Backface
        xOut.oB0 = float4(backAmbient + backDiffuse + backEmissive, backMaterial.Diffuse.a);
        xOut.oB1 = float4(backSpecular, 0);
    }

    // TODO verify if TwoSidedLighting can be enabled independently of Lighting
    // Diffuse and specular for when lighting is disabled
    // Use default values. Materials aren't used
    if (!state.Modes.Lighting)
    {
        xOut.oD0 = state.Modes.ColorVertex ? xIn.color[0] : float4(1, 1, 1, 1);
        xOut.oD1 = state.Modes.ColorVertex ? xIn.color[1] : float4(0, 0, 0, 0);
    }

    if(!state.Modes.TwoSidedLighting)
    {
        xOut.oB0 = state.Modes.ColorVertex ? xIn.backColor[0] : float4(1, 1, 1, 1);
        xOut.oB1 = state.Modes.ColorVertex ? xIn.backColor[1] : float4(0, 0, 0, 0);
    }

    xOut.oD0 = saturate(xOut.oD0);
    xOut.oD1 = saturate(xOut.oD1);
    xOut.oB0 = saturate(xOut.oB0);
    xOut.oB1 = saturate(xOut.oB1);

    float fog = DoFog();
    xOut.oFog = fog;

    // TODO point stuff
	xOut.oPts = 0;

    // xOut.oD0 = float4(world.Normal, 1);

	// TODO reverse scaling for linear textures
    xOut.oT0 = DoTexCoord(0, xIn.texcoord);
    xOut.oT1 = DoTexCoord(1, xIn.texcoord);
    xOut.oT2 = DoTexCoord(2, xIn.texcoord);
    xOut.oT3 = DoTexCoord(3, xIn.texcoord);

	return xOut;
}
