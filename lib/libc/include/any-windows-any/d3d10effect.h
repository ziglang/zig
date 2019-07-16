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

#ifndef __WINE_D3D10EFFECT_H
#define __WINE_D3D10EFFECT_H

#include "d3d10.h"

#define D3D10_EFFECT_VARIABLE_POOLED                0x1
#define D3D10_EFFECT_VARIABLE_ANNOTATION            0x2
#define D3D10_EFFECT_VARIABLE_EXPLICIT_BIND_POINT   0x4

#ifndef D3D10_BYTES_FROM_BITS
#define D3D10_BYTES_FROM_BITS(x) (((x) + 7) >> 3)
#endif

typedef enum _D3D10_DEVICE_STATE_TYPES
{
    D3D10_DST_SO_BUFFERS = 1,
    D3D10_DST_OM_RENDER_TARGETS,
    D3D10_DST_DEPTH_STENCIL_STATE,
    D3D10_DST_BLEND_STATE,
    D3D10_DST_VS,
    D3D10_DST_VS_SAMPLERS,
    D3D10_DST_VS_SHADER_RESOURCES,
    D3D10_DST_VS_CONSTANT_BUFFERS,
    D3D10_DST_GS,
    D3D10_DST_GS_SAMPLERS,
    D3D10_DST_GS_SHADER_RESOURCES,
    D3D10_DST_GS_CONSTANT_BUFFERS,
    D3D10_DST_PS,
    D3D10_DST_PS_SAMPLERS,
    D3D10_DST_PS_SHADER_RESOURCES,
    D3D10_DST_PS_CONSTANT_BUFFERS,
    D3D10_DST_IA_VERTEX_BUFFERS,
    D3D10_DST_IA_INDEX_BUFFER,
    D3D10_DST_IA_INPUT_LAYOUT,
    D3D10_DST_IA_PRIMITIVE_TOPOLOGY,
    D3D10_DST_RS_VIEWPORTS,
    D3D10_DST_RS_SCISSOR_RECTS,
    D3D10_DST_RS_RASTERIZER_STATE,
    D3D10_DST_PREDICATION,
} D3D10_DEVICE_STATE_TYPES;

typedef struct _D3D10_EFFECT_TYPE_DESC
{
    const char *TypeName;
    D3D10_SHADER_VARIABLE_CLASS Class;
    D3D10_SHADER_VARIABLE_TYPE Type;
    UINT Elements;
    UINT Members;
    UINT Rows;
    UINT Columns;
    UINT PackedSize;
    UINT UnpackedSize;
    UINT Stride;
} D3D10_EFFECT_TYPE_DESC;

typedef struct _D3D10_EFFECT_VARIABLE_DESC
{
    const char *Name;
    const char *Semantic;
    UINT Flags;
    UINT Annotations;
    UINT BufferOffset;
    UINT ExplicitBindPoint;
} D3D10_EFFECT_VARIABLE_DESC;

typedef struct _D3D10_TECHNIQUE_DESC
{
    const char *Name;
    UINT Passes;
    UINT Annotations;
} D3D10_TECHNIQUE_DESC;

typedef struct _D3D10_STATE_BLOCK_MASK
{
    BYTE VS;
    BYTE VSSamplers[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_SAMPLER_SLOT_COUNT)];
    BYTE VSShaderResources[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT)];
    BYTE VSConstantBuffers[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT)];
    BYTE GS;
    BYTE GSSamplers[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_SAMPLER_SLOT_COUNT)];
    BYTE GSShaderResources[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT)];
    BYTE GSConstantBuffers[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT)];
    BYTE PS;
    BYTE PSSamplers[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_SAMPLER_SLOT_COUNT)];
    BYTE PSShaderResources[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT)];
    BYTE PSConstantBuffers[D3D10_BYTES_FROM_BITS(D3D10_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT)];
    BYTE IAVertexBuffers[D3D10_BYTES_FROM_BITS(D3D10_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT)];
    BYTE IAIndexBuffer;
    BYTE IAInputLayout;
    BYTE IAPrimitiveTopology;
    BYTE OMRenderTargets;
    BYTE OMDepthStencilState;
    BYTE OMBlendState;
    BYTE RSViewports;
    BYTE RSScissorRects;
    BYTE RSRasterizerState;
    BYTE SOBuffers;
    BYTE Predication;
} D3D10_STATE_BLOCK_MASK;

