#include <_mingw_unicode.h>
#undef INTERFACE
/*
 * Copyright 2008 Luis Busquets
 * Copyright 2014 Kai Tietz
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

#ifndef __D3DX9SHADER_H__
#define __D3DX9SHADER_H__

#define D3DXSHADER_DEBUG                          0x1
#define D3DXSHADER_SKIPVALIDATION                 0x2
#define D3DXSHADER_SKIPOPTIMIZATION               0x4
#define D3DXSHADER_PACKMATRIX_ROWMAJOR            0x8
#define D3DXSHADER_PACKMATRIX_COLUMNMAJOR         0x10
#define D3DXSHADER_PARTIALPRECISION               0x20
#define D3DXSHADER_FORCE_VS_SOFTWARE_NOOPT        0x40
#define D3DXSHADER_FORCE_PS_SOFTWARE_NOOPT        0x80
#define D3DXSHADER_NO_PRESHADER                   0x100
#define D3DXSHADER_AVOID_FLOW_CONTROL             0x200
#define D3DXSHADER_PREFER_FLOW_CONTROL            0x400
#define D3DXSHADER_ENABLE_BACKWARDS_COMPATIBILITY 0x1000
#define D3DXSHADER_IEEE_STRICTNESS                0x2000

#define D3DXSHADER_OPTIMIZATION_LEVEL0            0x4000
#define D3DXSHADER_OPTIMIZATION_LEVEL1            0x0
#define D3DXSHADER_OPTIMIZATION_LEVEL2            0xC000
#define D3DXSHADER_OPTIMIZATION_LEVEL3            0x8000

#define D3DXSHADER_USE_LEGACY_D3DX9_31_DLL        0x10000

#define D3DXCONSTTABLE_LARGEADDRESSAWARE          0x20000

typedef const char *D3DXHANDLE;
typedef D3DXHANDLE *LPD3DXHANDLE;

typedef enum _D3DXREGISTER_SET
{
    D3DXRS_BOOL,
    D3DXRS_INT4,
    D3DXRS_FLOAT4,
    D3DXRS_SAMPLER,
    D3DXRS_FORCE_DWORD = 0x7fffffff
} D3DXREGISTER_SET, *LPD3DXREGISTER_SET;

typedef enum D3DXPARAMETER_CLASS
{
    D3DXPC_SCALAR,
    D3DXPC_VECTOR,
    D3DXPC_MATRIX_ROWS,
    D3DXPC_MATRIX_COLUMNS,
    D3DXPC_OBJECT,
    D3DXPC_STRUCT,
    D3DXPC_FORCE_DWORD = 0x7fffffff,
} D3DXPARAMETER_CLASS, *LPD3DXPARAMETER_CLASS;

typedef enum D3DXPARAMETER_TYPE
{
    D3DXPT_VOID,
    D3DXPT_BOOL,
    D3DXPT_INT,
    D3DXPT_FLOAT,
    D3DXPT_STRING,
    D3DXPT_TEXTURE,
    D3DXPT_TEXTURE1D,
    D3DXPT_TEXTURE2D,
    D3DXPT_TEXTURE3D,
    D3DXPT_TEXTURECUBE,
    D3DXPT_SAMPLER,
    D3DXPT_SAMPLER1D,
    D3DXPT_SAMPLER2D,
    D3DXPT_SAMPLER3D,
    D3DXPT_SAMPLERCUBE,
    D3DXPT_PIXELSHADER,
    D3DXPT_VERTEXSHADER,
    D3DXPT_PIXELFRAGMENT,
    D3DXPT_VERTEXFRAGMENT,
    D3DXPT_UNSUPPORTED,
    D3DXPT_FORCE_DWORD = 0x7fffffff,
} D3DXPARAMETER_TYPE, *LPD3DXPARAMETER_TYPE;

typedef struct _D3DXCONSTANTTABLE_DESC
{
    const char *Creator;
    DWORD Version;
    UINT Constants;
} D3DXCONSTANTTABLE_DESC, *LPD3DXCONSTANTTABLE_DESC;

typedef struct _D3DXCONSTANT_DESC
{
    const char *Name;
    D3DXREGISTER_SET RegisterSet;
    UINT RegisterIndex;
    UINT RegisterCount;
    D3DXPARAMETER_CLASS Class;
    D3DXPARAMETER_TYPE Type;
    UINT Rows;
    UINT Columns;
    UINT Elements;
    UINT StructMembers;
    UINT Bytes;
    const void *DefaultValue;
} D3DXCONSTANT_DESC, *LPD3DXCONSTANT_DESC;

#if D3DX_SDK_VERSION < 43
DEFINE_GUID(IID_ID3DXConstantTable, 0x9dca3190, 0x38b9, 0x4fc3, 0x92, 0xe3, 0x39, 0xc6, 0xdd, 0xfb, 0x35, 0x8b);
#else
DEFINE_GUID(IID_ID3DXConstantTable, 0xab3c758f, 0x093e, 0x4356, 0xb7, 0x62, 0x4d, 0xb1, 0x8f, 0x1b, 0x3a, 0x01);
#endif

#undef INTERFACE
#define INTERFACE ID3DXConstantTable

DECLARE_INTERFACE_(ID3DXConstantTable, ID3DXBuffer)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBuffer methods ***/
    STDMETHOD_(void *, GetBufferPointer)(THIS) PURE;
    STDMETHOD_(DWORD, GetBufferSize)(THIS) PURE;
    /*** ID3DXConstantTable methods ***/
    STDMETHOD(GetDesc)(THIS_ D3DXCONSTANTTABLE_DESC *pDesc) PURE;
    STDMETHOD(GetConstantDesc)(THIS_ D3DXHANDLE hConstant, D3DXCONSTANT_DESC *pConstantDesc, UINT *pCount) PURE;
    STDMETHOD_(UINT, GetSamplerIndex)(THIS_ D3DXHANDLE hConstant) PURE;
    STDMETHOD_(D3DXHANDLE, GetConstant)(THIS_ D3DXHANDLE hConstant, UINT Index) PURE;
    STDMETHOD_(D3DXHANDLE, GetConstantByName)(THIS_ D3DXHANDLE constant, const char *name) PURE;
    STDMETHOD_(D3DXHANDLE, GetConstantElement)(THIS_ D3DXHANDLE hConstant, UINT Index) PURE;
    STDMETHOD(SetDefaults)(THIS_ struct IDirect3DDevice9 *device) PURE;
    STDMETHOD(SetValue)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const void *data, UINT data_size) PURE;
    STDMETHOD(SetBool)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant, WINBOOL value) PURE;
    STDMETHOD(SetBoolArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const WINBOOL *values, UINT value_count) PURE;
    STDMETHOD(SetInt)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant, INT value) PURE;
    STDMETHOD(SetIntArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const INT *values, UINT value_count) PURE;
    STDMETHOD(SetFloat)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant, float value) PURE;
    STDMETHOD(SetFloatArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const float *values, UINT value_count) PURE;
    STDMETHOD(SetVector)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant, const D3DXVECTOR4 *value) PURE;
    STDMETHOD(SetVectorArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const D3DXVECTOR4 *values, UINT value_count) PURE;
    STDMETHOD(SetMatrix)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant, const D3DXMATRIX *value) PURE;
    STDMETHOD(SetMatrixArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const D3DXMATRIX *values, UINT value_count) PURE;
    STDMETHOD(SetMatrixPointerArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const D3DXMATRIX **values, UINT value_count) PURE;
    STDMETHOD(SetMatrixTranspose)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const D3DXMATRIX *value) PURE;
    STDMETHOD(SetMatrixTransposeArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const D3DXMATRIX *values, UINT value_count) PURE;
    STDMETHOD(SetMatrixTransposePointerArray)(THIS_ struct IDirect3DDevice9 *device, D3DXHANDLE constant,
            const D3DXMATRIX **values, UINT value_count) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define ID3DXConstantTable_QueryInterface(p,a,b)                      (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXConstantTable_AddRef(p)                                  (p)->lpVtbl->AddRef(p)
#define ID3DXConstantTable_Release(p)                                 (p)->lpVtbl->Release(p)
/*** ID3DXBuffer methods ***/
#define ID3DXConstantTable_GetBufferPointer(p)                        (p)->lpVtbl->GetBufferPointer(p)
#define ID3DXConstantTable_GetBufferSize(p)                           (p)->lpVtbl->GetBufferSize(p)
/*** ID3DXConstantTable methods ***/
#define ID3DXConstantTable_GetDesc(p,a)                               (p)->lpVtbl->GetDesc(p,a)
#define ID3DXConstantTable_GetConstantDesc(p,a,b,c)                   (p)->lpVtbl->GetConstantDesc(p,a,b,c)
#define ID3DXConstantTable_GetSamplerIndex(p,a)                       (p)->lpVtbl->GetSamplerIndex(p,a)
#define ID3DXConstantTable_GetConstant(p,a,b)                         (p)->lpVtbl->GetConstant(p,a,b)
#define ID3DXConstantTable_GetConstantByName(p,a,b)                   (p)->lpVtbl->GetConstantByName(p,a,b)
#define ID3DXConstantTable_GetConstantElement(p,a,b)                  (p)->lpVtbl->GetConstantElement(p,a,b)
#define ID3DXConstantTable_SetDefaults(p,a)                           (p)->lpVtbl->SetDefaults(p,a)
#define ID3DXConstantTable_SetValue(p,a,b,c,d)                        (p)->lpVtbl->SetValue(p,a,b,c,d)
#define ID3DXConstantTable_SetBool(p,a,b,c)                           (p)->lpVtbl->SetBool(p,a,b,c)
#define ID3DXConstantTable_SetBoolArray(p,a,b,c,d)                    (p)->lpVtbl->SetBoolArray(p,a,b,c,d)
#define ID3DXConstantTable_SetInt(p,a,b,c)                            (p)->lpVtbl->SetInt(p,a,b,c)
#define ID3DXConstantTable_SetIntArray(p,a,b,c,d)                     (p)->lpVtbl->SetIntArray(p,a,b,c,d)
#define ID3DXConstantTable_SetFloat(p,a,b,c)                          (p)->lpVtbl->SetFloat(p,a,b,c)
#define ID3DXConstantTable_SetFloatArray(p,a,b,c,d)                   (p)->lpVtbl->SetFloatArray(p,a,b,c,d)
#define ID3DXConstantTable_SetVector(p,a,b,c)                         (p)->lpVtbl->SetVector(p,a,b,c)
#define ID3DXConstantTable_SetVectorArray(p,a,b,c,d)                  (p)->lpVtbl->SetVectorArray(p,a,b,c,d)
#define ID3DXConstantTable_SetMatrix(p,a,b,c)                         (p)->lpVtbl->SetMatrix(p,a,b,c)
#define ID3DXConstantTable_SetMatrixArray(p,a,b,c,d)                  (p)->lpVtbl->SetMatrixArray(p,a,b,c,d)
#define ID3DXConstantTable_SetMatrixPointerArray(p,a,b,c,d)           (p)->lpVtbl->SetMatrixPointerArray(p,a,b,c,d)
#define ID3DXConstantTable_SetMatrixTranspose(p,a,b,c)                (p)->lpVtbl->SetMatrixTranspose(p,a,b,c)
#define ID3DXConstantTable_SetMatrixTransposeArray(p,a,b,c,d)         (p)->lpVtbl->SetMatrixTransposeArray(p,a,b,c,d)
#define ID3DXConstantTable_SetMatrixTransposePointerArray(p,a,b,c,d)  (p)->lpVtbl->SetMatrixTransposePointerArray(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define ID3DXConstantTable_QueryInterface(p,a,b)                      (p)->QueryInterface(a,b)
#define ID3DXConstantTable_AddRef(p)                                  (p)->AddRef()
#define ID3DXConstantTable_Release(p)                                 (p)->Release()
/*** ID3DXBuffer methods ***/
#define ID3DXConstantTable_GetBufferPointer(p)                        (p)->GetBufferPointer()
#define ID3DXConstantTable_GetBufferSize(p)                           (p)->GetBufferSize()
/*** ID3DXConstantTable methods ***/
#define ID3DXConstantTable_GetDesc(p,a)                               (p)->GetDesc(a)
#define ID3DXConstantTable_GetConstantDesc(p,a,b,c)                   (p)->GetConstantDesc(a,b,c)
#define ID3DXConstantTable_GetSamplerIndex(p,a)                       (p)->GetSamplerIndex(a)
#define ID3DXConstantTable_GetConstant(p,a,b)                         (p)->GetConstant(a,b)
#define ID3DXConstantTable_GetConstantByName(p,a,b)                   (p)->GetConstantByName(a,b)
#define ID3DXConstantTable_GetConstantElement(p,a,b)                  (p)->GetConstantElement(a,b)
#define ID3DXConstantTable_SetDefaults(p,a)                           (p)->SetDefaults(a)
#define ID3DXConstantTable_SetValue(p,a,b,c,d)                        (p)->SetValue(a,b,c,d)
#define ID3DXConstantTable_SetBool(p,a,b,c)                           (p)->SetBool(a,b,c)
#define ID3DXConstantTable_SetBoolArray(p,a,b,c,d)                    (p)->SetBoolArray(a,b,c,d)
#define ID3DXConstantTable_SetInt(p,a,b,c)                            (p)->SetInt(a,b,c)
#define ID3DXConstantTable_SetIntArray(p,a,b,c,d)                     (p)->SetIntArray(a,b,c,d)
#define ID3DXConstantTable_SetFloat(p,a,b,c)                          (p)->SetFloat(a,b,c)
#define ID3DXConstantTable_SetFloatArray(p,a,b,c,d)                   (p)->SetFloatArray(a,b,c,d)
#define ID3DXConstantTable_SetVector(p,a,b,c)                         (p)->SetVector(a,b,c)
#define ID3DXConstantTable_SetVectorArray(p,a,b,c,d)                  (p)->SetVectorArray(a,b,c,d)
#define ID3DXConstantTable_SetMatrix(p,a,b,c)                         (p)->SetMatrix(a,b,c)
#define ID3DXConstantTable_SetMatrixArray(p,a,b,c,d)                  (p)->SetMatrixArray(a,b,c,d)
#define ID3DXConstantTable_SetMatrixPointerArray(p,a,b,c,d)           (p)->SetMatrixPointerArray(a,b,c,d)
#define ID3DXConstantTable_SetMatrixTranspose(p,a,b,c)                (p)->SetMatrixTranspose(a,b,c)
#define ID3DXConstantTable_SetMatrixTransposeArray(p,a,b,c,d)         (p)->SetMatrixTransposeArray(a,b,c,d)
#define ID3DXConstantTable_SetMatrixTransposePointerArray(p,a,b,c,d)  (p)->SetMatrixTransposePointerArray(a,b,c,d)
#endif

typedef struct ID3DXConstantTable *LPD3DXCONSTANTTABLE;

typedef interface ID3DXTextureShader *LPD3DXTEXTURESHADER;

DEFINE_GUID(IID_ID3DXTextureShader, 0x3e3d67f8, 0xaa7a, 0x405d, 0xa8, 0x57, 0xba, 0x1, 0xd4, 0x75, 0x84, 0x26);

#define INTERFACE ID3DXTextureShader
DECLARE_INTERFACE_(ID3DXTextureShader, IUnknown)
{
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppv) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    STDMETHOD(GetFunction)(THIS_ struct ID3DXBuffer **ppFunction) PURE;
    STDMETHOD(GetConstantBuffer)(THIS_ struct ID3DXBuffer **ppConstantBuffer) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DXCONSTANTTABLE_DESC *pDesc) PURE;
    STDMETHOD(GetConstantDesc)(THIS_ D3DXHANDLE hConstant, D3DXCONSTANT_DESC *pConstantDesc, UINT *pCount) PURE;
    STDMETHOD_(D3DXHANDLE, GetConstant)(THIS_ D3DXHANDLE hConstant, UINT Index) PURE;
    STDMETHOD_(D3DXHANDLE, GetConstantByName)(THIS_ D3DXHANDLE hConstant, const char *pName) PURE;
    STDMETHOD_(D3DXHANDLE, GetConstantElement)(THIS_ D3DXHANDLE hConstant, UINT Index) PURE;
    STDMETHOD(SetDefaults)(THIS) PURE;
    STDMETHOD(SetValue)(THIS_ D3DXHANDLE hConstant, const void *pData, UINT Bytes) PURE;
    STDMETHOD(SetBool)(THIS_ D3DXHANDLE hConstant, WINBOOL b) PURE;
    STDMETHOD(SetBoolArray)(THIS_ D3DXHANDLE hConstant, const WINBOOL *pb, UINT Count) PURE;
    STDMETHOD(SetInt)(THIS_ D3DXHANDLE hConstant, INT n) PURE;
    STDMETHOD(SetIntArray)(THIS_ D3DXHANDLE hConstant, const INT *pn, UINT Count) PURE;
    STDMETHOD(SetFloat)(THIS_ D3DXHANDLE hConstant, FLOAT f) PURE;
    STDMETHOD(SetFloatArray)(THIS_ D3DXHANDLE hConstant, const FLOAT *pf, UINT Count) PURE;
    STDMETHOD(SetVector)(THIS_ D3DXHANDLE hConstant, const D3DXVECTOR4 *pVector) PURE;
    STDMETHOD(SetVectorArray)(THIS_ D3DXHANDLE hConstant, const D3DXVECTOR4 *pVector, UINT Count) PURE;
    STDMETHOD(SetMatrix)(THIS_ D3DXHANDLE hConstant, const D3DXMATRIX *pMatrix) PURE;
    STDMETHOD(SetMatrixArray)(THIS_ D3DXHANDLE hConstant, const D3DXMATRIX *pMatrix, UINT Count) PURE;
    STDMETHOD(SetMatrixPointerArray)(THIS_ D3DXHANDLE hConstant, const D3DXMATRIX **ppMatrix, UINT Count) PURE;
    STDMETHOD(SetMatrixTranspose)(THIS_ D3DXHANDLE hConstant, const D3DXMATRIX *pMatrix) PURE;
    STDMETHOD(SetMatrixTransposeArray)(THIS_ D3DXHANDLE hConstant, const D3DXMATRIX *pMatrix, UINT Count) PURE;
    STDMETHOD(SetMatrixTransposePointerArray)(THIS_ D3DXHANDLE hConstant, const D3DXMATRIX **ppMatrix, UINT Count) PURE;
};
#undef INTERFACE

