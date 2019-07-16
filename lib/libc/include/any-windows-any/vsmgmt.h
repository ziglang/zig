/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VSMGT
#define _INC_VSMGT

#include <vss.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _VSS_PROTECTION_FAULT {
  VSS_PROTECTION_FAULT_NONE                           = 0,
  VSS_PROTECTION_FAULT_DIFF_AREA_MISSING              = ( VSS_PROTECTION_FAULT_NONE + 1 ),
  VSS_PROTECTION_FAULT_IO_FAILURE_DURING_ONLINE       = ( VSS_PROTECTION_FAULT_DIFF_AREA_MISSING + 1 ),
  VSS_PROTECTION_FAULT_META_DATA_CORRUPTION           = ( VSS_PROTECTION_FAULT_IO_FAILURE_DURING_ONLINE + 1 ),
  VSS_PROTECTION_FAULT_MEMORY_ALLOCATION_FAILURE      = ( VSS_PROTECTION_FAULT_META_DATA_CORRUPTION + 1 ),
  VSS_PROTECTION_FAULT_MAPPED_MEMORY_FAILURE          = ( VSS_PROTECTION_FAULT_MEMORY_ALLOCATION_FAILURE + 1 ),
  VSS_PROTECTION_FAULT_COW_READ_FAILURE               = ( VSS_PROTECTION_FAULT_MAPPED_MEMORY_FAILURE + 1 ),
  VSS_PROTECTION_FAULT_COW_WRITE_FAILURE              = ( VSS_PROTECTION_FAULT_COW_READ_FAILURE + 1 ),
  VSS_PROTECTION_FAULT_DIFF_AREA_FULL                 = ( VSS_PROTECTION_FAULT_COW_WRITE_FAILURE + 1 ),
  VSS_PROTECTION_FAULT_GROW_TOO_SLOW                  = ( VSS_PROTECTION_FAULT_DIFF_AREA_FULL + 1 ),
  VSS_PROTECTION_FAULT_GROW_FAILED                    = ( VSS_PROTECTION_FAULT_GROW_TOO_SLOW + 1 ),
  VSS_PROTECTION_FAULT_DESTROY_ALL_SNAPSHOTS          = ( VSS_PROTECTION_FAULT_GROW_FAILED + 1 ),
  VSS_PROTECTION_FAULT_FILE_SYSTEM_FAILURE            = ( VSS_PROTECTION_FAULT_DESTROY_ALL_SNAPSHOTS + 1 ),
  VSS_PROTECTION_FAULT_IO_FAILURE                     = ( VSS_PROTECTION_FAULT_FILE_SYSTEM_FAILURE + 1 ),
  VSS_PROTECTION_FAULT_DIFF_AREA_REMOVED              = ( VSS_PROTECTION_FAULT_IO_FAILURE + 1 ),
  VSS_PROTECTION_FAULT_EXTERNAL_WRITER_TO_DIFF_AREA   = ( VSS_PROTECTION_FAULT_DIFF_AREA_REMOVED + 1 ) 
} VSS_PROTECTION_FAULT;

typedef enum _VSS_PROTECTION_LEVEL {
  VSS_PROTECTION_LEVEL_ORIGINAL_VOLUME   = 0,
  VSS_PROTECTION_LEVEL_SNAPSHOT          = ( VSS_PROTECTION_LEVEL_ORIGINAL_VOLUME + 1 ) 
} VSS_PROTECTION_LEVEL;

typedef enum _VSS_MGMT_OBJECT_TYPE {
  VSS_MGMT_OBJECT_UNKNOWN       = 0,
  VSS_MGMT_OBJECT_VOLUME        = 1,
  VSS_MGMT_OBJECT_DIFF_VOLUME   = 2,
  VSS_MGMT_OBJECT_DIFF_AREA     = 3 
} VSS_MGMT_OBJECT_TYPE, *PVSS_MGMT_OBJECT_TYPE;

typedef struct _VSS_VOLUME_PROP {
  VSS_PWSZ m_pwszVolumeName;
  VSS_PWSZ m_pwszVolumeDisplayName;
} VSS_VOLUME_PROP, *PVSS_VOLUME_PROP;

