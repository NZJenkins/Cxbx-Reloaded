
#ifndef DIRECT3D9VERTEXSHADER_H
#define DIRECT3D9VERTEXSHADER_H

#include "core\hle\D3D8\XbVertexShader.h"

enum class ShaderType {
	Empty = 0,
	Compilable,
	Unsupported,
};

static const char* vs_model_2_a = "vs_2_a";
static const char* vs_model_3_0 = "vs_3_0";
extern const char* g_vs_model;

extern ShaderType EmuGetShaderInfo(IntermediateVertexShader* pIntermediateShader);

extern HRESULT EmuCompileShader
(
    IntermediateVertexShader* pIntermediateShader,
    ID3DBlob** ppHostShader
);

extern HRESULT EmuCompileXboxFvf
(
	char** shaderData
);

#endif