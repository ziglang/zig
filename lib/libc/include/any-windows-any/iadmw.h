/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __iadmw_h__
#define __iadmw_h__

#ifndef __IMSAdminBaseW_FWD_DEFINED__
#define __IMSAdminBaseW_FWD_DEFINED__
typedef struct IMSAdminBaseW IMSAdminBaseW;
#endif

#ifndef __IMSAdminBase2W_FWD_DEFINED__
#define __IMSAdminBase2W_FWD_DEFINED__
typedef struct IMSAdminBase2W IMSAdminBase2W;
#endif

#ifndef __IMSAdminBase3W_FWD_DEFINED__
#define __IMSAdminBase3W_FWD_DEFINED__
typedef struct IMSAdminBase3W IMSAdminBase3W;
#endif

#ifndef __IMSImpExpHelpW_FWD_DEFINED__
#define __IMSImpExpHelpW_FWD_DEFINED__
typedef struct IMSImpExpHelpW IMSImpExpHelpW;
#endif

#ifndef __IMSAdminBaseSinkW_FWD_DEFINED__
#define __IMSAdminBaseSinkW_FWD_DEFINED__
typedef struct IMSAdminBaseSinkW IMSAdminBaseSinkW;
#endif

#ifndef __AsyncIMSAdminBaseSinkW_FWD_DEFINED__
#define __AsyncIMSAdminBaseSinkW_FWD_DEFINED__
typedef struct AsyncIMSAdminBaseSinkW AsyncIMSAdminBaseSinkW;
#endif

#include "mddefw.h"
#include "objidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _ADM_IADMW_
#define _ADM_IADMW_
#include <mdcommsg.h>
#include <mdmsg.h>

#define ADMINDATA_MAX_NAME_LEN 256

#define CLSID_MSAdminBase CLSID_MSAdminBase_W
#define IID_IMSAdminBase IID_IMSAdminBase_W
#define IMSAdminBase IMSAdminBaseW
#define IID_IMSAdminBase2 IID_IMSAdminBase2_W
#define IMSAdminBase2 IMSAdminBase2W
#define IID_IMSAdminBase3 IID_IMSAdminBase3_W
#define IMSAdminBase3 IMSAdminBase3W
#define IMSAdminBaseSink IMSAdminBaseSinkW
#define IID_IMSAdminBaseSink IID_IMSAdminBaseSink_W
#define IMSImpExpHelp IMSImpExpHelpW
#define IID_IMSImpExpHelp IID_IMSImpExpHelp_W
#define GETAdminBaseCLSID GETAdminBaseCLSIDW

#define AsyncIMSAdminBaseSink AsyncIMSAdminBaseSinkW
#define IID_AsyncIMSAdminBaseSink IID_AsyncIMSAdminBaseSink_W
  DEFINE_GUID(CLSID_MSAdminBase_W,0xa9e69610,0xb80d,0x11d0,0xb9,0xb9,0x0,0xa0,0xc9,0x22,0xe7,0x50);
  DEFINE_GUID(IID_IMSAdminBase_W,0x70b51430,0xb6ca,0x11d0,0xb9,0xb9,0x0,0xa0,0xc9,0x22,0xe7,0x50);
  DEFINE_GUID(IID_IMSAdminBase2_W,0x8298d101,0xf992,0x43b7,0x8e,0xca,0x50,0x52,0xd8,0x85,0xb9,0x95);
  DEFINE_GUID(IID_IMSAdminBase3_W,0xf612954d,0x3b0b,0x4c56,0x95,0x63,0x22,0x7b,0x7b,0xe6,0x24,0xb4);
  DEFINE_GUID(IID_IMSImpExpHelp_W,0x29ff67ff,0x8050,0x480f,0x9f,0x30,0xcc,0x41,0x63,0x5f,0x2f,0x9d);
  DEFINE_GUID(IID_IMSAdminBaseSink_W,0xa9e69612,0xb80d,0x11d0,0xb9,0xb9,0x0,0xa0,0xc9,0x22,0xe7,0x50);
  DEFINE_GUID(IID_AsyncIMSAdminBaseSink_W,0xa9e69613,0xb80d,0x11d0,0xb9,0xb9,0x0,0xa0,0xc9,0x22,0xe7,0x50);
  DEFINE_GUID(IID_IMSAdminBaseSinkNoAsyncCallback,0x41704d5c,0x75a0,0x4d0e,0xae,0x3f,0x80,0xa5,0xfc,0x4c,0xf6,0x53);
#define GETAdminBaseCLSIDW(IsService) CLSID_MSAdminBase_W

  extern RPC_IF_HANDLE __MIDL_itf_iadmw_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iadmw_0000_v0_0_s_ifspec;

