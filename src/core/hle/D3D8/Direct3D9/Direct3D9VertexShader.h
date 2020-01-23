
#ifndef XBDIRECT3D9VERTEXSHADER_H
#define XBDIRECT3D9VERTEXSHADER_H

#include "core\hle\D3D8\XbVertexShader.h"

extern HRESULT EmuCompileShader
(
    IntermediateVertexShader* pIntermediateShader,
    bool          bNoReservedConstants,
    bool* pbUseDeclarationOnly,
    ID3DBlob** ppHostShader
);

#endif