typedef struct _D3D10_EFFECT_DESC
{
    WINBOOL IsChildEffect;
    UINT ConstantBuffers;
    UINT SharedConstantBuffers;
    UINT GlobalVariables;
    UINT SharedGlobalVariables;
    UINT Techniques;
} D3D10_EFFECT_DESC;

typedef struct _D3D10_EFFECT_SHADER_DESC
{
    const BYTE *pInputSignature;
    WINBOOL IsInline;
    const BYTE *pBytecode;
    UINT BytecodeLength;
    const char *SODecl;
    UINT NumInputSignatureEntries;
    UINT NumOutputSignatureEntries;
} D3D10_EFFECT_SHADER_DESC;

typedef struct _D3D10_PASS_DESC
{
    const char *Name;
    UINT Annotations;
    BYTE *pIAInputSignature;
    SIZE_T IAInputSignatureSize;
    UINT StencilRef;
    UINT SampleMask;
    FLOAT BlendFactor[4];
} D3D10_PASS_DESC;

typedef struct _D3D10_PASS_SHADER_DESC
{
    struct ID3D10EffectShaderVariable *pShaderVariable;
    UINT ShaderIndex;
} D3D10_PASS_SHADER_DESC;

#define D3D10_EFFECT_COMPILE_CHILD_EFFECT    0x0001
#define D3D10_EFFECT_COMPILE_ALLOW_SLOW_OPS  0x0002
#define D3D10_EFFECT_SINGLE_THREADED         0x0008

DEFINE_GUID(IID_ID3D10EffectType, 0x4e9e1ddc, 0xcd9d, 0x4772, 0xa8, 0x37, 0x00, 0x18, 0x0b, 0x9b, 0x88, 0xfd);

#define INTERFACE ID3D10EffectType
DECLARE_INTERFACE(ID3D10EffectType)
{
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_TYPE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetMemberTypeByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetMemberTypeByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetMemberTypeBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(const char *, GetMemberName)(THIS_ UINT index) PURE;
    STDMETHOD_(const char *, GetMemberSemantic)(THIS_ UINT index) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectVariable, 0xae897105, 0x00e6, 0x45bf, 0xbb, 0x8e, 0x28, 0x1d, 0xd6, 0xdb, 0x8e, 0x1b);

#define INTERFACE ID3D10EffectVariable
DECLARE_INTERFACE(ID3D10EffectVariable)
{
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectConstantBuffer, 0x56648f4d, 0xcc8b, 0x4444, 0xa5, 0xad, 0xb5, 0xa3, 0xd7, 0x6e, 0x91, 0xb3);

#define INTERFACE ID3D10EffectConstantBuffer
DECLARE_INTERFACE_(ID3D10EffectConstantBuffer, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectConstantBuffer methods */
    STDMETHOD(SetConstantBuffer)(THIS_ ID3D10Buffer *buffer) PURE;
    STDMETHOD(GetConstantBuffer)(THIS_ ID3D10Buffer **buffer) PURE;
    STDMETHOD(SetTextureBuffer)(THIS_ ID3D10ShaderResourceView *view) PURE;
    STDMETHOD(GetTextureBuffer)(THIS_ ID3D10ShaderResourceView **view) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectScalarVariable, 0x00e48f7b, 0xd2c8, 0x49e8, 0xa8, 0x6c, 0x02, 0x2d, 0xee, 0x53, 0x43, 0x1f);

