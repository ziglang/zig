#undef INTERFACE
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

#ifndef __D3D11SHADER_H__
#define __D3D11SHADER_H__

#include "d3dcommon.h"

/* If not defined set d3dcompiler_47 by default. */
#ifndef D3D_COMPILER_VERSION
#define D3D_COMPILER_VERSION 47
#endif

/* These are defined as version-neutral in d3dcommon.h */
typedef D3D_CBUFFER_TYPE D3D11_CBUFFER_TYPE;

typedef D3D_RESOURCE_RETURN_TYPE D3D11_RESOURCE_RETURN_TYPE;

typedef D3D_TESSELLATOR_DOMAIN D3D11_TESSELLATOR_DOMAIN;

typedef D3D_TESSELLATOR_PARTITIONING D3D11_TESSELLATOR_PARTITIONING;

typedef D3D_TESSELLATOR_OUTPUT_PRIMITIVE D3D11_TESSELLATOR_OUTPUT_PRIMITIVE;

typedef struct _D3D11_SHADER_DESC
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
    D3D_PRIMITIVE_TOPOLOGY GSOutputTopology;
    UINT GSMaxOutputVertexCount;
    D3D_PRIMITIVE InputPrimitive;
    UINT PatchConstantParameters;
    UINT cGSInstanceCount;
    UINT cControlPoints;
    D3D_TESSELLATOR_OUTPUT_PRIMITIVE HSOutputPrimitive;
    D3D_TESSELLATOR_PARTITIONING HSPartitioning;
    D3D_TESSELLATOR_DOMAIN TessellatorDomain;
    UINT cBarrierInstructions;
    UINT cInterlockedInstructions;
    UINT cTextureStoreInstructions;
} D3D11_SHADER_DESC;

typedef struct _D3D11_SHADER_VARIABLE_DESC
{
    const char *Name;
    UINT StartOffset;
    UINT Size;
    UINT uFlags;
    void *DefaultValue;
    UINT StartTexture;
    UINT TextureSize;
    UINT StartSampler;
    UINT SamplerSize;
} D3D11_SHADER_VARIABLE_DESC;

typedef struct _D3D11_SHADER_TYPE_DESC
{
    D3D_SHADER_VARIABLE_CLASS Class;
    D3D_SHADER_VARIABLE_TYPE Type;
    UINT Rows;
    UINT Columns;
    UINT Elements;
    UINT Members;
    UINT Offset;
    const char *Name;
} D3D11_SHADER_TYPE_DESC;

typedef struct _D3D11_SHADER_BUFFER_DESC
{
    const char *Name;
    D3D_CBUFFER_TYPE Type;
    UINT Variables;
    UINT Size;
    UINT uFlags;
} D3D11_SHADER_BUFFER_DESC;

typedef struct _D3D11_SHADER_INPUT_BIND_DESC
{
    const char *Name;
    D3D_SHADER_INPUT_TYPE Type;
    UINT BindPoint;
    UINT BindCount;
    UINT uFlags;
    D3D_RESOURCE_RETURN_TYPE ReturnType;
    D3D_SRV_DIMENSION Dimension;
    UINT NumSamples;
} D3D11_SHADER_INPUT_BIND_DESC;

typedef struct _D3D11_SIGNATURE_PARAMETER_DESC
{
    const char *SemanticName;
    UINT SemanticIndex;
    UINT Register;
    D3D_NAME SystemValueType;
    D3D_REGISTER_COMPONENT_TYPE ComponentType;
    BYTE Mask;
    BYTE ReadWriteMask;
    UINT Stream;
#if D3D_COMPILER_VERSION >= 46
    D3D_MIN_PRECISION MinPrecision;
#endif
} D3D11_SIGNATURE_PARAMETER_DESC;

DEFINE_GUID(IID_ID3D11ShaderReflectionType, 0x6e6ffa6a, 0x9bae, 0x4613, 0xa5, 0x1e, 0x91, 0x65, 0x2d, 0x50, 0x8c, 0x21);

#define INTERFACE ID3D11ShaderReflectionType
DECLARE_INTERFACE(ID3D11ShaderReflectionType)
{
    STDMETHOD(GetDesc)(THIS_ D3D11_SHADER_TYPE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionType *, GetMemberTypeByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionType *, GetMemberTypeByName)(THIS_ const char *name) PURE;
    STDMETHOD_(const char *, GetMemberTypeName)(THIS_ UINT index) PURE;
    STDMETHOD(IsEqual)(THIS_ struct ID3D11ShaderReflectionType *type) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionType *, GetSubType)(THIS) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionType *, GetBaseClass)(THIS) PURE;
    STDMETHOD_(UINT, GetNumInterfaces)(THIS) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionType *, GetInterfaceByIndex)(THIS_ UINT index) PURE;
    STDMETHOD(IsOfType)(THIS_ struct ID3D11ShaderReflectionType *type) PURE;
    STDMETHOD(ImplementsInterface)(THIS_ ID3D11ShaderReflectionType *base) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D11ShaderReflectionVariable, 0x51f23923, 0xf3e5, 0x4bd1, 0x91, 0xcb, 0x60, 0x61, 0x77, 0xd8, 0xdb, 0x4c);

#define INTERFACE ID3D11ShaderReflectionVariable
DECLARE_INTERFACE(ID3D11ShaderReflectionVariable)
{
    STDMETHOD(GetDesc)(THIS_ D3D11_SHADER_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionType *, GetType)(THIS) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionConstantBuffer *, GetBuffer)(THIS) PURE;
    STDMETHOD_(UINT, GetInterfaceSlot)(THIS_ UINT index) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D11ShaderReflectionConstantBuffer, 0xeb62d63d, 0x93dd, 0x4318, 0x8a, 0xe8, 0xc6, 0xf8, 0x3a, 0xd3, 0x71, 0xb8);

