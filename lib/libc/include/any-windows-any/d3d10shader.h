#undef INTERFACE
/*
 * Copyright 2009 Henri Verbeet for CodeWeavers
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
 *
 */

#ifndef __WINE_D3D10SHADER_H
#define __WINE_D3D10SHADER_H

#include "d3d10.h"

#define D3D10_SHADER_DEBUG                          0x0001
#define D3D10_SHADER_SKIP_VALIDATION                0x0002
#define D3D10_SHADER_SKIP_OPTIMIZATION              0x0004
#define D3D10_SHADER_PACK_MATRIX_ROW_MAJOR          0x0008
#define D3D10_SHADER_PACK_MATRIX_COLUMN_MAJOR       0x0010
#define D3D10_SHADER_PARTIAL_PRECISION              0x0020
#define D3D10_SHADER_FORCE_VS_SOFTWARE_NO_OPT       0x0040
#define D3D10_SHADER_FORCE_PS_SOFTWARE_NO_OPT       0x0080
#define D3D10_SHADER_NO_PRESHADER                   0x0100
#define D3D10_SHADER_AVOID_FLOW_CONTROL             0x0200
#define D3D10_SHADER_PREFER_FLOW_CONTROL            0x0400
#define D3D10_SHADER_ENABLE_STRICTNESS              0x0800
#define D3D10_SHADER_ENABLE_BACKWARDS_COMPATIBILITY 0x1000
#define D3D10_SHADER_IEEE_STRICTNESS                0x2000
#define D3D10_SHADER_WARNINGS_ARE_ERRORS           0x40000

#define D3D10_SHADER_OPTIMIZATION_LEVEL0            0x4000
#define D3D10_SHADER_OPTIMIZATION_LEVEL1            0x0000
#define D3D10_SHADER_OPTIMIZATION_LEVEL2            0xC000
#define D3D10_SHADER_OPTIMIZATION_LEVEL3            0x8000

/* These are defined as version-neutral in d3dcommon.h */
typedef D3D_SHADER_MACRO D3D10_SHADER_MACRO;
typedef D3D_SHADER_MACRO *LPD3D10_SHADER_MACRO;

typedef D3D_SHADER_VARIABLE_CLASS D3D10_SHADER_VARIABLE_CLASS;
typedef D3D_SHADER_VARIABLE_CLASS *LPD3D10_SHADER_VARIABLE_CLASS;

typedef D3D_CBUFFER_TYPE D3D10_CBUFFER_TYPE;
typedef D3D_CBUFFER_TYPE *LPD3D10_CBUFFER_TYPE;

typedef D3D_REGISTER_COMPONENT_TYPE D3D10_REGISTER_COMPONENT_TYPE;

typedef D3D_RESOURCE_RETURN_TYPE D3D10_RESOURCE_RETURN_TYPE;

typedef D3D_NAME D3D10_NAME;

typedef D3D_SHADER_INPUT_TYPE D3D10_SHADER_INPUT_TYPE;
typedef D3D_SHADER_INPUT_TYPE *LPD3D10_SHADER_INPUT_TYPE;

typedef D3D_SHADER_VARIABLE_TYPE D3D10_SHADER_VARIABLE_TYPE;
typedef D3D_SHADER_VARIABLE_TYPE *LPD3D10_SHADER_VARIABLE_TYPE;

typedef D3D_INCLUDE_TYPE D3D10_INCLUDE_TYPE;
typedef ID3DInclude ID3D10Include;
typedef ID3DInclude *LPD3D10INCLUDE;
#define IID_ID3D10Include IID_ID3DInclude

typedef struct _D3D10_SHADER_INPUT_BIND_DESC
{
    const char *Name;
    D3D10_SHADER_INPUT_TYPE Type;
    UINT BindPoint;
    UINT BindCount;
    UINT uFlags;
    D3D10_RESOURCE_RETURN_TYPE ReturnType;
    D3D10_SRV_DIMENSION Dimension;
    UINT NumSamples;
} D3D10_SHADER_INPUT_BIND_DESC;

typedef struct _D3D10_SIGNATURE_PARAMETER_DESC
{
    const char *SemanticName;
    UINT SemanticIndex;
    UINT Register;
    D3D10_NAME SystemValueType;
    D3D10_REGISTER_COMPONENT_TYPE ComponentType;
    BYTE Mask;
    BYTE ReadWriteMask;
} D3D10_SIGNATURE_PARAMETER_DESC;

typedef struct _D3D10_SHADER_DESC
{
    UINT Version;
    const char *Creator;
    UINT Flags;
    UINT ConstantBuffers;
    UINT BoundResources;
    UINT InputParameters;
    UINT OutputParameters;
    UINT InstructionCount;
    UINT TempRegisterCount;
    UINT TempArrayCount;
    UINT DefCount;
    UINT DclCount;
    UINT TextureNormalInstructions;
    UINT TextureLoadInstructions;
    UINT TextureCompInstructions;
    UINT TextureBiasInstructions;
    UINT TextureGradientInstructions;
    UINT FloatInstructionCount;
    UINT IntInstructionCount;
    UINT UintInstructionCount;
    UINT StaticFlowControlCount;
    UINT DynamicFlowControlCount;
    UINT MacroInstructionCount;
    UINT ArrayInstructionCount;
    UINT CutInstructionCount;
    UINT EmitInstructionCount;
    D3D10_PRIMITIVE_TOPOLOGY GSOutputTopology;
    UINT GSMaxOutputVertexCount;
} D3D10_SHADER_DESC;