typedef struct _VSS_VOLUME_PROTECTION_INFO {
  VSS_PROTECTION_LEVEL m_protectionLevel;
  WINBOOL              m_volumeIsOfflineForProtection;
  VSS_PROTECTION_FAULT m_protectionFault;
  LONG                 m_failureStatus;
  WINBOOL              m_volumeHasUnusedDiffArea;
  DWORD                m_reserved;
} VSS_VOLUME_PROTECTION_INFO;

#if (_WIN32_WINNT >= 0x0600)

typedef struct _VSS_DIFF_AREA_PROP {
  VSS_PWSZ m_pwszVolumeName;
  VSS_PWSZ m_pwszDiffAreaVolumeName;
  LONGLONG m_llMaximumDiffSpace;
  LONGLONG m_llAllocatedDiffSpace;
  LONGLONG m_llUsedDiffSpace;
} VSS_DIFF_AREA_PROP, *PVSS_DIFF_AREA_PROP;

typedef struct _VSS_DIFF_VOLUME_PROP {
  VSS_PWSZ m_pwszVolumeName;
  VSS_PWSZ m_pwszVolumeDisplayName;
  LONGLONG m_llVolumeFreeSpace;
  LONGLONG m_llVolumeTotalSpace;
} VSS_DIFF_VOLUME_PROP, *PVSS_DIFF_VOLUME_PROP;

typedef union _VSS_MGMT_OBJECT_UNION {
  VSS_VOLUME_PROP      Vol;
  VSS_DIFF_VOLUME_PROP DiffVol;
  VSS_DIFF_AREA_PROP   DiffArea;
} VSS_MGMT_OBJECT_UNION, *PVSS_MGMT_OBJECT_UNION;

typedef struct _VSS_MGMT_OBJECT_PROP {
  VSS_MGMT_OBJECT_TYPE  Type;
  VSS_MGMT_OBJECT_UNION Obj;
} VSS_MGMT_OBJECT_PROP, *PVSS_MGMT_OBJECT_PROP;

#endif /* (_WIN32_WINNT >= 0x0600) */

#ifdef __cplusplus
}
#endif

#undef  INTERFACE
#define INTERFACE IVssDifferentialSoftwareSnapshotMgmt
/*IID_IVssDifferentialSoftwareSnapshotMgmt is defined as 214A0F28-B737-4026-B847-4F9E37D79529*/
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssDifferentialSoftwareSnapshotMgmt,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssDifferentialSoftwareSnapshotMgmt methods */
    STDMETHOD_(HRESULT,AddDiffArea)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace) PURE;
    STDMETHOD_(HRESULT,ChangeDiffAreaMaximumSize)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace) PURE;
    STDMETHOD_(HRESULT,QueryVolumesSupportedForDiffAreas)(THIS_ VSS_PWSZ pwszOriginalVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasForVolume)(THIS_ VSS_PWSZ pwszVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasOnVolume)(THIS_ VSS_PWSZ pwszVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasForSnapshot)(THIS_ VSS_ID SnapshotId,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,Opmun08NotUsedOnWire)(THIS) PURE; /* Reserved */

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssDifferentialSoftwareSnapshotMgmt_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssDifferentialSoftwareSnapshotMgmt_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssDifferentialSoftwareSnapshotMgmt_Release(This) (This)->lpVtbl->Release(This)
#define IVssDifferentialSoftwareSnapshotMgmt_AddDiffArea(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace) (This)->lpVtbl->AddDiffArea(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace)
#define IVssDifferentialSoftwareSnapshotMgmt_ChangeDiffAreaMaximumSize(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace) (This)->lpVtbl->ChangeDiffAreaMaximumSize(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace)
#define IVssDifferentialSoftwareSnapshotMgmt_QueryVolumesSupportedForDiffAreas(This,pwszOriginalVolumeName,ppEnum) (This)->lpVtbl->QueryVolumesSupportedForDiffAreas(This,pwszOriginalVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt_QueryDiffAreasForVolume(This,pwszVolumeName,ppEnum) (This)->lpVtbl->QueryDiffAreasForVolume(This,pwszVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt_QueryDiffAreasOnVolume(This,pwszVolumeName,ppEnum) (This)->lpVtbl->QueryDiffAreasOnVolume(This,pwszVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt_QueryDiffAreasForSnapshot(This,SnapshotId,ppEnum) (This)->lpVtbl->QueryDiffAreasForSnapshot(This,SnapshotId,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt_Opmun08NotUsedOnWire(This)
#endif /*COBJMACROS*/