#ifndef __IMSAdminBaseW_INTERFACE_DEFINED__
#define __IMSAdminBaseW_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSAdminBaseW;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSAdminBaseW : public IUnknown {
  public:
    virtual HRESULT WINAPI AddKey(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath) = 0;
    virtual HRESULT WINAPI DeleteKey(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath) = 0;
    virtual HRESULT WINAPI DeleteChildKeys(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath) = 0;
    virtual HRESULT WINAPI EnumKeys(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPWSTR pszMDName,DWORD dwMDEnumObjectIndex) = 0;
    virtual HRESULT WINAPI CopyKey(METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,WINBOOL bMDOverwriteFlag,WINBOOL bMDCopyFlag) = 0;
    virtual HRESULT WINAPI RenameKey(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPCWSTR pszMDNewName) = 0;
    virtual HRESULT WINAPI SetData(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData) = 0;
    virtual HRESULT WINAPI GetData(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen) = 0;
    virtual HRESULT WINAPI DeleteData(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType) = 0;
    virtual HRESULT WINAPI EnumData(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen) = 0;
    virtual HRESULT WINAPI GetAllData(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,unsigned char *pbMDBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI DeleteAllData(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDUserType,DWORD dwMDDataType) = 0;
    virtual HRESULT WINAPI CopyData(METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,WINBOOL bMDCopyFlag) = 0;
    virtual HRESULT WINAPI GetDataPaths(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
    virtual HRESULT WINAPI OpenKey(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAccessRequested,DWORD dwMDTimeOut,PMETADATA_HANDLE phMDNewHandle) = 0;
    virtual HRESULT WINAPI CloseKey(METADATA_HANDLE hMDHandle) = 0;
    virtual HRESULT WINAPI ChangePermissions(METADATA_HANDLE hMDHandle,DWORD dwMDTimeOut,DWORD dwMDAccessRequested) = 0;
    virtual HRESULT WINAPI SaveData(void) = 0;
    virtual HRESULT WINAPI GetHandleInfo(METADATA_HANDLE hMDHandle,PMETADATA_HANDLE_INFO pmdhiInfo) = 0;
    virtual HRESULT WINAPI GetSystemChangeNumber(DWORD *pdwSystemChangeNumber) = 0;
    virtual HRESULT WINAPI GetDataSetNumber(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD *pdwMDDataSetNumber) = 0;
    virtual HRESULT WINAPI SetLastChangeTime(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime) = 0;
    virtual HRESULT WINAPI GetLastChangeTime(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime) = 0;
    virtual HRESULT WINAPI KeyExchangePhase1(void) = 0;
    virtual HRESULT WINAPI KeyExchangePhase2(void) = 0;
    virtual HRESULT WINAPI Backup(LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags) = 0;
    virtual HRESULT WINAPI Restore(LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags) = 0;
    virtual HRESULT WINAPI EnumBackups(LPWSTR pszMDBackupLocation,DWORD *pdwMDVersion,PFILETIME pftMDBackupTime,DWORD dwMDEnumIndex) = 0;
    virtual HRESULT WINAPI DeleteBackup(LPCWSTR pszMDBackupLocation,DWORD dwMDVersion) = 0;
    virtual HRESULT WINAPI UnmarshalInterface(IMSAdminBaseW **piadmbwInterface) = 0;
    virtual HRESULT WINAPI GetServerGuid(void) = 0;
  };
#else
  typedef struct IMSAdminBaseWVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSAdminBaseW *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSAdminBaseW *This);
      ULONG (WINAPI *Release)(IMSAdminBaseW *This);
      HRESULT (WINAPI *AddKey)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *DeleteKey)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *DeleteChildKeys)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *EnumKeys)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPWSTR pszMDName,DWORD dwMDEnumObjectIndex);
      HRESULT (WINAPI *CopyKey)(IMSAdminBaseW *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,WINBOOL bMDOverwriteFlag,WINBOOL bMDCopyFlag);
      HRESULT (WINAPI *RenameKey)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPCWSTR pszMDNewName);
      HRESULT (WINAPI *SetData)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData);
      HRESULT (WINAPI *GetData)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen);
      HRESULT (WINAPI *DeleteData)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType);
      HRESULT (WINAPI *EnumData)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen);
      HRESULT (WINAPI *GetAllData)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,unsigned char *pbMDBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *DeleteAllData)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDUserType,DWORD dwMDDataType);
      HRESULT (WINAPI *CopyData)(IMSAdminBaseW *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,WINBOOL bMDCopyFlag);
      HRESULT (WINAPI *GetDataPaths)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *OpenKey)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAccessRequested,DWORD dwMDTimeOut,PMETADATA_HANDLE phMDNewHandle);
      HRESULT (WINAPI *CloseKey)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle);
      HRESULT (WINAPI *ChangePermissions)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,DWORD dwMDTimeOut,DWORD dwMDAccessRequested);
      HRESULT (WINAPI *SaveData)(IMSAdminBaseW *This);
      HRESULT (WINAPI *GetHandleInfo)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,PMETADATA_HANDLE_INFO pmdhiInfo);
      HRESULT (WINAPI *GetSystemChangeNumber)(IMSAdminBaseW *This,DWORD *pdwSystemChangeNumber);
      HRESULT (WINAPI *GetDataSetNumber)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD *pdwMDDataSetNumber);
      HRESULT (WINAPI *SetLastChangeTime)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
      HRESULT (WINAPI *GetLastChangeTime)(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
      HRESULT (WINAPI *KeyExchangePhase1)(IMSAdminBaseW *This);
      HRESULT (WINAPI *KeyExchangePhase2)(IMSAdminBaseW *This);
      HRESULT (WINAPI *Backup)(IMSAdminBaseW *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *Restore)(IMSAdminBaseW *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *EnumBackups)(IMSAdminBaseW *This,LPWSTR pszMDBackupLocation,DWORD *pdwMDVersion,PFILETIME pftMDBackupTime,DWORD dwMDEnumIndex);
      HRESULT (WINAPI *DeleteBackup)(IMSAdminBaseW *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion);
      HRESULT (WINAPI *UnmarshalInterface)(IMSAdminBaseW *This,IMSAdminBaseW **piadmbwInterface);
      HRESULT (WINAPI *GetServerGuid)(IMSAdminBaseW *This);
    END_INTERFACE
  } IMSAdminBaseWVtbl;
  struct IMSAdminBaseW {
    CONST_VTBL struct IMSAdminBaseWVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSAdminBaseW_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSAdminBaseW_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSAdminBaseW_Release(This) (This)->lpVtbl->Release(This)
#define IMSAdminBaseW_AddKey(This,hMDHandle,pszMDPath) (This)->lpVtbl->AddKey(This,hMDHandle,pszMDPath)
#define IMSAdminBaseW_DeleteKey(This,hMDHandle,pszMDPath) (This)->lpVtbl->DeleteKey(This,hMDHandle,pszMDPath)
#define IMSAdminBaseW_DeleteChildKeys(This,hMDHandle,pszMDPath) (This)->lpVtbl->DeleteChildKeys(This,hMDHandle,pszMDPath)
#define IMSAdminBaseW_EnumKeys(This,hMDHandle,pszMDPath,pszMDName,dwMDEnumObjectIndex) (This)->lpVtbl->EnumKeys(This,hMDHandle,pszMDPath,pszMDName,dwMDEnumObjectIndex)
#define IMSAdminBaseW_CopyKey(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,bMDOverwriteFlag,bMDCopyFlag) (This)->lpVtbl->CopyKey(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,bMDOverwriteFlag,bMDCopyFlag)
#define IMSAdminBaseW_RenameKey(This,hMDHandle,pszMDPath,pszMDNewName) (This)->lpVtbl->RenameKey(This,hMDHandle,pszMDPath,pszMDNewName)
#define IMSAdminBaseW_SetData(This,hMDHandle,pszMDPath,pmdrMDData) (This)->lpVtbl->SetData(This,hMDHandle,pszMDPath,pmdrMDData)
#define IMSAdminBaseW_GetData(This,hMDHandle,pszMDPath,pmdrMDData,pdwMDRequiredDataLen) (This)->lpVtbl->GetData(This,hMDHandle,pszMDPath,pmdrMDData,pdwMDRequiredDataLen)
#define IMSAdminBaseW_DeleteData(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType) (This)->lpVtbl->DeleteData(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType)
#define IMSAdminBaseW_EnumData(This,hMDHandle,pszMDPath,pmdrMDData,dwMDEnumDataIndex,pdwMDRequiredDataLen) (This)->lpVtbl->EnumData(This,hMDHandle,pszMDPath,pmdrMDData,dwMDEnumDataIndex,pdwMDRequiredDataLen)
#define IMSAdminBaseW_GetAllData(This,hMDHandle,pszMDPath,dwMDAttributes,dwMDUserType,dwMDDataType,pdwMDNumDataEntries,pdwMDDataSetNumber,dwMDBufferSize,pbMDBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetAllData(This,hMDHandle,pszMDPath,dwMDAttributes,dwMDUserType,dwMDDataType,pdwMDNumDataEntries,pdwMDDataSetNumber,dwMDBufferSize,pbMDBuffer,pdwMDRequiredBufferSize)
#define IMSAdminBaseW_DeleteAllData(This,hMDHandle,pszMDPath,dwMDUserType,dwMDDataType) (This)->lpVtbl->DeleteAllData(This,hMDHandle,pszMDPath,dwMDUserType,dwMDDataType)
#define IMSAdminBaseW_CopyData(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,dwMDAttributes,dwMDUserType,dwMDDataType,bMDCopyFlag) (This)->lpVtbl->CopyData(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,dwMDAttributes,dwMDUserType,dwMDDataType,bMDCopyFlag)
#define IMSAdminBaseW_GetDataPaths(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetDataPaths(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize)
#define IMSAdminBaseW_OpenKey(This,hMDHandle,pszMDPath,dwMDAccessRequested,dwMDTimeOut,phMDNewHandle) (This)->lpVtbl->OpenKey(This,hMDHandle,pszMDPath,dwMDAccessRequested,dwMDTimeOut,phMDNewHandle)
#define IMSAdminBaseW_CloseKey(This,hMDHandle) (This)->lpVtbl->CloseKey(This,hMDHandle)
#define IMSAdminBaseW_ChangePermissions(This,hMDHandle,dwMDTimeOut,dwMDAccessRequested) (This)->lpVtbl->ChangePermissions(This,hMDHandle,dwMDTimeOut,dwMDAccessRequested)
#define IMSAdminBaseW_SaveData(This) (This)->lpVtbl->SaveData(This)
#define IMSAdminBaseW_GetHandleInfo(This,hMDHandle,pmdhiInfo) (This)->lpVtbl->GetHandleInfo(This,hMDHandle,pmdhiInfo)
#define IMSAdminBaseW_GetSystemChangeNumber(This,pdwSystemChangeNumber) (This)->lpVtbl->GetSystemChangeNumber(This,pdwSystemChangeNumber)
#define IMSAdminBaseW_GetDataSetNumber(This,hMDHandle,pszMDPath,pdwMDDataSetNumber) (This)->lpVtbl->GetDataSetNumber(This,hMDHandle,pszMDPath,pdwMDDataSetNumber)
#define IMSAdminBaseW_SetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime) (This)->lpVtbl->SetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime)
#define IMSAdminBaseW_GetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime) (This)->lpVtbl->GetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime)
#define IMSAdminBaseW_KeyExchangePhase1(This) (This)->lpVtbl->KeyExchangePhase1(This)
#define IMSAdminBaseW_KeyExchangePhase2(This) (This)->lpVtbl->KeyExchangePhase2(This)
#define IMSAdminBaseW_Backup(This,pszMDBackupLocation,dwMDVersion,dwMDFlags) (This)->lpVtbl->Backup(This,pszMDBackupLocation,dwMDVersion,dwMDFlags)
#define IMSAdminBaseW_Restore(This,pszMDBackupLocation,dwMDVersion,dwMDFlags) (This)->lpVtbl->Restore(This,pszMDBackupLocation,dwMDVersion,dwMDFlags)
#define IMSAdminBaseW_EnumBackups(This,pszMDBackupLocation,pdwMDVersion,pftMDBackupTime,dwMDEnumIndex) (This)->lpVtbl->EnumBackups(This,pszMDBackupLocation,pdwMDVersion,pftMDBackupTime,dwMDEnumIndex)
#define IMSAdminBaseW_DeleteBackup(This,pszMDBackupLocation,dwMDVersion) (This)->lpVtbl->DeleteBackup(This,pszMDBackupLocation,dwMDVersion)
#define IMSAdminBaseW_UnmarshalInterface(This,piadmbwInterface) (This)->lpVtbl->UnmarshalInterface(This,piadmbwInterface)
#define IMSAdminBaseW_GetServerGuid(This) (This)->lpVtbl->GetServerGuid(This)
#endif
#endif
  HRESULT WINAPI IMSAdminBaseW_AddKey_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
  void __RPC_STUB IMSAdminBaseW_AddKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_DeleteKey_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
  void __RPC_STUB IMSAdminBaseW_DeleteKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_DeleteChildKeys_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
  void __RPC_STUB IMSAdminBaseW_DeleteChildKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_EnumKeys_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPWSTR pszMDName,DWORD dwMDEnumObjectIndex);
  void __RPC_STUB IMSAdminBaseW_EnumKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_CopyKey_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,WINBOOL bMDOverwriteFlag,WINBOOL bMDCopyFlag);
  void __RPC_STUB IMSAdminBaseW_CopyKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_RenameKey_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPCWSTR pszMDNewName);
  void __RPC_STUB IMSAdminBaseW_RenameKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_SetData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData);
  void __RPC_STUB IMSAdminBaseW_R_SetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_GetData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen,struct _IIS_CRYPTO_BLOB **ppDataBlob);
  void __RPC_STUB IMSAdminBaseW_R_GetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_DeleteData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType);
  void __RPC_STUB IMSAdminBaseW_DeleteData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_EnumData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen,struct _IIS_CRYPTO_BLOB **ppDataBlob);
  void __RPC_STUB IMSAdminBaseW_R_EnumData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_GetAllData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,DWORD *pdwMDRequiredBufferSize,struct _IIS_CRYPTO_BLOB **ppDataBlob);
  void __RPC_STUB IMSAdminBaseW_R_GetAllData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_DeleteAllData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDUserType,DWORD dwMDDataType);
  void __RPC_STUB IMSAdminBaseW_DeleteAllData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_CopyData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,WINBOOL bMDCopyFlag);
  void __RPC_STUB IMSAdminBaseW_CopyData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_GetDataPaths_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSAdminBaseW_GetDataPaths_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_OpenKey_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAccessRequested,DWORD dwMDTimeOut,PMETADATA_HANDLE phMDNewHandle);
  void __RPC_STUB IMSAdminBaseW_OpenKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_CloseKey_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle);
  void __RPC_STUB IMSAdminBaseW_CloseKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_ChangePermissions_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,DWORD dwMDTimeOut,DWORD dwMDAccessRequested);
  void __RPC_STUB IMSAdminBaseW_ChangePermissions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_SaveData_Proxy(IMSAdminBaseW *This);
  void __RPC_STUB IMSAdminBaseW_SaveData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_GetHandleInfo_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,PMETADATA_HANDLE_INFO pmdhiInfo);
  void __RPC_STUB IMSAdminBaseW_GetHandleInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_GetSystemChangeNumber_Proxy(IMSAdminBaseW *This,DWORD *pdwSystemChangeNumber);
  void __RPC_STUB IMSAdminBaseW_GetSystemChangeNumber_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_GetDataSetNumber_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD *pdwMDDataSetNumber);
  void __RPC_STUB IMSAdminBaseW_GetDataSetNumber_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_SetLastChangeTime_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
  void __RPC_STUB IMSAdminBaseW_SetLastChangeTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_GetLastChangeTime_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
  void __RPC_STUB IMSAdminBaseW_GetLastChangeTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_KeyExchangePhase1_Proxy(IMSAdminBaseW *This,struct _IIS_CRYPTO_BLOB *pClientKeyExchangeKeyBlob,struct _IIS_CRYPTO_BLOB *pClientSignatureKeyBlob,struct _IIS_CRYPTO_BLOB **ppServerKeyExchangeKeyBlob,struct _IIS_CRYPTO_BLOB **ppServerSignatureKeyBlob,struct _IIS_CRYPTO_BLOB **ppServerSessionKeyBlob);
  void __RPC_STUB IMSAdminBaseW_R_KeyExchangePhase1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_KeyExchangePhase2_Proxy(IMSAdminBaseW *This,struct _IIS_CRYPTO_BLOB *pClientSessionKeyBlob,struct _IIS_CRYPTO_BLOB *pClientHashBlob,struct _IIS_CRYPTO_BLOB **ppServerHashBlob);
  void __RPC_STUB IMSAdminBaseW_R_KeyExchangePhase2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_Backup_Proxy(IMSAdminBaseW *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
  void __RPC_STUB IMSAdminBaseW_Backup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_Restore_Proxy(IMSAdminBaseW *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
  void __RPC_STUB IMSAdminBaseW_Restore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_EnumBackups_Proxy(IMSAdminBaseW *This,LPWSTR pszMDBackupLocation,DWORD *pdwMDVersion,PFILETIME pftMDBackupTime,DWORD dwMDEnumIndex);
  void __RPC_STUB IMSAdminBaseW_EnumBackups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_DeleteBackup_Proxy(IMSAdminBaseW *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion);
  void __RPC_STUB IMSAdminBaseW_DeleteBackup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_UnmarshalInterface_Proxy(IMSAdminBaseW *This,IMSAdminBaseW **piadmbwInterface);
  void __RPC_STUB IMSAdminBaseW_UnmarshalInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseW_R_GetServerGuid_Proxy(IMSAdminBaseW *This,GUID *pServerGuid);
  void __RPC_STUB IMSAdminBaseW_R_GetServerGuid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMSAdminBase2W_INTERFACE_DEFINED__
#define __IMSAdminBase2W_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSAdminBase2W;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSAdminBase2W : public IMSAdminBaseW {
  public:
    virtual HRESULT WINAPI BackupWithPasswd(LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd) = 0;
    virtual HRESULT WINAPI RestoreWithPasswd(LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd) = 0;
    virtual HRESULT WINAPI Export(LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,DWORD dwMDFlags) = 0;
    virtual HRESULT WINAPI Import(LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,LPCWSTR pszDestPath,DWORD dwMDFlags) = 0;
    virtual HRESULT WINAPI RestoreHistory(LPCWSTR pszMDHistoryLocation,DWORD dwMDMajorVersion,DWORD dwMDMinorVersion,DWORD dwMDFlags) = 0;
    virtual HRESULT WINAPI EnumHistory(LPWSTR pszMDHistoryLocation,DWORD *pdwMDMajorVersion,DWORD *pdwMDMinorVersion,PFILETIME pftMDHistoryTime,DWORD dwMDEnumIndex) = 0;
  };
#else
  typedef struct IMSAdminBase2WVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSAdminBase2W *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSAdminBase2W *This);
      ULONG (WINAPI *Release)(IMSAdminBase2W *This);
      HRESULT (WINAPI *AddKey)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *DeleteKey)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *DeleteChildKeys)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *EnumKeys)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPWSTR pszMDName,DWORD dwMDEnumObjectIndex);
      HRESULT (WINAPI *CopyKey)(IMSAdminBase2W *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,WINBOOL bMDOverwriteFlag,WINBOOL bMDCopyFlag);
      HRESULT (WINAPI *RenameKey)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPCWSTR pszMDNewName);
      HRESULT (WINAPI *SetData)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData);
      HRESULT (WINAPI *GetData)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen);
      HRESULT (WINAPI *DeleteData)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType);
      HRESULT (WINAPI *EnumData)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen);
      HRESULT (WINAPI *GetAllData)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,unsigned char *pbMDBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *DeleteAllData)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDUserType,DWORD dwMDDataType);
      HRESULT (WINAPI *CopyData)(IMSAdminBase2W *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,WINBOOL bMDCopyFlag);
      HRESULT (WINAPI *GetDataPaths)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *OpenKey)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAccessRequested,DWORD dwMDTimeOut,PMETADATA_HANDLE phMDNewHandle);
      HRESULT (WINAPI *CloseKey)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle);
      HRESULT (WINAPI *ChangePermissions)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,DWORD dwMDTimeOut,DWORD dwMDAccessRequested);
      HRESULT (WINAPI *SaveData)(IMSAdminBase2W *This);
      HRESULT (WINAPI *GetHandleInfo)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,PMETADATA_HANDLE_INFO pmdhiInfo);
      HRESULT (WINAPI *GetSystemChangeNumber)(IMSAdminBase2W *This,DWORD *pdwSystemChangeNumber);
      HRESULT (WINAPI *GetDataSetNumber)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD *pdwMDDataSetNumber);
      HRESULT (WINAPI *SetLastChangeTime)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
      HRESULT (WINAPI *GetLastChangeTime)(IMSAdminBase2W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
      HRESULT (WINAPI *KeyExchangePhase1)(IMSAdminBase2W *This);
      HRESULT (WINAPI *KeyExchangePhase2)(IMSAdminBase2W *This);
      HRESULT (WINAPI *Backup)(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *Restore)(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *EnumBackups)(IMSAdminBase2W *This,LPWSTR pszMDBackupLocation,DWORD *pdwMDVersion,PFILETIME pftMDBackupTime,DWORD dwMDEnumIndex);
      HRESULT (WINAPI *DeleteBackup)(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion);
      HRESULT (WINAPI *UnmarshalInterface)(IMSAdminBase2W *This,IMSAdminBaseW **piadmbwInterface);
      HRESULT (WINAPI *GetServerGuid)(IMSAdminBase2W *This);
      HRESULT (WINAPI *BackupWithPasswd)(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd);
      HRESULT (WINAPI *RestoreWithPasswd)(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd);
      HRESULT (WINAPI *Export)(IMSAdminBase2W *This,LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,DWORD dwMDFlags);
      HRESULT (WINAPI *Import)(IMSAdminBase2W *This,LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,LPCWSTR pszDestPath,DWORD dwMDFlags);
      HRESULT (WINAPI *RestoreHistory)(IMSAdminBase2W *This,LPCWSTR pszMDHistoryLocation,DWORD dwMDMajorVersion,DWORD dwMDMinorVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *EnumHistory)(IMSAdminBase2W *This,LPWSTR pszMDHistoryLocation,DWORD *pdwMDMajorVersion,DWORD *pdwMDMinorVersion,PFILETIME pftMDHistoryTime,DWORD dwMDEnumIndex);
    END_INTERFACE
  } IMSAdminBase2WVtbl;
  struct IMSAdminBase2W {
    CONST_VTBL struct IMSAdminBase2WVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSAdminBase2W_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSAdminBase2W_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSAdminBase2W_Release(This) (This)->lpVtbl->Release(This)
#define IMSAdminBase2W_AddKey(This,hMDHandle,pszMDPath) (This)->lpVtbl->AddKey(This,hMDHandle,pszMDPath)
#define IMSAdminBase2W_DeleteKey(This,hMDHandle,pszMDPath) (This)->lpVtbl->DeleteKey(This,hMDHandle,pszMDPath)
#define IMSAdminBase2W_DeleteChildKeys(This,hMDHandle,pszMDPath) (This)->lpVtbl->DeleteChildKeys(This,hMDHandle,pszMDPath)
#define IMSAdminBase2W_EnumKeys(This,hMDHandle,pszMDPath,pszMDName,dwMDEnumObjectIndex) (This)->lpVtbl->EnumKeys(This,hMDHandle,pszMDPath,pszMDName,dwMDEnumObjectIndex)
#define IMSAdminBase2W_CopyKey(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,bMDOverwriteFlag,bMDCopyFlag) (This)->lpVtbl->CopyKey(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,bMDOverwriteFlag,bMDCopyFlag)
#define IMSAdminBase2W_RenameKey(This,hMDHandle,pszMDPath,pszMDNewName) (This)->lpVtbl->RenameKey(This,hMDHandle,pszMDPath,pszMDNewName)
#define IMSAdminBase2W_SetData(This,hMDHandle,pszMDPath,pmdrMDData) (This)->lpVtbl->SetData(This,hMDHandle,pszMDPath,pmdrMDData)
#define IMSAdminBase2W_GetData(This,hMDHandle,pszMDPath,pmdrMDData,pdwMDRequiredDataLen) (This)->lpVtbl->GetData(This,hMDHandle,pszMDPath,pmdrMDData,pdwMDRequiredDataLen)
#define IMSAdminBase2W_DeleteData(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType) (This)->lpVtbl->DeleteData(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType)
#define IMSAdminBase2W_EnumData(This,hMDHandle,pszMDPath,pmdrMDData,dwMDEnumDataIndex,pdwMDRequiredDataLen) (This)->lpVtbl->EnumData(This,hMDHandle,pszMDPath,pmdrMDData,dwMDEnumDataIndex,pdwMDRequiredDataLen)
#define IMSAdminBase2W_GetAllData(This,hMDHandle,pszMDPath,dwMDAttributes,dwMDUserType,dwMDDataType,pdwMDNumDataEntries,pdwMDDataSetNumber,dwMDBufferSize,pbMDBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetAllData(This,hMDHandle,pszMDPath,dwMDAttributes,dwMDUserType,dwMDDataType,pdwMDNumDataEntries,pdwMDDataSetNumber,dwMDBufferSize,pbMDBuffer,pdwMDRequiredBufferSize)
#define IMSAdminBase2W_DeleteAllData(This,hMDHandle,pszMDPath,dwMDUserType,dwMDDataType) (This)->lpVtbl->DeleteAllData(This,hMDHandle,pszMDPath,dwMDUserType,dwMDDataType)
#define IMSAdminBase2W_CopyData(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,dwMDAttributes,dwMDUserType,dwMDDataType,bMDCopyFlag) (This)->lpVtbl->CopyData(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,dwMDAttributes,dwMDUserType,dwMDDataType,bMDCopyFlag)
#define IMSAdminBase2W_GetDataPaths(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetDataPaths(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize)
#define IMSAdminBase2W_OpenKey(This,hMDHandle,pszMDPath,dwMDAccessRequested,dwMDTimeOut,phMDNewHandle) (This)->lpVtbl->OpenKey(This,hMDHandle,pszMDPath,dwMDAccessRequested,dwMDTimeOut,phMDNewHandle)
#define IMSAdminBase2W_CloseKey(This,hMDHandle) (This)->lpVtbl->CloseKey(This,hMDHandle)
#define IMSAdminBase2W_ChangePermissions(This,hMDHandle,dwMDTimeOut,dwMDAccessRequested) (This)->lpVtbl->ChangePermissions(This,hMDHandle,dwMDTimeOut,dwMDAccessRequested)
#define IMSAdminBase2W_SaveData(This) (This)->lpVtbl->SaveData(This)
#define IMSAdminBase2W_GetHandleInfo(This,hMDHandle,pmdhiInfo) (This)->lpVtbl->GetHandleInfo(This,hMDHandle,pmdhiInfo)
#define IMSAdminBase2W_GetSystemChangeNumber(This,pdwSystemChangeNumber) (This)->lpVtbl->GetSystemChangeNumber(This,pdwSystemChangeNumber)
#define IMSAdminBase2W_GetDataSetNumber(This,hMDHandle,pszMDPath,pdwMDDataSetNumber) (This)->lpVtbl->GetDataSetNumber(This,hMDHandle,pszMDPath,pdwMDDataSetNumber)
#define IMSAdminBase2W_SetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime) (This)->lpVtbl->SetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime)
#define IMSAdminBase2W_GetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime) (This)->lpVtbl->GetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime)
#define IMSAdminBase2W_KeyExchangePhase1(This) (This)->lpVtbl->KeyExchangePhase1(This)
#define IMSAdminBase2W_KeyExchangePhase2(This) (This)->lpVtbl->KeyExchangePhase2(This)
#define IMSAdminBase2W_Backup(This,pszMDBackupLocation,dwMDVersion,dwMDFlags) (This)->lpVtbl->Backup(This,pszMDBackupLocation,dwMDVersion,dwMDFlags)
#define IMSAdminBase2W_Restore(This,pszMDBackupLocation,dwMDVersion,dwMDFlags) (This)->lpVtbl->Restore(This,pszMDBackupLocation,dwMDVersion,dwMDFlags)
#define IMSAdminBase2W_EnumBackups(This,pszMDBackupLocation,pdwMDVersion,pftMDBackupTime,dwMDEnumIndex) (This)->lpVtbl->EnumBackups(This,pszMDBackupLocation,pdwMDVersion,pftMDBackupTime,dwMDEnumIndex)
#define IMSAdminBase2W_DeleteBackup(This,pszMDBackupLocation,dwMDVersion) (This)->lpVtbl->DeleteBackup(This,pszMDBackupLocation,dwMDVersion)
#define IMSAdminBase2W_UnmarshalInterface(This,piadmbwInterface) (This)->lpVtbl->UnmarshalInterface(This,piadmbwInterface)
#define IMSAdminBase2W_GetServerGuid(This) (This)->lpVtbl->GetServerGuid(This)
#define IMSAdminBase2W_BackupWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd) (This)->lpVtbl->BackupWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd)
#define IMSAdminBase2W_RestoreWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd) (This)->lpVtbl->RestoreWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd)
#define IMSAdminBase2W_Export(This,pszPasswd,pszFileName,pszSourcePath,dwMDFlags) (This)->lpVtbl->Export(This,pszPasswd,pszFileName,pszSourcePath,dwMDFlags)
#define IMSAdminBase2W_Import(This,pszPasswd,pszFileName,pszSourcePath,pszDestPath,dwMDFlags) (This)->lpVtbl->Import(This,pszPasswd,pszFileName,pszSourcePath,pszDestPath,dwMDFlags)
#define IMSAdminBase2W_RestoreHistory(This,pszMDHistoryLocation,dwMDMajorVersion,dwMDMinorVersion,dwMDFlags) (This)->lpVtbl->RestoreHistory(This,pszMDHistoryLocation,dwMDMajorVersion,dwMDMinorVersion,dwMDFlags)
#define IMSAdminBase2W_EnumHistory(This,pszMDHistoryLocation,pdwMDMajorVersion,pdwMDMinorVersion,pftMDHistoryTime,dwMDEnumIndex) (This)->lpVtbl->EnumHistory(This,pszMDHistoryLocation,pdwMDMajorVersion,pdwMDMinorVersion,pftMDHistoryTime,dwMDEnumIndex)
#endif
#endif
  HRESULT WINAPI IMSAdminBase2W_BackupWithPasswd_Proxy(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd);
  void __RPC_STUB IMSAdminBase2W_BackupWithPasswd_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBase2W_RestoreWithPasswd_Proxy(IMSAdminBase2W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd);
  void __RPC_STUB IMSAdminBase2W_RestoreWithPasswd_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBase2W_Export_Proxy(IMSAdminBase2W *This,LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,DWORD dwMDFlags);
  void __RPC_STUB IMSAdminBase2W_Export_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBase2W_Import_Proxy(IMSAdminBase2W *This,LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,LPCWSTR pszDestPath,DWORD dwMDFlags);
  void __RPC_STUB IMSAdminBase2W_Import_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBase2W_RestoreHistory_Proxy(IMSAdminBase2W *This,LPCWSTR pszMDHistoryLocation,DWORD dwMDMajorVersion,DWORD dwMDMinorVersion,DWORD dwMDFlags);
  void __RPC_STUB IMSAdminBase2W_RestoreHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBase2W_EnumHistory_Proxy(IMSAdminBase2W *This,LPWSTR pszMDHistoryLocation,DWORD *pdwMDMajorVersion,DWORD *pdwMDMinorVersion,PFILETIME pftMDHistoryTime,DWORD dwMDEnumIndex);
  void __RPC_STUB IMSAdminBase2W_EnumHistory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMSAdminBase3W_INTERFACE_DEFINED__
#define __IMSAdminBase3W_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSAdminBase3W;
#if defined(__cplusplus) && !defined(CINTERFACE)

  struct IMSAdminBase3W : public IMSAdminBase2W {
  public:
    virtual HRESULT WINAPI GetChildPaths(METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD cchMDBufferSize,WCHAR *pszBuffer,DWORD *pcchMDRequiredBufferSize) = 0;
  };
#else
  typedef struct IMSAdminBase3WVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSAdminBase3W *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSAdminBase3W *This);
      ULONG (WINAPI *Release)(IMSAdminBase3W *This);
      HRESULT (WINAPI *AddKey)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *DeleteKey)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *DeleteChildKeys)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath);
      HRESULT (WINAPI *EnumKeys)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPWSTR pszMDName,DWORD dwMDEnumObjectIndex);
      HRESULT (WINAPI *CopyKey)(IMSAdminBase3W *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,WINBOOL bMDOverwriteFlag,WINBOOL bMDCopyFlag);
      HRESULT (WINAPI *RenameKey)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,LPCWSTR pszMDNewName);
      HRESULT (WINAPI *SetData)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData);
      HRESULT (WINAPI *GetData)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen);
      HRESULT (WINAPI *DeleteData)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType);
      HRESULT (WINAPI *EnumData)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen);
      HRESULT (WINAPI *GetAllData)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,unsigned char *pbMDBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *DeleteAllData)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDUserType,DWORD dwMDDataType);
      HRESULT (WINAPI *CopyData)(IMSAdminBase3W *This,METADATA_HANDLE hMDSourceHandle,LPCWSTR pszMDSourcePath,METADATA_HANDLE hMDDestHandle,LPCWSTR pszMDDestPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,WINBOOL bMDCopyFlag);
      HRESULT (WINAPI *GetDataPaths)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDIdentifier,DWORD dwMDDataType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize);
      HRESULT (WINAPI *OpenKey)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAccessRequested,DWORD dwMDTimeOut,PMETADATA_HANDLE phMDNewHandle);
      HRESULT (WINAPI *CloseKey)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle);
      HRESULT (WINAPI *ChangePermissions)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,DWORD dwMDTimeOut,DWORD dwMDAccessRequested);
      HRESULT (WINAPI *SaveData)(IMSAdminBase3W *This);
      HRESULT (WINAPI *GetHandleInfo)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,PMETADATA_HANDLE_INFO pmdhiInfo);
      HRESULT (WINAPI *GetSystemChangeNumber)(IMSAdminBase3W *This,DWORD *pdwSystemChangeNumber);
      HRESULT (WINAPI *GetDataSetNumber)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD *pdwMDDataSetNumber);
      HRESULT (WINAPI *SetLastChangeTime)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
      HRESULT (WINAPI *GetLastChangeTime)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PFILETIME pftMDLastChangeTime,WINBOOL bLocalTime);
      HRESULT (WINAPI *KeyExchangePhase1)(IMSAdminBase3W *This);
      HRESULT (WINAPI *KeyExchangePhase2)(IMSAdminBase3W *This);
      HRESULT (WINAPI *Backup)(IMSAdminBase3W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *Restore)(IMSAdminBase3W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *EnumBackups)(IMSAdminBase3W *This,LPWSTR pszMDBackupLocation,DWORD *pdwMDVersion,PFILETIME pftMDBackupTime,DWORD dwMDEnumIndex);
      HRESULT (WINAPI *DeleteBackup)(IMSAdminBase3W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion);
      HRESULT (WINAPI *UnmarshalInterface)(IMSAdminBase3W *This,IMSAdminBaseW **piadmbwInterface);
      HRESULT (WINAPI *GetServerGuid)(IMSAdminBase3W *This);
      HRESULT (WINAPI *BackupWithPasswd)(IMSAdminBase3W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd);
      HRESULT (WINAPI *RestoreWithPasswd)(IMSAdminBase3W *This,LPCWSTR pszMDBackupLocation,DWORD dwMDVersion,DWORD dwMDFlags,LPCWSTR pszPasswd);
      HRESULT (WINAPI *Export)(IMSAdminBase3W *This,LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,DWORD dwMDFlags);
      HRESULT (WINAPI *Import)(IMSAdminBase3W *This,LPCWSTR pszPasswd,LPCWSTR pszFileName,LPCWSTR pszSourcePath,LPCWSTR pszDestPath,DWORD dwMDFlags);
      HRESULT (WINAPI *RestoreHistory)(IMSAdminBase3W *This,LPCWSTR pszMDHistoryLocation,DWORD dwMDMajorVersion,DWORD dwMDMinorVersion,DWORD dwMDFlags);
      HRESULT (WINAPI *EnumHistory)(IMSAdminBase3W *This,LPWSTR pszMDHistoryLocation,DWORD *pdwMDMajorVersion,DWORD *pdwMDMinorVersion,PFILETIME pftMDHistoryTime,DWORD dwMDEnumIndex);
      HRESULT (WINAPI *GetChildPaths)(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD cchMDBufferSize,WCHAR *pszBuffer,DWORD *pcchMDRequiredBufferSize);
    END_INTERFACE
  } IMSAdminBase3WVtbl;
  struct IMSAdminBase3W {
    CONST_VTBL struct IMSAdminBase3WVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSAdminBase3W_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSAdminBase3W_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSAdminBase3W_Release(This) (This)->lpVtbl->Release(This)
#define IMSAdminBase3W_AddKey(This,hMDHandle,pszMDPath) (This)->lpVtbl->AddKey(This,hMDHandle,pszMDPath)
#define IMSAdminBase3W_DeleteKey(This,hMDHandle,pszMDPath) (This)->lpVtbl->DeleteKey(This,hMDHandle,pszMDPath)
#define IMSAdminBase3W_DeleteChildKeys(This,hMDHandle,pszMDPath) (This)->lpVtbl->DeleteChildKeys(This,hMDHandle,pszMDPath)
#define IMSAdminBase3W_EnumKeys(This,hMDHandle,pszMDPath,pszMDName,dwMDEnumObjectIndex) (This)->lpVtbl->EnumKeys(This,hMDHandle,pszMDPath,pszMDName,dwMDEnumObjectIndex)
#define IMSAdminBase3W_CopyKey(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,bMDOverwriteFlag,bMDCopyFlag) (This)->lpVtbl->CopyKey(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,bMDOverwriteFlag,bMDCopyFlag)
#define IMSAdminBase3W_RenameKey(This,hMDHandle,pszMDPath,pszMDNewName) (This)->lpVtbl->RenameKey(This,hMDHandle,pszMDPath,pszMDNewName)
#define IMSAdminBase3W_SetData(This,hMDHandle,pszMDPath,pmdrMDData) (This)->lpVtbl->SetData(This,hMDHandle,pszMDPath,pmdrMDData)
#define IMSAdminBase3W_GetData(This,hMDHandle,pszMDPath,pmdrMDData,pdwMDRequiredDataLen) (This)->lpVtbl->GetData(This,hMDHandle,pszMDPath,pmdrMDData,pdwMDRequiredDataLen)
#define IMSAdminBase3W_DeleteData(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType) (This)->lpVtbl->DeleteData(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType)
#define IMSAdminBase3W_EnumData(This,hMDHandle,pszMDPath,pmdrMDData,dwMDEnumDataIndex,pdwMDRequiredDataLen) (This)->lpVtbl->EnumData(This,hMDHandle,pszMDPath,pmdrMDData,dwMDEnumDataIndex,pdwMDRequiredDataLen)
#define IMSAdminBase3W_GetAllData(This,hMDHandle,pszMDPath,dwMDAttributes,dwMDUserType,dwMDDataType,pdwMDNumDataEntries,pdwMDDataSetNumber,dwMDBufferSize,pbMDBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetAllData(This,hMDHandle,pszMDPath,dwMDAttributes,dwMDUserType,dwMDDataType,pdwMDNumDataEntries,pdwMDDataSetNumber,dwMDBufferSize,pbMDBuffer,pdwMDRequiredBufferSize)
#define IMSAdminBase3W_DeleteAllData(This,hMDHandle,pszMDPath,dwMDUserType,dwMDDataType) (This)->lpVtbl->DeleteAllData(This,hMDHandle,pszMDPath,dwMDUserType,dwMDDataType)
#define IMSAdminBase3W_CopyData(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,dwMDAttributes,dwMDUserType,dwMDDataType,bMDCopyFlag) (This)->lpVtbl->CopyData(This,hMDSourceHandle,pszMDSourcePath,hMDDestHandle,pszMDDestPath,dwMDAttributes,dwMDUserType,dwMDDataType,bMDCopyFlag)
#define IMSAdminBase3W_GetDataPaths(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->GetDataPaths(This,hMDHandle,pszMDPath,dwMDIdentifier,dwMDDataType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize)
#define IMSAdminBase3W_OpenKey(This,hMDHandle,pszMDPath,dwMDAccessRequested,dwMDTimeOut,phMDNewHandle) (This)->lpVtbl->OpenKey(This,hMDHandle,pszMDPath,dwMDAccessRequested,dwMDTimeOut,phMDNewHandle)
#define IMSAdminBase3W_CloseKey(This,hMDHandle) (This)->lpVtbl->CloseKey(This,hMDHandle)
#define IMSAdminBase3W_ChangePermissions(This,hMDHandle,dwMDTimeOut,dwMDAccessRequested) (This)->lpVtbl->ChangePermissions(This,hMDHandle,dwMDTimeOut,dwMDAccessRequested)
#define IMSAdminBase3W_SaveData(This) (This)->lpVtbl->SaveData(This)
#define IMSAdminBase3W_GetHandleInfo(This,hMDHandle,pmdhiInfo) (This)->lpVtbl->GetHandleInfo(This,hMDHandle,pmdhiInfo)
#define IMSAdminBase3W_GetSystemChangeNumber(This,pdwSystemChangeNumber) (This)->lpVtbl->GetSystemChangeNumber(This,pdwSystemChangeNumber)
#define IMSAdminBase3W_GetDataSetNumber(This,hMDHandle,pszMDPath,pdwMDDataSetNumber) (This)->lpVtbl->GetDataSetNumber(This,hMDHandle,pszMDPath,pdwMDDataSetNumber)
#define IMSAdminBase3W_SetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime) (This)->lpVtbl->SetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime)
#define IMSAdminBase3W_GetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime) (This)->lpVtbl->GetLastChangeTime(This,hMDHandle,pszMDPath,pftMDLastChangeTime,bLocalTime)
#define IMSAdminBase3W_KeyExchangePhase1(This) (This)->lpVtbl->KeyExchangePhase1(This)
#define IMSAdminBase3W_KeyExchangePhase2(This) (This)->lpVtbl->KeyExchangePhase2(This)
#define IMSAdminBase3W_Backup(This,pszMDBackupLocation,dwMDVersion,dwMDFlags) (This)->lpVtbl->Backup(This,pszMDBackupLocation,dwMDVersion,dwMDFlags)
#define IMSAdminBase3W_Restore(This,pszMDBackupLocation,dwMDVersion,dwMDFlags) (This)->lpVtbl->Restore(This,pszMDBackupLocation,dwMDVersion,dwMDFlags)
#define IMSAdminBase3W_EnumBackups(This,pszMDBackupLocation,pdwMDVersion,pftMDBackupTime,dwMDEnumIndex) (This)->lpVtbl->EnumBackups(This,pszMDBackupLocation,pdwMDVersion,pftMDBackupTime,dwMDEnumIndex)
#define IMSAdminBase3W_DeleteBackup(This,pszMDBackupLocation,dwMDVersion) (This)->lpVtbl->DeleteBackup(This,pszMDBackupLocation,dwMDVersion)
#define IMSAdminBase3W_UnmarshalInterface(This,piadmbwInterface) (This)->lpVtbl->UnmarshalInterface(This,piadmbwInterface)
#define IMSAdminBase3W_GetServerGuid(This) (This)->lpVtbl->GetServerGuid(This)
#define IMSAdminBase3W_BackupWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd) (This)->lpVtbl->BackupWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd)
#define IMSAdminBase3W_RestoreWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd) (This)->lpVtbl->RestoreWithPasswd(This,pszMDBackupLocation,dwMDVersion,dwMDFlags,pszPasswd)
#define IMSAdminBase3W_Export(This,pszPasswd,pszFileName,pszSourcePath,dwMDFlags) (This)->lpVtbl->Export(This,pszPasswd,pszFileName,pszSourcePath,dwMDFlags)
#define IMSAdminBase3W_Import(This,pszPasswd,pszFileName,pszSourcePath,pszDestPath,dwMDFlags) (This)->lpVtbl->Import(This,pszPasswd,pszFileName,pszSourcePath,pszDestPath,dwMDFlags)
#define IMSAdminBase3W_RestoreHistory(This,pszMDHistoryLocation,dwMDMajorVersion,dwMDMinorVersion,dwMDFlags) (This)->lpVtbl->RestoreHistory(This,pszMDHistoryLocation,dwMDMajorVersion,dwMDMinorVersion,dwMDFlags)
#define IMSAdminBase3W_EnumHistory(This,pszMDHistoryLocation,pdwMDMajorVersion,pdwMDMinorVersion,pftMDHistoryTime,dwMDEnumIndex) (This)->lpVtbl->EnumHistory(This,pszMDHistoryLocation,pdwMDMajorVersion,pdwMDMinorVersion,pftMDHistoryTime,dwMDEnumIndex)
#define IMSAdminBase3W_GetChildPaths(This,hMDHandle,pszMDPath,cchMDBufferSize,pszBuffer,pcchMDRequiredBufferSize) (This)->lpVtbl->GetChildPaths(This,hMDHandle,pszMDPath,cchMDBufferSize,pszBuffer,pcchMDRequiredBufferSize)
#endif
#endif
  HRESULT WINAPI IMSAdminBase3W_GetChildPaths_Proxy(IMSAdminBase3W *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD cchMDBufferSize,WCHAR *pszBuffer,DWORD *pcchMDRequiredBufferSize);
  void __RPC_STUB IMSAdminBase3W_GetChildPaths_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMSImpExpHelpW_INTERFACE_DEFINED__
#define __IMSImpExpHelpW_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSImpExpHelpW;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSImpExpHelpW : public IUnknown {
  public:
    virtual HRESULT WINAPI EnumeratePathsInFile(LPCWSTR pszFileName,LPCWSTR pszKeyType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize) = 0;
  };