typedef struct _D3D10_SHADER_BUFFER_DESC
{
    const char *Name;
    D3D10_CBUFFER_TYPE Type;
    UINT Variables;
    UINT Size;
    UINT uFlags;
} D3D10_SHADER_BUFFER_DESC;

typedef struct _D3D10_SHADER_VARIABLE_DESC
{
    const char *Name;
    UINT StartOffset;
    UINT Size;
    UINT uFlags;
    void *DefaultValue;
} D3D10_SHADER_VARIABLE_DESC;

typedef struct _D3D10_SHADER_TYPE_DESC
{
    D3D10_SHADER_VARIABLE_CLASS Class;
    D3D10_SHADER_VARIABLE_TYPE Type;
    UINT Rows;
    UINT Columns;
    UINT Elements;
    UINT Members;
    UINT Offset;
} D3D10_SHADER_TYPE_DESC;

DEFINE_GUID(IID_ID3D10ShaderReflectionType, 0xc530ad7d, 0x9b16, 0x4395, 0xa9, 0x79, 0xba, 0x2e, 0xcf, 0xf8, 0x3a, 0xdd);

#define INTERFACE ID3D10ShaderReflectionType
DECLARE_INTERFACE(ID3D10ShaderReflectionType)
{
    STDMETHOD(GetDesc)(THIS_ D3D10_SHADER_TYPE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionType *, GetMemberTypeByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionType *, GetMemberTypeByName)(THIS_ const char *name) PURE;
    STDMETHOD_(const char *, GetMemberTypeName)(THIS_ UINT index) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10ShaderReflectionVariable, 0x1bf63c95, 0x2650, 0x405d, 0x99, 0xc1, 0x36, 0x36, 0xbd, 0x1d, 0xa0, 0xa1);

#define INTERFACE ID3D10ShaderReflectionVariable
DECLARE_INTERFACE(ID3D10ShaderReflectionVariable)
{
    STDMETHOD(GetDesc)(THIS_ D3D10_SHADER_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionType *, GetType)(THIS) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10ShaderReflectionConstantBuffer, 0x66c66a94, 0xdddd, 0x4b62, 0xa6, 0x6a, 0xf0, 0xda, 0x33, 0xc2, 0xb4, 0xd0);

#define INTERFACE ID3D10ShaderReflectionConstantBuffer
DECLARE_INTERFACE(ID3D10ShaderReflectionConstantBuffer)
{
    STDMETHOD(GetDesc)(THIS_ D3D10_SHADER_BUFFER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionVariable *, GetVariableByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionVariable *, GetVariableByName)(THIS_ const char *name) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10ShaderReflection, 0xd40e20b6, 0xf8f7, 0x42ad, 0xab, 0x20, 0x4b, 0xaf, 0x8f, 0x15, 0xdf, 0xaa);

#define INTERFACE ID3D10ShaderReflection
DECLARE_INTERFACE_(ID3D10ShaderReflection, IUnknown)
{
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* ID3D10ShaderReflection methods */
    STDMETHOD(GetDesc)(THIS_ D3D10_SHADER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionConstantBuffer *, GetConstantBufferByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10ShaderReflectionConstantBuffer *, GetConstantBufferByName)(THIS_ const char *name) PURE;
    STDMETHOD(GetResourceBindingDesc)(THIS_ UINT index, D3D10_SHADER_INPUT_BIND_DESC *desc) PURE;
    STDMETHOD(GetInputParameterDesc)(THIS_ UINT index, D3D10_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD(GetOutputParameterDesc)(THIS_ UINT index, D3D10_SIGNATURE_PARAMETER_DESC *desc) PURE;
};
#undef INTERFACE


#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI D3D10CompileShader(const char *data, SIZE_T data_size, const char *filename,
        const D3D10_SHADER_MACRO *defines, ID3D10Include *include, const char *entrypoint,
        const char *profile, UINT flags, ID3D10Blob **shader, ID3D10Blob **error_messages);
HRESULT WINAPI D3D10DisassembleShader(const void *data, SIZE_T data_size,
        WINBOOL color_code, const char *comments, ID3D10Blob **disassembly);
const char * WINAPI D3D10GetVertexShaderProfile(ID3D10Device *device);
const char * WINAPI D3D10GetGeometryShaderProfile(ID3D10Device *device);
const char * WINAPI D3D10GetPixelShaderProfile(ID3D10Device *device);

HRESULT WINAPI D3D10ReflectShader(const void *data, SIZE_T data_size, ID3D10ShaderReflection **reflector);
HRESULT WINAPI D3D10GetInputSignatureBlob(const void *data, SIZE_T data_size, ID3D10Blob **blob);
HRESULT WINAPI D3D10GetOutputSignatureBlob(const void *data, SIZE_T data_size, ID3D10Blob **blob);
HRESULT WINAPI D3D10GetInputAndOutputSignatureBlob(const void *data, SIZE_T data_size, ID3D10Blob **blob);
HRESULT WINAPI D3D10GetShaderDebugInfo(const void *data, SIZE_T data_size, ID3D10Blob **blob);

#ifdef __cplusplus
}
#endif

#endif /* __WINE_D3D10SHADER_H */