#if (_WIN32_WINNT >= 0x0600)
#undef  INTERFACE
#define INTERFACE IVssDifferentialSoftwareSnapshotMgmt2
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssDifferentialSoftwareSnapshotMgmt2,IVssDifferentialSoftwareSnapshotMgmt)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssDifferentialSoftwareSnapshotMgmt methods */
    STDMETHOD_(HRESULT,AddDiffArea)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace) PURE;
    STDMETHOD_(HRESULT,ChangeDiffAreaMaximumSize)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace) PURE;
    STDMETHOD_(HRESULT,QueryVolumesSupportedForDiffAreas)(THIS_ VSS_PWSZ pwszOriginalVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasForVolume)(THIS_ VSS_PWSZ pwszVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasOnVolume)(THIS_ VSS_PWSZ pwszVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasForSnapshot)(THIS_ VSS_ID SnapshotId,IVssEnumMgmtObject **ppEnum) PURE;

    /* IVssDifferentialSoftwareSnapshotMgmt2 methods */
    STDMETHOD_(HRESULT,ChangeDiffAreaMaximumSizeEx)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace,WINBOOL bVolatile) PURE;
    STDMETHOD_(HRESULT,MigrateDiffAreas)(THIS) PURE;      /*Unsupported*/
    STDMETHOD_(HRESULT,QueryMigrationStatus)(THIS) PURE;  /*Unsupported*/
    STDMETHOD_(HRESULT,SetSnapshotPriority)(THIS) PURE;   /*Unsupported*/

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssDifferentialSoftwareSnapshotMgmt2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssDifferentialSoftwareSnapshotMgmt2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssDifferentialSoftwareSnapshotMgmt2_Release(This) (This)->lpVtbl->Release(This)
#define IVssDifferentialSoftwareSnapshotMgmt2_AddDiffArea(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace) (This)->lpVtbl->AddDiffArea(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace)
#define IVssDifferentialSoftwareSnapshotMgmt2_ChangeDiffAreaMaximumSize(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace) (This)->lpVtbl->ChangeDiffAreaMaximumSize(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace)
#define IVssDifferentialSoftwareSnapshotMgmt2_QueryVolumesSupportedForDiffAreas(This,pwszOriginalVolumeName,ppEnum) (This)->lpVtbl->QueryVolumesSupportedForDiffAreas(This,pwszOriginalVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt2_QueryDiffAreasForVolume(This,pwszVolumeName,ppEnum) (This)->lpVtbl->QueryDiffAreasForVolume(This,pwszVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt2_QueryDiffAreasOnVolume(This,pwszVolumeName,ppEnum) (This)->lpVtbl->QueryDiffAreasOnVolume(This,pwszVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt2_QueryDiffAreasForSnapshot(This,SnapshotId,ppEnum) (This)->lpVtbl->QueryDiffAreasForSnapshot(This,SnapshotId,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt2_ChangeDiffAreaMaximumSizeEx(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace,bVolatile) (This)->lpVtbl->ChangeDiffAreaMaximumSizeEx(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace,bVolatile)
#define IVssDifferentialSoftwareSnapshotMgmt2_MigrateDiffAreas() (This)->lpVtbl->MigrateDiffAreas(This)
#define IVssDifferentialSoftwareSnapshotMgmt2_QueryMigrationStatus() (This)->lpVtbl->QueryMigrationStatus(This)
#define IVssDifferentialSoftwareSnapshotMgmt2_SetSnapshotPriority() (This)->lpVtbl->SetSnapshotPriority(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssDifferentialSoftwareSnapshotMgmt3
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssDifferentialSoftwareSnapshotMgmt3,IVssDifferentialSoftwareSnapshotMgmt2)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssDifferentialSoftwareSnapshotMgmt methods */
    STDMETHOD_(HRESULT,AddDiffArea)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace) PURE;
    STDMETHOD_(HRESULT,ChangeDiffAreaMaximumSize)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace) PURE;
    STDMETHOD_(HRESULT,QueryVolumesSupportedForDiffAreas)(THIS_ VSS_PWSZ pwszOriginalVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasForVolume)(THIS_ VSS_PWSZ pwszVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasOnVolume)(THIS_ VSS_PWSZ pwszVolumeName,IVssEnumMgmtObject **ppEnum) PURE;
    STDMETHOD_(HRESULT,QueryDiffAreasForSnapshot)(THIS_ VSS_ID SnapshotId,IVssEnumMgmtObject **ppEnum) PURE;

    /* IVssDifferentialSoftwareSnapshotMgmt2 methods */
    STDMETHOD_(HRESULT,ChangeDiffAreaMaximumSizeEx)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PWSZ pwszDiffAreaVolumeName,LONGLONG llMaximumDiffSpace,WINBOOL bVolatile) PURE;
    STDMETHOD_(HRESULT,MigrateDiffAreas)(THIS) PURE;      /*Unsupported*/
    STDMETHOD_(HRESULT,QueryMigrationStatus)(THIS) PURE;  /*Unsupported*/
    STDMETHOD_(HRESULT,SetSnapshotPriority)(THIS) PURE;   /*Unsupported*/

    /* IVssDifferentialSoftwareSnapshotMgmt3 methods */
    STDMETHOD_(HRESULT,SetVolumeProtectLevel)(THIS_ VSS_PWSZ pwszVolumeName,VSS_PROTECTION_LEVEL protectionLevel) PURE;
    STDMETHOD_(HRESULT,GetVolumeProtectLevel)(THIS_ VSS_PWSZ pwszVolumeName,VSS_VOLUME_PROTECTION_INFO *protectionLevel) PURE;
    STDMETHOD_(HRESULT,ClearVolumeProtectFault)(THIS_ VSS_PWSZ pwszVolumeName) PURE;
    STDMETHOD_(HRESULT,DeleteUnusedDiffAreas)(THIS_ VSS_PWSZ pwszDiffAreaVolumeName) PURE;
    STDMETHOD_(HRESULT,QuerySnapshotDeltaBitmap)(THIS) PURE;  /*Unsupported*/

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssDifferentialSoftwareSnapshotMgmt3_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssDifferentialSoftwareSnapshotMgmt3_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssDifferentialSoftwareSnapshotMgmt3_Release(This) (This)->lpVtbl->Release(This)
#define IVssDifferentialSoftwareSnapshotMgmt3_AddDiffArea(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace) (This)->lpVtbl->AddDiffArea(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace)
#define IVssDifferentialSoftwareSnapshotMgmt3_ChangeDiffAreaMaximumSize(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace) (This)->lpVtbl->ChangeDiffAreaMaximumSize(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace)
#define IVssDifferentialSoftwareSnapshotMgmt3_QueryVolumesSupportedForDiffAreas(This,pwszOriginalVolumeName,ppEnum) (This)->lpVtbl->QueryVolumesSupportedForDiffAreas(This,pwszOriginalVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt3_QueryDiffAreasForVolume(This,pwszVolumeName,ppEnum) (This)->lpVtbl->QueryDiffAreasForVolume(This,pwszVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt3_QueryDiffAreasOnVolume(This,pwszVolumeName,ppEnum) (This)->lpVtbl->QueryDiffAreasOnVolume(This,pwszVolumeName,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt3_QueryDiffAreasForSnapshot(This,SnapshotId,ppEnum) (This)->lpVtbl->QueryDiffAreasForSnapshot(This,SnapshotId,ppEnum)
#define IVssDifferentialSoftwareSnapshotMgmt3_ChangeDiffAreaMaximumSizeEx(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace,bVolatile) (This)->lpVtbl->ChangeDiffAreaMaximumSizeEx(This,pwszVolumeName,pwszDiffAreaVolumeName,llMaximumDiffSpace,bVolatile)
#define IVssDifferentialSoftwareSnapshotMgmt3_MigrateDiffAreas() (This)->lpVtbl->MigrateDiffAreas(This)
#define IVssDifferentialSoftwareSnapshotMgmt3_QueryMigrationStatus() (This)->lpVtbl->QueryMigrationStatus(This)
#define IVssDifferentialSoftwareSnapshotMgmt3_SetSnapshotPriority() (This)->lpVtbl->SetSnapshotPriority(This)
#define IVssDifferentialSoftwareSnapshotMgmt3_SetVolumeProtectLevel(This,pwszVolumeName,protectionLevel) (This)->lpVtbl->SetVolumeProtectLevel(This,pwszVolumeName,protectionLevel)
#define IVssDifferentialSoftwareSnapshotMgmt3_GetVolumeProtectLevel(This,pwszVolumeName,protectionLevel) (This)->lpVtbl->GetVolumeProtectLevel(This,pwszVolumeName,protectionLevel)
#define IVssDifferentialSoftwareSnapshotMgmt3_ClearVolumeProtectFault(This,pwszVolumeName) (This)->lpVtbl->ClearVolumeProtectFault(This,pwszVolumeName)
#define IVssDifferentialSoftwareSnapshotMgmt3_DeleteUnusedDiffAreas(This,pwszDiffAreaVolumeName) (This)->lpVtbl->DeleteUnusedDiffAreas(This,pwszDiffAreaVolumeName)
#define IVssDifferentialSoftwareSnapshotMgmt3_QuerySnapshotDeltaBitmap() (This)->lpVtbl->QuerySnapshotDeltaBitmap(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssEnumMgmtObject
/*IID_IVssEnumMgmtObject is defined as 01954E6B-9254-4e6e-808C-C9E05D007696*/
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssEnumMgmtObject,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssEnumMgmtObject methods */
    STDMETHOD_(HRESULT,Next)(THIS_ ULONG celt,VSS_MGMT_OBJECT_PROP *rgelt,ULONG *pceltFetched) PURE;
    STDMETHOD_(HRESULT,Skip)(THIS_ ULONG celt) PURE;
    STDMETHOD_(HRESULT,Reset)(THIS) PURE;
    STDMETHOD_(HRESULT,Clone)(THIS_ IVssEnumMgmtObject **ppenum) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssEnumMgmtObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssEnumMgmtObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssEnumMgmtObject_Release(This) (This)->lpVtbl->Release(This)
