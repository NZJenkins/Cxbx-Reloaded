// This starts the raw string (comment to get syntax highlighting, UNCOMMENT to compile) :
R"DELIMITER(

struct VS_INPUT
{
	float4 v[16] : TEXCOORD;
};

struct VS_OUTPUT
{
	float4 oPos : POSITION;
	float4 oD0  : COLOR0; // Colour 0
	float4 oD1  : COLOR1; // Colour 1
	float  oFog : FOG;
	float  oPts : PSIZE;
	float4 oB0  : TEXCOORD4; // Backface Colour 0
	float4 oB1  : TEXCOORD5; // Backface Colour 1
	float4 oT0  : TEXCOORD0; // Texture Coord 0
	float4 oT1  : TEXCOORD1; // Texture Coord 1
	float4 oT2  : TEXCOORD2; // Texture Coord 2
	float4 oT3  : TEXCOORD3; // Texture Coord 3
};

// Constant registers
extern float4 hostConstants[192] : register(c0);

// Vertex input overrides for SetVertexData4f support
extern float4 vOverrideValue[16]  : register(c192);
extern float4 vOverridePacked[4]  : register(c208);

extern float4  xboxViewportScale   : register(c212);
extern float4  xboxViewportOffset  : register(c213);

// Map Xbox [-96, 95] to Host [0, 191]
// Account for Xbox's negative constant indexes
float4 c(int index) {
	// Out-of-range reads return 0
	if (index < -96 || index > 95)
		return float4(0, 0, 0, 0);

	return hostConstants[index + 96];
}

// Generic macros
#define x_mov(src0) src0

// Macros for MAC ('Multiply And Accumulate') opcodes
#define x_mul(src0, src1) src0 * src1
#define x_add(src0, src1) src0 + src1
#define x_dst(src0, src1) dst(src0, src1)
#define x_min(src0, src1) min(src0, src1)
#define x_max(src0, src1) max(src0, src1)
#define x_mad(src0, src1, src2) src0 * src1 + src2

// Xbox MAC functions
int x_arl(float src0) {
	// The address register should be floored
	// Due to rounding differences with the Xbox (and increased precision on PC?)
	// some titles produce values just below the threshold of the next integer.
	// We can add a small bias to make sure it's bumped over the threshold
	// Test Case: Azurik (divides indexes 755, then scales them back in the vertex shader)
	return floor(src0 + 0.0001);
}


float x_dp3(float4 src0, float4 src1) {
	return dot(src0.xyz, src1.xyz);
}

float x_dph(float4 src0, float4 src1) {
	return x_dp3(src0, src1) + src1.w;
}

float x_dp4(float4 src0, float4 src1) {
	return dot(src0, src1);
}

float4 x_sge(float4 src0, float4 src1) {
	float4 dest;
	dest.x = (src0.x >= src1.x) ? 1.0f : 0.0f;
	dest.y = (src0.y >= src1.y) ? 1.0f : 0.0f;
	dest.z = (src0.z >= src1.z) ? 1.0f : 0.0f;
	dest.w = (src0.w >= src1.w) ? 1.0f : 0.0f;
	return dest;
}

float4 x_slt(float4 src0, float4 src1) {
	float4 dest;
	dest.x = (src0.x < src1.x) ? 1.0f : 0.0f;
	dest.y = (src0.y < src1.y) ? 1.0f : 0.0f;
	dest.z = (src0.z < src1.z) ? 1.0f : 0.0f;
	dest.w = (src0.w < src1.w) ? 1.0f : 0.0f;
	return dest;
}

// Xbox ILU Functions

float x_rcp(float4 src0) {
	return 1 / src0.x;
}

// Clamped reciprocal
float x_rcc(float4 src0) {
	float input = src0.x;

	// Calculate the reciprocal
	float r = 1.0f / input;

	// Clamp
	return (r > 0)
		? clamp(r, 5.42101e-020, 1.84467e+019)
		: clamp(r, -1.84467e+019, -5.42101e-020);
}

float x_rsq(float4 src0) {
	return rsqrt(src0.x);
}