typedef struct _D3DXMACRO
{
    const char *Name;
    const char *Definition;
} D3DXMACRO, *LPD3DXMACRO;

typedef struct _D3DXSEMANTIC {
    UINT Usage;
    UINT UsageIndex;
} D3DXSEMANTIC, *LPD3DXSEMANTIC;

typedef enum _D3DXINCLUDE_TYPE
{
    D3DXINC_LOCAL,
    D3DXINC_SYSTEM,
    D3DXINC_FORCE_DWORD = 0x7fffffff,
} D3DXINCLUDE_TYPE, *LPD3DXINCLUDE_TYPE;

#define INTERFACE ID3DXInclude

DECLARE_INTERFACE(ID3DXInclude)
{
    STDMETHOD(Open)(THIS_ D3DXINCLUDE_TYPE include_type, const char *filename,
            const void *parent_data, const void **data, UINT *bytes) PURE;
    STDMETHOD(Close)(THIS_ const void *data) PURE;
};
#undef INTERFACE

#define ID3DXInclude_Open(p,a,b,c,d,e)  (p)->lpVtbl->Open(p,a,b,c,d,e)
#define ID3DXInclude_Close(p,a)         (p)->lpVtbl->Close(p,a)

typedef struct ID3DXInclude *LPD3DXINCLUDE;