#define INTERFACE ID3D10EffectScalarVariable
DECLARE_INTERFACE_(ID3D10EffectScalarVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectScalarVariable methods */
    STDMETHOD(SetFloat)(THIS_ float value) PURE;
    STDMETHOD(GetFloat)(THIS_ float *value) PURE;
    STDMETHOD(SetFloatArray)(THIS_ float *values, UINT offset, UINT count) PURE;
    STDMETHOD(GetFloatArray)(THIS_ float *values, UINT offset, UINT count) PURE;
    STDMETHOD(SetInt)(THIS_ int value) PURE;
    STDMETHOD(GetInt)(THIS_ int *value) PURE;
    STDMETHOD(SetIntArray)(THIS_ int *values, UINT offset, UINT count) PURE;
    STDMETHOD(GetIntArray)(THIS_ int *values, UINT offset, UINT count) PURE;
    STDMETHOD(SetBool)(THIS_ WINBOOL value) PURE;
    STDMETHOD(GetBool)(THIS_ WINBOOL *value) PURE;
    STDMETHOD(SetBoolArray)(THIS_ WINBOOL *values, UINT offset, UINT count) PURE;
    STDMETHOD(GetBoolArray)(THIS_ WINBOOL *values, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectVectorVariable, 0x62b98c44, 0x1f82, 0x4c67, 0xbc, 0xd0, 0x72, 0xcf, 0x8f, 0x21, 0x7e, 0x81);

#define INTERFACE ID3D10EffectVectorVariable
DECLARE_INTERFACE_(ID3D10EffectVectorVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectVectorVariable methods */
    STDMETHOD(SetBoolVector)(THIS_ WINBOOL *value) PURE;
    STDMETHOD(SetIntVector)(THIS_ int *value) PURE;
    STDMETHOD(SetFloatVector)(THIS_ float *value) PURE;
    STDMETHOD(GetBoolVector)(THIS_ WINBOOL *value) PURE;
    STDMETHOD(GetIntVector)(THIS_ int *value) PURE;
    STDMETHOD(GetFloatVector)(THIS_ float *value) PURE;
    STDMETHOD(SetBoolVectorArray)(THIS_ WINBOOL *values, UINT offset, UINT count) PURE;
    STDMETHOD(SetIntVectorArray)(THIS_ int *values, UINT offset, UINT count) PURE;
    STDMETHOD(SetFloatVectorArray)(THIS_ float *values, UINT offset, UINT count) PURE;
    STDMETHOD(GetBoolVectorArray)(THIS_ WINBOOL *values, UINT offset, UINT count) PURE;
    STDMETHOD(GetIntVectorArray)(THIS_ int *values, UINT offset, UINT count) PURE;
    STDMETHOD(GetFloatVectorArray)(THIS_ float *values, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectMatrixVariable, 0x50666c24, 0xb82f, 0x4eed, 0xa1, 0x72, 0x5b, 0x6e, 0x7e, 0x85, 0x22, 0xe0);

#define INTERFACE ID3D10EffectMatrixVariable
DECLARE_INTERFACE_(ID3D10EffectMatrixVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectMatrixVariable methods */
    STDMETHOD(SetMatrix)(THIS_ float *data) PURE;
    STDMETHOD(GetMatrix)(THIS_ float *data) PURE;
    STDMETHOD(SetMatrixArray)(THIS_ float *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetMatrixArray)(THIS_ float *data, UINT offset, UINT count) PURE;
    STDMETHOD(SetMatrixTranspose)(THIS_ float *data) PURE;
    STDMETHOD(GetMatrixTranspose)(THIS_ float *data) PURE;
    STDMETHOD(SetMatrixTransposeArray)(THIS_ float *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetMatrixTransposeArray)(THIS_ float *data, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectStringVariable, 0x71417501, 0x8df9, 0x4e0a, 0xa7, 0x8a, 0x25, 0x5f, 0x97, 0x56, 0xba, 0xff);

#define INTERFACE ID3D10EffectStringVariable
DECLARE_INTERFACE_(ID3D10EffectStringVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectStringVariable methods */
    STDMETHOD(GetString)(THIS_ const char **str) PURE;
    STDMETHOD(GetStringArray)(THIS_ const char **strs, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectShaderResourceVariable,
        0xc0a7157b, 0xd872, 0x4b1d, 0x80, 0x73, 0xef, 0xc2, 0xac, 0xd4, 0xb1, 0xfc);

#define INTERFACE ID3D10EffectShaderResourceVariable
DECLARE_INTERFACE_(ID3D10EffectShaderResourceVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectShaderResourceVariable methods */
    STDMETHOD(SetResource)(THIS_ ID3D10ShaderResourceView *resource) PURE;
    STDMETHOD(GetResource)(THIS_ ID3D10ShaderResourceView **resource) PURE;
    STDMETHOD(SetResourceArray)(THIS_ ID3D10ShaderResourceView **resources, UINT offset, UINT count) PURE;
    STDMETHOD(GetResourceArray)(THIS_ ID3D10ShaderResourceView **resources, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectRenderTargetViewVariable,
        0x28ca0cc3, 0xc2c9, 0x40bb, 0xb5, 0x7f, 0x67, 0xb7, 0x37, 0x12, 0x2b, 0x17);

#define INTERFACE ID3D10EffectRenderTargetViewVariable
DECLARE_INTERFACE_(ID3D10EffectRenderTargetViewVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectRenderTargetViewVariable methods */
    STDMETHOD(SetRenderTarget)(THIS_ ID3D10RenderTargetView *view) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ ID3D10RenderTargetView **view) PURE;
    STDMETHOD(SetRenderTargetArray)(THIS_ ID3D10RenderTargetView **views, UINT offset, UINT count) PURE;
    STDMETHOD(GetRenderTargetArray)(THIS_ ID3D10RenderTargetView **views, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectDepthStencilViewVariable,
        0x3e02c918, 0xcc79, 0x4985, 0xb6, 0x22, 0x2d, 0x92, 0xad, 0x70, 0x16, 0x23);

#define INTERFACE ID3D10EffectDepthStencilViewVariable
DECLARE_INTERFACE_(ID3D10EffectDepthStencilViewVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectDepthStencilViewVariable methods */
    STDMETHOD(SetDepthStencil)(THIS_ ID3D10DepthStencilView *view) PURE;
    STDMETHOD(GetDepthStencil)(THIS_ ID3D10DepthStencilView **view) PURE;
    STDMETHOD(SetDepthStencilArray)(THIS_ ID3D10DepthStencilView **views, UINT offset, UINT count) PURE;
    STDMETHOD(GetDepthStencilArray)(THIS_ ID3D10DepthStencilView **views, UINT offset, UINT count) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectShaderVariable, 0x80849279, 0xc799, 0x4797, 0x8c, 0x33, 0x04, 0x07, 0xa0, 0x7d, 0x9e, 0x06);

#define INTERFACE ID3D10EffectShaderVariable
DECLARE_INTERFACE_(ID3D10EffectShaderVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectShaderVariable methods */
    STDMETHOD(GetShaderDesc)(THIS_ UINT index, D3D10_EFFECT_SHADER_DESC *desc) PURE;
    STDMETHOD(GetVertexShader)(THIS_ UINT index, ID3D10VertexShader **shader) PURE;
    STDMETHOD(GetGeometryShader)(THIS_ UINT index, ID3D10GeometryShader **shader) PURE;
    STDMETHOD(GetPixelShader)(THIS_ UINT index, ID3D10PixelShader **shader) PURE;
    STDMETHOD(GetInputSignatureElementDesc)(THIS_ UINT shader_index, UINT element_index,
            D3D10_SIGNATURE_PARAMETER_DESC *desc) PURE;
    STDMETHOD(GetOutputSignatureElementDesc)(THIS_ UINT shader_index, UINT element_index,
            D3D10_SIGNATURE_PARAMETER_DESC *desc) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectBlendVariable, 0x1fcd2294, 0xdf6d, 0x4eae, 0x86, 0xb3, 0x0e, 0x91, 0x60, 0xcf, 0xb0, 0x7b);

#define INTERFACE ID3D10EffectBlendVariable
DECLARE_INTERFACE_(ID3D10EffectBlendVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectBlendVariable methods */
    STDMETHOD(GetBlendState)(THIS_ UINT index, ID3D10BlendState **blend_state) PURE;
    STDMETHOD(GetBackingStore)(THIS_ UINT index, D3D10_BLEND_DESC *desc) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectDepthStencilVariable,
        0xaf482368, 0x330a, 0x46a5, 0x9a, 0x5c, 0x01, 0xc7, 0x1a, 0xf2, 0x4c, 0x8d);

#define INTERFACE ID3D10EffectDepthStencilVariable
DECLARE_INTERFACE_(ID3D10EffectDepthStencilVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectDepthStencilVariable methods */
    STDMETHOD(GetDepthStencilState)(THIS_ UINT index, ID3D10DepthStencilState **depth_stencil_state) PURE;
    STDMETHOD(GetBackingStore)(THIS_ UINT index, D3D10_DEPTH_STENCIL_DESC *desc) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectRasterizerVariable,
        0x21af9f0e, 0x4d94, 0x4ea9, 0x97, 0x85, 0x2c, 0xb7, 0x6b, 0x8c, 0x0b, 0x34);

#define INTERFACE ID3D10EffectRasterizerVariable
DECLARE_INTERFACE_(ID3D10EffectRasterizerVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectRasterizerVariable methods */
    STDMETHOD(GetRasterizerState)(THIS_ UINT index, ID3D10RasterizerState **rasterizer_state) PURE;
    STDMETHOD(GetBackingStore)(THIS_ UINT index, D3D10_RASTERIZER_DESC *desc) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectSamplerVariable,
        0x6530d5c7, 0x07e9, 0x4271, 0xa4, 0x18, 0xe7, 0xce, 0x4b, 0xd1, 0xe4, 0x80);

#define INTERFACE ID3D10EffectSamplerVariable
DECLARE_INTERFACE_(ID3D10EffectSamplerVariable, ID3D10EffectVariable)
{
    /* ID3D10EffectVariable methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectType *, GetType)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_VARIABLE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetMemberBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetElement)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetParentConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectScalarVariable *, AsScalar)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectVectorVariable *, AsVector)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectMatrixVariable *, AsMatrix)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectStringVariable *, AsString)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderResourceVariable *, AsShaderResource)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRenderTargetViewVariable *, AsRenderTargetView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilViewVariable *, AsDepthStencilView)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, AsConstantBuffer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectShaderVariable *, AsShader)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectBlendVariable *, AsBlend)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectDepthStencilVariable *, AsDepthStencil)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectRasterizerVariable *, AsRasterizer)(THIS) PURE;
    STDMETHOD_(struct ID3D10EffectSamplerVariable *, AsSampler)(THIS) PURE;
    STDMETHOD(SetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    STDMETHOD(GetRawValue)(THIS_ void *data, UINT offset, UINT count) PURE;
    /* ID3D10EffectSamplerVariable methods */
    STDMETHOD(GetSampler)(THIS_ UINT index, ID3D10SamplerState **sampler) PURE;
    STDMETHOD(GetBackingStore)(THIS_ UINT index, D3D10_SAMPLER_DESC *desc) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectTechnique, 0xdb122ce8, 0xd1c9, 0x4292, 0xb2, 0x37, 0x24, 0xed, 0x3d, 0xe8, 0xb1, 0x75);

#define INTERFACE ID3D10EffectTechnique
DECLARE_INTERFACE(ID3D10EffectTechnique)
{
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_TECHNIQUE_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectPass *, GetPassByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectPass *, GetPassByName)(THIS_ const char *name) PURE;
    STDMETHOD(ComputeStateBlockMask)(THIS_ D3D10_STATE_BLOCK_MASK *mask) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10Effect, 0x51b0ca8b, 0xec0b, 0x4519, 0x87, 0x0d, 0x8e, 0xe1, 0xcb, 0x50, 0x17, 0xc7);

#define INTERFACE ID3D10Effect
DECLARE_INTERFACE_(ID3D10Effect, IUnknown)
{
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* ID3D10Effect methods */
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsPool)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ ID3D10Device **device) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_EFFECT_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetConstantBufferByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectConstantBuffer *, GetConstantBufferByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetVariableByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetVariableByName)(THIS_ const char *name) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetVariableBySemantic)(THIS_ const char *semantic) PURE;
    STDMETHOD_(struct ID3D10EffectTechnique *, GetTechniqueByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectTechnique *, GetTechniqueByName)(THIS_ const char *name) PURE;
    STDMETHOD(Optimize)(THIS) PURE;
    STDMETHOD_(WINBOOL, IsOptimized)(THIS) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectPool, 0x9537ab04, 0x3250, 0x412e, 0x82, 0x13, 0xfc, 0xd2, 0xf8, 0x67, 0x79, 0x33);

