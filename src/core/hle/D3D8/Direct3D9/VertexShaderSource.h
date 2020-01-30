
#ifndef DIRECT3D9SHADERCACHE_H
#define DIRECT3D9SHADERCACHE_H

#include "VertexShader.h"
#include <map>

typedef uint64_t ShaderKey;

// Manages creation and caching of vertex shaders
class VertexShaderSource {

public:
	ShaderKey CreateShader(const DWORD* pXboxFunction, DWORD* pXboxFunctionSize);
	IDirect3DVertexShader *GetShader(ShaderKey key);
	HRESULT ReleaseShader(ShaderKey key);

	void ResetD3DDevice(IDirect3DDevice* pD3DDevice);

	// TODO
	// WriteCacheToDisk
	// LoadCacheFromDisk

private:
	struct LazyVertexShader {
		bool isReady = false;
		std::future<ID3DBlob*> compileResult;
		IDirect3DVertexShader* pHostVertexShader = nullptr;

		// TODO better to not release compiled shaders at all?
		// What if the same shader handle is released twice..?
		int referenceCount = 0;

		// TODO
		// ShaderVersion
		// OptimizationLevel
	};

	IDirect3DDevice* pD3DDevice;
	std::mutex cacheMutex;
	std::map<ShaderKey, LazyVertexShader> cache;

	bool VertexShaderSource::_FindShader(ShaderKey key, LazyVertexShader** ppLazyShader);
};

#endif
