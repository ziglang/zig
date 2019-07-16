#undef INTERFACE
/*
 * Copyright 2004 Christian Costa
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

#ifndef __WINE_DXFILE_H
#define __WINE_DXFILE_H

#include <objbase.h>
#include <winnt.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

typedef DWORD DXFILEFORMAT;

#define DXFILEFORMAT_BINARY     0
#define DXFILEFORMAT_TEXT       1
#define DXFILEFORMAT_COMPRESSED 2

typedef DWORD DXFILELOADOPTIONS;

#define DXFILELOAD_FROMFILE     __MSABI_LONG(0x00)
#define DXFILELOAD_FROMRESOURCE __MSABI_LONG(0x01)
#define DXFILELOAD_FROMMEMORY   __MSABI_LONG(0x02)
#define DXFILELOAD_FROMSTREAM   __MSABI_LONG(0x04)
#define DXFILELOAD_FROMURL      __MSABI_LONG(0x08)

typedef struct _DXFILELOADRESOURCE {
    HMODULE hModule;
    LPCSTR /*LPCTSTR*/ lpName;
    LPCSTR /*LPCTSTR*/ lpType;
} DXFILELOADRESOURCE, *LPDXFILELOADRESOURCE;

typedef struct _DXFILELOADMEMORY {
    LPVOID lpMemory;
    DWORD dSize;
} DXFILELOADMEMORY, *LPDXFILELOADMEMORY;

typedef struct IDirectXFile *LPDIRECTXFILE;
typedef struct IDirectXFileEnumObject *LPDIRECTXFILEENUMOBJECT;
typedef struct IDirectXFileSaveObject *LPDIRECTXFILESAVEOBJECT;
typedef struct IDirectXFileObject *LPDIRECTXFILEOBJECT;
typedef struct IDirectXFileData *LPDIRECTXFILEDATA;
typedef struct IDirectXFileDataReference *LPDIRECTXFILEDATAREFERENCE;
typedef struct IDirectXFileBinary *LPDIRECTXFILEBINARY;

STDAPI DirectXFileCreate(LPDIRECTXFILE *lplpDirectXFile);