#define INTERFACE ID3D10EffectPool
DECLARE_INTERFACE_(ID3D10EffectPool, IUnknown)
{
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* ID3D10EffectPool methods */
    STDMETHOD_(struct ID3D10Effect *, AsEffect)(THIS) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10EffectPass, 0x5cfbeb89, 0x1a06, 0x46e0, 0xb2, 0x82, 0xe3, 0xf9, 0xbf, 0xa3, 0x6a, 0x54);

#define INTERFACE ID3D10EffectPass
DECLARE_INTERFACE(ID3D10EffectPass)
{
    STDMETHOD_(WINBOOL, IsValid)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3D10_PASS_DESC *desc) PURE;
    STDMETHOD(GetVertexShaderDesc)(THIS_ D3D10_PASS_SHADER_DESC *desc) PURE;
    STDMETHOD(GetGeometryShaderDesc)(THIS_ D3D10_PASS_SHADER_DESC *desc) PURE;
    STDMETHOD(GetPixelShaderDesc)(THIS_ D3D10_PASS_SHADER_DESC *desc) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(struct ID3D10EffectVariable *, GetAnnotationByName)(THIS_ const char *name) PURE;
    STDMETHOD(Apply)(THIS_ UINT flags) PURE;
    STDMETHOD(ComputeStateBlockMask)(THIS_ D3D10_STATE_BLOCK_MASK *mask) PURE;
};
#undef INTERFACE