#else
  typedef struct IMSImpExpHelpWVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSImpExpHelpW *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSImpExpHelpW *This);
      ULONG (WINAPI *Release)(IMSImpExpHelpW *This);
      HRESULT (WINAPI *EnumeratePathsInFile)(IMSImpExpHelpW *This,LPCWSTR pszFileName,LPCWSTR pszKeyType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize);
    END_INTERFACE
  } IMSImpExpHelpWVtbl;
  struct IMSImpExpHelpW {
    CONST_VTBL struct IMSImpExpHelpWVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSImpExpHelpW_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSImpExpHelpW_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSImpExpHelpW_Release(This) (This)->lpVtbl->Release(This)
#define IMSImpExpHelpW_EnumeratePathsInFile(This,pszFileName,pszKeyType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize) (This)->lpVtbl->EnumeratePathsInFile(This,pszFileName,pszKeyType,dwMDBufferSize,pszBuffer,pdwMDRequiredBufferSize)
#endif
#endif
  HRESULT WINAPI IMSImpExpHelpW_EnumeratePathsInFile_Proxy(IMSImpExpHelpW *This,LPCWSTR pszFileName,LPCWSTR pszKeyType,DWORD dwMDBufferSize,WCHAR *pszBuffer,DWORD *pdwMDRequiredBufferSize);
  void __RPC_STUB IMSImpExpHelpW_EnumeratePathsInFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMSAdminBaseSinkW_INTERFACE_DEFINED__
#define __IMSAdminBaseSinkW_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMSAdminBaseSinkW;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMSAdminBaseSinkW : public IUnknown {
  public:
    virtual HRESULT WINAPI SinkNotify(DWORD dwMDNumElements,MD_CHANGE_OBJECT_W pcoChangeList[]) = 0;
    virtual HRESULT WINAPI ShutdownNotify(void) = 0;
  };