typedef struct _D3DXFRAGMENT_DESC
{
    const char *Name;
    DWORD Target;

} D3DXFRAGMENT_DESC, *LPD3DXFRAGMENT_DESC;


DEFINE_GUID(IID_ID3DXFragmentLinker, 0x1a2c0cc2, 0xe5b6, 0x4ebc, 0x9e, 0x8d, 0x39, 0xe, 0x5, 0x78, 0x11, 0xb6);

#define INTERFACE ID3DXFragmentLinker
DECLARE_INTERFACE_(ID3DXFragmentLinker, IUnknown)
{
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **ppv) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD_(UINT, GetNumberOfFragments)(THIS) PURE;

    STDMETHOD_(D3DXHANDLE, GetFragmentHandleByIndex)(THIS_ UINT index) PURE;
    STDMETHOD_(D3DXHANDLE, GetFragmentHandleByName)(THIS_ const char *name) PURE;
    STDMETHOD(GetFragmentDesc)(THIS_ D3DXHANDLE name, D3DXFRAGMENT_DESC *frag_desc) PURE;

    STDMETHOD(AddFragments)(THIS_ const DWORD *fragments) PURE;

    STDMETHOD(GetAllFragments)(THIS_ ID3DXBuffer **buffer) PURE;
    STDMETHOD(GetFragment)(THIS_ D3DXHANDLE name, ID3DXBuffer **buffer) PURE;

    STDMETHOD(LinkShader)(THIS_ const char *profile, DWORD flags, const D3DXHANDLE *fragmenthandles, UINT fragments, ID3DXBuffer **buffer, ID3DXBuffer **errors) PURE;
    STDMETHOD(LinkVertexShader)(THIS_ const char *profile, DWORD flags, const D3DXHANDLE *fragment_handles, UINT fragments, IDirect3DVertexShader9 **shader, ID3DXBuffer **errors) PURE;
    STDMETHOD(LinkPixelShader)(THIS_ const char *profile, DWORD flags, const D3DXHANDLE *fragment_handles, UINT fragments, IDirect3DPixelShader9 **shader, ID3DXBuffer **errors) PURE;

    STDMETHOD(ClearCache)(THIS) PURE;
};
#undef INTERFACE