DEFINE_GUID(IID_ID3D10StateBlock, 0x0803425a, 0x57f5, 0x4dd6, 0x94, 0x65, 0xa8, 0x75, 0x70, 0x83, 0x4a, 0x08);

#define INTERFACE ID3D10StateBlock
DECLARE_INTERFACE_(ID3D10StateBlock, IUnknown)
{
    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **object) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* ID3D10StateBlock methods */
    STDMETHOD(Capture)(THIS) PURE;
    STDMETHOD(Apply)(THIS) PURE;
    STDMETHOD(ReleaseAllDeviceObjects)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ ID3D10Device **device) PURE;
};
#undef INTERFACE

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI D3D10CompileEffectFromMemory(void *data, SIZE_T data_size, const char *filename,
        const D3D10_SHADER_MACRO *defines, ID3D10Include *include, UINT hlsl_flags, UINT fx_flags,
        ID3D10Blob **effect, ID3D10Blob **errors);
HRESULT WINAPI D3D10CreateEffectFromMemory(void *data, SIZE_T data_size, UINT flags,
        ID3D10Device *device, ID3D10EffectPool *effect_pool, ID3D10Effect **effect);
HRESULT WINAPI D3D10CreateEffectPoolFromMemory(void *data, SIZE_T data_size, UINT fx_flags,
        ID3D10Device *device, ID3D10EffectPool **effect_pool);