#else
  typedef struct IMSAdminBaseSinkWVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMSAdminBaseSinkW *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMSAdminBaseSinkW *This);
      ULONG (WINAPI *Release)(IMSAdminBaseSinkW *This);
      HRESULT (WINAPI *SinkNotify)(IMSAdminBaseSinkW *This,DWORD dwMDNumElements,MD_CHANGE_OBJECT_W pcoChangeList[]);
      HRESULT (WINAPI *ShutdownNotify)(IMSAdminBaseSinkW *This);
    END_INTERFACE
  } IMSAdminBaseSinkWVtbl;
  struct IMSAdminBaseSinkW {
    CONST_VTBL struct IMSAdminBaseSinkWVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMSAdminBaseSinkW_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMSAdminBaseSinkW_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMSAdminBaseSinkW_Release(This) (This)->lpVtbl->Release(This)
#define IMSAdminBaseSinkW_SinkNotify(This,dwMDNumElements,pcoChangeList) (This)->lpVtbl->SinkNotify(This,dwMDNumElements,pcoChangeList)
#define IMSAdminBaseSinkW_ShutdownNotify(This) (This)->lpVtbl->ShutdownNotify(This)
#endif
#endif
  HRESULT WINAPI IMSAdminBaseSinkW_SinkNotify_Proxy(IMSAdminBaseSinkW *This,DWORD dwMDNumElements,MD_CHANGE_OBJECT_W pcoChangeList[]);
  void __RPC_STUB IMSAdminBaseSinkW_SinkNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMSAdminBaseSinkW_ShutdownNotify_Proxy(IMSAdminBaseSinkW *This);
  void __RPC_STUB IMSAdminBaseSinkW_ShutdownNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIMSAdminBaseSinkW_INTERFACE_DEFINED__
#define __AsyncIMSAdminBaseSinkW_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIMSAdminBaseSinkW;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIMSAdminBaseSinkW : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_SinkNotify(DWORD dwMDNumElements,MD_CHANGE_OBJECT_W pcoChangeList[]) = 0;
    virtual HRESULT WINAPI Finish_SinkNotify(void) = 0;
    virtual HRESULT WINAPI Begin_ShutdownNotify(void) = 0;
    virtual HRESULT WINAPI Finish_ShutdownNotify(void) = 0;
  };
