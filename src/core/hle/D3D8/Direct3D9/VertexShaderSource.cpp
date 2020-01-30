#define LOG_PREFIX CXBXR_MODULE::VTXSH

#include "VertexShaderSource.h"

#include "Logging.h"
#include "util/hasher.h"

ID3DBlob* AsyncCreateVertexShader(IntermediateVertexShader intermediateShader, ShaderKey key) {
	ID3DBlob* pCompiledShader;

	auto hRet = EmuCompileShader(
		&intermediateShader,
		&pCompiledShader
	);

	EmuLog(LOG_LEVEL::DEBUG, "Finished compiling shader %llx", key);

	return pCompiledShader;
}


 bool VertexShaderSource::_FindShader(ShaderKey key, LazyVertexShader** ppLazyShader) {
	auto it = cache.find(key);
	if (it == cache.end()) {
		// We didn't find anything! Was CreateShader called?
		EmuLog(LOG_LEVEL::WARNING, "No vertex shader found for key %llx", key);
		return false;
	}

	*ppLazyShader = &it->second;
	return true;
}


ShaderKey VertexShaderSource::CreateShader(const DWORD* pXboxFunction, DWORD *pXboxFunctionSize) {
	IntermediateVertexShader intermediateShader;

	// Parse into intermediate format
	EmuParseVshFunction((DWORD*)pXboxFunction,
		pXboxFunctionSize,
		&intermediateShader);

	ShaderKey key = ComputeHash((void*)pXboxFunction, *pXboxFunctionSize);

	// Check if we need to create the shader
	auto it = cache.find(key);
	if (it != cache.end()) {
		EmuLog(LOG_LEVEL::DEBUG, "Vertex shader %llx has been created already", key);
		// Increment reference count
		it->second.referenceCount++;
		EmuLog(LOG_LEVEL::DEBUG, "Incremented ref count for shader %llx (%d)", key, it->second.referenceCount);
		return key;
	}

	auto newShader = LazyVertexShader();

	auto shaderType = EmuGetShaderInfo(&intermediateShader);

	if (shaderType == ShaderType::Compilable)
	{
		// Start compiling the shader in the background
		// TODO proper threading / threadpool.
		// We should have some control over the number and priority of threads
		EmuLog(LOG_LEVEL::DEBUG, "Creating vertex shader %llx size %d", key, *pXboxFunctionSize);
		newShader.compileResult = std::async(std::launch::async, AsyncCreateVertexShader, intermediateShader, key);
	}
	else {
		newShader.isReady = true;
		newShader.pHostVertexShader = nullptr;
	}

	// Put the shader into the cache
	cache[key] = std::move(newShader);

	return key;
}

IDirect3DVertexShader* VertexShaderSource::GetShader(ShaderKey key)
{
	LazyVertexShader* pLazyShader = nullptr;

	// Look for the shader in the cache
	if (!_FindShader(key, &pLazyShader)) {
		return nullptr; // we didn't find anything
	}

	// If the shader is ready, return it
	if (pLazyShader->isReady) {
		return pLazyShader->pHostVertexShader;
	}

	if (pD3DDevice == nullptr) {
		EmuLog(LOG_LEVEL::WARNING, "Can't create shader - no D3D device is set!");
		return nullptr;
	}

	// We need to get the compiled HLSL and create a shader from it
	ID3DBlob* pCompiledShader = nullptr;
	try {
		// TODO one day, check is_ready before logging this (non-standard..?)
		EmuLog(LOG_LEVEL::DEBUG, "Waiting for shader...");
		pCompiledShader = pLazyShader->compileResult.get();

		// Create the shader
		auto hRet = pD3DDevice->CreateVertexShader
		(
			(DWORD*)pCompiledShader->GetBufferPointer(),
			&pLazyShader->pHostVertexShader
		);

		EmuLog(LOG_LEVEL::DEBUG, "Created new vertex shader instance!");
		// DEBUG_D3DRESULT(hRet, "g_pD3DDevice->CreateVertexShader");
	}
	catch (const std::exception & e) {
		EmuLog(LOG_LEVEL::ERROR2, "Failed compiling shader: %s", e.what());
	}

	if (pCompiledShader) {
		pCompiledShader->Release();

		// TODO compile the shader at a higher optimization level in a background thread
	}

	// The shader is ready
	pLazyShader->isReady = true;

	return pLazyShader->pHostVertexShader;
}
HRESULT VertexShaderSource::ReleaseShader(ShaderKey key)
{
	EmuLog(LOG_LEVEL::DEBUG, "Releasing shader %llx", key);
	LazyVertexShader* pLazyShader;
	if (_FindShader(key, &pLazyShader)) {

		pLazyShader->referenceCount--;
		EmuLog(LOG_LEVEL::DEBUG, "Decremented ref count for shader %llx (%d)", key, pLazyShader->referenceCount);

		if (pLazyShader->referenceCount > 0) {
			return D3D_OK;
		}

		HRESULT hRet;
		if (pLazyShader->isReady) {
			hRet = pLazyShader->pHostVertexShader->Release();
		}
		else {
			hRet = pLazyShader->compileResult.get()->Release();
		}

		cache.erase(key);
		return hRet;
	}
	else {
		EmuLog(LOG_LEVEL::WARNING, "Nothing to release!");
	}

	return D3D_OK;
}

void VertexShaderSource::ResetD3DDevice(IDirect3DDevice* newDevice)
{
	EmuLog(LOG_LEVEL::DEBUG, "Resetting D3D device");
	this->pD3DDevice = newDevice;
}
