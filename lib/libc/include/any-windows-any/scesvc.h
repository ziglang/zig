/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
DEFINE_GUID(cNodetypeSceTemplateServices,0x24a7f717,0x1f0c,0x11d1,0xaf,0xfb,0x0,0xc0,0x4f,0xb9,0x84,0xf9);
DEFINE_GUID(cNodetypeSceAnalysisServices,0x678050c7,0x1ff8,0x11d1,0xaf,0xfb,0x0,0xc0,0x4f,0xb9,0x84,0xf9);
DEFINE_GUID(cNodetypeSceEventLog,0x2ce06698,0x4bf3,0x11d1,0x8c,0x30,0x0,0xc0,0x4f,0xb9,0x84,0xf9);
DEFINE_GUID(IID_ISceSvcAttachmentPersistInfo,0x6d90e0d0,0x200d,0x11d1,0xaf,0xfb,0x0,0xc0,0x4f,0xb9,0x84,0xf9);
DEFINE_GUID(IID_ISceSvcAttachmentData,0x17c35fde,0x200d,0x11d1,0xaf,0xfb,0x0,0xc0,0x4f,0xb9,0x84,0xf9);

#ifndef _scesvc_
#define _scesvc_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _SCE_SHARED_HEADER
#define _SCE_SHARED_HEADER

  typedef DWORD SCESTATUS;

#define SCESTATUS_SUCCESS __MSABI_LONG(0)
#define SCESTATUS_INVALID_PARAMETER __MSABI_LONG(1)
#define SCESTATUS_RECORD_NOT_FOUND __MSABI_LONG(2)
#define SCESTATUS_INVALID_DATA __MSABI_LONG(3)
#define SCESTATUS_OBJECT_EXIST __MSABI_LONG(4)
#define SCESTATUS_BUFFER_TOO_SMALL __MSABI_LONG(5)
#define SCESTATUS_PROFILE_NOT_FOUND __MSABI_LONG(6)
#define SCESTATUS_BAD_FORMAT __MSABI_LONG(7)
#define SCESTATUS_NOT_ENOUGH_RESOURCE __MSABI_LONG(8)
#define SCESTATUS_ACCESS_DENIED __MSABI_LONG(9)
#define SCESTATUS_CANT_DELETE __MSABI_LONG(10)
#define SCESTATUS_PREFIX_OVERFLOW __MSABI_LONG(11)
#define SCESTATUS_OTHER_ERROR __MSABI_LONG(12)
#define SCESTATUS_ALREADY_RUNNING __MSABI_LONG(13)
#define SCESTATUS_SERVICE_NOT_SUPPORT __MSABI_LONG(14)
#define SCESTATUS_MOD_NOT_FOUND __MSABI_LONG(15)
#define SCESTATUS_EXCEPTION_IN_SERVER __MSABI_LONG(16)
#define SCESTATUS_NO_TEMPLATE_GIVEN __MSABI_LONG(17)
#define SCESTATUS_NO_MAPPING __MSABI_LONG(18)
#define SCESTATUS_TRUST_FAIL __MSABI_LONG(19)

  typedef struct _SCESVC_CONFIGURATION_LINE_ {
    LPTSTR Key;
    LPTSTR Value;
    DWORD ValueLen;
  } SCESVC_CONFIGURATION_LINE,*PSCESVC_CONFIGURATION_LINE;

  typedef struct _SCESVC_CONFIGURATION_INFO_ {
    DWORD Count;
    PSCESVC_CONFIGURATION_LINE Lines;
  } SCESVC_CONFIGURATION_INFO,*PSCESVC_CONFIGURATION_INFO;

  typedef PVOID SCE_HANDLE;
  typedef ULONG SCE_ENUMERATION_CONTEXT,*PSCE_ENUMERATION_CONTEXT;

  typedef enum _SCESVC_INFO_TYPE {
    SceSvcConfigurationInfo,SceSvcMergedPolicyInfo,SceSvcAnalysisInfo,SceSvcInternalUse
  } SCESVC_INFO_TYPE;

#define SCE_ROOT_PATH TEXT("Software\\Microsoft\\Windows NT\\CurrentVersion\\SeCEdit")
#define SCE_ROOT_SERVICE_PATH SCE_ROOT_PATH TEXT("\\SvcEngs")
#endif

  typedef PVOID SCESVC_HANDLE;

  typedef struct _SCESVC_ANALYSIS_LINE_ {
    LPTSTR Key;
    PBYTE Value;
    DWORD ValueLen;
  } SCESVC_ANALYSIS_LINE,*PSCESVC_ANALYSIS_LINE;

  typedef struct _SCESVC_ANALYSIS_INFO_ {
    DWORD Count;
    PSCESVC_ANALYSIS_LINE Lines;
  } SCESVC_ANALYSIS_INFO,*PSCESVC_ANALYSIS_INFO;