#define IVssEnumMgmtObject_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IVssEnumMgmtObject_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IVssEnumMgmtObject_Reset() (This)->lpVtbl->Reset(This)
#define IVssEnumMgmtObject_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif /*COBJMACROS*/

#endif /* (_WIN32_WINNT >= 0x0600) */

#undef  INTERFACE
#define INTERFACE IVssSnapshotMgmt
/*IID_IVssSnapshotMgmt is defined as FA7DF749-66E7-4986-A27F-E2F04AE53772*/
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IVssSnapshotMgmt,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssSnapshotMgmt methods */
    STDMETHOD_(HRESULT,GetProviderMgmtInterface)(THIS_ VSS_ID ProviderId,REFIID InterfaceId,IUnknown **ppItf) PURE;
    STDMETHOD_(HRESULT,QueryVolumesSupportedForSnapshots)(THIS) PURE; /*Unsupported*/
    STDMETHOD_(HRESULT,QuerySnapshotsByVolume)(THIS) PURE;            /*Unsupported*/

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssSnapshotMgmt_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssSnapshotMgmt_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssSnapshotMgmt_Release(This) (This)->lpVtbl->Release(This)
#define IVssSnapshotMgmt_GetProviderMgmtInterface(This,ProviderId,InterfaceId,ppItf) (This)->lpVtbl->GetProviderMgmtInterface(This,ProviderId,InterfaceId,ppItf)
#define IVssSnapshotMgmt_QueryVolumesSupportedForSnapshots() (This)->lpVtbl->QueryVolumesSupportedForSnapshots(This)
#define IVssSnapshotMgmt_QuerySnapshotsByVolume() (This)->lpVtbl->QuerySnapshotsByVolume(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IVssSnapshotMgmt2
DECLARE_INTERFACE_(IVssSnapshotMgmt2,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IVssSnapshotMgmt2 methods */
    STDMETHOD_(HRESULT,GetMinDiffAreaSize)(THIS_ LONGLONG *pllMinDiffAreaSize) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IVssSnapshotMgmt2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVssSnapshotMgmt2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVssSnapshotMgmt2_Release(This) (This)->lpVtbl->Release(This)
#define IVssSnapshotMgmt2_GetMinDiffAreaSize(This,pllMinDiffAreaSize) (This)->lpVtbl->GetMinDiffAreaSize(This,pllMinDiffAreaSize)
#endif /*COBJMACROS*/

#endif /*_INC_VSMGT*/
