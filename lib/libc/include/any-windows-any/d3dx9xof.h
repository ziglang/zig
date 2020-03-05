#undef INTERFACE
/*
 * Copyright 2011 Dylan Smith
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

#ifndef __WINE_D3DX9XOF_H
#define __WINE_D3DX9XOF_H

#include "d3dx9.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef DWORD D3DXF_FILEFORMAT;
#define D3DXF_FILEFORMAT_BINARY     0
#define D3DXF_FILEFORMAT_TEXT       1
#define D3DXF_FILEFORMAT_COMPRESSED 2

typedef DWORD D3DXF_FILESAVEOPTIONS;
#define D3DXF_FILESAVE_TOFILE   0x00
#define D3DXF_FILESAVE_TOWFILE  0x01

typedef DWORD D3DXF_FILELOADOPTIONS;
#define D3DXF_FILELOAD_FROMFILE     0x00
#define D3DXF_FILELOAD_FROMWFILE    0x01
#define D3DXF_FILELOAD_FROMRESOURCE 0x02
#define D3DXF_FILELOAD_FROMMEMORY   0x03

typedef struct _D3DXF_FILELOADRESOURCE
{
    HMODULE hModule;
    const char *lpName;
    const char *lpType;
} D3DXF_FILELOADRESOURCE;

typedef struct _D3DXF_FILELOADMEMORY
{
    const void *lpMemory;
    SIZE_T dSize;
} D3DXF_FILELOADMEMORY;


#ifndef _NO_COM
DEFINE_GUID(IID_ID3DXFile,           0xcef08cf9, 0x7b4f, 0x4429, 0x96, 0x24, 0x2a, 0x69, 0x0a, 0x93, 0x32, 0x01);
DEFINE_GUID(IID_ID3DXFileSaveObject, 0xcef08cfa, 0x7b4f, 0x4429, 0x96, 0x24, 0x2a, 0x69, 0x0a, 0x93, 0x32, 0x01);
DEFINE_GUID(IID_ID3DXFileSaveData,   0xcef08cfb, 0x7b4f, 0x4429, 0x96, 0x24, 0x2a, 0x69, 0x0a, 0x93, 0x32, 0x01);
DEFINE_GUID(IID_ID3DXFileEnumObject, 0xcef08cfc, 0x7b4f, 0x4429, 0x96, 0x24, 0x2a, 0x69, 0x0a, 0x93, 0x32, 0x01);
DEFINE_GUID(IID_ID3DXFileData,       0xcef08cfd, 0x7b4f, 0x4429, 0x96, 0x24, 0x2a, 0x69, 0x0a, 0x93, 0x32, 0x01);
#endif /* _NO_COM */

typedef interface ID3DXFile *LPD3DXFILE, **LPLPD3DXFILE;
typedef interface ID3DXFileSaveObject *LPD3DXFILESAVEOBJECT, **LPLPD3DXFILESAVEOBJECT;
typedef interface ID3DXFileSaveData *LPD3DXFILESAVEDATA, **LPLPD3DXFILESAVEDATA;
typedef interface ID3DXFileEnumObject *LPD3DXFILEENUMOBJECT, **LPLPD3DXFILEENUMOBJECT;
typedef interface ID3DXFileData *LPD3DXFILEDATA, **LPLPD3DXFILEDATA;

STDAPI D3DXFileCreate(struct ID3DXFile **file);

#define INTERFACE ID3DXFile
DECLARE_INTERFACE_IID_(ID3DXFile,IUnknown,"cef08cf9-7b4f-4429-9624-2a690a933201")
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** ID3DXFile methods ***/
    STDMETHOD(CreateEnumObject)(THIS_ const void *src, D3DXF_FILELOADOPTIONS type,
            struct ID3DXFileEnumObject **enum_obj) PURE;
    STDMETHOD(CreateSaveObject)(THIS_ const void *data, D3DXF_FILESAVEOPTIONS flags,
            D3DXF_FILEFORMAT format, struct ID3DXFileSaveObject **save_obj) PURE;
    STDMETHOD(RegisterTemplates)(THIS_ const void *data, SIZE_T data_size) PURE;
    STDMETHOD(RegisterEnumTemplates)(THIS_ struct ID3DXFileEnumObject *enum_obj) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXFileSaveObject
DECLARE_INTERFACE_IID_(ID3DXFileSaveObject,IUnknown,"cef08cfa-7b4f-4429-9624-2a690a933201")
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** ID3DXFileSaveObject methods ***/
    STDMETHOD(GetFile)(THIS_ ID3DXFile **file) PURE;
    STDMETHOD(AddDataObject)(THIS_ REFGUID template_guid, const char *name, const GUID *guid,
            SIZE_T data_size, const void *data, struct ID3DXFileSaveData **obj) PURE;
    STDMETHOD(Save)(THIS) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXFileSaveData
DECLARE_INTERFACE_IID_(ID3DXFileSaveData,IUnknown,"cef08cfb-7b4f-4429-9624-2a690a933201")
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** ID3DXFileSaveObject methods ***/
    STDMETHOD(GetSave)(THIS_ ID3DXFileSaveObject **save_obj) PURE;
    STDMETHOD(GetName)(THIS_ char *name, SIZE_T *size) PURE;
    STDMETHOD(GetId)(THIS_ LPGUID) PURE;
    STDMETHOD(GetType)(THIS_ GUID*) PURE;
    STDMETHOD(AddDataObject)(THIS_ REFGUID template_guid, const char *name, const GUID *guid,
            SIZE_T data_size, const void *data, ID3DXFileSaveData **obj) PURE;
    STDMETHOD(AddDataReference)(THIS_ const char *name, const GUID *id) PURE;
};
#undef INTERFACE


#define INTERFACE ID3DXFileEnumObject
DECLARE_INTERFACE_IID_(ID3DXFileEnumObject,IUnknown,"cef08cfc-7b4f-4429-9624-2a690a933201")
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** ID3DXFileEnumObject methods ***/
    STDMETHOD(GetFile)(THIS_ ID3DXFile **file) PURE;
    STDMETHOD(GetChildren)(THIS_ SIZE_T*) PURE;
    STDMETHOD(GetChild)(THIS_ SIZE_T id, struct ID3DXFileData **child) PURE;
    STDMETHOD(GetDataObjectById)(THIS_ REFGUID guid, struct ID3DXFileData **obj) PURE;
    STDMETHOD(GetDataObjectByName)(THIS_ const char *name, struct ID3DXFileData **obj) PURE;
};
#undef INTERFACE

#define INTERFACE ID3DXFileData
DECLARE_INTERFACE_IID_(ID3DXFileData,IUnknown,"cef08cfd-7b4f-4429-9624-2a690a933201")
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** ID3DXFileData methods ***/
    STDMETHOD(GetEnum)(THIS_ ID3DXFileEnumObject **enum_obj) PURE;
    STDMETHOD(GetName)(THIS_ char *name, SIZE_T *size) PURE;
    STDMETHOD(GetId)(THIS_ LPGUID) PURE;
    STDMETHOD(Lock)(THIS_ SIZE_T *data_size, const void **data) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(GetType)(THIS_ GUID*) PURE;
    STDMETHOD_(WINBOOL,IsReference)(THIS) PURE;
    STDMETHOD(GetChildren)(THIS_ SIZE_T*) PURE;
    STDMETHOD(GetChild)(THIS_ SIZE_T id, ID3DXFileData **child) PURE;
};
#undef INTERFACE

/* D3DX File errors */
#define _FACD3DXF 0x876

#define D3DXFERR_BADOBJECT          MAKE_HRESULT(1,_FACD3DXF,900)
#define D3DXFERR_BADVALUE           MAKE_HRESULT(1,_FACD3DXF,901)
#define D3DXFERR_BADTYPE            MAKE_HRESULT(1,_FACD3DXF,902)
#define D3DXFERR_NOTFOUND           MAKE_HRESULT(1,_FACD3DXF,903)
#define D3DXFERR_NOTDONEYET         MAKE_HRESULT(1,_FACD3DXF,904)
#define D3DXFERR_FILENOTFOUND       MAKE_HRESULT(1,_FACD3DXF,905)
#define D3DXFERR_RESOURCENOTFOUND   MAKE_HRESULT(1,_FACD3DXF,906)
#define D3DXFERR_BADRESOURCE        MAKE_HRESULT(1,_FACD3DXF,907)
#define D3DXFERR_BADFILETYPE        MAKE_HRESULT(1,_FACD3DXF,908)
#define D3DXFERR_BADFILEVERSION     MAKE_HRESULT(1,_FACD3DXF,909)
#define D3DXFERR_BADFILEFLOATSIZE   MAKE_HRESULT(1,_FACD3DXF,910)
#define D3DXFERR_BADFILE            MAKE_HRESULT(1,_FACD3DXF,911)
#define D3DXFERR_PARSEERROR         MAKE_HRESULT(1,_FACD3DXF,912)
#define D3DXFERR_BADARRAYSIZE       MAKE_HRESULT(1,_FACD3DXF,913)
#define D3DXFERR_BADDATAREFERENCE   MAKE_HRESULT(1,_FACD3DXF,914)
#define D3DXFERR_NOMOREOBJECTS      MAKE_HRESULT(1,_FACD3DXF,915)
#define D3DXFERR_NOMOREDATA         MAKE_HRESULT(1,_FACD3DXF,916)
#define D3DXFERR_BADCACHEFILE       MAKE_HRESULT(1,_FACD3DXF,917)

#ifdef __cplusplus
}
#endif

#endif /* __WINE_D3DX9XOF_H */
