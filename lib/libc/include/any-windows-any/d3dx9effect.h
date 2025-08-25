#include <_mingw_unicode.h>
#undef INTERFACE
/*
 * Copyright 2010 Christian Costa
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

#include "d3dx9.h"

#ifndef __D3DX9EFFECT_H__
#define __D3DX9EFFECT_H__

#define D3DXFX_DONOTSAVESTATE (1 << 0)
#define D3DXFX_DONOTSAVESHADERSTATE (1 << 1)
#define D3DXFX_DONOTSAVESAMPLERSTATE (1 << 2)
#define D3DXFX_NOT_CLONEABLE (1 << 11)
#define D3DXFX_LARGEADDRESSAWARE (1 << 17)

#define D3DX_PARAMETER_SHARED       1
#define D3DX_PARAMETER_LITERAL      2
#define D3DX_PARAMETER_ANNOTATION   4

typedef struct _D3DXEFFECT_DESC
{
    const char *Creator;
    UINT Parameters;
    UINT Techniques;
    UINT Functions;
} D3DXEFFECT_DESC;

typedef struct _D3DXPARAMETER_DESC
{
    const char *Name;
    const char *Semantic;
    D3DXPARAMETER_CLASS Class;
    D3DXPARAMETER_TYPE Type;
    UINT Rows;
    UINT Columns;
    UINT Elements;
    UINT Annotations;
    UINT StructMembers;
    DWORD Flags;
    UINT Bytes;
} D3DXPARAMETER_DESC;

typedef struct _D3DXTECHNIQUE_DESC
{
    const char *Name;
    UINT Passes;
    UINT Annotations;
} D3DXTECHNIQUE_DESC;

typedef struct _D3DXPASS_DESC
{
    const char *Name;
    UINT Annotations;
    const DWORD *pVertexShaderFunction;
    const DWORD *pPixelShaderFunction;
} D3DXPASS_DESC;

typedef struct _D3DXFUNCTION_DESC
{
    const char *Name;
    UINT Annotations;
} D3DXFUNCTION_DESC;

typedef struct ID3DXEffectPool *LPD3DXEFFECTPOOL;

DEFINE_GUID(IID_ID3DXEffectPool, 0x9537ab04, 0x3250, 0x412e, 0x82, 0x13, 0xfc, 0xd2, 0xf8, 0x67, 0x79, 0x33);

#undef INTERFACE
#define INTERFACE ID3DXEffectPool

DECLARE_INTERFACE_(ID3DXEffectPool, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
};
#undef INTERFACE

typedef struct ID3DXBaseEffect *LPD3DXBASEEFFECT;

DEFINE_GUID(IID_ID3DXBaseEffect, 0x17c18ac, 0x103f, 0x4417, 0x8c, 0x51, 0x6b, 0xf6, 0xef, 0x1e, 0x56, 0xbe);

#define INTERFACE ID3DXBaseEffect

DECLARE_INTERFACE_(ID3DXBaseEffect, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBaseEffect methods ***/
    STDMETHOD(GetDesc)(THIS_ D3DXEFFECT_DESC* desc) PURE;
    STDMETHOD(GetParameterDesc)(THIS_ D3DXHANDLE parameter, D3DXPARAMETER_DESC* desc) PURE;
    STDMETHOD(GetTechniqueDesc)(THIS_ D3DXHANDLE technique, D3DXTECHNIQUE_DESC* desc) PURE;
    STDMETHOD(GetPassDesc)(THIS_ D3DXHANDLE pass, D3DXPASS_DESC* desc) PURE;
    STDMETHOD(GetFunctionDesc)(THIS_ D3DXHANDLE shader, D3DXFUNCTION_DESC* desc) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameter)(THIS_ D3DXHANDLE parameter, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterByName)(THIS_ D3DXHANDLE parameter, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterBySemantic)(THIS_ D3DXHANDLE parameter, const char *semantic) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterElement)(THIS_ D3DXHANDLE parameter, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetTechnique)(THIS_ UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetTechniqueByName)(THIS_ const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetPass)(THIS_ D3DXHANDLE technique, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetPassByName)(THIS_ D3DXHANDLE technique, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetFunction)(THIS_ UINT index);
    STDMETHOD_(D3DXHANDLE, GetFunctionByName)(THIS_ const char *name);
    STDMETHOD_(D3DXHANDLE, GetAnnotation)(THIS_ D3DXHANDLE object, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetAnnotationByName)(THIS_ D3DXHANDLE object, const char *name) PURE;
    STDMETHOD(SetValue)(THIS_ D3DXHANDLE parameter, const void *data, UINT bytes) PURE;
    STDMETHOD(GetValue)(THIS_ D3DXHANDLE parameter, void *data, UINT bytes) PURE;
    STDMETHOD(SetBool)(THIS_ D3DXHANDLE parameter, WINBOOL b) PURE;
    STDMETHOD(GetBool)(THIS_ D3DXHANDLE parameter, WINBOOL* b) PURE;
    STDMETHOD(SetBoolArray)(THIS_ D3DXHANDLE parameter, const WINBOOL *b, UINT count) PURE;
    STDMETHOD(GetBoolArray)(THIS_ D3DXHANDLE parameter, WINBOOL* b, UINT count) PURE;
    STDMETHOD(SetInt)(THIS_ D3DXHANDLE parameter, INT n) PURE;
    STDMETHOD(GetInt)(THIS_ D3DXHANDLE parameter, INT* n) PURE;
    STDMETHOD(SetIntArray)(THIS_ D3DXHANDLE parameter, const INT *n, UINT count) PURE;
    STDMETHOD(GetIntArray)(THIS_ D3DXHANDLE parameter, INT* n, UINT count) PURE;
    STDMETHOD(SetFloat)(THIS_ D3DXHANDLE parameter, FLOAT f) PURE;
    STDMETHOD(GetFloat)(THIS_ D3DXHANDLE parameter, FLOAT* f) PURE;
    STDMETHOD(SetFloatArray)(THIS_ D3DXHANDLE parameter, const FLOAT *f, UINT count) PURE;
    STDMETHOD(GetFloatArray)(THIS_ D3DXHANDLE parameter, FLOAT* f, UINT count) PURE;
    STDMETHOD(SetVector)(THIS_ D3DXHANDLE parameter, const D3DXVECTOR4 *vector) PURE;
    STDMETHOD(GetVector)(THIS_ D3DXHANDLE parameter, D3DXVECTOR4* vector) PURE;
    STDMETHOD(SetVectorArray)(THIS_ D3DXHANDLE parameter, const D3DXVECTOR4 *vector, UINT count) PURE;
    STDMETHOD(GetVectorArray)(THIS_ D3DXHANDLE parameter, D3DXVECTOR4* vector, UINT count) PURE;
    STDMETHOD(SetMatrix)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix) PURE;
    STDMETHOD(GetMatrix)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix) PURE;
    STDMETHOD(SetMatrixArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix, UINT count) PURE;
    STDMETHOD(GetMatrixArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix, UINT count) PURE;
    STDMETHOD(SetMatrixPointerArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX **matrix, UINT count) PURE;
    STDMETHOD(GetMatrixPointerArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX** matrix, UINT count) PURE;
    STDMETHOD(SetMatrixTranspose)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix) PURE;
    STDMETHOD(GetMatrixTranspose)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix) PURE;
    STDMETHOD(SetMatrixTransposeArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix, UINT count) PURE;
    STDMETHOD(GetMatrixTransposeArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix, UINT count) PURE;
    STDMETHOD(SetMatrixTransposePointerArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX **matrix, UINT count) PURE;
    STDMETHOD(GetMatrixTransposePointerArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX** matrix, UINT count) PURE;
    STDMETHOD(SetString)(THIS_ D3DXHANDLE parameter, const char *string) PURE;
    STDMETHOD(GetString)(THIS_ D3DXHANDLE parameter, const char **string) PURE;
    STDMETHOD(SetTexture)(THIS_ D3DXHANDLE parameter, struct IDirect3DBaseTexture9 *texture) PURE;
    STDMETHOD(GetTexture)(THIS_ D3DXHANDLE parameter, struct IDirect3DBaseTexture9 **texture) PURE;
    STDMETHOD(GetPixelShader)(THIS_ D3DXHANDLE parameter, struct IDirect3DPixelShader9 **shader) PURE;
    STDMETHOD(GetVertexShader)(THIS_ D3DXHANDLE parameter, struct IDirect3DVertexShader9 **shader) PURE;
    STDMETHOD(SetArrayRange)(THIS_ D3DXHANDLE parameter, UINT start, UINT end) PURE;
};
#undef INTERFACE