#define INTERFACE ID3D11ShaderReflectionConstantBuffer
DECLARE_INTERFACE(ID3D11ShaderReflectionConstantBuffer)
{
    STDMETHOD(GetDesc)(THIS_ D3D11_SHADER_BUFFER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionVariable *, GetVariableByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionVariable *, GetVariableByName)(THIS_ const char *name) PURE;
};
#undef INTERFACE

#if D3D_COMPILER_VERSION <= 42
DEFINE_GUID(IID_ID3D11ShaderReflection, 0x17f27486, 0xa342, 0x4d10, 0x88, 0x42, 0xab, 0x08, 0x74, 0xe7, 0xf6, 0x70);
#elif D3D_COMPILER_VERSION == 43
DEFINE_GUID(IID_ID3D11ShaderReflection, 0x0a233719, 0x3960, 0x4578, 0x9d, 0x7c, 0x20, 0x3b, 0x8b, 0x1d, 0x9c, 0xc1);
#else
DEFINE_GUID(IID_ID3D11ShaderReflection, 0x8d536ca1, 0x0cca, 0x4956, 0xa8, 0x37, 0x78, 0x69, 0x63, 0x75, 0x55, 0x84);
#endif

#define INTERFACE ID3D11ShaderReflection
DECLARE_INTERFACE_(ID3D11ShaderReflection, IUnknown)
{
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* ID3D11ShaderReflection methods */
    STDMETHOD(GetDesc)(THIS_ D3D11_SHADER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionConstantBuffer *, GetConstantBufferByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionConstantBuffer *, GetConstantBufferByName)(THIS_ const char *name) PURE;
    STDMETHOD(GetResourceBindingDesc)(THIS_ UINT index, D3D11_SHADER_INPUT_BIND_DESC *desc) PURE;
    STDMETHOD(GetInputParameterDesc)(THIS_ UINT index, D3D11_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD(GetOutputParameterDesc)(THIS_ UINT index, D3D11_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD(GetPatchConstantParameterDesc)(THIS_ UINT index, D3D11_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D11ShaderReflectionVariable *, GetVariableByName)(THIS_ const char *name) PURE;
    STDMETHOD(GetResourceBindingDescByName)(THIS_ const char *name, D3D11_SHADER_INPUT_BIND_DESC *desc) PURE;
    STDMETHOD_(UINT, GetMovInstructionCount)(THIS) PURE;
    STDMETHOD_(UINT, GetMovcInstructionCount)(THIS) PURE;
    STDMETHOD_(UINT, GetConversionInstructionCount)(THIS) PURE;
    STDMETHOD_(UINT, GetBitwiseInstructionCount)(THIS) PURE;
    STDMETHOD_(D3D_PRIMITIVE, GetGSInputPrimitive)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsSampleFrequencyShader)(THIS) PURE;
    STDMETHOD_(UINT, GetNumInterfaceSlots)(THIS) PURE;
    STDMETHOD(GetMinFeatureLevel)(THIS_ enum D3D_FEATURE_LEVEL *level) PURE;
    STDMETHOD_(UINT, GetThreadGroupSize)(THIS_ UINT *sizex, UINT *sizey, UINT *sizez) PURE;
    STDMETHOD_(UINT64, GetRequiresFlags)(THIS) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D11ModuleInstance, 0x469e07f7, 0x45a, 0x48d5, 0xaa, 0x12, 0x68, 0xa4, 0x78, 0xcd, 0xf7, 0x5d);

#define INTERFACE ID3D11ModuleInstance
DECLARE_INTERFACE_(ID3D11ModuleInstance, IUnknown)
{
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ID3D11ModuleInstance methods */
    STDMETHOD(BindConstantBuffer)(THIS_ UINT srcslot, UINT dstslot, UINT dstoffset) PURE;
    STDMETHOD(BindConstantBufferByName)(THIS_ const char *name, UINT dstslot, UINT dstoffset) PURE;

    STDMETHOD(BindResource)(THIS_ UINT srcslot, UINT dstslot, UINT count) PURE;
    STDMETHOD(BindResourceByName)(THIS_ const char *name, UINT dstslot, UINT count) PURE;

    STDMETHOD(BindSampler)(THIS_ UINT srcslot,  UINT dstslot,  UINT count) PURE;
    STDMETHOD(BindSamplerByName)(THIS_ const char *name,  UINT dstslot, UINT count) PURE;

    STDMETHOD(BindUnorderedAccessView)(THIS_ UINT srcslot,  UINT dstslot, UINT count) PURE;
    STDMETHOD(BindUnorderedAccessViewByName)(THIS_ const char *name, UINT dstslot, UINT count) PURE;

    STDMETHOD(BindResourceAsUnorderedAccessView)(THIS_ UINT srcslot, UINT dstslot, UINT count) PURE;
    STDMETHOD(BindResourceAsUnorderedAccessViewByName)(THIS_ const char *name, UINT dstslot, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D11Module, 0xcac701ee, 0x80fc, 0x4122, 0x82, 0x42, 0x10, 0xb3, 0x9c, 0x8c, 0xec, 0x34);

#define INTERFACE ID3D11Module
DECLARE_INTERFACE_(ID3D11Module, IUnknown)
{
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* ID3D11Module methods */
    STDMETHOD(CreateInstance)(THIS_ const char *instnamespace, ID3D11ModuleInstance **moduleinstance) PURE;
};
#undef INTERFACE

#endif