HRESULT WINAPI D3D10CreateStateBlock(ID3D10Device *device,
        D3D10_STATE_BLOCK_MASK *mask, ID3D10StateBlock **stateblock);

HRESULT WINAPI D3D10StateBlockMaskDifference(D3D10_STATE_BLOCK_MASK *mask_x,
        D3D10_STATE_BLOCK_MASK *mask_y, D3D10_STATE_BLOCK_MASK *result);
HRESULT WINAPI D3D10StateBlockMaskDisableAll(D3D10_STATE_BLOCK_MASK *mask);
HRESULT WINAPI D3D10StateBlockMaskDisableCapture(D3D10_STATE_BLOCK_MASK *mask,
        D3D10_DEVICE_STATE_TYPES state_type, UINT start_idx, UINT count);
HRESULT WINAPI D3D10StateBlockMaskEnableAll(D3D10_STATE_BLOCK_MASK *mask);
HRESULT WINAPI D3D10StateBlockMaskEnableCapture(D3D10_STATE_BLOCK_MASK *mask,
        D3D10_DEVICE_STATE_TYPES state_type, UINT start_idx, UINT count);
WINBOOL WINAPI D3D10StateBlockMaskGetSetting(D3D10_STATE_BLOCK_MASK *mask,
        D3D10_DEVICE_STATE_TYPES state_type, UINT idx);
HRESULT WINAPI D3D10StateBlockMaskIntersect(D3D10_STATE_BLOCK_MASK *mask_x,
        D3D10_STATE_BLOCK_MASK *mask_y, D3D10_STATE_BLOCK_MASK *result);
HRESULT WINAPI D3D10StateBlockMaskUnion(D3D10_STATE_BLOCK_MASK *mask_x,
        D3D10_STATE_BLOCK_MASK *mask_y, D3D10_STATE_BLOCK_MASK *result);

#ifdef __cplusplus
}
#endif

#endif /* __WINE_D3D10EFFECT_H */