#ifdef __cplusplus
extern "C" {
#endif

const char * WINAPI D3DXGetPixelShaderProfile(struct IDirect3DDevice9 *device);
UINT WINAPI D3DXGetShaderSize(const DWORD *byte_code);
DWORD WINAPI D3DXGetShaderVersion(const DWORD *byte_code);
const char * WINAPI D3DXGetVertexShaderProfile(struct IDirect3DDevice9 *device);
HRESULT WINAPI D3DXFindShaderComment(const DWORD *byte_code, DWORD fourcc, const void **data, UINT *size);
HRESULT WINAPI D3DXGetShaderSamplers(const DWORD *byte_code, const char **samplers, UINT *count);

HRESULT WINAPI D3DXAssembleShaderFromFileA(const char *filename, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
HRESULT WINAPI D3DXAssembleShaderFromFileW(const WCHAR *filename, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
#define D3DXAssembleShaderFromFile __MINGW_NAME_AW(D3DXAssembleShaderFromFile)

HRESULT WINAPI D3DXAssembleShaderFromResourceA(HMODULE module, const char *resource, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
HRESULT WINAPI D3DXAssembleShaderFromResourceW(HMODULE module, const WCHAR *resource, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
#define D3DXAssembleShaderFromResource __MINGW_NAME_AW(D3DXAssembleShaderFromResource)

HRESULT WINAPI D3DXAssembleShader(const char *data, UINT data_len, const D3DXMACRO *defines,
        ID3DXInclude *include, DWORD flags, ID3DXBuffer **shader, ID3DXBuffer **error_messages);

HRESULT WINAPI D3DXCompileShader(const char *src_data, UINT data_len, const D3DXMACRO *defines,
        ID3DXInclude *include, const char *function_name, const char *profile, DWORD flags,
        ID3DXBuffer **shader, ID3DXBuffer **error_messages, ID3DXConstantTable **constant_table);

HRESULT WINAPI D3DXDisassembleShader(const DWORD *pShader, WINBOOL EnableColorCode, const char *pComments, struct ID3DXBuffer **ppDisassembly);

HRESULT WINAPI D3DXCompileShaderFromFileA(const char *filename, const D3DXMACRO *defines,
        ID3DXInclude *include, const char *entrypoint, const char *profile, DWORD flags,
        ID3DXBuffer **shader, ID3DXBuffer **error_messages, ID3DXConstantTable **constant_table);
HRESULT WINAPI D3DXCompileShaderFromFileW(const WCHAR *filename, const D3DXMACRO *defines,
        ID3DXInclude *include, const char *entrypoint, const char *profile, DWORD flags,
        ID3DXBuffer **shader, ID3DXBuffer **error_messages, ID3DXConstantTable **constant_table);
#define D3DXCompileShaderFromFile __MINGW_NAME_AW(D3DXCompileShaderFromFile)

HRESULT WINAPI D3DXCompileShaderFromResourceA(HMODULE module, const char *resource, const D3DXMACRO *defines,
        ID3DXInclude *include, const char *entrypoint, const char *profile, DWORD flags,
        ID3DXBuffer **shader, ID3DXBuffer **error_messages, ID3DXConstantTable **constant_table);
HRESULT WINAPI D3DXCompileShaderFromResourceW(HMODULE module, const WCHAR *resource, const D3DXMACRO *defines,
        ID3DXInclude *include, const char *entrypoint, const char *profile, DWORD flags,
        ID3DXBuffer **shader, ID3DXBuffer **error_messages, ID3DXConstantTable **constant_table);
#define D3DXCompileShaderFromResource __MINGW_NAME_AW(D3DXCompileShaderFromResource)

HRESULT WINAPI D3DXPreprocessShader(const char *data, UINT data_len, const D3DXMACRO *defines,
        ID3DXInclude *include, ID3DXBuffer **shader, ID3DXBuffer **error_messages);

HRESULT WINAPI D3DXPreprocessShaderFromFileA(const char *filename, const D3DXMACRO *defines,
        ID3DXInclude *include, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
HRESULT WINAPI D3DXPreprocessShaderFromFileW(const WCHAR *filename, const D3DXMACRO *defines,
        ID3DXInclude *include, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
#define D3DXPreprocessShaderFromFile __MINGW_NAME_AW(D3DXPreprocessShaderFromFile)

HRESULT WINAPI D3DXPreprocessShaderFromResourceA(HMODULE module, const char *resource, const D3DXMACRO *defines,
        ID3DXInclude *include, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
HRESULT WINAPI D3DXPreprocessShaderFromResourceW(HMODULE module, const WCHAR *resource, const D3DXMACRO *defines,
        ID3DXInclude *include, ID3DXBuffer **shader, ID3DXBuffer **error_messages);
#define D3DXPreprocessShaderFromResource __MINGW_NAME_AW(D3DXPreprocessShaderFromResource)

HRESULT WINAPI D3DXGetShaderConstantTableEx(const DWORD *byte_code, DWORD flags, ID3DXConstantTable **constant_table);

HRESULT WINAPI D3DXGetShaderConstantTable(const DWORD *byte_code, ID3DXConstantTable **constant_table);

HRESULT WINAPI D3DXGetShaderInputSemantics(const DWORD *pFunction, D3DXSEMANTIC *pSemantics, UINT *pCount);
HRESULT WINAPI D3DXGetShaderOutputSemantics(const DWORD *pFunction, D3DXSEMANTIC *pSemantics, UINT *pCount);

HRESULT WINAPI D3DXCreateTextureShader(const DWORD *pFunction, ID3DXTextureShader **ppTextureShader);

HRESULT WINAPI D3DXCreateFragmentLinker(IDirect3DDevice9 *device, UINT size, ID3DXFragmentLinker **linker);
HRESULT WINAPI D3DXCreateFragmentLinkerEx(IDirect3DDevice9 *device, UINT size, DWORD flags, ID3DXFragmentLinker **linker);

#ifdef __cplusplus
}
#endif

typedef struct _D3DXSHADER_CONSTANTTABLE
{
    DWORD Size;
    DWORD Creator;
    DWORD Version;
    DWORD Constants;
    DWORD ConstantInfo;
    DWORD Flags;
    DWORD Target;
} D3DXSHADER_CONSTANTTABLE, *LPD3DXSHADER_CONSTANTTABLE;

typedef struct _D3DXSHADER_CONSTANTINFO
{
    DWORD Name;
    WORD  RegisterSet;
    WORD  RegisterIndex;
    WORD  RegisterCount;
    WORD  Reserved;
    DWORD TypeInfo;
    DWORD DefaultValue;
} D3DXSHADER_CONSTANTINFO, *LPD3DXSHADER_CONSTANTINFO;

typedef struct _D3DXSHADER_TYPEINFO
{
    WORD  Class;
    WORD  Type;
    WORD  Rows;
    WORD  Columns;
    WORD  Elements;
    WORD  StructMembers;
    DWORD StructMemberInfo;
} D3DXSHADER_TYPEINFO, *LPD3DXSHADER_TYPEINFO;

typedef struct _D3DXSHADER_STRUCTMEMBERINFO
{
    DWORD Name;
    DWORD TypeInfo;
} D3DXSHADER_STRUCTMEMBERINFO, *LPD3DXSHADER_STRUCTMEMBERINFO;

#endif /* __D3DX9SHADER_H__ */