#define INTERFACE IDirectXFile
DECLARE_INTERFACE_(IDirectXFile,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectXFile methods ***/
    STDMETHOD(CreateEnumObject) (THIS_ LPVOID, DXFILELOADOPTIONS, LPDIRECTXFILEENUMOBJECT *) PURE;
    STDMETHOD(CreateSaveObject) (THIS_ LPCSTR, DXFILEFORMAT, LPDIRECTXFILESAVEOBJECT *) PURE;
    STDMETHOD(RegisterTemplates) (THIS_ LPVOID, DWORD) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFile_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFile_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFile_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFile methods ***/
#define IDirectXFile_CreateEnumObject(p,a,b,c) (p)->lpVtbl->CreateEnumObject(p,a,b,c)
#define IDirectXFile_CreateSaveObject(p,a,b,c) (p)->lpVtbl->CreateSaveObject(p,a,b,c)
#define IDirectXFile_RegisterTemplates(p,a,b)  (p)->lpVtbl->RegisterTemplates(p,a,b)
#endif

#define INTERFACE IDirectXFileEnumObject
DECLARE_INTERFACE_(IDirectXFileEnumObject,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectXFileEnumObject methods ***/
    STDMETHOD(GetNextDataObject)    (THIS_ LPDIRECTXFILEDATA *) PURE;
    STDMETHOD(GetDataObjectById)    (THIS_ REFGUID, LPDIRECTXFILEDATA *) PURE;
    STDMETHOD(GetDataObjectByName)  (THIS_ LPCSTR, LPDIRECTXFILEDATA *) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFileEnumObject_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFileEnumObject_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFileEnumObject_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFileEnumObject methods ***/
#define IDirectXFileEnumObject_GetNextDataObject(p,a)     (p)->lpVtbl->GetNextDataObject(p,a)
#define IDirectXFileEnumObject_GetDataObjectById(p,a,b)   (p)->lpVtbl->GetDataObjectById(p,a,b)
#define IDirectXFileEnumObject_GetDataObjectByName(p,a,b) (p)->lpVtbl->GetDataObjectByName(p,a,b)
#endif

#define INTERFACE IDirectXFileSaveObject
DECLARE_INTERFACE_(IDirectXFileSaveObject,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectXFileSaveObject methods ***/
    STDMETHOD(SaveTemplates) (THIS_ DWORD, const GUID **) PURE;
    STDMETHOD(CreateDataObject) (THIS_ REFGUID, LPCSTR, const GUID *, DWORD, LPVOID, LPDIRECTXFILEDATA *) PURE;
    STDMETHOD(SaveData) (THIS_ LPDIRECTXFILEDATA) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFileSaveObject_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFileSaveObject_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFileSaveObject_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFileSaveObject methods ***/
#define IDirectXFileSaveObject_SaveTemplates(p,a,b)            (p)->lpVtbl->SaveTemplates(p,a,b)
#define IDirectXFileSaveObject_CreateDataObject(p,a,b,c,d,e,f) (p)->lpVtbl->CreateDataObject(p,a,b,c,d,e,f)
#define IDirectXFileSaveObject_SaveData(p,a)                   (p)->lpVtbl->SaveData(p,a)
#endif

#define IUNKNOWN_METHODS(kind) \
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) kind; \
    STDMETHOD_(ULONG,AddRef)(THIS) kind; \
    STDMETHOD_(ULONG,Release)(THIS) kind

#define IDIRECTXFILEOBJECT_METHODS(kind) \
    STDMETHOD(GetName) (THIS_ LPSTR, LPDWORD) kind; \
    STDMETHOD(GetId) (THIS_ LPGUID) kind

#define INTERFACE IDirectXFileObject
DECLARE_INTERFACE_(IDirectXFileObject,IUnknown)
{
    IUNKNOWN_METHODS(PURE);
    IDIRECTXFILEOBJECT_METHODS(PURE);
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFileObject_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFileObject_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFileObject_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFileObject methods ***/
#define IDirectXFileObject_GetName(p,a,b) (p)->lpVtbl->GetName(p,a,b)
#define IDirectXFileObject_GetId(p,a)     (p)->lpVtbl->GetId(p,a)
#endif

#define INTERFACE IDirectXFileData
DECLARE_INTERFACE_(IDirectXFileData,IDirectXFileObject)
{
    IUNKNOWN_METHODS(PURE);
    IDIRECTXFILEOBJECT_METHODS(PURE);
    /*** IDirectXFileData methods ***/
    STDMETHOD(GetData) (THIS_ LPCSTR, DWORD *, void **) PURE;
    STDMETHOD(GetType) (THIS_ const GUID **) PURE;
    STDMETHOD(GetNextObject) (THIS_ LPDIRECTXFILEOBJECT *) PURE;
    STDMETHOD(AddDataObject) (THIS_ LPDIRECTXFILEDATA) PURE;
    STDMETHOD(AddDataReference) (THIS_ LPCSTR, const GUID *) PURE;
    STDMETHOD(AddBinaryObject) (THIS_ LPCSTR, const GUID *, LPCSTR, LPVOID, DWORD) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFileData_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFileData_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFileData_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFileObject methods ***/
#define IDirectXFileData_GetName(p,a,b) (p)->lpVtbl->GetName(p,a,b)
#define IDirectXFileData_GetId(p,a)     (p)->lpVtbl->GetId(p,a)
    /*** IDirectXFileData methods ***/
#define IDirectXFileData_GetData(p,a,b,c)             (p)->lpVtbl->GetData(p,a,b,c)
#define IDirectXFileData_GetType(p,a)                 (p)->lpVtbl->GetType(p,a)
#define IDirectXFileData_GetNextObject(p,a)           (p)->lpVtbl->GetNextObject(p,a)
#define IDirectXFileData_AddDataObject(p,a)           (p)->lpVtbl->AddDataObject(p,a)
#define IDirectXFileData_AddDataReference(p,a,b)      (p)->lpVtbl->AddDataReference(p,a,b)
#define IDirectXFileData_AddBinaryObject(p,a,b,c,d,e) (p)->lpVtbl->AddBinaryObject(p,a,b,c,d,e)
#endif

#define INTERFACE IDirectXFileDataReference
DECLARE_INTERFACE_(IDirectXFileDataReference,IDirectXFileObject)
{
    IUNKNOWN_METHODS(PURE);
    IDIRECTXFILEOBJECT_METHODS(PURE);
    /*** IDirectXFileDataReference methods ***/
    STDMETHOD(Resolve) (THIS_ LPDIRECTXFILEDATA *) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFileDataReference_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFileDataReference_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFileDataReference_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFileObject methods ***/
#define IDirectXFileDataReference_GetName(p,a,b) (p)->lpVtbl->GetName(p,a,b)
#define IDirectXFileDataReference_GetId(p,a)     (p)->lpVtbl->GetId(p,a)
    /*** IDirectXFileDataReference methods ***/
#define IDirectXFileDataReference_Resolve(p,a) (p)->lpVtbl->Resolve(p,a)
#endif

#define INTERFACE IDirectXFileBinary
DECLARE_INTERFACE_(IDirectXFileBinary,IDirectXFileObject)
{
    IUNKNOWN_METHODS(PURE);
    IDIRECTXFILEOBJECT_METHODS(PURE);
    /*** IDirectXFileBinary methods ***/
    STDMETHOD(GetSize)      (THIS_ DWORD *) PURE;
    STDMETHOD(GetMimeType)  (THIS_ LPCSTR *) PURE;
    STDMETHOD(Read)         (THIS_ LPVOID, DWORD, LPDWORD) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
    /*** IUnknown methods ***/
#define IDirectXFileBinary_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectXFileBinary_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectXFileBinary_Release(p)            (p)->lpVtbl->Release(p)
    /*** IDirectXFileObject methods ***/
#define IDirectXFileBinary_GetName(p,a,b) (p)->lpVtbl->GetName(p,a,b)
#define IDirectXFileBinary_GetId(p,a)     (p)->lpVtbl->GetId(p,a)
    /*** IDirectXFileBinary methods ***/
#define IDirectXFileBinary_GetSize(p,a)     (p)->lpVtbl->GetSize(p,a)
#define IDirectXFileBinary_GetMimeType(p,a) (p)->lpVtbl->GetMimeType(p,a)
#define IDirectXFileBinary_Read(p,a,b,c)    (p)->lpVtbl->Read(p,a,b,c)
#endif

/* DirectXFile Object CLSID */
DEFINE_GUID(CLSID_CDirectXFile,             0x4516ec43, 0x8f20, 0x11d0, 0x9b, 0x6d, 0x00, 0x00, 0xc0, 0x78, 0x1b, 0xc3);

/* DirectX File Interface GUIDs */
DEFINE_GUID(IID_IDirectXFile,               0x3d82ab40, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);
DEFINE_GUID(IID_IDirectXFileEnumObject,     0x3d82ab41, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);
DEFINE_GUID(IID_IDirectXFileSaveObject,     0x3d82ab42, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);
DEFINE_GUID(IID_IDirectXFileObject,         0x3d82ab43, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);
DEFINE_GUID(IID_IDirectXFileData,           0x3d82ab44, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);
DEFINE_GUID(IID_IDirectXFileDataReference,  0x3d82ab45, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);
DEFINE_GUID(IID_IDirectXFileBinary,         0x3d82ab46, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);

/* DirectX File Header template's GUID */
DEFINE_GUID(TID_DXFILEHeader,               0x3d82ab43, 0x62da, 0x11cf, 0xab, 0x39, 0x00, 0x20, 0xaf, 0x71, 0xe4, 0x33);

/* DirectX File errors */
#define _FACDD  0x876
#define MAKE_DDHRESULT( code )  MAKE_HRESULT( 1, _FACDD, code )

#define DXFILE_OK   0

#define DXFILEERR_BADOBJECT                 MAKE_DDHRESULT(850)
#define DXFILEERR_BADVALUE                  MAKE_DDHRESULT(851)
#define DXFILEERR_BADTYPE                   MAKE_DDHRESULT(852)
#define DXFILEERR_BADSTREAMHANDLE           MAKE_DDHRESULT(853)
#define DXFILEERR_BADALLOC                  MAKE_DDHRESULT(854)
#define DXFILEERR_NOTFOUND                  MAKE_DDHRESULT(855)
#define DXFILEERR_NOTDONEYET                MAKE_DDHRESULT(856)
#define DXFILEERR_FILENOTFOUND              MAKE_DDHRESULT(857)
#define DXFILEERR_RESOURCENOTFOUND          MAKE_DDHRESULT(858)
#define DXFILEERR_URLNOTFOUND               MAKE_DDHRESULT(859)
#define DXFILEERR_BADRESOURCE               MAKE_DDHRESULT(860)
#define DXFILEERR_BADFILETYPE               MAKE_DDHRESULT(861)
#define DXFILEERR_BADFILEVERSION            MAKE_DDHRESULT(862)
#define DXFILEERR_BADFILEFLOATSIZE          MAKE_DDHRESULT(863)
#define DXFILEERR_BADFILECOMPRESSIONTYPE    MAKE_DDHRESULT(864)
#define DXFILEERR_BADFILE                   MAKE_DDHRESULT(865)
#define DXFILEERR_PARSEERROR                MAKE_DDHRESULT(866)
#define DXFILEERR_NOTEMPLATE                MAKE_DDHRESULT(867)
#define DXFILEERR_BADARRAYSIZE              MAKE_DDHRESULT(868)
#define DXFILEERR_BADDATAREFERENCE          MAKE_DDHRESULT(869)
#define DXFILEERR_INTERNALERROR             MAKE_DDHRESULT(870)
#define DXFILEERR_NOMOREOBJECTS             MAKE_DDHRESULT(871)
#define DXFILEERR_BADINTRINSICS             MAKE_DDHRESULT(872)
#define DXFILEERR_NOMORESTREAMHANDLES       MAKE_DDHRESULT(873)
#define DXFILEERR_NOMOREDATA                MAKE_DDHRESULT(874)
#define DXFILEERR_BADCACHEFILE              MAKE_DDHRESULT(875)
#define DXFILEERR_NOINTERNET                MAKE_DDHRESULT(876)

#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* __WINE_DXFILE_H */