#else
  typedef struct AsyncIMSAdminBaseSinkWVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIMSAdminBaseSinkW *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIMSAdminBaseSinkW *This);
      ULONG (WINAPI *Release)(AsyncIMSAdminBaseSinkW *This);
      HRESULT (WINAPI *Begin_SinkNotify)(AsyncIMSAdminBaseSinkW *This,DWORD dwMDNumElements,MD_CHANGE_OBJECT_W pcoChangeList[]);
      HRESULT (WINAPI *Finish_SinkNotify)(AsyncIMSAdminBaseSinkW *This);
      HRESULT (WINAPI *Begin_ShutdownNotify)(AsyncIMSAdminBaseSinkW *This);
      HRESULT (WINAPI *Finish_ShutdownNotify)(AsyncIMSAdminBaseSinkW *This);
    END_INTERFACE
  } AsyncIMSAdminBaseSinkWVtbl;
  struct AsyncIMSAdminBaseSinkW {
    CONST_VTBL struct AsyncIMSAdminBaseSinkWVtbl *lpVtbl;
  };
#ifdef COBJMACROS
  define AsyncIMSAdminBaseSinkW_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIMSAdminBaseSinkW_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIMSAdminBaseSinkW_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIMSAdminBaseSinkW_Begin_SinkNotify(This,dwMDNumElements,pcoChangeList) (This)->lpVtbl->Begin_SinkNotify(This,dwMDNumElements,pcoChangeList)