#define SCESVC_ENUMERATION_MAX __MSABI_LONG(100)

  typedef SCESTATUS (CALLBACK *PFSCE_QUERY_INFO)(SCE_HANDLE sceHandle,SCESVC_INFO_TYPE sceType,LPTSTR lpPrefix,WINBOOL bExact,PVOID *ppvInfo,PSCE_ENUMERATION_CONTEXT psceEnumHandle);
  typedef SCESTATUS (CALLBACK *PFSCE_SET_INFO)(SCE_HANDLE sceHandle,SCESVC_INFO_TYPE sceType,LPTSTR lpPrefix,WINBOOL bExact,PVOID pvInfo);
  typedef SCESTATUS (CALLBACK *PFSCE_FREE_INFO)(PVOID pvServiceInfo);

#define SCE_LOG_LEVEL_ALWAYS 0
#define SCE_LOG_LEVEL_ERROR 1
#define SCE_LOG_LEVEL_DETAIL 2
#define SCE_LOG_LEVEL_DEBUG 3

  typedef SCESTATUS (CALLBACK *PFSCE_LOG_INFO)(INT ErrLevel,DWORD Win32rc,LPTSTR pErrFmt,...);

  typedef struct _SCESVC_CALLBACK_INFO_ {
    SCE_HANDLE sceHandle;
    PFSCE_QUERY_INFO pfQueryInfo;
    PFSCE_SET_INFO pfSetInfo;
    PFSCE_FREE_INFO pfFreeInfo;
    PFSCE_LOG_INFO pfLogInfo;
  } SCESVC_CALLBACK_INFO,*PSCESVC_CALLBACK_INFO;

  typedef SCESTATUS (*PF_ConfigAnalyzeService)(PSCESVC_CALLBACK_INFO pSceCbInfo);
  typedef SCESTATUS (*PF_UpdateService)(PSCESVC_CALLBACK_INFO pSceCbInfo,PSCESVC_CONFIGURATION_INFO ServiceInfo);

#ifdef __cplusplus
}
#endif
#endif

#ifndef _UUIDS_SCE_ATTACHMENT_
#define _UUIDS_SCE_ATTACHMENT_

#include "rpc.h"
#include "rpcndr.h"

#if __RPCNDR_H_VERSION__ < 440
#define __RPCNDR_H_VERSION__ 440
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define struuidNodetypeSceTemplateServices "{24a7f717-1f0c-11d1-affb-00c04fb984f9}"
#define lstruuidNodetypeSceTemplateServices L"{24a7f717-1f0c-11d1-affb-00c04fb984f9}"
#define struuidNodetypeSceAnalysisServices "{678050c7-1ff8-11d1-affb-00c04fb984f9}"
#define lstruuidNodetypeSceAnalysisServices L"{678050c7-1ff8-11d1-affb-00c04fb984f9}"
#define struuidNodetypeSceEventLog "{2ce06698-4bf3-11d1-8c30-00c04fb984f9}"
#define lstruuidNodetypeSceEventLog L"{2ce06698-4bf3-11d1-8c30-00c04fb984f9}"

  typedef PSCESVC_CONFIGURATION_INFO *LPSCESVC_CONFIGURATION_INFO;
  typedef PSCESVC_ANALYSIS_INFO *LPSCESVC_ANALYSIS_INFO;

#define CCF_SCESVC_ATTACHMENT L"CCF_SCESVC_ATTACHMENT"
#define CCF_SCESVC_ATTACHMENT_DATA L"CCF_SCESVC_ATTACHMENT_DATA"

  typedef struct ISceSvcAttachmentPersistInfo ISceSvcAttachmentPersistInfo;
  typedef ISceSvcAttachmentPersistInfo *LPSCESVCATTACHMENTPERSISTINFO;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISceSvcAttachmentPersistInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Save(LPTSTR lpTemplateName,SCESVC_HANDLE *scesvcHandle,PVOID *ppvData,PBOOL pbOverwriteAll) = 0;
    virtual HRESULT WINAPI IsDirty(LPTSTR lpTemplateName) = 0;
    virtual HRESULT WINAPI FreeBuffer(PVOID pvData) = 0;
  };