typedef struct ID3DXEffectStateManager *LPD3DXEFFECTSTATEMANAGER;

DEFINE_GUID(IID_ID3DXEffectStateManager, 0x79aab587, 0x6dbc, 0x4fa7, 0x82, 0xde, 0x37, 0xfa, 0x17, 0x81, 0xc5, 0xce);

#define INTERFACE ID3DXEffectStateManager

DECLARE_INTERFACE_(ID3DXEffectStateManager, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXEffectStateManager methods ***/
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(SetMaterial)(THIS_ const D3DMATERIAL9 *material) PURE;
    STDMETHOD(SetLight)(THIS_ DWORD index, const D3DLIGHT9 *light) PURE;
    STDMETHOD(LightEnable)(THIS_ DWORD index, WINBOOL enable) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE state, DWORD value) PURE;
    STDMETHOD(SetTexture)(THIS_ DWORD stage, struct IDirect3DBaseTexture9 *texture) PURE;
    STDMETHOD(SetTextureStageState)(THIS_ DWORD stage, D3DTEXTURESTAGESTATETYPE type, DWORD value) PURE;
    STDMETHOD(SetSamplerState)(THIS_ DWORD sampler, D3DSAMPLERSTATETYPE type, DWORD value) PURE;
    STDMETHOD(SetNPatchMode)(THIS_ FLOAT num_segments) PURE;
    STDMETHOD(SetFVF)(THIS_ DWORD format) PURE;
    STDMETHOD(SetVertexShader)(THIS_ struct IDirect3DVertexShader9 *shader) PURE;
    STDMETHOD(SetVertexShaderConstantF)(THIS_ UINT register_index, const FLOAT *constant_data, UINT register_count) PURE;
    STDMETHOD(SetVertexShaderConstantI)(THIS_ UINT register_index, const INT *constant_data, UINT register_count) PURE;
    STDMETHOD(SetVertexShaderConstantB)(THIS_ UINT register_index, const WINBOOL *constant_data, UINT register_count) PURE;
    STDMETHOD(SetPixelShader)(THIS_ struct IDirect3DPixelShader9 *shader) PURE;
    STDMETHOD(SetPixelShaderConstantF)(THIS_ UINT register_index, const FLOAT *constant_data, UINT register_count) PURE;
    STDMETHOD(SetPixelShaderConstantI)(THIS_ UINT register_index, const INT *constant_data, UINT register_count) PURE;
    STDMETHOD(SetPixelShaderConstantB)(THIS_ UINT register_index, const WINBOOL *constant_data, UINT register_count) PURE;
};
#undef INTERFACE

