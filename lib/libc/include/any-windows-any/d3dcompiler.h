#include <_mingw_unicode.h>
/*
 * Copyright 2010 Matteo Bruni for CodeWeavers
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __D3DCOMPILER_H__
#define __D3DCOMPILER_H__

#include "d3d11shader.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__GNUC__)
#define D3DCOMPILER_DLL_W (const WCHAR[]){'d','3','d','c','o','m','p','i','l','e','r','_','4','3','.','d','l','l',0}
#elif defined(_MSC_VER)
#define D3DCOMPILER_DLL_W L"d3dcompiler_43.dll"
#else
static const WCHAR D3DCOMPILER_DLL_W[] = {'d','3','d','c','o','m','p','i','l','e','r','_','4','3','.','d','l','l',0};
#endif

#define D3DCOMPILER_DLL_A  "d3dcompiler_43.dll"
#define D3DCOMPILER_DLL    __MINGW_NAME_AW(D3DCOMPILER_DLL_)

#define D3DCOMPILE_DEBUG                            0x00000001
#define D3DCOMPILE_SKIP_VALIDATION                  0x00000002
#define D3DCOMPILE_SKIP_OPTIMIZATION                0x00000004
#define D3DCOMPILE_PACK_MATRIX_ROW_MAJOR            0x00000008
#define D3DCOMPILE_PACK_MATRIX_COLUMN_MAJOR         0x00000010
#define D3DCOMPILE_PARTIAL_PRECISION                0x00000020
#define D3DCOMPILE_FORCE_VS_SOFTWARE_NO_OPT         0x00000040
#define D3DCOMPILE_FORCE_PS_SOFTWARE_NO_OPT         0x00000080
#define D3DCOMPILE_NO_PRESHADER                     0x00000100
#define D3DCOMPILE_AVOID_FLOW_CONTROL               0x00000200
#define D3DCOMPILE_PREFER_FLOW_CONTROL              0x00000400
#define D3DCOMPILE_ENABLE_STRICTNESS                0x00000800
#define D3DCOMPILE_ENABLE_BACKWARDS_COMPATIBILITY   0x00001000
#define D3DCOMPILE_IEEE_STRICTNESS                  0x00002000
#define D3DCOMPILE_OPTIMIZATION_LEVEL0              0x00004000
#define D3DCOMPILE_OPTIMIZATION_LEVEL1              0x00000000
#define D3DCOMPILE_OPTIMIZATION_LEVEL2              0x0000c000
#define D3DCOMPILE_OPTIMIZATION_LEVEL3              0x00008000
#define D3DCOMPILE_RESERVED16                       0x00010000
#define D3DCOMPILE_RESERVED17                       0x00020000
#define D3DCOMPILE_WARNINGS_ARE_ERRORS              0x00040000
#define D3DCOMPILE_RESOURCES_MAY_ALIAS              0x00080000

#define D3D_DISASM_ENABLE_COLOR_CODE                0x00000001
#define D3D_DISASM_ENABLE_DEFAULT_VALUE_PRINTS      0x00000002
#define D3D_DISASM_ENABLE_INSTRUCTION_NUMBERING     0x00000004
#define D3D_DISASM_ENABLE_INSTRUCTION_CYCLE         0x00000008
#define D3D_DISASM_DISABLE_DEBUG_INFO               0x00000010

HRESULT WINAPI D3DCompile(const void *data, SIZE_T data_size, const char *filename,
        const D3D_SHADER_MACRO *defines, ID3DInclude *include, const char *entrypoint,
        const char *target, UINT sflags, UINT eflags, ID3DBlob **shader, ID3DBlob **error_messages);
typedef HRESULT (WINAPI *pD3DCompile)(const void *data, SIZE_T data_size, const char *filename,
        const D3D_SHADER_MACRO *defines, ID3DInclude *include, const char *entrypoint,
        const char *target, UINT sflags, UINT eflags, ID3DBlob **shader, ID3DBlob **error_messages);

typedef enum D3DCOMPILER_STRIP_FLAGS
{
    D3DCOMPILER_STRIP_REFLECTION_DATA = 1,
    D3DCOMPILER_STRIP_DEBUG_INFO = 2,
    D3DCOMPILER_STRIP_TEST_BLOBS = 4,
    D3DCOMPILER_STRIP_FORCE_DWORD = 0x7fffffff
} D3DCOMPILER_STRIP_FLAGS;

HRESULT WINAPI D3DStripShader(const void *data, SIZE_T data_size, UINT flags, ID3DBlob **blob);

typedef enum D3D_BLOB_PART
{
    D3D_BLOB_INPUT_SIGNATURE_BLOB,
    D3D_BLOB_OUTPUT_SIGNATURE_BLOB,
    D3D_BLOB_INPUT_AND_OUTPUT_SIGNATURE_BLOB,
    D3D_BLOB_PATCH_CONSTANT_SIGNATURE_BLOB,
    D3D_BLOB_ALL_SIGNATURE_BLOB,
    D3D_BLOB_DEBUG_INFO,
    D3D_BLOB_LEGACY_SHADER,
    D3D_BLOB_XNA_PREPASS_SHADER,
    D3D_BLOB_XNA_SHADER,
    D3D_BLOB_TEST_ALTERNATE_SHADER = 0x8000,
    D3D_BLOB_TEST_COMPILE_DETAILS,
    D3D_BLOB_TEST_COMPILE_PERF
} D3D_BLOB_PART;

HRESULT WINAPI D3DDisassemble(const void *data, SIZE_T data_size,
        UINT flags, const char *comments, ID3DBlob **disassembly);
typedef HRESULT (WINAPI *pD3DDisassemble)(const void *data, SIZE_T data_size,
        UINT flags, const char *comments, ID3DBlob **disassembly);
HRESULT WINAPI D3DGetBlobPart(const void *data, SIZE_T data_size, D3D_BLOB_PART part, UINT flags, ID3DBlob **blob);
HRESULT WINAPI D3DGetInputSignatureBlob(const void *data, SIZE_T data_size, ID3DBlob **blob);
HRESULT WINAPI D3DGetOutputSignatureBlob(const void *data, SIZE_T data_size, ID3DBlob **blob);
HRESULT WINAPI D3DGetInputAndOutputSignatureBlob(const void *data, SIZE_T data_size, ID3DBlob **blob);
HRESULT WINAPI D3DGetDebugInfo(const void *data, SIZE_T data_size, ID3DBlob **blob);
HRESULT WINAPI D3DReadFileToBlob(const WCHAR *filename, ID3DBlob **contents);
HRESULT WINAPI D3DWriteBlobToFile(ID3DBlob *blob, const WCHAR *filename, WINBOOL overwrite);
HRESULT WINAPI D3DReflect(const void *data, SIZE_T data_size, REFIID riid, void **reflector);

HRESULT WINAPI D3DCreateBlob(SIZE_T data_size, ID3DBlob **blob);

HRESULT WINAPI D3DPreprocess(const void *data, SIZE_T size, const char *filename,
        const D3D_SHADER_MACRO *defines, ID3DInclude *include,
        ID3DBlob **shader, ID3DBlob **error_messages);
typedef HRESULT (WINAPI *pD3DPreprocess)(const void *data, SIZE_T size, const char *filename,
        const D3D_SHADER_MACRO *defines, ID3DInclude *include,
        ID3DBlob **shader, ID3DBlob **error_messages);

HRESULT WINAPI D3DLoadModule(const void *data, SIZE_T size, ID3D11Module **module);

#ifdef __cplusplus
}
#endif

#endif