float4 x_exp(float4 src0) {
	float input = src0.x;
	float x = exp2(floor(input));
	float fractional = frac(input);
	float power = exp2(input);
	return float4(x, fractional, power, 1);
}

float4 x_log(float4 src0) {
	float input = src0.x;
	float exponent = floor(log2(input));
	float mantissa = 1 / exp2(exponent);
	float logResult = log2(input);
	return float4(exponent, mantissa, logResult, 1);
}

float4 x_lit(float4 src0) {
	const float epsilon = 1.0 / 256.0;
	float diffuse = src0.x;
	float blinn = src0.y;
	float specPower = clamp(src0.w, -(128 - epsilon), (128 - epsilon));

	float4 dest;
	dest.x = 1;
	dest.y = max(diffuse, 0);
	dest.z = diffuse > 0 ? pow(2, specPower * log(blinn)) : 0;
	dest.w = 1;

	return dest;
}

float4 reverseScreenspaceTransform(float4 oPos) {
	// On Xbox, oPos should contain the vertex position in screenspace
	// We need to reverse this transformation
	// Conventionally, each Xbox Vertex Shader includes instructions like this
	// mul oPos.xyz, r12, c-38
	// +rcc r1.x, r12.w
	// mad oPos.xyz, r12, r1.x, c-37
	// where c-37 and c-38 are reserved transform values

	oPos.xyz -= xboxViewportOffset.xyz; // reverse offset
	oPos.xyz *= oPos.w; // reverse perspective divide
	oPos.xyz /= xboxViewportScale.xyz; // reverse scale

	// TODO Now transform to host coords..?
	// oPos.xyz *= hostCorrectionScale;

	return oPos;
}

VS_OUTPUT main(const VS_INPUT xIn)
{
	// Temporary variables
	// Including support for the non-existent r13, which turns up in samples like Ripple! TODO investigate!
	float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r13;
	r0 = r1 = r2 = r3 = r4 = r5 = r6 = r7 = r8 = r9 = r10 = r11 = r13 = float4(0, 0, 0, 1); // TODO correct?
    #define r12 oPos // oPos and r12 are two ways of accessing the same register on Xbox

	// Xbox index register
	int a;

	// Output variables
	float4 oPos, oD0, oD1, oB0, oB1, oT0, oT1, oT2, oT3;
	oPos = oD0 = oD1 = oB0 = oB1 = oT0 = oT1 = oT2 = oT3 = float4(0, 0, 0, 1); // TODO correct?

	// Single component outputs
	// x is write-only on Xbox. Use float4 as some games use incorrect masks
	float4 oFog, oPts;
	oFog = oPts = 0;

	// Xbox Input registers
    float4 v[16];
    # define v0  v[0]
    # define v1  v[1]
    # define v2  v[2]
    # define v3  v[3]
    # define v4  v[4]
    # define v5  v[5]
    # define v6  v[6]
    # define v7  v[7]
    # define v8  v[8]
    # define v9  v[9]
    # define v10 v[10]
    # define v11 v[11]
    # define v12 v[12]
    # define v13 v[13]
    # define v14 v[14]
    # define v15 v[15]

	// View 4 packed overrides as an array of 16 floats
	float vOverride[16] = (float[16])vOverridePacked;

	// Initialize input registers from the vertex buffer
	// or an override if any
	for(uint i = 0; i < 16; i++){
		v[i] = vOverride[i] ? vOverrideValue[i] : xIn.v[i];
	}

	// Insert Xbox shader here

	// <Xbox Shader> // !!MUST CORRESPOND WITH THE REGEX IN EmuRecompileVshFunction!!

	// Copy variables to output struct
	VS_OUTPUT xOut;

	xOut.oPos = reverseScreenspaceTransform(oPos);
	xOut.oD0 = oD0;
	xOut.oD1 = oD1;
	xOut.oFog = oFog;
	xOut.oPts = oPts;
	xOut.oB0 = oB0;
	xOut.oB1 = oB1;
	xOut.oT0 = oT0;
	xOut.oT1 = oT1;
	xOut.oT2 = oT2;
	xOut.oT3 = oT3;

	return xOut;
}

// )DELIMITER" /* This terminates the raw string" // */