typedef struct ID3DXEffect *LPD3DXEFFECT;

#if D3DX_SDK_VERSION <= 25
DEFINE_GUID(IID_ID3DXEffect, 0xd165ccb1, 0x62b0, 0x4a33, 0xb3, 0xfa, 0xa9, 0x23, 0x00, 0x30, 0x5a, 0x11);
#elif D3DX_SDK_VERSION == 26
DEFINE_GUID(IID_ID3DXEffect, 0xc7b17651, 0x5420, 0x490e, 0x8a, 0x7f, 0x92, 0x36, 0x75, 0xa2, 0xd6, 0x87);
#else
DEFINE_GUID(IID_ID3DXEffect, 0xf6ceb4b3, 0x4e4c, 0x40dd, 0xb8, 0x83, 0x8d, 0x8d, 0xe5, 0xea, 0x0c, 0xd5);
#endif

#define INTERFACE ID3DXEffect

DECLARE_INTERFACE_(ID3DXEffect, ID3DXBaseEffect)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBaseEffect methods ***/
    STDMETHOD(GetDesc)(THIS_ D3DXEFFECT_DESC* desc) PURE;
    STDMETHOD(GetParameterDesc)(THIS_ D3DXHANDLE parameter, D3DXPARAMETER_DESC* desc) PURE;
    STDMETHOD(GetTechniqueDesc)(THIS_ D3DXHANDLE technique, D3DXTECHNIQUE_DESC* desc) PURE;
    STDMETHOD(GetPassDesc)(THIS_ D3DXHANDLE pass, D3DXPASS_DESC* desc) PURE;
    STDMETHOD(GetFunctionDesc)(THIS_ D3DXHANDLE shader, D3DXFUNCTION_DESC* desc) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameter)(THIS_ D3DXHANDLE parameter, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterByName)(THIS_ D3DXHANDLE parameter, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterBySemantic)(THIS_ D3DXHANDLE parameter, const char *semantic) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterElement)(THIS_ D3DXHANDLE parameter, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetTechnique)(THIS_ UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetTechniqueByName)(THIS_ const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetPass)(THIS_ D3DXHANDLE technique, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetPassByName)(THIS_ D3DXHANDLE technique, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetFunction)(THIS_ UINT index);
    STDMETHOD_(D3DXHANDLE, GetFunctionByName)(THIS_ const char *name);
    STDMETHOD_(D3DXHANDLE, GetAnnotation)(THIS_ D3DXHANDLE object, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetAnnotationByName)(THIS_ D3DXHANDLE object, const char *name) PURE;
    STDMETHOD(SetValue)(THIS_ D3DXHANDLE parameter, const void *data, UINT bytes) PURE;
    STDMETHOD(GetValue)(THIS_ D3DXHANDLE parameter, void *data, UINT bytes) PURE;
    STDMETHOD(SetBool)(THIS_ D3DXHANDLE parameter, WINBOOL b) PURE;
    STDMETHOD(GetBool)(THIS_ D3DXHANDLE parameter, WINBOOL* b) PURE;
    STDMETHOD(SetBoolArray)(THIS_ D3DXHANDLE parameter, const WINBOOL *b, UINT count) PURE;
    STDMETHOD(GetBoolArray)(THIS_ D3DXHANDLE parameter, WINBOOL* b, UINT count) PURE;
    STDMETHOD(SetInt)(THIS_ D3DXHANDLE parameter, INT n) PURE;
    STDMETHOD(GetInt)(THIS_ D3DXHANDLE parameter, INT* n) PURE;
    STDMETHOD(SetIntArray)(THIS_ D3DXHANDLE parameter, const INT *n, UINT count) PURE;
    STDMETHOD(GetIntArray)(THIS_ D3DXHANDLE parameter, INT* n, UINT count) PURE;
    STDMETHOD(SetFloat)(THIS_ D3DXHANDLE parameter, FLOAT f) PURE;
    STDMETHOD(GetFloat)(THIS_ D3DXHANDLE parameter, FLOAT* f) PURE;
    STDMETHOD(SetFloatArray)(THIS_ D3DXHANDLE parameter, const FLOAT *f, UINT count) PURE;
    STDMETHOD(GetFloatArray)(THIS_ D3DXHANDLE parameter, FLOAT* f, UINT count) PURE;
    STDMETHOD(SetVector)(THIS_ D3DXHANDLE parameter, const D3DXVECTOR4 *vector) PURE;
    STDMETHOD(GetVector)(THIS_ D3DXHANDLE parameter, D3DXVECTOR4* vector) PURE;
    STDMETHOD(SetVectorArray)(THIS_ D3DXHANDLE parameter, const D3DXVECTOR4 *vector, UINT count) PURE;
    STDMETHOD(GetVectorArray)(THIS_ D3DXHANDLE parameter, D3DXVECTOR4* vector, UINT count) PURE;
    STDMETHOD(SetMatrix)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix) PURE;
    STDMETHOD(GetMatrix)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix) PURE;
    STDMETHOD(SetMatrixArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix, UINT count) PURE;
    STDMETHOD(GetMatrixArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix, UINT count) PURE;
    STDMETHOD(SetMatrixPointerArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX **matrix, UINT count) PURE;
    STDMETHOD(GetMatrixPointerArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX** matrix, UINT count) PURE;
    STDMETHOD(SetMatrixTranspose)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix) PURE;
    STDMETHOD(GetMatrixTranspose)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix) PURE;
    STDMETHOD(SetMatrixTransposeArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix, UINT count) PURE;
    STDMETHOD(GetMatrixTransposeArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix, UINT count) PURE;
    STDMETHOD(SetMatrixTransposePointerArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX **matrix, UINT count) PURE;
    STDMETHOD(GetMatrixTransposePointerArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX** matrix, UINT count) PURE;
    STDMETHOD(SetString)(THIS_ D3DXHANDLE parameter, const char *string) PURE;
    STDMETHOD(GetString)(THIS_ D3DXHANDLE parameter, const char **string) PURE;
    STDMETHOD(SetTexture)(THIS_ D3DXHANDLE parameter, struct IDirect3DBaseTexture9 *texture) PURE;
    STDMETHOD(GetTexture)(THIS_ D3DXHANDLE parameter, struct IDirect3DBaseTexture9 **texture) PURE;
    STDMETHOD(GetPixelShader)(THIS_ D3DXHANDLE parameter, struct IDirect3DPixelShader9 **shader) PURE;
    STDMETHOD(GetVertexShader)(THIS_ D3DXHANDLE parameter, struct IDirect3DVertexShader9 **shader) PURE;
    STDMETHOD(SetArrayRange)(THIS_ D3DXHANDLE parameter, UINT start, UINT end) PURE;
    /*** ID3DXEffect methods ***/
    STDMETHOD(GetPool)(THIS_ ID3DXEffectPool **pool) PURE;
    STDMETHOD(SetTechnique)(THIS_ D3DXHANDLE technique) PURE;
    STDMETHOD_(D3DXHANDLE, GetCurrentTechnique)(THIS) PURE;
    STDMETHOD(ValidateTechnique)(THIS_ D3DXHANDLE technique) PURE;
    STDMETHOD(FindNextValidTechnique)(THIS_ D3DXHANDLE technique, D3DXHANDLE* next_technique) PURE;
    STDMETHOD_(WINBOOL, IsParameterUsed)(THIS_ D3DXHANDLE parameter, D3DXHANDLE technique) PURE;
    STDMETHOD(Begin)(THIS_ UINT *passes, DWORD flags) PURE;
    STDMETHOD(BeginPass)(THIS_ UINT pass) PURE;
    STDMETHOD(CommitChanges)(THIS) PURE;
    STDMETHOD(EndPass)(THIS) PURE;
    STDMETHOD(End)(THIS) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(OnLostDevice)(THIS) PURE;
    STDMETHOD(OnResetDevice)(THIS) PURE;
    STDMETHOD(SetStateManager)(THIS_ ID3DXEffectStateManager *manager) PURE;
    STDMETHOD(GetStateManager)(THIS_ ID3DXEffectStateManager **manager) PURE;
    STDMETHOD(BeginParameterBlock)(THIS) PURE;
    STDMETHOD_(D3DXHANDLE, EndParameterBlock)(THIS) PURE;
    STDMETHOD(ApplyParameterBlock)(THIS_ D3DXHANDLE parameter_block) PURE;