#define AsyncIMSAdminBaseSinkW_Finish_SinkNotify(This) (This)->lpVtbl->Finish_SinkNotify(This)
#define AsyncIMSAdminBaseSinkW_Begin_ShutdownNotify(This) (This)->lpVtbl->Begin_ShutdownNotify(This)
#define AsyncIMSAdminBaseSinkW_Finish_ShutdownNotify(This) (This)->lpVtbl->Finish_ShutdownNotify(This)
#endif
#endif
    HRESULT WINAPI AsyncIMSAdminBaseSinkW_Begin_SinkNotify_Proxy(AsyncIMSAdminBaseSinkW *This,DWORD dwMDNumElements,MD_CHANGE_OBJECT_W pcoChangeList[]);
  void __RPC_STUB AsyncIMSAdminBaseSinkW_Begin_SinkNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIMSAdminBaseSinkW_Finish_SinkNotify_Proxy(AsyncIMSAdminBaseSinkW *This);
  void __RPC_STUB AsyncIMSAdminBaseSinkW_Finish_SinkNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIMSAdminBaseSinkW_Begin_ShutdownNotify_Proxy(AsyncIMSAdminBaseSinkW *This);
  void __RPC_STUB AsyncIMSAdminBaseSinkW_Begin_ShutdownNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIMSAdminBaseSinkW_Finish_ShutdownNotify_Proxy(AsyncIMSAdminBaseSinkW *This);
  void __RPC_STUB AsyncIMSAdminBaseSinkW_Finish_ShutdownNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_iadmw_0272_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iadmw_0272_v0_0_s_ifspec;

  HRESULT WINAPI IMSAdminBaseW_SetData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData);
  HRESULT WINAPI IMSAdminBaseW_SetData_Stub(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData);
  HRESULT WINAPI IMSAdminBaseW_GetData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen);
  HRESULT WINAPI IMSAdminBaseW_GetData_Stub(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD *pdwMDRequiredDataLen,struct _IIS_CRYPTO_BLOB **ppDataBlob);
  HRESULT WINAPI IMSAdminBaseW_EnumData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen);
  HRESULT WINAPI IMSAdminBaseW_EnumData_Stub(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,PMETADATA_RECORD pmdrMDData,DWORD dwMDEnumDataIndex,DWORD *pdwMDRequiredDataLen,struct _IIS_CRYPTO_BLOB **ppDataBlob);
  HRESULT WINAPI IMSAdminBaseW_GetAllData_Proxy(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,unsigned char *pbMDBuffer,DWORD *pdwMDRequiredBufferSize);
  HRESULT WINAPI IMSAdminBaseW_GetAllData_Stub(IMSAdminBaseW *This,METADATA_HANDLE hMDHandle,LPCWSTR pszMDPath,DWORD dwMDAttributes,DWORD dwMDUserType,DWORD dwMDDataType,DWORD *pdwMDNumDataEntries,DWORD *pdwMDDataSetNumber,DWORD dwMDBufferSize,DWORD *pdwMDRequiredBufferSize,struct _IIS_CRYPTO_BLOB **ppDataBlob);
  HRESULT WINAPI IMSAdminBaseW_KeyExchangePhase1_Proxy(IMSAdminBaseW *This);
  HRESULT WINAPI IMSAdminBaseW_KeyExchangePhase1_Stub(IMSAdminBaseW *This,struct _IIS_CRYPTO_BLOB *pClientKeyExchangeKeyBlob,struct _IIS_CRYPTO_BLOB *pClientSignatureKeyBlob,struct _IIS_CRYPTO_BLOB **ppServerKeyExchangeKeyBlob,struct _IIS_CRYPTO_BLOB **ppServerSignatureKeyBlob,struct _IIS_CRYPTO_BLOB **ppServerSessionKeyBlob);
  HRESULT WINAPI IMSAdminBaseW_KeyExchangePhase2_Proxy(IMSAdminBaseW *This);
  HRESULT WINAPI IMSAdminBaseW_KeyExchangePhase2_Stub(IMSAdminBaseW *This,struct _IIS_CRYPTO_BLOB *pClientSessionKeyBlob,struct _IIS_CRYPTO_BLOB *pClientHashBlob,struct _IIS_CRYPTO_BLOB **ppServerHashBlob);
  HRESULT WINAPI IMSAdminBaseW_GetServerGuid_Proxy(IMSAdminBaseW *This);
  HRESULT WINAPI IMSAdminBaseW_GetServerGuid_Stub(IMSAdminBaseW *This,GUID *pServerGuid);

#ifdef __cplusplus
}
#endif
#endif