#else
  typedef struct ISceSvcAttachmentPersistInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISceSvcAttachmentPersistInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISceSvcAttachmentPersistInfo *This);
      ULONG (WINAPI *Release)(ISceSvcAttachmentPersistInfo *This);
      HRESULT (WINAPI *Save)(ISceSvcAttachmentPersistInfo *This,LPTSTR lpTemplateName,SCESVC_HANDLE scesvcHandle,PVOID *ppvData,PBOOL pbOverwriteAll);
      HRESULT (WINAPI *FreeBuffer)(ISceSvcAttachmentPersistInfo *This,PVOID pvData);
      HRESULT (WINAPI *IsDirty)(ISceSvcAttachmentPersistInfo *This,LPTSTR lpTemplateName);
    END_INTERFACE
  } ISceSvcAttachmentPersistInfoVtbl;
  struct ISceSvcAttachmentPersistInfo {
    CONST_VTBL struct ISceSvcAttachmentPersistInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISceSvcAttachmentPersistInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISceSvcAttachmentPersistInfo_Release(This) (This)->lpVtbl->Release(This)
#define ISceSvcAttachmentPersistInfo_Save(This,lpTemplateName,scesvcHandle,ppvData,pbOverwriteAll) (This)->lpVtbl->Save(lpTemplateName,scesvcHandle,ppvData,pbOverwriteAll)
#define ISceSvcAttachmentPersistInfo_FreeBuffer(This,pvData) (This)->lpVtbl->FreeBuffer(pvData)
#define ISceSvcAttachmentPersistInfo_CloseHandle(This,lpTemplateName) (This)->lpVtbl->IsDirty(lpTemplateName)
#endif
#endif

  typedef struct ISceSvcAttachmentData ISceSvcAttachmentData;
  typedef ISceSvcAttachmentData *LPSCESVCATTACHMENTDATA;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISceSvcAttachmentData : public IUnknown {
  public:
    virtual HRESULT WINAPI GetData(SCESVC_HANDLE scesvcHandle,SCESVC_INFO_TYPE sceType,PVOID *ppvData,PSCE_ENUMERATION_CONTEXT psceEnumHandle) = 0;
    virtual HRESULT WINAPI Initialize(LPCTSTR lpServiceName,LPCTSTR lpTemplateName,LPSCESVCATTACHMENTPERSISTINFO lpSceSvcPersistInfo,SCESVC_HANDLE *pscesvcHandle) = 0;
    virtual HRESULT WINAPI FreeBuffer(PVOID pvData) = 0;
    virtual HRESULT WINAPI CloseHandle(SCESVC_HANDLE scesvcHandle) = 0;
  };
#else
  typedef struct ISceSvcAttachmentDataVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISceSvcAttachmentData *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISceSvcAttachmentData *This);
      ULONG (WINAPI *Release)(ISceSvcAttachmentData *This);
      HRESULT (WINAPI *Initialize)(ISceSvcAttachmentData *This,LPCTSTR lpServiceName,LPCTSTR lpTemplateName,LPSCESVCATTACHMENTPERSISTINFO lpSceSvcPersistInfo,SCESVC_HANDLE *pscesvcHandle);
      HRESULT (WINAPI *GetData)(ISceSvcAttachmentData *This,SCESVC_HANDLE scesvcHandle,SCESVC_INFO_TYPE sceType,PVOID *ppvData,PSCE_ENUMERATION_CONTEXT psceEnumHandle);
      HRESULT (WINAPI *FreeBuffer)(ISceSvcAttachmentData *This,PVOID pvData);
      HRESULT (WINAPI *CloseHandle)(ISceSvcAttachmentData *This,SCESVC_HANDLE scesvcHandle);
    END_INTERFACE
  } ISceSvcAttachmentDataVtbl;
  struct ISceSvcAttachmentData {
    CONST_VTBL struct ISceSvcAttachmentDataVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISceSvcAttachmentData_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISceSvcAttachmentData_Release(This) (This)->lpVtbl->Release(This)
#define ISceSvcAttachmentData_Initialize(This,lpServiceName,lpTemplateName,lpSceSvcPersistInfo,pscesvcHandle) (This)->lpVtbl->Initialize(lpServiceName,lpTemplateName,lpSceSvcPersistInfo,pscesvcHandle)
#define ISceSvcAttachmentData_GetData(This,scesvcHandle,sceType,ppvData,psceEnumHandle) (This)->lpVtbl->GetData(scesvcHandle,sceType,ppvData,psceEnumHandle)
#define ISceSvcAttachmentData_FreeBuffer(This,pvData) (This)->lpVtbl->FreeBuffer(pvData)
#define ISceSvcAttachmentData_CloseHandle(This,scesvcHandle) (This)->lpVtbl->CloseHandle(scesvcHandle)
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