#if D3DX_SDK_VERSION >= 26
    STDMETHOD(DeleteParameterBlock)(THIS_ D3DXHANDLE parameter_block) PURE;
#endif
    STDMETHOD(CloneEffect)(THIS_ struct IDirect3DDevice9 *device, struct ID3DXEffect **effect) PURE;
#if D3DX_SDK_VERSION >= 27
    STDMETHOD(SetRawValue)(THIS_ D3DXHANDLE parameter, const void *data, UINT byte_offset, UINT bytes) PURE;
#endif
};

#undef INTERFACE

typedef struct ID3DXEffectCompiler *LPD3DXEFFECTCOMPILER;

DEFINE_GUID(IID_ID3DXEffectCompiler, 0x51b8a949, 0x1a31, 0x47e6, 0xbe, 0xa0, 0x4b, 0x30, 0xdb, 0x53, 0xf1, 0xe0);

#define INTERFACE ID3DXEffectCompiler

DECLARE_INTERFACE_(ID3DXEffectCompiler, ID3DXBaseEffect)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBaseEffect methods ***/
    STDMETHOD(GetDesc)(THIS_ D3DXEFFECT_DESC* desc) PURE;
    STDMETHOD(GetParameterDesc)(THIS_ D3DXHANDLE parameter, D3DXPARAMETER_DESC* desc) PURE;
    STDMETHOD(GetTechniqueDesc)(THIS_ D3DXHANDLE technique, D3DXTECHNIQUE_DESC* desc) PURE;
    STDMETHOD(GetPassDesc)(THIS_ D3DXHANDLE pass, D3DXPASS_DESC* desc) PURE;
    STDMETHOD(GetFunctionDesc)(THIS_ D3DXHANDLE shader, D3DXFUNCTION_DESC* desc) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameter)(THIS_ D3DXHANDLE parameter, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterByName)(THIS_ D3DXHANDLE parameter, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterBySemantic)(THIS_ D3DXHANDLE parameter, const char *semantic) PURE;
    STDMETHOD_(D3DXHANDLE, GetParameterElement)(THIS_ D3DXHANDLE parameter, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetTechnique)(THIS_ UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetTechniqueByName)(THIS_ const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetPass)(THIS_ D3DXHANDLE technique, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetPassByName)(THIS_ D3DXHANDLE technique, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetFunction)(THIS_ UINT index);
    STDMETHOD_(D3DXHANDLE, GetFunctionByName)(THIS_ const char *name);
    STDMETHOD_(D3DXHANDLE, GetAnnotation)(THIS_ D3DXHANDLE object, UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetAnnotationByName)(THIS_ D3DXHANDLE object, const char *name) PURE;
    STDMETHOD(SetValue)(THIS_ D3DXHANDLE parameter, const void *data, UINT bytes) PURE;
    STDMETHOD(GetValue)(THIS_ D3DXHANDLE parameter, void *data, UINT bytes) PURE;
    STDMETHOD(SetBool)(THIS_ D3DXHANDLE parameter, WINBOOL b) PURE;
    STDMETHOD(GetBool)(THIS_ D3DXHANDLE parameter, WINBOOL* b) PURE;
    STDMETHOD(SetBoolArray)(THIS_ D3DXHANDLE parameter, const WINBOOL *b, UINT count) PURE;
    STDMETHOD(GetBoolArray)(THIS_ D3DXHANDLE parameter, WINBOOL* b, UINT count) PURE;
    STDMETHOD(SetInt)(THIS_ D3DXHANDLE parameter, INT n) PURE;
    STDMETHOD(GetInt)(THIS_ D3DXHANDLE parameter, INT* n) PURE;
    STDMETHOD(SetIntArray)(THIS_ D3DXHANDLE parameter, const INT *n, UINT count) PURE;
    STDMETHOD(GetIntArray)(THIS_ D3DXHANDLE parameter, INT* n, UINT count) PURE;
    STDMETHOD(SetFloat)(THIS_ D3DXHANDLE parameter, FLOAT f) PURE;
    STDMETHOD(GetFloat)(THIS_ D3DXHANDLE parameter, FLOAT* f) PURE;
    STDMETHOD(SetFloatArray)(THIS_ D3DXHANDLE parameter, const FLOAT *f, UINT count) PURE;
    STDMETHOD(GetFloatArray)(THIS_ D3DXHANDLE parameter, FLOAT* f, UINT count) PURE;
    STDMETHOD(SetVector)(THIS_ D3DXHANDLE parameter, const D3DXVECTOR4 *vector) PURE;
    STDMETHOD(GetVector)(THIS_ D3DXHANDLE parameter, D3DXVECTOR4* vector) PURE;
    STDMETHOD(SetVectorArray)(THIS_ D3DXHANDLE parameter, const D3DXVECTOR4 *vector, UINT count) PURE;
    STDMETHOD(GetVectorArray)(THIS_ D3DXHANDLE parameter, D3DXVECTOR4* vector, UINT count) PURE;
    STDMETHOD(SetMatrix)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix) PURE;
    STDMETHOD(GetMatrix)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix) PURE;
    STDMETHOD(SetMatrixArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix, UINT count) PURE;
    STDMETHOD(GetMatrixArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix, UINT count) PURE;
    STDMETHOD(SetMatrixPointerArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX **matrix, UINT count) PURE;
    STDMETHOD(GetMatrixPointerArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX** matrix, UINT count) PURE;
    STDMETHOD(SetMatrixTranspose)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix) PURE;
    STDMETHOD(GetMatrixTranspose)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix) PURE;
    STDMETHOD(SetMatrixTransposeArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX *matrix, UINT count) PURE;
    STDMETHOD(GetMatrixTransposeArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX* matrix, UINT count) PURE;
    STDMETHOD(SetMatrixTransposePointerArray)(THIS_ D3DXHANDLE parameter, const D3DXMATRIX **matrix, UINT count) PURE;
    STDMETHOD(GetMatrixTransposePointerArray)(THIS_ D3DXHANDLE parameter, D3DXMATRIX** matrix, UINT count) PURE;
    STDMETHOD(SetString)(THIS_ D3DXHANDLE parameter, const char *string) PURE;
    STDMETHOD(GetString)(THIS_ D3DXHANDLE parameter, const char **string) PURE;
    STDMETHOD(SetTexture)(THIS_ D3DXHANDLE parameter, struct IDirect3DBaseTexture9 *texture) PURE;
    STDMETHOD(GetTexture)(THIS_ D3DXHANDLE parameter, struct IDirect3DBaseTexture9 **texture) PURE;
    STDMETHOD(GetPixelShader)(THIS_ D3DXHANDLE parameter, struct IDirect3DPixelShader9 **shader) PURE;
    STDMETHOD(GetVertexShader)(THIS_ D3DXHANDLE parameter, struct IDirect3DVertexShader9 **shader) PURE;
    STDMETHOD(SetArrayRange)(THIS_ D3DXHANDLE parameter, UINT start, UINT end) PURE;
    /*** ID3DXEffectCompiler methods ***/
    STDMETHOD(SetLiteral)(THIS_ D3DXHANDLE parameter, WINBOOL literal) PURE;
    STDMETHOD(GetLiteral)(THIS_ D3DXHANDLE parameter, WINBOOL* literal) PURE;
    STDMETHOD(CompileEffect)(THIS_ DWORD flags, ID3DXBuffer **effect, ID3DXBuffer **error_msgs) PURE;
    STDMETHOD(CompileShader)(THIS_ D3DXHANDLE function, const char *target, DWORD flags,
            ID3DXBuffer **shader, ID3DXBuffer **error_msgs, ID3DXConstantTable **constant_table) PURE;
};
#undef INTERFACE

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI D3DXCreateEffectPool(ID3DXEffectPool **pool);
HRESULT WINAPI D3DXCreateEffect(struct IDirect3DDevice9 *device, const void *srcdata, UINT srcdatalen,
        const D3DXMACRO *defines, struct ID3DXInclude *include, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
HRESULT WINAPI D3DXCreateEffectEx(struct IDirect3DDevice9 *device, const void *srcdata, UINT srcdatalen,
        const D3DXMACRO *defines, struct ID3DXInclude *include, const char *skip_constants, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
HRESULT WINAPI D3DXCreateEffectCompiler(const char *srcdata, UINT srcdatalen, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXEffectCompiler **compiler, ID3DXBuffer **parse_errors);
HRESULT WINAPI D3DXCreateEffectFromFileExA(struct IDirect3DDevice9 *device, const char *srcfile,
        const D3DXMACRO *defines, struct ID3DXInclude *include, const char *skip_constants, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
HRESULT WINAPI D3DXCreateEffectFromFileExW(struct IDirect3DDevice9 *device, const WCHAR *srcfile,
        const D3DXMACRO *defines, struct ID3DXInclude *include, const char *skip_constants, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
#define D3DXCreateEffectFromFileEx __MINGW_NAME_AW(D3DXCreateEffectFromFileEx)

HRESULT WINAPI D3DXCreateEffectFromFileA(struct IDirect3DDevice9 *device, const char *srcfile,
        const D3DXMACRO *defines, struct ID3DXInclude *include, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
HRESULT WINAPI D3DXCreateEffectFromFileW(struct IDirect3DDevice9 *device, const WCHAR *srcfile,
        const D3DXMACRO *defines, struct ID3DXInclude *include, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
#define D3DXCreateEffectFromFile __MINGW_NAME_AW(D3DXCreateEffectFromFile)

HRESULT WINAPI D3DXCreateEffectFromResourceExA(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const char *srcresource, const D3DXMACRO *defines, struct ID3DXInclude *include,
        const char *skip_constants, DWORD flags, struct ID3DXEffectPool *pool,
        struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
HRESULT WINAPI D3DXCreateEffectFromResourceExW(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const WCHAR *srcresource, const D3DXMACRO *defines, struct ID3DXInclude *include,
        const char *skip_constants, DWORD flags, struct ID3DXEffectPool *pool,
        struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
#define D3DXCreateEffectFromResourceEx __MINGW_NAME_AW(D3DXCreateEffectFromResourceEx)

HRESULT WINAPI D3DXCreateEffectFromResourceA(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const char *srcresource, const D3DXMACRO *defines, struct ID3DXInclude *include, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
HRESULT WINAPI D3DXCreateEffectFromResourceW(struct IDirect3DDevice9 *device, HMODULE srcmodule,
        const WCHAR *srcresource, const D3DXMACRO *defines, struct ID3DXInclude *include, DWORD flags,
        struct ID3DXEffectPool *pool, struct ID3DXEffect **effect, struct ID3DXBuffer **compilation_errors);
#define D3DXCreateEffectFromResource __MINGW_NAME_AW(D3DXCreateEffectFromResource)

HRESULT WINAPI D3DXCreateEffectCompilerFromFileA(const char *srcfile, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXEffectCompiler **effectcompiler, ID3DXBuffer **parseerrors);
HRESULT WINAPI D3DXCreateEffectCompilerFromFileW(const WCHAR *srcfile, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXEffectCompiler **effectcompiler, ID3DXBuffer **parseerrors);
#define D3DXCreateEffectCompilerFromFile __MINGW_NAME_AW(D3DXCreateEffectCompilerFromFile)

HRESULT WINAPI D3DXCreateEffectCompilerFromResourceA(HMODULE srcmodule, const char *srcresource,
        const D3DXMACRO *defines, ID3DXInclude *include, DWORD flags,
        ID3DXEffectCompiler **effectcompiler, ID3DXBuffer **parseerrors);
HRESULT WINAPI D3DXCreateEffectCompilerFromResourceW(HMODULE srcmodule, const WCHAR *srcresource,
        const D3DXMACRO *defines, ID3DXInclude *include, DWORD flags,
        ID3DXEffectCompiler **effectcompiler, ID3DXBuffer **parseerrors);
#define D3DXCreateEffectCompilerFromResource __MINGW_NAME_AW(D3DXCreateEffectCompilerFromResource)

HRESULT WINAPI D3DXDisassembleEffect(ID3DXEffect *effect, WINBOOL enable_color_code, ID3DXBuffer **disassembly);

#ifdef __cplusplus
}
#endif

#endif /* __D3DX9EFFECT_H__ */
