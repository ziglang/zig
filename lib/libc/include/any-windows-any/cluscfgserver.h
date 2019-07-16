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
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __cluscfgserver_h__
#define __cluscfgserver_h__

#ifndef __IClusCfgNodeInfo_FWD_DEFINED__
#define __IClusCfgNodeInfo_FWD_DEFINED__
typedef struct IClusCfgNodeInfo IClusCfgNodeInfo;
#endif

#ifndef __AsyncIClusCfgNodeInfo_FWD_DEFINED__
#define __AsyncIClusCfgNodeInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgNodeInfo AsyncIClusCfgNodeInfo;
#endif

#ifndef __IEnumClusCfgManagedResources_FWD_DEFINED__
#define __IEnumClusCfgManagedResources_FWD_DEFINED__
typedef struct IEnumClusCfgManagedResources IEnumClusCfgManagedResources;
#endif

#ifndef __AsyncIEnumClusCfgManagedResources_FWD_DEFINED__
#define __AsyncIEnumClusCfgManagedResources_FWD_DEFINED__
typedef struct AsyncIEnumClusCfgManagedResources AsyncIEnumClusCfgManagedResources;
#endif

#ifndef __IEnumClusCfgNetworks_FWD_DEFINED__
#define __IEnumClusCfgNetworks_FWD_DEFINED__
typedef struct IEnumClusCfgNetworks IEnumClusCfgNetworks;
#endif

#ifndef __AsyncIEnumClusCfgNetworks_FWD_DEFINED__
#define __AsyncIEnumClusCfgNetworks_FWD_DEFINED__
typedef struct AsyncIEnumClusCfgNetworks AsyncIEnumClusCfgNetworks;
#endif

#ifndef __IClusCfgManagedResourceInfo_FWD_DEFINED__
#define __IClusCfgManagedResourceInfo_FWD_DEFINED__
typedef struct IClusCfgManagedResourceInfo IClusCfgManagedResourceInfo;
#endif

#ifndef __AsyncIClusCfgManagedResourceInfo_FWD_DEFINED__
#define __AsyncIClusCfgManagedResourceInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgManagedResourceInfo AsyncIClusCfgManagedResourceInfo;
#endif

#ifndef __IEnumClusCfgPartitions_FWD_DEFINED__
#define __IEnumClusCfgPartitions_FWD_DEFINED__
typedef struct IEnumClusCfgPartitions IEnumClusCfgPartitions;
#endif

#ifndef __AsyncIEnumClusCfgPartitions_FWD_DEFINED__
#define __AsyncIEnumClusCfgPartitions_FWD_DEFINED__
typedef struct AsyncIEnumClusCfgPartitions AsyncIEnumClusCfgPartitions;
#endif

#ifndef __IClusCfgPartitionInfo_FWD_DEFINED__
#define __IClusCfgPartitionInfo_FWD_DEFINED__
typedef struct IClusCfgPartitionInfo IClusCfgPartitionInfo;
#endif

#ifndef __AsyncIClusCfgPartitionInfo_FWD_DEFINED__
#define __AsyncIClusCfgPartitionInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgPartitionInfo AsyncIClusCfgPartitionInfo;
#endif

#ifndef __IEnumClusCfgIPAddresses_FWD_DEFINED__
#define __IEnumClusCfgIPAddresses_FWD_DEFINED__
typedef struct IEnumClusCfgIPAddresses IEnumClusCfgIPAddresses;
#endif

#ifndef __AsyncIEnumClusCfgIPAddresses_FWD_DEFINED__
#define __AsyncIEnumClusCfgIPAddresses_FWD_DEFINED__
typedef struct AsyncIEnumClusCfgIPAddresses AsyncIEnumClusCfgIPAddresses;
#endif

#ifndef __IClusCfgIPAddressInfo_FWD_DEFINED__
#define __IClusCfgIPAddressInfo_FWD_DEFINED__
typedef struct IClusCfgIPAddressInfo IClusCfgIPAddressInfo;
#endif

#ifndef __AsyncIClusCfgIPAddressInfo_FWD_DEFINED__
#define __AsyncIClusCfgIPAddressInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgIPAddressInfo AsyncIClusCfgIPAddressInfo;
#endif

#ifndef __IClusCfgNetworkInfo_FWD_DEFINED__
#define __IClusCfgNetworkInfo_FWD_DEFINED__
typedef struct IClusCfgNetworkInfo IClusCfgNetworkInfo;
#endif

#ifndef __AsyncIClusCfgNetworkInfo_FWD_DEFINED__
#define __AsyncIClusCfgNetworkInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgNetworkInfo AsyncIClusCfgNetworkInfo;
#endif

#ifndef __IClusCfgClusterInfo_FWD_DEFINED__
#define __IClusCfgClusterInfo_FWD_DEFINED__
typedef struct IClusCfgClusterInfo IClusCfgClusterInfo;
#endif

#ifndef __AsyncIClusCfgClusterInfo_FWD_DEFINED__
#define __AsyncIClusCfgClusterInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgClusterInfo AsyncIClusCfgClusterInfo;
#endif

#ifndef __IClusCfgInitialize_FWD_DEFINED__
#define __IClusCfgInitialize_FWD_DEFINED__
typedef struct IClusCfgInitialize IClusCfgInitialize;
#endif

#ifndef __AsyncIClusCfgInitialize_FWD_DEFINED__
#define __AsyncIClusCfgInitialize_FWD_DEFINED__
typedef struct AsyncIClusCfgInitialize AsyncIClusCfgInitialize;
#endif

#ifndef __IClusCfgCallback_FWD_DEFINED__
#define __IClusCfgCallback_FWD_DEFINED__
typedef struct IClusCfgCallback IClusCfgCallback;
#endif

#ifndef __AsyncIClusCfgCallback_FWD_DEFINED__
#define __AsyncIClusCfgCallback_FWD_DEFINED__
typedef struct AsyncIClusCfgCallback AsyncIClusCfgCallback;
#endif

#ifndef __IClusCfgCredentials_FWD_DEFINED__
#define __IClusCfgCredentials_FWD_DEFINED__
typedef struct IClusCfgCredentials IClusCfgCredentials;
#endif

#ifndef __AsyncIClusCfgCredentials_FWD_DEFINED__
#define __AsyncIClusCfgCredentials_FWD_DEFINED__
typedef struct AsyncIClusCfgCredentials AsyncIClusCfgCredentials;
#endif

#ifndef __IClusCfgCapabilities_FWD_DEFINED__
#define __IClusCfgCapabilities_FWD_DEFINED__
typedef struct IClusCfgCapabilities IClusCfgCapabilities;
#endif

#ifndef __IClusCfgManagedResourceCfg_FWD_DEFINED__
#define __IClusCfgManagedResourceCfg_FWD_DEFINED__
typedef struct IClusCfgManagedResourceCfg IClusCfgManagedResourceCfg;
#endif

#ifndef __IClusCfgResourcePreCreate_FWD_DEFINED__
#define __IClusCfgResourcePreCreate_FWD_DEFINED__
typedef struct IClusCfgResourcePreCreate IClusCfgResourcePreCreate;
#endif

#ifndef __IClusCfgResourceCreate_FWD_DEFINED__
#define __IClusCfgResourceCreate_FWD_DEFINED__
typedef struct IClusCfgResourceCreate IClusCfgResourceCreate;
#endif

#ifndef __IClusCfgResourcePostCreate_FWD_DEFINED__
#define __IClusCfgResourcePostCreate_FWD_DEFINED__
typedef struct IClusCfgResourcePostCreate IClusCfgResourcePostCreate;
#endif

#ifndef __IClusCfgGroupCfg_FWD_DEFINED__
#define __IClusCfgGroupCfg_FWD_DEFINED__
typedef struct IClusCfgGroupCfg IClusCfgGroupCfg;
#endif

#ifndef __IClusCfgMemberSetChangeListener_FWD_DEFINED__
#define __IClusCfgMemberSetChangeListener_FWD_DEFINED__
typedef struct IClusCfgMemberSetChangeListener IClusCfgMemberSetChangeListener;
#endif

#ifndef __AsyncIClusCfgMemberSetChangeListener_FWD_DEFINED__
#define __AsyncIClusCfgMemberSetChangeListener_FWD_DEFINED__
typedef struct AsyncIClusCfgMemberSetChangeListener AsyncIClusCfgMemberSetChangeListener;
#endif

#ifndef __IClusCfgResourceTypeInfo_FWD_DEFINED__
#define __IClusCfgResourceTypeInfo_FWD_DEFINED__
typedef struct IClusCfgResourceTypeInfo IClusCfgResourceTypeInfo;
#endif

#ifndef __AsyncIClusCfgResourceTypeInfo_FWD_DEFINED__
#define __AsyncIClusCfgResourceTypeInfo_FWD_DEFINED__
typedef struct AsyncIClusCfgResourceTypeInfo AsyncIClusCfgResourceTypeInfo;
#endif

#ifndef __IClusCfgResourceTypeCreate_FWD_DEFINED__
#define __IClusCfgResourceTypeCreate_FWD_DEFINED__
typedef struct IClusCfgResourceTypeCreate IClusCfgResourceTypeCreate;
#endif

#ifndef __AsyncIClusCfgResourceTypeCreate_FWD_DEFINED__
#define __AsyncIClusCfgResourceTypeCreate_FWD_DEFINED__
typedef struct AsyncIClusCfgResourceTypeCreate AsyncIClusCfgResourceTypeCreate;
#endif

#ifndef __IClusCfgEvictCleanup_FWD_DEFINED__
#define __IClusCfgEvictCleanup_FWD_DEFINED__
typedef struct IClusCfgEvictCleanup IClusCfgEvictCleanup;
#endif

#ifndef __AsyncIClusCfgEvictCleanup_FWD_DEFINED__
#define __AsyncIClusCfgEvictCleanup_FWD_DEFINED__
typedef struct AsyncIClusCfgEvictCleanup AsyncIClusCfgEvictCleanup;
#endif

#ifndef __IClusCfgStartupListener_FWD_DEFINED__
#define __IClusCfgStartupListener_FWD_DEFINED__
typedef struct IClusCfgStartupListener IClusCfgStartupListener;
#endif

#ifndef __AsyncIClusCfgStartupListener_FWD_DEFINED__
#define __AsyncIClusCfgStartupListener_FWD_DEFINED__
typedef struct AsyncIClusCfgStartupListener AsyncIClusCfgStartupListener;
#endif

#ifndef __IClusCfgStartupNotify_FWD_DEFINED__
#define __IClusCfgStartupNotify_FWD_DEFINED__
typedef struct IClusCfgStartupNotify IClusCfgStartupNotify;
#endif

#ifndef __AsyncIClusCfgStartupNotify_FWD_DEFINED__
#define __AsyncIClusCfgStartupNotify_FWD_DEFINED__
typedef struct AsyncIClusCfgStartupNotify AsyncIClusCfgStartupNotify;
#endif

#ifndef __IClusCfgManagedResourceData_FWD_DEFINED__
#define __IClusCfgManagedResourceData_FWD_DEFINED__
typedef struct IClusCfgManagedResourceData IClusCfgManagedResourceData;
#endif

#ifndef __IClusCfgVerifyQuorum_FWD_DEFINED__
#define __IClusCfgVerifyQuorum_FWD_DEFINED__
typedef struct IClusCfgVerifyQuorum IClusCfgVerifyQuorum;
#endif

#ifndef __IClusCfgEvictListener_FWD_DEFINED__
#define __IClusCfgEvictListener_FWD_DEFINED__
typedef struct IClusCfgEvictListener IClusCfgEvictListener;
#endif

#ifndef __AsyncIClusCfgEvictListener_FWD_DEFINED__
#define __AsyncIClusCfgEvictListener_FWD_DEFINED__
typedef struct AsyncIClusCfgEvictListener AsyncIClusCfgEvictListener;
#endif

#ifndef __IClusCfgEvictNotify_FWD_DEFINED__
#define __IClusCfgEvictNotify_FWD_DEFINED__
typedef struct IClusCfgEvictNotify IClusCfgEvictNotify;
#endif

#ifndef __AsyncIClusCfgEvictNotify_FWD_DEFINED__
#define __AsyncIClusCfgEvictNotify_FWD_DEFINED__
typedef struct AsyncIClusCfgEvictNotify AsyncIClusCfgEvictNotify;
#endif

#include "unknwn.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef enum __MIDL___MIDL_itf_cluscfgserver_0000_0001 {
    dluUNKNOWN = 0,dluNO_ROOT_DIRECTORY,dluREMOVABLE_DISK,dluFIXED_DISK,
    dluNETWORK_DRIVE,dluCOMPACT_DISC,dluRAM_DISK,dluSYSTEM,
    dluUNUSED,
    dluSTART_OF_SYSTEM_BUS = 50,dluNO_ROOT_DIRECTORY_SYSTEM_BUS = 51,
    dluREMOVABLE_DISK_SYSTEM_BUS = 52,dluFIXED_DISK_SYSTEM_BUS = 53,
    dluNETWORK_DRIVE_SYSTEM_BUS = 54,dluCOMPACT_DISC_SYSTEM_BUS =  55,
    dluRAM_DISK_SYSTEM_BUS = 56,dluSYSTEM_SYSTEM_BUS = 57,
    dluUNUSED_SYSTEM_BUS = 58,dluMAX = 59
  } EDriveLetterUsage;

  typedef struct _DRIVELETTERMAPPING {
    EDriveLetterUsage dluDrives[26 ];
  } SDriveLetterMapping;

  typedef enum __MIDL___MIDL_itf_cluscfgserver_0000_0002 {
    cmUNKNOWN = 0,cmCREATE_CLUSTER,cmADD_NODE_TO_CLUSTER,cmCLEANUP_NODE_AFTER_EVICT,
    cmMAX
  } ECommitMode;

  typedef enum EClusCfgCleanupReason {
    crSUCCESS = 0,crCANCELLED = 1,crERROR = 2
  } EClusCfgCleanupReason;

  typedef enum EDependencyFlags {
    dfUNKNOWN = 0,dfSHARED = 1,dfEXCLUSIVE = 2
  } EDependencyFlags;

  extern RPC_IF_HANDLE __MIDL_itf_cluscfgserver_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_cluscfgserver_0000_v0_0_s_ifspec;

#ifndef __IClusCfgNodeInfo_INTERFACE_DEFINED__
#define __IClusCfgNodeInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgNodeInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgNodeInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI IsMemberOfCluster(void) = 0;
    virtual HRESULT WINAPI GetClusterConfigInfo(IClusCfgClusterInfo **ppClusCfgClusterInfoOut) = 0;
    virtual HRESULT WINAPI GetOSVersion(DWORD *pdwMajorVersionOut,DWORD *pdwMinorVersionOut,WORD *pwSuiteMaskOut,BYTE *pbProductTypeOut,BSTR *pbstrCSDVersionOut) = 0;
    virtual HRESULT WINAPI GetClusterVersion(DWORD *pdwNodeHighestVersion,DWORD *pdwNodeLowestVersion) = 0;
    virtual HRESULT WINAPI GetDriveLetterMappings(SDriveLetterMapping *pdlmDriveLetterUsageOut) = 0;
    virtual HRESULT WINAPI GetMaxNodeCount(DWORD *pcMaxNodesOut) = 0;
    virtual HRESULT WINAPI GetProcessorInfo(WORD *pwProcessorArchitectureOut,WORD *pwProcessorLevelOut) = 0;
  };
#else
  typedef struct IClusCfgNodeInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgNodeInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgNodeInfo *This);
      ULONG (WINAPI *Release)(IClusCfgNodeInfo *This);
      HRESULT (WINAPI *GetName)(IClusCfgNodeInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *SetName)(IClusCfgNodeInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *IsMemberOfCluster)(IClusCfgNodeInfo *This);
      HRESULT (WINAPI *GetClusterConfigInfo)(IClusCfgNodeInfo *This,IClusCfgClusterInfo **ppClusCfgClusterInfoOut);
      HRESULT (WINAPI *GetOSVersion)(IClusCfgNodeInfo *This,DWORD *pdwMajorVersionOut,DWORD *pdwMinorVersionOut,WORD *pwSuiteMaskOut,BYTE *pbProductTypeOut,BSTR *pbstrCSDVersionOut);
      HRESULT (WINAPI *GetClusterVersion)(IClusCfgNodeInfo *This,DWORD *pdwNodeHighestVersion,DWORD *pdwNodeLowestVersion);
      HRESULT (WINAPI *GetDriveLetterMappings)(IClusCfgNodeInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
      HRESULT (WINAPI *GetMaxNodeCount)(IClusCfgNodeInfo *This,DWORD *pcMaxNodesOut);
      HRESULT (WINAPI *GetProcessorInfo)(IClusCfgNodeInfo *This,WORD *pwProcessorArchitectureOut,WORD *pwProcessorLevelOut);
    END_INTERFACE
  } IClusCfgNodeInfoVtbl;
  struct IClusCfgNodeInfo {
    CONST_VTBL struct IClusCfgNodeInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgNodeInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgNodeInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgNodeInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgNodeInfo_GetName(This,pbstrNameOut) (This)->lpVtbl->GetName(This,pbstrNameOut)
#define IClusCfgNodeInfo_SetName(This,pcszNameIn) (This)->lpVtbl->SetName(This,pcszNameIn)
#define IClusCfgNodeInfo_IsMemberOfCluster(This) (This)->lpVtbl->IsMemberOfCluster(This)
#define IClusCfgNodeInfo_GetClusterConfigInfo(This,ppClusCfgClusterInfoOut) (This)->lpVtbl->GetClusterConfigInfo(This,ppClusCfgClusterInfoOut)
#define IClusCfgNodeInfo_GetOSVersion(This,pdwMajorVersionOut,pdwMinorVersionOut,pwSuiteMaskOut,pbProductTypeOut,pbstrCSDVersionOut) (This)->lpVtbl->GetOSVersion(This,pdwMajorVersionOut,pdwMinorVersionOut,pwSuiteMaskOut,pbProductTypeOut,pbstrCSDVersionOut)
#define IClusCfgNodeInfo_GetClusterVersion(This,pdwNodeHighestVersion,pdwNodeLowestVersion) (This)->lpVtbl->GetClusterVersion(This,pdwNodeHighestVersion,pdwNodeLowestVersion)
#define IClusCfgNodeInfo_GetDriveLetterMappings(This,pdlmDriveLetterUsageOut) (This)->lpVtbl->GetDriveLetterMappings(This,pdlmDriveLetterUsageOut)
#define IClusCfgNodeInfo_GetMaxNodeCount(This,pcMaxNodesOut) (This)->lpVtbl->GetMaxNodeCount(This,pcMaxNodesOut)
#define IClusCfgNodeInfo_GetProcessorInfo(This,pwProcessorArchitectureOut,pwProcessorLevelOut) (This)->lpVtbl->GetProcessorInfo(This,pwProcessorArchitectureOut,pwProcessorLevelOut)
#endif
#endif
  HRESULT WINAPI IClusCfgNodeInfo_GetName_Proxy(IClusCfgNodeInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB IClusCfgNodeInfo_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_SetName_Proxy(IClusCfgNodeInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgNodeInfo_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_IsMemberOfCluster_Proxy(IClusCfgNodeInfo *This);
  void __RPC_STUB IClusCfgNodeInfo_IsMemberOfCluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_GetClusterConfigInfo_Proxy(IClusCfgNodeInfo *This,IClusCfgClusterInfo **ppClusCfgClusterInfoOut);
  void __RPC_STUB IClusCfgNodeInfo_GetClusterConfigInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_GetOSVersion_Proxy(IClusCfgNodeInfo *This,DWORD *pdwMajorVersionOut,DWORD *pdwMinorVersionOut,WORD *pwSuiteMaskOut,BYTE *pbProductTypeOut,BSTR *pbstrCSDVersionOut);
  void __RPC_STUB IClusCfgNodeInfo_GetOSVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_GetClusterVersion_Proxy(IClusCfgNodeInfo *This,DWORD *pdwNodeHighestVersion,DWORD *pdwNodeLowestVersion);
  void __RPC_STUB IClusCfgNodeInfo_GetClusterVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_GetDriveLetterMappings_Proxy(IClusCfgNodeInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
  void __RPC_STUB IClusCfgNodeInfo_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_GetMaxNodeCount_Proxy(IClusCfgNodeInfo *This,DWORD *pcMaxNodesOut);
  void __RPC_STUB IClusCfgNodeInfo_GetMaxNodeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNodeInfo_GetProcessorInfo_Proxy(IClusCfgNodeInfo *This,WORD *pwProcessorArchitectureOut,WORD *pwProcessorLevelOut);
  void __RPC_STUB IClusCfgNodeInfo_GetProcessorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgNodeInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgNodeInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgNodeInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgNodeInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_GetName(void) = 0;
    virtual HRESULT WINAPI Finish_GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI Begin_SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI Finish_SetName(void) = 0;
    virtual HRESULT WINAPI Begin_IsMemberOfCluster(void) = 0;
    virtual HRESULT WINAPI Finish_IsMemberOfCluster(void) = 0;
    virtual HRESULT WINAPI Begin_GetClusterConfigInfo(void) = 0;
    virtual HRESULT WINAPI Finish_GetClusterConfigInfo(IClusCfgClusterInfo **ppClusCfgClusterInfoOut) = 0;
    virtual HRESULT WINAPI Begin_GetOSVersion(void) = 0;
    virtual HRESULT WINAPI Finish_GetOSVersion(DWORD *pdwMajorVersionOut,DWORD *pdwMinorVersionOut,WORD *pwSuiteMaskOut,BYTE *pbProductTypeOut,BSTR *pbstrCSDVersionOut) = 0;
    virtual HRESULT WINAPI Begin_GetClusterVersion(void) = 0;
    virtual HRESULT WINAPI Finish_GetClusterVersion(DWORD *pdwNodeHighestVersion,DWORD *pdwNodeLowestVersion) = 0;
    virtual HRESULT WINAPI Begin_GetDriveLetterMappings(void) = 0;
    virtual HRESULT WINAPI Finish_GetDriveLetterMappings(SDriveLetterMapping *pdlmDriveLetterUsageOut) = 0;
    virtual HRESULT WINAPI Begin_GetMaxNodeCount(void) = 0;
    virtual HRESULT WINAPI Finish_GetMaxNodeCount(DWORD *pcMaxNodesOut) = 0;
    virtual HRESULT WINAPI Begin_GetProcessorInfo(void) = 0;
    virtual HRESULT WINAPI Finish_GetProcessorInfo(WORD *pwProcessorArchitectureOut,WORD *pwProcessorLevelOut) = 0;
  };
#else
  typedef struct AsyncIClusCfgNodeInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgNodeInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgNodeInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Begin_GetName)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetName)(AsyncIClusCfgNodeInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *Begin_SetName)(AsyncIClusCfgNodeInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *Finish_SetName)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Begin_IsMemberOfCluster)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_IsMemberOfCluster)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Begin_GetClusterConfigInfo)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetClusterConfigInfo)(AsyncIClusCfgNodeInfo *This,IClusCfgClusterInfo **ppClusCfgClusterInfoOut);
      HRESULT (WINAPI *Begin_GetOSVersion)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetOSVersion)(AsyncIClusCfgNodeInfo *This,DWORD *pdwMajorVersionOut,DWORD *pdwMinorVersionOut,WORD *pwSuiteMaskOut,BYTE *pbProductTypeOut,BSTR *pbstrCSDVersionOut);
      HRESULT (WINAPI *Begin_GetClusterVersion)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetClusterVersion)(AsyncIClusCfgNodeInfo *This,DWORD *pdwNodeHighestVersion,DWORD *pdwNodeLowestVersion);
      HRESULT (WINAPI *Begin_GetDriveLetterMappings)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetDriveLetterMappings)(AsyncIClusCfgNodeInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
      HRESULT (WINAPI *Begin_GetMaxNodeCount)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetMaxNodeCount)(AsyncIClusCfgNodeInfo *This,DWORD *pcMaxNodesOut);
      HRESULT (WINAPI *Begin_GetProcessorInfo)(AsyncIClusCfgNodeInfo *This);
      HRESULT (WINAPI *Finish_GetProcessorInfo)(AsyncIClusCfgNodeInfo *This,WORD *pwProcessorArchitectureOut,WORD *pwProcessorLevelOut);
    END_INTERFACE
  } AsyncIClusCfgNodeInfoVtbl;
  struct AsyncIClusCfgNodeInfo {
    CONST_VTBL struct AsyncIClusCfgNodeInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgNodeInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgNodeInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgNodeInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgNodeInfo_Begin_GetName(This) (This)->lpVtbl->Begin_GetName(This)
#define AsyncIClusCfgNodeInfo_Finish_GetName(This,pbstrNameOut) (This)->lpVtbl->Finish_GetName(This,pbstrNameOut)
#define AsyncIClusCfgNodeInfo_Begin_SetName(This,pcszNameIn) (This)->lpVtbl->Begin_SetName(This,pcszNameIn)
#define AsyncIClusCfgNodeInfo_Finish_SetName(This) (This)->lpVtbl->Finish_SetName(This)
#define AsyncIClusCfgNodeInfo_Begin_IsMemberOfCluster(This) (This)->lpVtbl->Begin_IsMemberOfCluster(This)
#define AsyncIClusCfgNodeInfo_Finish_IsMemberOfCluster(This) (This)->lpVtbl->Finish_IsMemberOfCluster(This)
#define AsyncIClusCfgNodeInfo_Begin_GetClusterConfigInfo(This) (This)->lpVtbl->Begin_GetClusterConfigInfo(This)
#define AsyncIClusCfgNodeInfo_Finish_GetClusterConfigInfo(This,ppClusCfgClusterInfoOut) (This)->lpVtbl->Finish_GetClusterConfigInfo(This,ppClusCfgClusterInfoOut)
#define AsyncIClusCfgNodeInfo_Begin_GetOSVersion(This) (This)->lpVtbl->Begin_GetOSVersion(This)
#define AsyncIClusCfgNodeInfo_Finish_GetOSVersion(This,pdwMajorVersionOut,pdwMinorVersionOut,pwSuiteMaskOut,pbProductTypeOut,pbstrCSDVersionOut) (This)->lpVtbl->Finish_GetOSVersion(This,pdwMajorVersionOut,pdwMinorVersionOut,pwSuiteMaskOut,pbProductTypeOut,pbstrCSDVersionOut)
#define AsyncIClusCfgNodeInfo_Begin_GetClusterVersion(This) (This)->lpVtbl->Begin_GetClusterVersion(This)
#define AsyncIClusCfgNodeInfo_Finish_GetClusterVersion(This,pdwNodeHighestVersion,pdwNodeLowestVersion) (This)->lpVtbl->Finish_GetClusterVersion(This,pdwNodeHighestVersion,pdwNodeLowestVersion)
#define AsyncIClusCfgNodeInfo_Begin_GetDriveLetterMappings(This) (This)->lpVtbl->Begin_GetDriveLetterMappings(This)
#define AsyncIClusCfgNodeInfo_Finish_GetDriveLetterMappings(This,pdlmDriveLetterUsageOut) (This)->lpVtbl->Finish_GetDriveLetterMappings(This,pdlmDriveLetterUsageOut)
#define AsyncIClusCfgNodeInfo_Begin_GetMaxNodeCount(This) (This)->lpVtbl->Begin_GetMaxNodeCount(This)
#define AsyncIClusCfgNodeInfo_Finish_GetMaxNodeCount(This,pcMaxNodesOut) (This)->lpVtbl->Finish_GetMaxNodeCount(This,pcMaxNodesOut)
#define AsyncIClusCfgNodeInfo_Begin_GetProcessorInfo(This) (This)->lpVtbl->Begin_GetProcessorInfo(This)
#define AsyncIClusCfgNodeInfo_Finish_GetProcessorInfo(This,pwProcessorArchitectureOut,pwProcessorLevelOut) (This)->lpVtbl->Finish_GetProcessorInfo(This,pwProcessorArchitectureOut,pwProcessorLevelOut)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetName_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetName_Proxy(AsyncIClusCfgNodeInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_SetName_Proxy(AsyncIClusCfgNodeInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_SetName_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_IsMemberOfCluster_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_IsMemberOfCluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_IsMemberOfCluster_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_IsMemberOfCluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetClusterConfigInfo_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetClusterConfigInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetClusterConfigInfo_Proxy(AsyncIClusCfgNodeInfo *This,IClusCfgClusterInfo **ppClusCfgClusterInfoOut);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetClusterConfigInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetOSVersion_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetOSVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetOSVersion_Proxy(AsyncIClusCfgNodeInfo *This,DWORD *pdwMajorVersionOut,DWORD *pdwMinorVersionOut,WORD *pwSuiteMaskOut,BYTE *pbProductTypeOut,BSTR *pbstrCSDVersionOut);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetOSVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetClusterVersion_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetClusterVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetClusterVersion_Proxy(AsyncIClusCfgNodeInfo *This,DWORD *pdwNodeHighestVersion,DWORD *pdwNodeLowestVersion);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetClusterVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetDriveLetterMappings_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetDriveLetterMappings_Proxy(AsyncIClusCfgNodeInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetMaxNodeCount_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetMaxNodeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetMaxNodeCount_Proxy(AsyncIClusCfgNodeInfo *This,DWORD *pcMaxNodesOut);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetMaxNodeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Begin_GetProcessorInfo_Proxy(AsyncIClusCfgNodeInfo *This);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Begin_GetProcessorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNodeInfo_Finish_GetProcessorInfo_Proxy(AsyncIClusCfgNodeInfo *This,WORD *pwProcessorArchitectureOut,WORD *pwProcessorLevelOut);
  void __RPC_STUB AsyncIClusCfgNodeInfo_Finish_GetProcessorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumClusCfgManagedResources_INTERFACE_DEFINED__
#define __IEnumClusCfgManagedResources_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumClusCfgManagedResources;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumClusCfgManagedResources : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG cNumberRequestedIn,IClusCfgManagedResourceInfo **rgpManagedResourceInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG cNumberToSkip) = 0;
    virtual HRESULT WINAPI Clone(IEnumClusCfgManagedResources **ppEnumManagedResourcesOut) = 0;
    virtual HRESULT WINAPI Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct IEnumClusCfgManagedResourcesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumClusCfgManagedResources *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumClusCfgManagedResources *This);
      ULONG (WINAPI *Release)(IEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Next)(IEnumClusCfgManagedResources *This,ULONG cNumberRequestedIn,IClusCfgManagedResourceInfo **rgpManagedResourceInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Reset)(IEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Skip)(IEnumClusCfgManagedResources *This,ULONG cNumberToSkip);
      HRESULT (WINAPI *Clone)(IEnumClusCfgManagedResources *This,IEnumClusCfgManagedResources **ppEnumManagedResourcesOut);
      HRESULT (WINAPI *Count)(IEnumClusCfgManagedResources *This,DWORD *pnCountOut);
    END_INTERFACE
  } IEnumClusCfgManagedResourcesVtbl;
  struct IEnumClusCfgManagedResources {
    CONST_VTBL struct IEnumClusCfgManagedResourcesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumClusCfgManagedResources_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumClusCfgManagedResources_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumClusCfgManagedResources_Release(This) (This)->lpVtbl->Release(This)
#define IEnumClusCfgManagedResources_Next(This,cNumberRequestedIn,rgpManagedResourceInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Next(This,cNumberRequestedIn,rgpManagedResourceInfoOut,pcNumberFetchedOut)
#define IEnumClusCfgManagedResources_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumClusCfgManagedResources_Skip(This,cNumberToSkip) (This)->lpVtbl->Skip(This,cNumberToSkip)
#define IEnumClusCfgManagedResources_Clone(This,ppEnumManagedResourcesOut) (This)->lpVtbl->Clone(This,ppEnumManagedResourcesOut)
#define IEnumClusCfgManagedResources_Count(This,pnCountOut) (This)->lpVtbl->Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI IEnumClusCfgManagedResources_Next_Proxy(IEnumClusCfgManagedResources *This,ULONG cNumberRequestedIn,IClusCfgManagedResourceInfo **rgpManagedResourceInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB IEnumClusCfgManagedResources_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgManagedResources_Reset_Proxy(IEnumClusCfgManagedResources *This);
  void __RPC_STUB IEnumClusCfgManagedResources_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgManagedResources_Skip_Proxy(IEnumClusCfgManagedResources *This,ULONG cNumberToSkip);
  void __RPC_STUB IEnumClusCfgManagedResources_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgManagedResources_Clone_Proxy(IEnumClusCfgManagedResources *This,IEnumClusCfgManagedResources **ppEnumManagedResourcesOut);
  void __RPC_STUB IEnumClusCfgManagedResources_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgManagedResources_Count_Proxy(IEnumClusCfgManagedResources *This,DWORD *pnCountOut);
  void __RPC_STUB IEnumClusCfgManagedResources_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIEnumClusCfgManagedResources_INTERFACE_DEFINED__
#define __AsyncIEnumClusCfgManagedResources_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIEnumClusCfgManagedResources;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIEnumClusCfgManagedResources : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Next(ULONG cNumberRequestedIn) = 0;
    virtual HRESULT WINAPI Finish_Next(IClusCfgManagedResourceInfo **rgpManagedResourceInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Begin_Reset(void) = 0;
    virtual HRESULT WINAPI Finish_Reset(void) = 0;
    virtual HRESULT WINAPI Begin_Skip(ULONG cNumberToSkip) = 0;
    virtual HRESULT WINAPI Finish_Skip(void) = 0;
    virtual HRESULT WINAPI Begin_Clone(void) = 0;
    virtual HRESULT WINAPI Finish_Clone(IEnumClusCfgManagedResources **ppEnumManagedResourcesOut) = 0;
    virtual HRESULT WINAPI Begin_Count(void) = 0;
    virtual HRESULT WINAPI Finish_Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct AsyncIEnumClusCfgManagedResourcesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIEnumClusCfgManagedResources *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIEnumClusCfgManagedResources *This);
      ULONG (WINAPI *Release)(AsyncIEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Begin_Next)(AsyncIEnumClusCfgManagedResources *This,ULONG cNumberRequestedIn);
      HRESULT (WINAPI *Finish_Next)(AsyncIEnumClusCfgManagedResources *This,IClusCfgManagedResourceInfo **rgpManagedResourceInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Begin_Reset)(AsyncIEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Finish_Reset)(AsyncIEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Begin_Skip)(AsyncIEnumClusCfgManagedResources *This,ULONG cNumberToSkip);
      HRESULT (WINAPI *Finish_Skip)(AsyncIEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Begin_Clone)(AsyncIEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Finish_Clone)(AsyncIEnumClusCfgManagedResources *This,IEnumClusCfgManagedResources **ppEnumManagedResourcesOut);
      HRESULT (WINAPI *Begin_Count)(AsyncIEnumClusCfgManagedResources *This);
      HRESULT (WINAPI *Finish_Count)(AsyncIEnumClusCfgManagedResources *This,DWORD *pnCountOut);
    END_INTERFACE
  } AsyncIEnumClusCfgManagedResourcesVtbl;
  struct AsyncIEnumClusCfgManagedResources {
    CONST_VTBL struct AsyncIEnumClusCfgManagedResourcesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIEnumClusCfgManagedResources_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIEnumClusCfgManagedResources_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIEnumClusCfgManagedResources_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIEnumClusCfgManagedResources_Begin_Next(This,cNumberRequestedIn) (This)->lpVtbl->Begin_Next(This,cNumberRequestedIn)
#define AsyncIEnumClusCfgManagedResources_Finish_Next(This,rgpManagedResourceInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Finish_Next(This,rgpManagedResourceInfoOut,pcNumberFetchedOut)
#define AsyncIEnumClusCfgManagedResources_Begin_Reset(This) (This)->lpVtbl->Begin_Reset(This)
#define AsyncIEnumClusCfgManagedResources_Finish_Reset(This) (This)->lpVtbl->Finish_Reset(This)
#define AsyncIEnumClusCfgManagedResources_Begin_Skip(This,cNumberToSkip) (This)->lpVtbl->Begin_Skip(This,cNumberToSkip)
#define AsyncIEnumClusCfgManagedResources_Finish_Skip(This) (This)->lpVtbl->Finish_Skip(This)
#define AsyncIEnumClusCfgManagedResources_Begin_Clone(This) (This)->lpVtbl->Begin_Clone(This)
#define AsyncIEnumClusCfgManagedResources_Finish_Clone(This,ppEnumManagedResourcesOut) (This)->lpVtbl->Finish_Clone(This,ppEnumManagedResourcesOut)
#define AsyncIEnumClusCfgManagedResources_Begin_Count(This) (This)->lpVtbl->Begin_Count(This)
#define AsyncIEnumClusCfgManagedResources_Finish_Count(This,pnCountOut) (This)->lpVtbl->Finish_Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Begin_Next_Proxy(AsyncIEnumClusCfgManagedResources *This,ULONG cNumberRequestedIn);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Begin_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Finish_Next_Proxy(AsyncIEnumClusCfgManagedResources *This,IClusCfgManagedResourceInfo **rgpManagedResourceInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Finish_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Begin_Reset_Proxy(AsyncIEnumClusCfgManagedResources *This);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Begin_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Finish_Reset_Proxy(AsyncIEnumClusCfgManagedResources *This);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Finish_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Begin_Skip_Proxy(AsyncIEnumClusCfgManagedResources *This,ULONG cNumberToSkip);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Begin_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Finish_Skip_Proxy(AsyncIEnumClusCfgManagedResources *This);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Finish_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Begin_Clone_Proxy(AsyncIEnumClusCfgManagedResources *This);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Begin_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Finish_Clone_Proxy(AsyncIEnumClusCfgManagedResources *This,IEnumClusCfgManagedResources **ppEnumManagedResourcesOut);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Finish_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Begin_Count_Proxy(AsyncIEnumClusCfgManagedResources *This);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Begin_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgManagedResources_Finish_Count_Proxy(AsyncIEnumClusCfgManagedResources *This,DWORD *pnCountOut);
  void __RPC_STUB AsyncIEnumClusCfgManagedResources_Finish_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumClusCfgNetworks_INTERFACE_DEFINED__
#define __IEnumClusCfgNetworks_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumClusCfgNetworks;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumClusCfgNetworks : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG cNumberRequestedIn,IClusCfgNetworkInfo **rgpNetworkInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Skip(ULONG cNumberToSkipIn) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumClusCfgNetworks **ppEnumNetworksOut) = 0;
    virtual HRESULT WINAPI Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct IEnumClusCfgNetworksVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumClusCfgNetworks *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumClusCfgNetworks *This);
      ULONG (WINAPI *Release)(IEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Next)(IEnumClusCfgNetworks *This,ULONG cNumberRequestedIn,IClusCfgNetworkInfo **rgpNetworkInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Skip)(IEnumClusCfgNetworks *This,ULONG cNumberToSkipIn);
      HRESULT (WINAPI *Reset)(IEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Clone)(IEnumClusCfgNetworks *This,IEnumClusCfgNetworks **ppEnumNetworksOut);
      HRESULT (WINAPI *Count)(IEnumClusCfgNetworks *This,DWORD *pnCountOut);
    END_INTERFACE
  } IEnumClusCfgNetworksVtbl;
  struct IEnumClusCfgNetworks {
    CONST_VTBL struct IEnumClusCfgNetworksVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumClusCfgNetworks_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumClusCfgNetworks_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumClusCfgNetworks_Release(This) (This)->lpVtbl->Release(This)
#define IEnumClusCfgNetworks_Next(This,cNumberRequestedIn,rgpNetworkInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Next(This,cNumberRequestedIn,rgpNetworkInfoOut,pcNumberFetchedOut)
#define IEnumClusCfgNetworks_Skip(This,cNumberToSkipIn) (This)->lpVtbl->Skip(This,cNumberToSkipIn)
#define IEnumClusCfgNetworks_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumClusCfgNetworks_Clone(This,ppEnumNetworksOut) (This)->lpVtbl->Clone(This,ppEnumNetworksOut)
#define IEnumClusCfgNetworks_Count(This,pnCountOut) (This)->lpVtbl->Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI IEnumClusCfgNetworks_Next_Proxy(IEnumClusCfgNetworks *This,ULONG cNumberRequestedIn,IClusCfgNetworkInfo **rgpNetworkInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB IEnumClusCfgNetworks_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgNetworks_Skip_Proxy(IEnumClusCfgNetworks *This,ULONG cNumberToSkipIn);
  void __RPC_STUB IEnumClusCfgNetworks_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgNetworks_Reset_Proxy(IEnumClusCfgNetworks *This);
  void __RPC_STUB IEnumClusCfgNetworks_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgNetworks_Clone_Proxy(IEnumClusCfgNetworks *This,IEnumClusCfgNetworks **ppEnumNetworksOut);
  void __RPC_STUB IEnumClusCfgNetworks_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgNetworks_Count_Proxy(IEnumClusCfgNetworks *This,DWORD *pnCountOut);
  void __RPC_STUB IEnumClusCfgNetworks_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIEnumClusCfgNetworks_INTERFACE_DEFINED__
#define __AsyncIEnumClusCfgNetworks_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIEnumClusCfgNetworks;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIEnumClusCfgNetworks : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Next(ULONG cNumberRequestedIn) = 0;
    virtual HRESULT WINAPI Finish_Next(IClusCfgNetworkInfo **rgpNetworkInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Begin_Skip(ULONG cNumberToSkipIn) = 0;
    virtual HRESULT WINAPI Finish_Skip(void) = 0;
    virtual HRESULT WINAPI Begin_Reset(void) = 0;
    virtual HRESULT WINAPI Finish_Reset(void) = 0;
    virtual HRESULT WINAPI Begin_Clone(void) = 0;
    virtual HRESULT WINAPI Finish_Clone(IEnumClusCfgNetworks **ppEnumNetworksOut) = 0;
    virtual HRESULT WINAPI Begin_Count(void) = 0;
    virtual HRESULT WINAPI Finish_Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct AsyncIEnumClusCfgNetworksVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIEnumClusCfgNetworks *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIEnumClusCfgNetworks *This);
      ULONG (WINAPI *Release)(AsyncIEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Begin_Next)(AsyncIEnumClusCfgNetworks *This,ULONG cNumberRequestedIn);
      HRESULT (WINAPI *Finish_Next)(AsyncIEnumClusCfgNetworks *This,IClusCfgNetworkInfo **rgpNetworkInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Begin_Skip)(AsyncIEnumClusCfgNetworks *This,ULONG cNumberToSkipIn);
      HRESULT (WINAPI *Finish_Skip)(AsyncIEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Begin_Reset)(AsyncIEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Finish_Reset)(AsyncIEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Begin_Clone)(AsyncIEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Finish_Clone)(AsyncIEnumClusCfgNetworks *This,IEnumClusCfgNetworks **ppEnumNetworksOut);
      HRESULT (WINAPI *Begin_Count)(AsyncIEnumClusCfgNetworks *This);
      HRESULT (WINAPI *Finish_Count)(AsyncIEnumClusCfgNetworks *This,DWORD *pnCountOut);
    END_INTERFACE
  } AsyncIEnumClusCfgNetworksVtbl;
  struct AsyncIEnumClusCfgNetworks {
    CONST_VTBL struct AsyncIEnumClusCfgNetworksVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIEnumClusCfgNetworks_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIEnumClusCfgNetworks_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIEnumClusCfgNetworks_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIEnumClusCfgNetworks_Begin_Next(This,cNumberRequestedIn) (This)->lpVtbl->Begin_Next(This,cNumberRequestedIn)
#define AsyncIEnumClusCfgNetworks_Finish_Next(This,rgpNetworkInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Finish_Next(This,rgpNetworkInfoOut,pcNumberFetchedOut)
#define AsyncIEnumClusCfgNetworks_Begin_Skip(This,cNumberToSkipIn) (This)->lpVtbl->Begin_Skip(This,cNumberToSkipIn)
#define AsyncIEnumClusCfgNetworks_Finish_Skip(This) (This)->lpVtbl->Finish_Skip(This)
#define AsyncIEnumClusCfgNetworks_Begin_Reset(This) (This)->lpVtbl->Begin_Reset(This)
#define AsyncIEnumClusCfgNetworks_Finish_Reset(This) (This)->lpVtbl->Finish_Reset(This)
#define AsyncIEnumClusCfgNetworks_Begin_Clone(This) (This)->lpVtbl->Begin_Clone(This)
#define AsyncIEnumClusCfgNetworks_Finish_Clone(This,ppEnumNetworksOut) (This)->lpVtbl->Finish_Clone(This,ppEnumNetworksOut)
#define AsyncIEnumClusCfgNetworks_Begin_Count(This) (This)->lpVtbl->Begin_Count(This)
#define AsyncIEnumClusCfgNetworks_Finish_Count(This,pnCountOut) (This)->lpVtbl->Finish_Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Begin_Next_Proxy(AsyncIEnumClusCfgNetworks *This,ULONG cNumberRequestedIn);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Begin_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Finish_Next_Proxy(AsyncIEnumClusCfgNetworks *This,IClusCfgNetworkInfo **rgpNetworkInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Finish_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Begin_Skip_Proxy(AsyncIEnumClusCfgNetworks *This,ULONG cNumberToSkipIn);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Begin_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Finish_Skip_Proxy(AsyncIEnumClusCfgNetworks *This);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Finish_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Begin_Reset_Proxy(AsyncIEnumClusCfgNetworks *This);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Begin_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Finish_Reset_Proxy(AsyncIEnumClusCfgNetworks *This);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Finish_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Begin_Clone_Proxy(AsyncIEnumClusCfgNetworks *This);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Begin_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Finish_Clone_Proxy(AsyncIEnumClusCfgNetworks *This,IEnumClusCfgNetworks **ppEnumNetworksOut);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Finish_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Begin_Count_Proxy(AsyncIEnumClusCfgNetworks *This);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Begin_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgNetworks_Finish_Count_Proxy(AsyncIEnumClusCfgNetworks *This,DWORD *pnCountOut);
  void __RPC_STUB AsyncIEnumClusCfgNetworks_Finish_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgManagedResourceInfo_INTERFACE_DEFINED__
#define __IClusCfgManagedResourceInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgManagedResourceInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgManagedResourceInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI IsManaged(void) = 0;
    virtual HRESULT WINAPI SetManaged(WINBOOL fIsManagedIn) = 0;
    virtual HRESULT WINAPI IsQuorumResource(void) = 0;
    virtual HRESULT WINAPI SetQuorumResource(WINBOOL fIsQuorumResourceIn) = 0;
    virtual HRESULT WINAPI IsQuorumCapable(void) = 0;
    virtual HRESULT WINAPI SetQuorumCapable(WINBOOL fIsQuorumCapableIn) = 0;
    virtual HRESULT WINAPI GetDriveLetterMappings(SDriveLetterMapping *pdlmDriveLetterMappingOut) = 0;
    virtual HRESULT WINAPI SetDriveLetterMappings(SDriveLetterMapping dlmDriveLetterMappingIn) = 0;
    virtual HRESULT WINAPI IsManagedByDefault(void) = 0;
    virtual HRESULT WINAPI SetManagedByDefault(WINBOOL fIsManagedByDefaultIn) = 0;
  };
#else
  typedef struct IClusCfgManagedResourceInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgManagedResourceInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgManagedResourceInfo *This);
      ULONG (WINAPI *Release)(IClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *GetUID)(IClusCfgManagedResourceInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *GetName)(IClusCfgManagedResourceInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *SetName)(IClusCfgManagedResourceInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *IsManaged)(IClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *SetManaged)(IClusCfgManagedResourceInfo *This,WINBOOL fIsManagedIn);
      HRESULT (WINAPI *IsQuorumResource)(IClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *SetQuorumResource)(IClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumResourceIn);
      HRESULT (WINAPI *IsQuorumCapable)(IClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *SetQuorumCapable)(IClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumCapableIn);
      HRESULT (WINAPI *GetDriveLetterMappings)(IClusCfgManagedResourceInfo *This,SDriveLetterMapping *pdlmDriveLetterMappingOut);
      HRESULT (WINAPI *SetDriveLetterMappings)(IClusCfgManagedResourceInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
      HRESULT (WINAPI *IsManagedByDefault)(IClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *SetManagedByDefault)(IClusCfgManagedResourceInfo *This,WINBOOL fIsManagedByDefaultIn);
    END_INTERFACE
  } IClusCfgManagedResourceInfoVtbl;
  struct IClusCfgManagedResourceInfo {
    CONST_VTBL struct IClusCfgManagedResourceInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgManagedResourceInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgManagedResourceInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgManagedResourceInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgManagedResourceInfo_GetUID(This,pbstrUIDOut) (This)->lpVtbl->GetUID(This,pbstrUIDOut)
#define IClusCfgManagedResourceInfo_GetName(This,pbstrNameOut) (This)->lpVtbl->GetName(This,pbstrNameOut)
#define IClusCfgManagedResourceInfo_SetName(This,pcszNameIn) (This)->lpVtbl->SetName(This,pcszNameIn)
#define IClusCfgManagedResourceInfo_IsManaged(This) (This)->lpVtbl->IsManaged(This)
#define IClusCfgManagedResourceInfo_SetManaged(This,fIsManagedIn) (This)->lpVtbl->SetManaged(This,fIsManagedIn)
#define IClusCfgManagedResourceInfo_IsQuorumResource(This) (This)->lpVtbl->IsQuorumResource(This)
#define IClusCfgManagedResourceInfo_SetQuorumResource(This,fIsQuorumResourceIn) (This)->lpVtbl->SetQuorumResource(This,fIsQuorumResourceIn)
#define IClusCfgManagedResourceInfo_IsQuorumCapable(This) (This)->lpVtbl->IsQuorumCapable(This)
#define IClusCfgManagedResourceInfo_SetQuorumCapable(This,fIsQuorumCapableIn) (This)->lpVtbl->SetQuorumCapable(This,fIsQuorumCapableIn)
#define IClusCfgManagedResourceInfo_GetDriveLetterMappings(This,pdlmDriveLetterMappingOut) (This)->lpVtbl->GetDriveLetterMappings(This,pdlmDriveLetterMappingOut)
#define IClusCfgManagedResourceInfo_SetDriveLetterMappings(This,dlmDriveLetterMappingIn) (This)->lpVtbl->SetDriveLetterMappings(This,dlmDriveLetterMappingIn)
#define IClusCfgManagedResourceInfo_IsManagedByDefault(This) (This)->lpVtbl->IsManagedByDefault(This)
#define IClusCfgManagedResourceInfo_SetManagedByDefault(This,fIsManagedByDefaultIn) (This)->lpVtbl->SetManagedByDefault(This,fIsManagedByDefaultIn)
#endif
#endif
  HRESULT WINAPI IClusCfgManagedResourceInfo_GetUID_Proxy(IClusCfgManagedResourceInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB IClusCfgManagedResourceInfo_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_GetName_Proxy(IClusCfgManagedResourceInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB IClusCfgManagedResourceInfo_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_SetName_Proxy(IClusCfgManagedResourceInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgManagedResourceInfo_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_IsManaged_Proxy(IClusCfgManagedResourceInfo *This);
  void __RPC_STUB IClusCfgManagedResourceInfo_IsManaged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_SetManaged_Proxy(IClusCfgManagedResourceInfo *This,WINBOOL fIsManagedIn);
  void __RPC_STUB IClusCfgManagedResourceInfo_SetManaged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_IsQuorumResource_Proxy(IClusCfgManagedResourceInfo *This);
  void __RPC_STUB IClusCfgManagedResourceInfo_IsQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_SetQuorumResource_Proxy(IClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumResourceIn);
  void __RPC_STUB IClusCfgManagedResourceInfo_SetQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_IsQuorumCapable_Proxy(IClusCfgManagedResourceInfo *This);
  void __RPC_STUB IClusCfgManagedResourceInfo_IsQuorumCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_SetQuorumCapable_Proxy(IClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumCapableIn);
  void __RPC_STUB IClusCfgManagedResourceInfo_SetQuorumCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_GetDriveLetterMappings_Proxy(IClusCfgManagedResourceInfo *This,SDriveLetterMapping *pdlmDriveLetterMappingOut);
  void __RPC_STUB IClusCfgManagedResourceInfo_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_SetDriveLetterMappings_Proxy(IClusCfgManagedResourceInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
  void __RPC_STUB IClusCfgManagedResourceInfo_SetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_IsManagedByDefault_Proxy(IClusCfgManagedResourceInfo *This);
  void __RPC_STUB IClusCfgManagedResourceInfo_IsManagedByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceInfo_SetManagedByDefault_Proxy(IClusCfgManagedResourceInfo *This,WINBOOL fIsManagedByDefaultIn);
  void __RPC_STUB IClusCfgManagedResourceInfo_SetManagedByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgManagedResourceInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgManagedResourceInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgManagedResourceInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgManagedResourceInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_GetUID(void) = 0;
    virtual HRESULT WINAPI Finish_GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI Begin_GetName(void) = 0;
    virtual HRESULT WINAPI Finish_GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI Begin_SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI Finish_SetName(void) = 0;
    virtual HRESULT WINAPI Begin_IsManaged(void) = 0;
    virtual HRESULT WINAPI Finish_IsManaged(void) = 0;
    virtual HRESULT WINAPI Begin_SetManaged(WINBOOL fIsManagedIn) = 0;
    virtual HRESULT WINAPI Finish_SetManaged(void) = 0;
    virtual HRESULT WINAPI Begin_IsQuorumResource(void) = 0;
    virtual HRESULT WINAPI Finish_IsQuorumResource(void) = 0;
    virtual HRESULT WINAPI Begin_SetQuorumResource(WINBOOL fIsQuorumResourceIn) = 0;
    virtual HRESULT WINAPI Finish_SetQuorumResource(void) = 0;
    virtual HRESULT WINAPI Begin_IsQuorumCapable(void) = 0;
    virtual HRESULT WINAPI Finish_IsQuorumCapable(void) = 0;
    virtual HRESULT WINAPI Begin_SetQuorumCapable(WINBOOL fIsQuorumCapableIn) = 0;
    virtual HRESULT WINAPI Finish_SetQuorumCapable(void) = 0;
    virtual HRESULT WINAPI Begin_GetDriveLetterMappings(void) = 0;
    virtual HRESULT WINAPI Finish_GetDriveLetterMappings(SDriveLetterMapping *pdlmDriveLetterMappingOut) = 0;
    virtual HRESULT WINAPI Begin_SetDriveLetterMappings(SDriveLetterMapping dlmDriveLetterMappingIn) = 0;
    virtual HRESULT WINAPI Finish_SetDriveLetterMappings(void) = 0;
    virtual HRESULT WINAPI Begin_IsManagedByDefault(void) = 0;
    virtual HRESULT WINAPI Finish_IsManagedByDefault(void) = 0;
    virtual HRESULT WINAPI Begin_SetManagedByDefault(WINBOOL fIsManagedByDefaultIn) = 0;
    virtual HRESULT WINAPI Finish_SetManagedByDefault(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgManagedResourceInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgManagedResourceInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgManagedResourceInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_GetUID)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_GetUID)(AsyncIClusCfgManagedResourceInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *Begin_GetName)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_GetName)(AsyncIClusCfgManagedResourceInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *Begin_SetName)(AsyncIClusCfgManagedResourceInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *Finish_SetName)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_IsManaged)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_IsManaged)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_SetManaged)(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsManagedIn);
      HRESULT (WINAPI *Finish_SetManaged)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_IsQuorumResource)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_IsQuorumResource)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_SetQuorumResource)(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumResourceIn);
      HRESULT (WINAPI *Finish_SetQuorumResource)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_IsQuorumCapable)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_IsQuorumCapable)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_SetQuorumCapable)(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumCapableIn);
      HRESULT (WINAPI *Finish_SetQuorumCapable)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_GetDriveLetterMappings)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_GetDriveLetterMappings)(AsyncIClusCfgManagedResourceInfo *This,SDriveLetterMapping *pdlmDriveLetterMappingOut);
      HRESULT (WINAPI *Begin_SetDriveLetterMappings)(AsyncIClusCfgManagedResourceInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
      HRESULT (WINAPI *Finish_SetDriveLetterMappings)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_IsManagedByDefault)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Finish_IsManagedByDefault)(AsyncIClusCfgManagedResourceInfo *This);
      HRESULT (WINAPI *Begin_SetManagedByDefault)(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsManagedByDefaultIn);
      HRESULT (WINAPI *Finish_SetManagedByDefault)(AsyncIClusCfgManagedResourceInfo *This);
    END_INTERFACE
  } AsyncIClusCfgManagedResourceInfoVtbl;
  struct AsyncIClusCfgManagedResourceInfo {
    CONST_VTBL struct AsyncIClusCfgManagedResourceInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgManagedResourceInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgManagedResourceInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgManagedResourceInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_GetUID(This) (This)->lpVtbl->Begin_GetUID(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_GetUID(This,pbstrUIDOut) (This)->lpVtbl->Finish_GetUID(This,pbstrUIDOut)
#define AsyncIClusCfgManagedResourceInfo_Begin_GetName(This) (This)->lpVtbl->Begin_GetName(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_GetName(This,pbstrNameOut) (This)->lpVtbl->Finish_GetName(This,pbstrNameOut)
#define AsyncIClusCfgManagedResourceInfo_Begin_SetName(This,pcszNameIn) (This)->lpVtbl->Begin_SetName(This,pcszNameIn)
#define AsyncIClusCfgManagedResourceInfo_Finish_SetName(This) (This)->lpVtbl->Finish_SetName(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_IsManaged(This) (This)->lpVtbl->Begin_IsManaged(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_IsManaged(This) (This)->lpVtbl->Finish_IsManaged(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_SetManaged(This,fIsManagedIn) (This)->lpVtbl->Begin_SetManaged(This,fIsManagedIn)
#define AsyncIClusCfgManagedResourceInfo_Finish_SetManaged(This) (This)->lpVtbl->Finish_SetManaged(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_IsQuorumResource(This) (This)->lpVtbl->Begin_IsQuorumResource(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_IsQuorumResource(This) (This)->lpVtbl->Finish_IsQuorumResource(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_SetQuorumResource(This,fIsQuorumResourceIn) (This)->lpVtbl->Begin_SetQuorumResource(This,fIsQuorumResourceIn)
#define AsyncIClusCfgManagedResourceInfo_Finish_SetQuorumResource(This) (This)->lpVtbl->Finish_SetQuorumResource(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_IsQuorumCapable(This) (This)->lpVtbl->Begin_IsQuorumCapable(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_IsQuorumCapable(This) (This)->lpVtbl->Finish_IsQuorumCapable(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_SetQuorumCapable(This,fIsQuorumCapableIn) (This)->lpVtbl->Begin_SetQuorumCapable(This,fIsQuorumCapableIn)
#define AsyncIClusCfgManagedResourceInfo_Finish_SetQuorumCapable(This) (This)->lpVtbl->Finish_SetQuorumCapable(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_GetDriveLetterMappings(This) (This)->lpVtbl->Begin_GetDriveLetterMappings(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_GetDriveLetterMappings(This,pdlmDriveLetterMappingOut) (This)->lpVtbl->Finish_GetDriveLetterMappings(This,pdlmDriveLetterMappingOut)
#define AsyncIClusCfgManagedResourceInfo_Begin_SetDriveLetterMappings(This,dlmDriveLetterMappingIn) (This)->lpVtbl->Begin_SetDriveLetterMappings(This,dlmDriveLetterMappingIn)
#define AsyncIClusCfgManagedResourceInfo_Finish_SetDriveLetterMappings(This) (This)->lpVtbl->Finish_SetDriveLetterMappings(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_IsManagedByDefault(This) (This)->lpVtbl->Begin_IsManagedByDefault(This)
#define AsyncIClusCfgManagedResourceInfo_Finish_IsManagedByDefault(This) (This)->lpVtbl->Finish_IsManagedByDefault(This)
#define AsyncIClusCfgManagedResourceInfo_Begin_SetManagedByDefault(This,fIsManagedByDefaultIn) (This)->lpVtbl->Begin_SetManagedByDefault(This,fIsManagedByDefaultIn)
#define AsyncIClusCfgManagedResourceInfo_Finish_SetManagedByDefault(This) (This)->lpVtbl->Finish_SetManagedByDefault(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_GetUID_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_GetUID_Proxy(AsyncIClusCfgManagedResourceInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_GetName_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_GetName_Proxy(AsyncIClusCfgManagedResourceInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_SetName_Proxy(AsyncIClusCfgManagedResourceInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_SetName_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_IsManaged_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_IsManaged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_IsManaged_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_IsManaged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_SetManaged_Proxy(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsManagedIn);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_SetManaged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_SetManaged_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_SetManaged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_IsQuorumResource_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_IsQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_IsQuorumResource_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_IsQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_SetQuorumResource_Proxy(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumResourceIn);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_SetQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_SetQuorumResource_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_SetQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_IsQuorumCapable_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_IsQuorumCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_IsQuorumCapable_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_IsQuorumCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_SetQuorumCapable_Proxy(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsQuorumCapableIn);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_SetQuorumCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_SetQuorumCapable_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_SetQuorumCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_GetDriveLetterMappings_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_GetDriveLetterMappings_Proxy(AsyncIClusCfgManagedResourceInfo *This,SDriveLetterMapping *pdlmDriveLetterMappingOut);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_SetDriveLetterMappings_Proxy(AsyncIClusCfgManagedResourceInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_SetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_SetDriveLetterMappings_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_SetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_IsManagedByDefault_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_IsManagedByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_IsManagedByDefault_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_IsManagedByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Begin_SetManagedByDefault_Proxy(AsyncIClusCfgManagedResourceInfo *This,WINBOOL fIsManagedByDefaultIn);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Begin_SetManagedByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgManagedResourceInfo_Finish_SetManagedByDefault_Proxy(AsyncIClusCfgManagedResourceInfo *This);
  void __RPC_STUB AsyncIClusCfgManagedResourceInfo_Finish_SetManagedByDefault_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumClusCfgPartitions_INTERFACE_DEFINED__
#define __IEnumClusCfgPartitions_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumClusCfgPartitions;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumClusCfgPartitions : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG cNumberRequestedIn,IClusCfgPartitionInfo **rgpPartitionInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG cNumberToSkip) = 0;
    virtual HRESULT WINAPI Clone(IEnumClusCfgPartitions **ppEnumPartitions) = 0;
    virtual HRESULT WINAPI Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct IEnumClusCfgPartitionsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumClusCfgPartitions *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumClusCfgPartitions *This);
      ULONG (WINAPI *Release)(IEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Next)(IEnumClusCfgPartitions *This,ULONG cNumberRequestedIn,IClusCfgPartitionInfo **rgpPartitionInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Reset)(IEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Skip)(IEnumClusCfgPartitions *This,ULONG cNumberToSkip);
      HRESULT (WINAPI *Clone)(IEnumClusCfgPartitions *This,IEnumClusCfgPartitions **ppEnumPartitions);
      HRESULT (WINAPI *Count)(IEnumClusCfgPartitions *This,DWORD *pnCountOut);
    END_INTERFACE
  } IEnumClusCfgPartitionsVtbl;
  struct IEnumClusCfgPartitions {
    CONST_VTBL struct IEnumClusCfgPartitionsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumClusCfgPartitions_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumClusCfgPartitions_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumClusCfgPartitions_Release(This) (This)->lpVtbl->Release(This)
#define IEnumClusCfgPartitions_Next(This,cNumberRequestedIn,rgpPartitionInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Next(This,cNumberRequestedIn,rgpPartitionInfoOut,pcNumberFetchedOut)
#define IEnumClusCfgPartitions_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumClusCfgPartitions_Skip(This,cNumberToSkip) (This)->lpVtbl->Skip(This,cNumberToSkip)
#define IEnumClusCfgPartitions_Clone(This,ppEnumPartitions) (This)->lpVtbl->Clone(This,ppEnumPartitions)
#define IEnumClusCfgPartitions_Count(This,pnCountOut) (This)->lpVtbl->Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI IEnumClusCfgPartitions_Next_Proxy(IEnumClusCfgPartitions *This,ULONG cNumberRequestedIn,IClusCfgPartitionInfo **rgpPartitionInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB IEnumClusCfgPartitions_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgPartitions_Reset_Proxy(IEnumClusCfgPartitions *This);
  void __RPC_STUB IEnumClusCfgPartitions_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgPartitions_Skip_Proxy(IEnumClusCfgPartitions *This,ULONG cNumberToSkip);
  void __RPC_STUB IEnumClusCfgPartitions_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgPartitions_Clone_Proxy(IEnumClusCfgPartitions *This,IEnumClusCfgPartitions **ppEnumPartitions);
  void __RPC_STUB IEnumClusCfgPartitions_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgPartitions_Count_Proxy(IEnumClusCfgPartitions *This,DWORD *pnCountOut);
  void __RPC_STUB IEnumClusCfgPartitions_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIEnumClusCfgPartitions_INTERFACE_DEFINED__
#define __AsyncIEnumClusCfgPartitions_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIEnumClusCfgPartitions;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIEnumClusCfgPartitions : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Next(ULONG cNumberRequestedIn) = 0;
    virtual HRESULT WINAPI Finish_Next(IClusCfgPartitionInfo **rgpPartitionInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Begin_Reset(void) = 0;
    virtual HRESULT WINAPI Finish_Reset(void) = 0;
    virtual HRESULT WINAPI Begin_Skip(ULONG cNumberToSkip) = 0;
    virtual HRESULT WINAPI Finish_Skip(void) = 0;
    virtual HRESULT WINAPI Begin_Clone(void) = 0;
    virtual HRESULT WINAPI Finish_Clone(IEnumClusCfgPartitions **ppEnumPartitions) = 0;
    virtual HRESULT WINAPI Begin_Count(void) = 0;
    virtual HRESULT WINAPI Finish_Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct AsyncIEnumClusCfgPartitionsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIEnumClusCfgPartitions *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIEnumClusCfgPartitions *This);
      ULONG (WINAPI *Release)(AsyncIEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Begin_Next)(AsyncIEnumClusCfgPartitions *This,ULONG cNumberRequestedIn);
      HRESULT (WINAPI *Finish_Next)(AsyncIEnumClusCfgPartitions *This,IClusCfgPartitionInfo **rgpPartitionInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Begin_Reset)(AsyncIEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Finish_Reset)(AsyncIEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Begin_Skip)(AsyncIEnumClusCfgPartitions *This,ULONG cNumberToSkip);
      HRESULT (WINAPI *Finish_Skip)(AsyncIEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Begin_Clone)(AsyncIEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Finish_Clone)(AsyncIEnumClusCfgPartitions *This,IEnumClusCfgPartitions **ppEnumPartitions);
      HRESULT (WINAPI *Begin_Count)(AsyncIEnumClusCfgPartitions *This);
      HRESULT (WINAPI *Finish_Count)(AsyncIEnumClusCfgPartitions *This,DWORD *pnCountOut);
    END_INTERFACE
  } AsyncIEnumClusCfgPartitionsVtbl;
  struct AsyncIEnumClusCfgPartitions {
    CONST_VTBL struct AsyncIEnumClusCfgPartitionsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIEnumClusCfgPartitions_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIEnumClusCfgPartitions_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIEnumClusCfgPartitions_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIEnumClusCfgPartitions_Begin_Next(This,cNumberRequestedIn) (This)->lpVtbl->Begin_Next(This,cNumberRequestedIn)
#define AsyncIEnumClusCfgPartitions_Finish_Next(This,rgpPartitionInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Finish_Next(This,rgpPartitionInfoOut,pcNumberFetchedOut)
#define AsyncIEnumClusCfgPartitions_Begin_Reset(This) (This)->lpVtbl->Begin_Reset(This)
#define AsyncIEnumClusCfgPartitions_Finish_Reset(This) (This)->lpVtbl->Finish_Reset(This)
#define AsyncIEnumClusCfgPartitions_Begin_Skip(This,cNumberToSkip) (This)->lpVtbl->Begin_Skip(This,cNumberToSkip)
#define AsyncIEnumClusCfgPartitions_Finish_Skip(This) (This)->lpVtbl->Finish_Skip(This)
#define AsyncIEnumClusCfgPartitions_Begin_Clone(This) (This)->lpVtbl->Begin_Clone(This)
#define AsyncIEnumClusCfgPartitions_Finish_Clone(This,ppEnumPartitions) (This)->lpVtbl->Finish_Clone(This,ppEnumPartitions)
#define AsyncIEnumClusCfgPartitions_Begin_Count(This) (This)->lpVtbl->Begin_Count(This)
#define AsyncIEnumClusCfgPartitions_Finish_Count(This,pnCountOut) (This)->lpVtbl->Finish_Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Begin_Next_Proxy(AsyncIEnumClusCfgPartitions *This,ULONG cNumberRequestedIn);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Begin_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Finish_Next_Proxy(AsyncIEnumClusCfgPartitions *This,IClusCfgPartitionInfo **rgpPartitionInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Finish_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Begin_Reset_Proxy(AsyncIEnumClusCfgPartitions *This);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Begin_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Finish_Reset_Proxy(AsyncIEnumClusCfgPartitions *This);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Finish_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Begin_Skip_Proxy(AsyncIEnumClusCfgPartitions *This,ULONG cNumberToSkip);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Begin_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Finish_Skip_Proxy(AsyncIEnumClusCfgPartitions *This);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Finish_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Begin_Clone_Proxy(AsyncIEnumClusCfgPartitions *This);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Begin_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Finish_Clone_Proxy(AsyncIEnumClusCfgPartitions *This,IEnumClusCfgPartitions **ppEnumPartitions);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Finish_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Begin_Count_Proxy(AsyncIEnumClusCfgPartitions *This);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Begin_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgPartitions_Finish_Count_Proxy(AsyncIEnumClusCfgPartitions *This,DWORD *pnCountOut);
  void __RPC_STUB AsyncIEnumClusCfgPartitions_Finish_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgPartitionInfo_INTERFACE_DEFINED__
#define __IClusCfgPartitionInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgPartitionInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgPartitionInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI GetDescription(BSTR *pbstrDescriptionOut) = 0;
    virtual HRESULT WINAPI SetDescription(LPCWSTR pcszDescriptionIn) = 0;
    virtual HRESULT WINAPI GetDriveLetterMappings(SDriveLetterMapping *pdlmDriveLetterUsageOut) = 0;
    virtual HRESULT WINAPI SetDriveLetterMappings(SDriveLetterMapping dlmDriveLetterMappingIn) = 0;
    virtual HRESULT WINAPI GetSize(ULONG *pcMegaBytes) = 0;
  };
#else
  typedef struct IClusCfgPartitionInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgPartitionInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgPartitionInfo *This);
      ULONG (WINAPI *Release)(IClusCfgPartitionInfo *This);
      HRESULT (WINAPI *GetUID)(IClusCfgPartitionInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *GetName)(IClusCfgPartitionInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *SetName)(IClusCfgPartitionInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *GetDescription)(IClusCfgPartitionInfo *This,BSTR *pbstrDescriptionOut);
      HRESULT (WINAPI *SetDescription)(IClusCfgPartitionInfo *This,LPCWSTR pcszDescriptionIn);
      HRESULT (WINAPI *GetDriveLetterMappings)(IClusCfgPartitionInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
      HRESULT (WINAPI *SetDriveLetterMappings)(IClusCfgPartitionInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
      HRESULT (WINAPI *GetSize)(IClusCfgPartitionInfo *This,ULONG *pcMegaBytes);
    END_INTERFACE
  } IClusCfgPartitionInfoVtbl;
  struct IClusCfgPartitionInfo {
    CONST_VTBL struct IClusCfgPartitionInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgPartitionInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgPartitionInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgPartitionInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgPartitionInfo_GetUID(This,pbstrUIDOut) (This)->lpVtbl->GetUID(This,pbstrUIDOut)
#define IClusCfgPartitionInfo_GetName(This,pbstrNameOut) (This)->lpVtbl->GetName(This,pbstrNameOut)
#define IClusCfgPartitionInfo_SetName(This,pcszNameIn) (This)->lpVtbl->SetName(This,pcszNameIn)
#define IClusCfgPartitionInfo_GetDescription(This,pbstrDescriptionOut) (This)->lpVtbl->GetDescription(This,pbstrDescriptionOut)
#define IClusCfgPartitionInfo_SetDescription(This,pcszDescriptionIn) (This)->lpVtbl->SetDescription(This,pcszDescriptionIn)
#define IClusCfgPartitionInfo_GetDriveLetterMappings(This,pdlmDriveLetterUsageOut) (This)->lpVtbl->GetDriveLetterMappings(This,pdlmDriveLetterUsageOut)
#define IClusCfgPartitionInfo_SetDriveLetterMappings(This,dlmDriveLetterMappingIn) (This)->lpVtbl->SetDriveLetterMappings(This,dlmDriveLetterMappingIn)
#define IClusCfgPartitionInfo_GetSize(This,pcMegaBytes) (This)->lpVtbl->GetSize(This,pcMegaBytes)
#endif
#endif
  HRESULT WINAPI IClusCfgPartitionInfo_GetUID_Proxy(IClusCfgPartitionInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB IClusCfgPartitionInfo_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_GetName_Proxy(IClusCfgPartitionInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB IClusCfgPartitionInfo_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_SetName_Proxy(IClusCfgPartitionInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgPartitionInfo_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_GetDescription_Proxy(IClusCfgPartitionInfo *This,BSTR *pbstrDescriptionOut);
  void __RPC_STUB IClusCfgPartitionInfo_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_SetDescription_Proxy(IClusCfgPartitionInfo *This,LPCWSTR pcszDescriptionIn);
  void __RPC_STUB IClusCfgPartitionInfo_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_GetDriveLetterMappings_Proxy(IClusCfgPartitionInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
  void __RPC_STUB IClusCfgPartitionInfo_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_SetDriveLetterMappings_Proxy(IClusCfgPartitionInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
  void __RPC_STUB IClusCfgPartitionInfo_SetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgPartitionInfo_GetSize_Proxy(IClusCfgPartitionInfo *This,ULONG *pcMegaBytes);
  void __RPC_STUB IClusCfgPartitionInfo_GetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgPartitionInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgPartitionInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgPartitionInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgPartitionInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_GetUID(void) = 0;
    virtual HRESULT WINAPI Finish_GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI Begin_GetName(void) = 0;
    virtual HRESULT WINAPI Finish_GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI Begin_SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI Finish_SetName(void) = 0;
    virtual HRESULT WINAPI Begin_GetDescription(void) = 0;
    virtual HRESULT WINAPI Finish_GetDescription(BSTR *pbstrDescriptionOut) = 0;
    virtual HRESULT WINAPI Begin_SetDescription(LPCWSTR pcszDescriptionIn) = 0;
    virtual HRESULT WINAPI Finish_SetDescription(void) = 0;
    virtual HRESULT WINAPI Begin_GetDriveLetterMappings(void) = 0;
    virtual HRESULT WINAPI Finish_GetDriveLetterMappings(SDriveLetterMapping *pdlmDriveLetterUsageOut) = 0;
    virtual HRESULT WINAPI Begin_SetDriveLetterMappings(SDriveLetterMapping dlmDriveLetterMappingIn) = 0;
    virtual HRESULT WINAPI Finish_SetDriveLetterMappings(void) = 0;
    virtual HRESULT WINAPI Begin_GetSize(void) = 0;
    virtual HRESULT WINAPI Finish_GetSize(ULONG *pcMegaBytes) = 0;
  };
#else
  typedef struct AsyncIClusCfgPartitionInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgPartitionInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgPartitionInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Begin_GetUID)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Finish_GetUID)(AsyncIClusCfgPartitionInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *Begin_GetName)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Finish_GetName)(AsyncIClusCfgPartitionInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *Begin_SetName)(AsyncIClusCfgPartitionInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *Finish_SetName)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Begin_GetDescription)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Finish_GetDescription)(AsyncIClusCfgPartitionInfo *This,BSTR *pbstrDescriptionOut);
      HRESULT (WINAPI *Begin_SetDescription)(AsyncIClusCfgPartitionInfo *This,LPCWSTR pcszDescriptionIn);
      HRESULT (WINAPI *Finish_SetDescription)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Begin_GetDriveLetterMappings)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Finish_GetDriveLetterMappings)(AsyncIClusCfgPartitionInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
      HRESULT (WINAPI *Begin_SetDriveLetterMappings)(AsyncIClusCfgPartitionInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
      HRESULT (WINAPI *Finish_SetDriveLetterMappings)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Begin_GetSize)(AsyncIClusCfgPartitionInfo *This);
      HRESULT (WINAPI *Finish_GetSize)(AsyncIClusCfgPartitionInfo *This,ULONG *pcMegaBytes);
    END_INTERFACE
  } AsyncIClusCfgPartitionInfoVtbl;
  struct AsyncIClusCfgPartitionInfo {
    CONST_VTBL struct AsyncIClusCfgPartitionInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgPartitionInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgPartitionInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgPartitionInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgPartitionInfo_Begin_GetUID(This) (This)->lpVtbl->Begin_GetUID(This)
#define AsyncIClusCfgPartitionInfo_Finish_GetUID(This,pbstrUIDOut) (This)->lpVtbl->Finish_GetUID(This,pbstrUIDOut)
#define AsyncIClusCfgPartitionInfo_Begin_GetName(This) (This)->lpVtbl->Begin_GetName(This)
#define AsyncIClusCfgPartitionInfo_Finish_GetName(This,pbstrNameOut) (This)->lpVtbl->Finish_GetName(This,pbstrNameOut)
#define AsyncIClusCfgPartitionInfo_Begin_SetName(This,pcszNameIn) (This)->lpVtbl->Begin_SetName(This,pcszNameIn)
#define AsyncIClusCfgPartitionInfo_Finish_SetName(This) (This)->lpVtbl->Finish_SetName(This)
#define AsyncIClusCfgPartitionInfo_Begin_GetDescription(This) (This)->lpVtbl->Begin_GetDescription(This)
#define AsyncIClusCfgPartitionInfo_Finish_GetDescription(This,pbstrDescriptionOut) (This)->lpVtbl->Finish_GetDescription(This,pbstrDescriptionOut)
#define AsyncIClusCfgPartitionInfo_Begin_SetDescription(This,pcszDescriptionIn) (This)->lpVtbl->Begin_SetDescription(This,pcszDescriptionIn)
#define AsyncIClusCfgPartitionInfo_Finish_SetDescription(This) (This)->lpVtbl->Finish_SetDescription(This)
#define AsyncIClusCfgPartitionInfo_Begin_GetDriveLetterMappings(This) (This)->lpVtbl->Begin_GetDriveLetterMappings(This)
#define AsyncIClusCfgPartitionInfo_Finish_GetDriveLetterMappings(This,pdlmDriveLetterUsageOut) (This)->lpVtbl->Finish_GetDriveLetterMappings(This,pdlmDriveLetterUsageOut)
#define AsyncIClusCfgPartitionInfo_Begin_SetDriveLetterMappings(This,dlmDriveLetterMappingIn) (This)->lpVtbl->Begin_SetDriveLetterMappings(This,dlmDriveLetterMappingIn)
#define AsyncIClusCfgPartitionInfo_Finish_SetDriveLetterMappings(This) (This)->lpVtbl->Finish_SetDriveLetterMappings(This)
#define AsyncIClusCfgPartitionInfo_Begin_GetSize(This) (This)->lpVtbl->Begin_GetSize(This)
#define AsyncIClusCfgPartitionInfo_Finish_GetSize(This,pcMegaBytes) (This)->lpVtbl->Finish_GetSize(This,pcMegaBytes)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_GetUID_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_GetUID_Proxy(AsyncIClusCfgPartitionInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_GetName_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_GetName_Proxy(AsyncIClusCfgPartitionInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_SetName_Proxy(AsyncIClusCfgPartitionInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_SetName_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_GetDescription_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_GetDescription_Proxy(AsyncIClusCfgPartitionInfo *This,BSTR *pbstrDescriptionOut);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_SetDescription_Proxy(AsyncIClusCfgPartitionInfo *This,LPCWSTR pcszDescriptionIn);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_SetDescription_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_GetDriveLetterMappings_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_GetDriveLetterMappings_Proxy(AsyncIClusCfgPartitionInfo *This,SDriveLetterMapping *pdlmDriveLetterUsageOut);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_GetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_SetDriveLetterMappings_Proxy(AsyncIClusCfgPartitionInfo *This,SDriveLetterMapping dlmDriveLetterMappingIn);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_SetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_SetDriveLetterMappings_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_SetDriveLetterMappings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Begin_GetSize_Proxy(AsyncIClusCfgPartitionInfo *This);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Begin_GetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgPartitionInfo_Finish_GetSize_Proxy(AsyncIClusCfgPartitionInfo *This,ULONG *pcMegaBytes);
  void __RPC_STUB AsyncIClusCfgPartitionInfo_Finish_GetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumClusCfgIPAddresses_INTERFACE_DEFINED__
#define __IEnumClusCfgIPAddresses_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumClusCfgIPAddresses;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumClusCfgIPAddresses : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG cNumberRequestedIn,IClusCfgIPAddressInfo **rgpIPAddressInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Skip(ULONG cNumberToSkipIn) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumClusCfgIPAddresses **ppEnumIPAddressesOut) = 0;
    virtual HRESULT WINAPI Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct IEnumClusCfgIPAddressesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumClusCfgIPAddresses *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumClusCfgIPAddresses *This);
      ULONG (WINAPI *Release)(IEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Next)(IEnumClusCfgIPAddresses *This,ULONG cNumberRequestedIn,IClusCfgIPAddressInfo **rgpIPAddressInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Skip)(IEnumClusCfgIPAddresses *This,ULONG cNumberToSkipIn);
      HRESULT (WINAPI *Reset)(IEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Clone)(IEnumClusCfgIPAddresses *This,IEnumClusCfgIPAddresses **ppEnumIPAddressesOut);
      HRESULT (WINAPI *Count)(IEnumClusCfgIPAddresses *This,DWORD *pnCountOut);
    END_INTERFACE
  } IEnumClusCfgIPAddressesVtbl;
  struct IEnumClusCfgIPAddresses {
    CONST_VTBL struct IEnumClusCfgIPAddressesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumClusCfgIPAddresses_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumClusCfgIPAddresses_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumClusCfgIPAddresses_Release(This) (This)->lpVtbl->Release(This)
#define IEnumClusCfgIPAddresses_Next(This,cNumberRequestedIn,rgpIPAddressInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Next(This,cNumberRequestedIn,rgpIPAddressInfoOut,pcNumberFetchedOut)
#define IEnumClusCfgIPAddresses_Skip(This,cNumberToSkipIn) (This)->lpVtbl->Skip(This,cNumberToSkipIn)
#define IEnumClusCfgIPAddresses_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumClusCfgIPAddresses_Clone(This,ppEnumIPAddressesOut) (This)->lpVtbl->Clone(This,ppEnumIPAddressesOut)
#define IEnumClusCfgIPAddresses_Count(This,pnCountOut) (This)->lpVtbl->Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI IEnumClusCfgIPAddresses_Next_Proxy(IEnumClusCfgIPAddresses *This,ULONG cNumberRequestedIn,IClusCfgIPAddressInfo **rgpIPAddressInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB IEnumClusCfgIPAddresses_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgIPAddresses_Skip_Proxy(IEnumClusCfgIPAddresses *This,ULONG cNumberToSkipIn);
  void __RPC_STUB IEnumClusCfgIPAddresses_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgIPAddresses_Reset_Proxy(IEnumClusCfgIPAddresses *This);
  void __RPC_STUB IEnumClusCfgIPAddresses_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgIPAddresses_Clone_Proxy(IEnumClusCfgIPAddresses *This,IEnumClusCfgIPAddresses **ppEnumIPAddressesOut);
  void __RPC_STUB IEnumClusCfgIPAddresses_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumClusCfgIPAddresses_Count_Proxy(IEnumClusCfgIPAddresses *This,DWORD *pnCountOut);
  void __RPC_STUB IEnumClusCfgIPAddresses_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIEnumClusCfgIPAddresses_INTERFACE_DEFINED__
#define __AsyncIEnumClusCfgIPAddresses_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIEnumClusCfgIPAddresses;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIEnumClusCfgIPAddresses : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Next(ULONG cNumberRequestedIn) = 0;
    virtual HRESULT WINAPI Finish_Next(IClusCfgIPAddressInfo **rgpIPAddressInfoOut,ULONG *pcNumberFetchedOut) = 0;
    virtual HRESULT WINAPI Begin_Skip(ULONG cNumberToSkipIn) = 0;
    virtual HRESULT WINAPI Finish_Skip(void) = 0;
    virtual HRESULT WINAPI Begin_Reset(void) = 0;
    virtual HRESULT WINAPI Finish_Reset(void) = 0;
    virtual HRESULT WINAPI Begin_Clone(void) = 0;
    virtual HRESULT WINAPI Finish_Clone(IEnumClusCfgIPAddresses **ppEnumIPAddressesOut) = 0;
    virtual HRESULT WINAPI Begin_Count(void) = 0;
    virtual HRESULT WINAPI Finish_Count(DWORD *pnCountOut) = 0;
  };
#else
  typedef struct AsyncIEnumClusCfgIPAddressesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIEnumClusCfgIPAddresses *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIEnumClusCfgIPAddresses *This);
      ULONG (WINAPI *Release)(AsyncIEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Begin_Next)(AsyncIEnumClusCfgIPAddresses *This,ULONG cNumberRequestedIn);
      HRESULT (WINAPI *Finish_Next)(AsyncIEnumClusCfgIPAddresses *This,IClusCfgIPAddressInfo **rgpIPAddressInfoOut,ULONG *pcNumberFetchedOut);
      HRESULT (WINAPI *Begin_Skip)(AsyncIEnumClusCfgIPAddresses *This,ULONG cNumberToSkipIn);
      HRESULT (WINAPI *Finish_Skip)(AsyncIEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Begin_Reset)(AsyncIEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Finish_Reset)(AsyncIEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Begin_Clone)(AsyncIEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Finish_Clone)(AsyncIEnumClusCfgIPAddresses *This,IEnumClusCfgIPAddresses **ppEnumIPAddressesOut);
      HRESULT (WINAPI *Begin_Count)(AsyncIEnumClusCfgIPAddresses *This);
      HRESULT (WINAPI *Finish_Count)(AsyncIEnumClusCfgIPAddresses *This,DWORD *pnCountOut);
    END_INTERFACE
  } AsyncIEnumClusCfgIPAddressesVtbl;
  struct AsyncIEnumClusCfgIPAddresses {
    CONST_VTBL struct AsyncIEnumClusCfgIPAddressesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIEnumClusCfgIPAddresses_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIEnumClusCfgIPAddresses_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIEnumClusCfgIPAddresses_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIEnumClusCfgIPAddresses_Begin_Next(This,cNumberRequestedIn) (This)->lpVtbl->Begin_Next(This,cNumberRequestedIn)
#define AsyncIEnumClusCfgIPAddresses_Finish_Next(This,rgpIPAddressInfoOut,pcNumberFetchedOut) (This)->lpVtbl->Finish_Next(This,rgpIPAddressInfoOut,pcNumberFetchedOut)
#define AsyncIEnumClusCfgIPAddresses_Begin_Skip(This,cNumberToSkipIn) (This)->lpVtbl->Begin_Skip(This,cNumberToSkipIn)
#define AsyncIEnumClusCfgIPAddresses_Finish_Skip(This) (This)->lpVtbl->Finish_Skip(This)
#define AsyncIEnumClusCfgIPAddresses_Begin_Reset(This) (This)->lpVtbl->Begin_Reset(This)
#define AsyncIEnumClusCfgIPAddresses_Finish_Reset(This) (This)->lpVtbl->Finish_Reset(This)
#define AsyncIEnumClusCfgIPAddresses_Begin_Clone(This) (This)->lpVtbl->Begin_Clone(This)
#define AsyncIEnumClusCfgIPAddresses_Finish_Clone(This,ppEnumIPAddressesOut) (This)->lpVtbl->Finish_Clone(This,ppEnumIPAddressesOut)
#define AsyncIEnumClusCfgIPAddresses_Begin_Count(This) (This)->lpVtbl->Begin_Count(This)
#define AsyncIEnumClusCfgIPAddresses_Finish_Count(This,pnCountOut) (This)->lpVtbl->Finish_Count(This,pnCountOut)
#endif
#endif
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Begin_Next_Proxy(AsyncIEnumClusCfgIPAddresses *This,ULONG cNumberRequestedIn);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Begin_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Finish_Next_Proxy(AsyncIEnumClusCfgIPAddresses *This,IClusCfgIPAddressInfo **rgpIPAddressInfoOut,ULONG *pcNumberFetchedOut);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Finish_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Begin_Skip_Proxy(AsyncIEnumClusCfgIPAddresses *This,ULONG cNumberToSkipIn);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Begin_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Finish_Skip_Proxy(AsyncIEnumClusCfgIPAddresses *This);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Finish_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Begin_Reset_Proxy(AsyncIEnumClusCfgIPAddresses *This);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Begin_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Finish_Reset_Proxy(AsyncIEnumClusCfgIPAddresses *This);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Finish_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Begin_Clone_Proxy(AsyncIEnumClusCfgIPAddresses *This);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Begin_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Finish_Clone_Proxy(AsyncIEnumClusCfgIPAddresses *This,IEnumClusCfgIPAddresses **ppEnumIPAddressesOut);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Finish_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Begin_Count_Proxy(AsyncIEnumClusCfgIPAddresses *This);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Begin_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIEnumClusCfgIPAddresses_Finish_Count_Proxy(AsyncIEnumClusCfgIPAddresses *This,DWORD *pnCountOut);
  void __RPC_STUB AsyncIEnumClusCfgIPAddresses_Finish_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgIPAddressInfo_INTERFACE_DEFINED__
#define __IClusCfgIPAddressInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgIPAddressInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgIPAddressInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI GetIPAddress(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI SetIPAddress(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI GetSubnetMask(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI SetSubnetMask(ULONG ulDottedQuadIn) = 0;
  };
#else
  typedef struct IClusCfgIPAddressInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgIPAddressInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgIPAddressInfo *This);
      ULONG (WINAPI *Release)(IClusCfgIPAddressInfo *This);
      HRESULT (WINAPI *GetUID)(IClusCfgIPAddressInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *GetIPAddress)(IClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *SetIPAddress)(IClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *GetSubnetMask)(IClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *SetSubnetMask)(IClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
    END_INTERFACE
  } IClusCfgIPAddressInfoVtbl;
  struct IClusCfgIPAddressInfo {
    CONST_VTBL struct IClusCfgIPAddressInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgIPAddressInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgIPAddressInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgIPAddressInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgIPAddressInfo_GetUID(This,pbstrUIDOut) (This)->lpVtbl->GetUID(This,pbstrUIDOut)
#define IClusCfgIPAddressInfo_GetIPAddress(This,pulDottedQuadOut) (This)->lpVtbl->GetIPAddress(This,pulDottedQuadOut)
#define IClusCfgIPAddressInfo_SetIPAddress(This,ulDottedQuadIn) (This)->lpVtbl->SetIPAddress(This,ulDottedQuadIn)
#define IClusCfgIPAddressInfo_GetSubnetMask(This,pulDottedQuadOut) (This)->lpVtbl->GetSubnetMask(This,pulDottedQuadOut)
#define IClusCfgIPAddressInfo_SetSubnetMask(This,ulDottedQuadIn) (This)->lpVtbl->SetSubnetMask(This,ulDottedQuadIn)
#endif
#endif
  HRESULT WINAPI IClusCfgIPAddressInfo_GetUID_Proxy(IClusCfgIPAddressInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB IClusCfgIPAddressInfo_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgIPAddressInfo_GetIPAddress_Proxy(IClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB IClusCfgIPAddressInfo_GetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgIPAddressInfo_SetIPAddress_Proxy(IClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB IClusCfgIPAddressInfo_SetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgIPAddressInfo_GetSubnetMask_Proxy(IClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB IClusCfgIPAddressInfo_GetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgIPAddressInfo_SetSubnetMask_Proxy(IClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB IClusCfgIPAddressInfo_SetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgIPAddressInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgIPAddressInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgIPAddressInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgIPAddressInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_GetUID(void) = 0;
    virtual HRESULT WINAPI Finish_GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI Begin_GetIPAddress(void) = 0;
    virtual HRESULT WINAPI Finish_GetIPAddress(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI Begin_SetIPAddress(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI Finish_SetIPAddress(void) = 0;
    virtual HRESULT WINAPI Begin_GetSubnetMask(void) = 0;
    virtual HRESULT WINAPI Finish_GetSubnetMask(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI Begin_SetSubnetMask(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI Finish_SetSubnetMask(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgIPAddressInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgIPAddressInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgIPAddressInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgIPAddressInfo *This);
      HRESULT (WINAPI *Begin_GetUID)(AsyncIClusCfgIPAddressInfo *This);
      HRESULT (WINAPI *Finish_GetUID)(AsyncIClusCfgIPAddressInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *Begin_GetIPAddress)(AsyncIClusCfgIPAddressInfo *This);
      HRESULT (WINAPI *Finish_GetIPAddress)(AsyncIClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *Begin_SetIPAddress)(AsyncIClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *Finish_SetIPAddress)(AsyncIClusCfgIPAddressInfo *This);
      HRESULT (WINAPI *Begin_GetSubnetMask)(AsyncIClusCfgIPAddressInfo *This);
      HRESULT (WINAPI *Finish_GetSubnetMask)(AsyncIClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *Begin_SetSubnetMask)(AsyncIClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *Finish_SetSubnetMask)(AsyncIClusCfgIPAddressInfo *This);
    END_INTERFACE
  } AsyncIClusCfgIPAddressInfoVtbl;
  struct AsyncIClusCfgIPAddressInfo {
    CONST_VTBL struct AsyncIClusCfgIPAddressInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgIPAddressInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgIPAddressInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgIPAddressInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgIPAddressInfo_Begin_GetUID(This) (This)->lpVtbl->Begin_GetUID(This)
#define AsyncIClusCfgIPAddressInfo_Finish_GetUID(This,pbstrUIDOut) (This)->lpVtbl->Finish_GetUID(This,pbstrUIDOut)
#define AsyncIClusCfgIPAddressInfo_Begin_GetIPAddress(This) (This)->lpVtbl->Begin_GetIPAddress(This)
#define AsyncIClusCfgIPAddressInfo_Finish_GetIPAddress(This,pulDottedQuadOut) (This)->lpVtbl->Finish_GetIPAddress(This,pulDottedQuadOut)
#define AsyncIClusCfgIPAddressInfo_Begin_SetIPAddress(This,ulDottedQuadIn) (This)->lpVtbl->Begin_SetIPAddress(This,ulDottedQuadIn)
#define AsyncIClusCfgIPAddressInfo_Finish_SetIPAddress(This) (This)->lpVtbl->Finish_SetIPAddress(This)
#define AsyncIClusCfgIPAddressInfo_Begin_GetSubnetMask(This) (This)->lpVtbl->Begin_GetSubnetMask(This)
#define AsyncIClusCfgIPAddressInfo_Finish_GetSubnetMask(This,pulDottedQuadOut) (This)->lpVtbl->Finish_GetSubnetMask(This,pulDottedQuadOut)
#define AsyncIClusCfgIPAddressInfo_Begin_SetSubnetMask(This,ulDottedQuadIn) (This)->lpVtbl->Begin_SetSubnetMask(This,ulDottedQuadIn)
#define AsyncIClusCfgIPAddressInfo_Finish_SetSubnetMask(This) (This)->lpVtbl->Finish_SetSubnetMask(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Begin_GetUID_Proxy(AsyncIClusCfgIPAddressInfo *This);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Begin_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Finish_GetUID_Proxy(AsyncIClusCfgIPAddressInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Finish_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Begin_GetIPAddress_Proxy(AsyncIClusCfgIPAddressInfo *This);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Begin_GetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Finish_GetIPAddress_Proxy(AsyncIClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Finish_GetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Begin_SetIPAddress_Proxy(AsyncIClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Begin_SetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Finish_SetIPAddress_Proxy(AsyncIClusCfgIPAddressInfo *This);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Finish_SetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Begin_GetSubnetMask_Proxy(AsyncIClusCfgIPAddressInfo *This);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Begin_GetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Finish_GetSubnetMask_Proxy(AsyncIClusCfgIPAddressInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Finish_GetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Begin_SetSubnetMask_Proxy(AsyncIClusCfgIPAddressInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Begin_SetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgIPAddressInfo_Finish_SetSubnetMask_Proxy(AsyncIClusCfgIPAddressInfo *This);
  void __RPC_STUB AsyncIClusCfgIPAddressInfo_Finish_SetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgNetworkInfo_INTERFACE_DEFINED__
#define __IClusCfgNetworkInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgNetworkInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgNetworkInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI GetDescription(BSTR *pbstrDescriptionOut) = 0;
    virtual HRESULT WINAPI SetDescription(LPCWSTR pcszDescriptionIn) = 0;
    virtual HRESULT WINAPI GetPrimaryNetworkAddress(IClusCfgIPAddressInfo **ppIPAddressOut) = 0;
    virtual HRESULT WINAPI SetPrimaryNetworkAddress(IClusCfgIPAddressInfo *pIPAddressIn) = 0;
    virtual HRESULT WINAPI IsPublic(void) = 0;
    virtual HRESULT WINAPI SetPublic(WINBOOL fIsPublicIn) = 0;
    virtual HRESULT WINAPI IsPrivate(void) = 0;
    virtual HRESULT WINAPI SetPrivate(WINBOOL fIsPrivateIn) = 0;
  };
#else
  typedef struct IClusCfgNetworkInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgNetworkInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgNetworkInfo *This);
      ULONG (WINAPI *Release)(IClusCfgNetworkInfo *This);
      HRESULT (WINAPI *GetUID)(IClusCfgNetworkInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *GetName)(IClusCfgNetworkInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *SetName)(IClusCfgNetworkInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *GetDescription)(IClusCfgNetworkInfo *This,BSTR *pbstrDescriptionOut);
      HRESULT (WINAPI *SetDescription)(IClusCfgNetworkInfo *This,LPCWSTR pcszDescriptionIn);
      HRESULT (WINAPI *GetPrimaryNetworkAddress)(IClusCfgNetworkInfo *This,IClusCfgIPAddressInfo **ppIPAddressOut);
      HRESULT (WINAPI *SetPrimaryNetworkAddress)(IClusCfgNetworkInfo *This,IClusCfgIPAddressInfo *pIPAddressIn);
      HRESULT (WINAPI *IsPublic)(IClusCfgNetworkInfo *This);
      HRESULT (WINAPI *SetPublic)(IClusCfgNetworkInfo *This,WINBOOL fIsPublicIn);
      HRESULT (WINAPI *IsPrivate)(IClusCfgNetworkInfo *This);
      HRESULT (WINAPI *SetPrivate)(IClusCfgNetworkInfo *This,WINBOOL fIsPrivateIn);
    END_INTERFACE
  } IClusCfgNetworkInfoVtbl;
  struct IClusCfgNetworkInfo {
    CONST_VTBL struct IClusCfgNetworkInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgNetworkInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgNetworkInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgNetworkInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgNetworkInfo_GetUID(This,pbstrUIDOut) (This)->lpVtbl->GetUID(This,pbstrUIDOut)
#define IClusCfgNetworkInfo_GetName(This,pbstrNameOut) (This)->lpVtbl->GetName(This,pbstrNameOut)
#define IClusCfgNetworkInfo_SetName(This,pcszNameIn) (This)->lpVtbl->SetName(This,pcszNameIn)
#define IClusCfgNetworkInfo_GetDescription(This,pbstrDescriptionOut) (This)->lpVtbl->GetDescription(This,pbstrDescriptionOut)
#define IClusCfgNetworkInfo_SetDescription(This,pcszDescriptionIn) (This)->lpVtbl->SetDescription(This,pcszDescriptionIn)
#define IClusCfgNetworkInfo_GetPrimaryNetworkAddress(This,ppIPAddressOut) (This)->lpVtbl->GetPrimaryNetworkAddress(This,ppIPAddressOut)
#define IClusCfgNetworkInfo_SetPrimaryNetworkAddress(This,pIPAddressIn) (This)->lpVtbl->SetPrimaryNetworkAddress(This,pIPAddressIn)
#define IClusCfgNetworkInfo_IsPublic(This) (This)->lpVtbl->IsPublic(This)
#define IClusCfgNetworkInfo_SetPublic(This,fIsPublicIn) (This)->lpVtbl->SetPublic(This,fIsPublicIn)
#define IClusCfgNetworkInfo_IsPrivate(This) (This)->lpVtbl->IsPrivate(This)
#define IClusCfgNetworkInfo_SetPrivate(This,fIsPrivateIn) (This)->lpVtbl->SetPrivate(This,fIsPrivateIn)
#endif
#endif
  HRESULT WINAPI IClusCfgNetworkInfo_GetUID_Proxy(IClusCfgNetworkInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB IClusCfgNetworkInfo_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_GetName_Proxy(IClusCfgNetworkInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB IClusCfgNetworkInfo_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_SetName_Proxy(IClusCfgNetworkInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgNetworkInfo_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_GetDescription_Proxy(IClusCfgNetworkInfo *This,BSTR *pbstrDescriptionOut);
  void __RPC_STUB IClusCfgNetworkInfo_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_SetDescription_Proxy(IClusCfgNetworkInfo *This,LPCWSTR pcszDescriptionIn);
  void __RPC_STUB IClusCfgNetworkInfo_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_GetPrimaryNetworkAddress_Proxy(IClusCfgNetworkInfo *This,IClusCfgIPAddressInfo **ppIPAddressOut);
  void __RPC_STUB IClusCfgNetworkInfo_GetPrimaryNetworkAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_SetPrimaryNetworkAddress_Proxy(IClusCfgNetworkInfo *This,IClusCfgIPAddressInfo *pIPAddressIn);
  void __RPC_STUB IClusCfgNetworkInfo_SetPrimaryNetworkAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_IsPublic_Proxy(IClusCfgNetworkInfo *This);
  void __RPC_STUB IClusCfgNetworkInfo_IsPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_SetPublic_Proxy(IClusCfgNetworkInfo *This,WINBOOL fIsPublicIn);
  void __RPC_STUB IClusCfgNetworkInfo_SetPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_IsPrivate_Proxy(IClusCfgNetworkInfo *This);
  void __RPC_STUB IClusCfgNetworkInfo_IsPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgNetworkInfo_SetPrivate_Proxy(IClusCfgNetworkInfo *This,WINBOOL fIsPrivateIn);
  void __RPC_STUB IClusCfgNetworkInfo_SetPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgNetworkInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgNetworkInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgNetworkInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgNetworkInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_GetUID(void) = 0;
    virtual HRESULT WINAPI Finish_GetUID(BSTR *pbstrUIDOut) = 0;
    virtual HRESULT WINAPI Begin_GetName(void) = 0;
    virtual HRESULT WINAPI Finish_GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI Begin_SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI Finish_SetName(void) = 0;
    virtual HRESULT WINAPI Begin_GetDescription(void) = 0;
    virtual HRESULT WINAPI Finish_GetDescription(BSTR *pbstrDescriptionOut) = 0;
    virtual HRESULT WINAPI Begin_SetDescription(LPCWSTR pcszDescriptionIn) = 0;
    virtual HRESULT WINAPI Finish_SetDescription(void) = 0;
    virtual HRESULT WINAPI Begin_GetPrimaryNetworkAddress(void) = 0;
    virtual HRESULT WINAPI Finish_GetPrimaryNetworkAddress(IClusCfgIPAddressInfo **ppIPAddressOut) = 0;
    virtual HRESULT WINAPI Begin_SetPrimaryNetworkAddress(IClusCfgIPAddressInfo *pIPAddressIn) = 0;
    virtual HRESULT WINAPI Finish_SetPrimaryNetworkAddress(void) = 0;
    virtual HRESULT WINAPI Begin_IsPublic(void) = 0;
    virtual HRESULT WINAPI Finish_IsPublic(void) = 0;
    virtual HRESULT WINAPI Begin_SetPublic(WINBOOL fIsPublicIn) = 0;
    virtual HRESULT WINAPI Finish_SetPublic(void) = 0;
    virtual HRESULT WINAPI Begin_IsPrivate(void) = 0;
    virtual HRESULT WINAPI Finish_IsPrivate(void) = 0;
    virtual HRESULT WINAPI Begin_SetPrivate(WINBOOL fIsPrivateIn) = 0;
    virtual HRESULT WINAPI Finish_SetPrivate(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgNetworkInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgNetworkInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgNetworkInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_GetUID)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Finish_GetUID)(AsyncIClusCfgNetworkInfo *This,BSTR *pbstrUIDOut);
      HRESULT (WINAPI *Begin_GetName)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Finish_GetName)(AsyncIClusCfgNetworkInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *Begin_SetName)(AsyncIClusCfgNetworkInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *Finish_SetName)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_GetDescription)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Finish_GetDescription)(AsyncIClusCfgNetworkInfo *This,BSTR *pbstrDescriptionOut);
      HRESULT (WINAPI *Begin_SetDescription)(AsyncIClusCfgNetworkInfo *This,LPCWSTR pcszDescriptionIn);
      HRESULT (WINAPI *Finish_SetDescription)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_GetPrimaryNetworkAddress)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Finish_GetPrimaryNetworkAddress)(AsyncIClusCfgNetworkInfo *This,IClusCfgIPAddressInfo **ppIPAddressOut);
      HRESULT (WINAPI *Begin_SetPrimaryNetworkAddress)(AsyncIClusCfgNetworkInfo *This,IClusCfgIPAddressInfo *pIPAddressIn);
      HRESULT (WINAPI *Finish_SetPrimaryNetworkAddress)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_IsPublic)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Finish_IsPublic)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_SetPublic)(AsyncIClusCfgNetworkInfo *This,WINBOOL fIsPublicIn);
      HRESULT (WINAPI *Finish_SetPublic)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_IsPrivate)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Finish_IsPrivate)(AsyncIClusCfgNetworkInfo *This);
      HRESULT (WINAPI *Begin_SetPrivate)(AsyncIClusCfgNetworkInfo *This,WINBOOL fIsPrivateIn);
      HRESULT (WINAPI *Finish_SetPrivate)(AsyncIClusCfgNetworkInfo *This);
    END_INTERFACE
  } AsyncIClusCfgNetworkInfoVtbl;
  struct AsyncIClusCfgNetworkInfo {
    CONST_VTBL struct AsyncIClusCfgNetworkInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgNetworkInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgNetworkInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgNetworkInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgNetworkInfo_Begin_GetUID(This) (This)->lpVtbl->Begin_GetUID(This)
#define AsyncIClusCfgNetworkInfo_Finish_GetUID(This,pbstrUIDOut) (This)->lpVtbl->Finish_GetUID(This,pbstrUIDOut)
#define AsyncIClusCfgNetworkInfo_Begin_GetName(This) (This)->lpVtbl->Begin_GetName(This)
#define AsyncIClusCfgNetworkInfo_Finish_GetName(This,pbstrNameOut) (This)->lpVtbl->Finish_GetName(This,pbstrNameOut)
#define AsyncIClusCfgNetworkInfo_Begin_SetName(This,pcszNameIn) (This)->lpVtbl->Begin_SetName(This,pcszNameIn)
#define AsyncIClusCfgNetworkInfo_Finish_SetName(This) (This)->lpVtbl->Finish_SetName(This)
#define AsyncIClusCfgNetworkInfo_Begin_GetDescription(This) (This)->lpVtbl->Begin_GetDescription(This)
#define AsyncIClusCfgNetworkInfo_Finish_GetDescription(This,pbstrDescriptionOut) (This)->lpVtbl->Finish_GetDescription(This,pbstrDescriptionOut)
#define AsyncIClusCfgNetworkInfo_Begin_SetDescription(This,pcszDescriptionIn) (This)->lpVtbl->Begin_SetDescription(This,pcszDescriptionIn)
#define AsyncIClusCfgNetworkInfo_Finish_SetDescription(This) (This)->lpVtbl->Finish_SetDescription(This)
#define AsyncIClusCfgNetworkInfo_Begin_GetPrimaryNetworkAddress(This) (This)->lpVtbl->Begin_GetPrimaryNetworkAddress(This)
#define AsyncIClusCfgNetworkInfo_Finish_GetPrimaryNetworkAddress(This,ppIPAddressOut) (This)->lpVtbl->Finish_GetPrimaryNetworkAddress(This,ppIPAddressOut)
#define AsyncIClusCfgNetworkInfo_Begin_SetPrimaryNetworkAddress(This,pIPAddressIn) (This)->lpVtbl->Begin_SetPrimaryNetworkAddress(This,pIPAddressIn)
#define AsyncIClusCfgNetworkInfo_Finish_SetPrimaryNetworkAddress(This) (This)->lpVtbl->Finish_SetPrimaryNetworkAddress(This)
#define AsyncIClusCfgNetworkInfo_Begin_IsPublic(This) (This)->lpVtbl->Begin_IsPublic(This)
#define AsyncIClusCfgNetworkInfo_Finish_IsPublic(This) (This)->lpVtbl->Finish_IsPublic(This)
#define AsyncIClusCfgNetworkInfo_Begin_SetPublic(This,fIsPublicIn) (This)->lpVtbl->Begin_SetPublic(This,fIsPublicIn)
#define AsyncIClusCfgNetworkInfo_Finish_SetPublic(This) (This)->lpVtbl->Finish_SetPublic(This)
#define AsyncIClusCfgNetworkInfo_Begin_IsPrivate(This) (This)->lpVtbl->Begin_IsPrivate(This)
#define AsyncIClusCfgNetworkInfo_Finish_IsPrivate(This) (This)->lpVtbl->Finish_IsPrivate(This)
#define AsyncIClusCfgNetworkInfo_Begin_SetPrivate(This,fIsPrivateIn) (This)->lpVtbl->Begin_SetPrivate(This,fIsPrivateIn)
#define AsyncIClusCfgNetworkInfo_Finish_SetPrivate(This) (This)->lpVtbl->Finish_SetPrivate(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_GetUID_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_GetUID_Proxy(AsyncIClusCfgNetworkInfo *This,BSTR *pbstrUIDOut);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_GetUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_GetName_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_GetName_Proxy(AsyncIClusCfgNetworkInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_SetName_Proxy(AsyncIClusCfgNetworkInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_SetName_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_GetDescription_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_GetDescription_Proxy(AsyncIClusCfgNetworkInfo *This,BSTR *pbstrDescriptionOut);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_SetDescription_Proxy(AsyncIClusCfgNetworkInfo *This,LPCWSTR pcszDescriptionIn);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_SetDescription_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_GetPrimaryNetworkAddress_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_GetPrimaryNetworkAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_GetPrimaryNetworkAddress_Proxy(AsyncIClusCfgNetworkInfo *This,IClusCfgIPAddressInfo **ppIPAddressOut);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_GetPrimaryNetworkAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_SetPrimaryNetworkAddress_Proxy(AsyncIClusCfgNetworkInfo *This,IClusCfgIPAddressInfo *pIPAddressIn);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_SetPrimaryNetworkAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_SetPrimaryNetworkAddress_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_SetPrimaryNetworkAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_IsPublic_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_IsPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_IsPublic_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_IsPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_SetPublic_Proxy(AsyncIClusCfgNetworkInfo *This,WINBOOL fIsPublicIn);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_SetPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_SetPublic_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_SetPublic_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_IsPrivate_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_IsPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_IsPrivate_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_IsPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Begin_SetPrivate_Proxy(AsyncIClusCfgNetworkInfo *This,WINBOOL fIsPrivateIn);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Begin_SetPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgNetworkInfo_Finish_SetPrivate_Proxy(AsyncIClusCfgNetworkInfo *This);
  void __RPC_STUB AsyncIClusCfgNetworkInfo_Finish_SetPrivate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgClusterInfo_INTERFACE_DEFINED__
#define __IClusCfgClusterInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgClusterInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgClusterInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI SetCommitMode(ECommitMode ecmNewModeIn) = 0;
    virtual HRESULT WINAPI GetCommitMode(ECommitMode *pecmCurrentModeOut) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI GetIPAddress(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI SetIPAddress(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI GetSubnetMask(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI SetSubnetMask(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI GetNetworkInfo(IClusCfgNetworkInfo **ppiccniOut) = 0;
    virtual HRESULT WINAPI SetNetworkInfo(IClusCfgNetworkInfo *piccniIn) = 0;
    virtual HRESULT WINAPI GetClusterServiceAccountCredentials(IClusCfgCredentials **ppicccCredentialsOut) = 0;
    virtual HRESULT WINAPI GetBindingString(BSTR *pbstrBindingStringOut) = 0;
    virtual HRESULT WINAPI SetBindingString(LPCWSTR pcszBindingStringIn) = 0;
    virtual HRESULT WINAPI GetMaxNodeCount(DWORD *pcMaxNodesOut) = 0;
  };
#else
  typedef struct IClusCfgClusterInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgClusterInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgClusterInfo *This);
      ULONG (WINAPI *Release)(IClusCfgClusterInfo *This);
      HRESULT (WINAPI *SetCommitMode)(IClusCfgClusterInfo *This,ECommitMode ecmNewModeIn);
      HRESULT (WINAPI *GetCommitMode)(IClusCfgClusterInfo *This,ECommitMode *pecmCurrentModeOut);
      HRESULT (WINAPI *GetName)(IClusCfgClusterInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *SetName)(IClusCfgClusterInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *GetIPAddress)(IClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *SetIPAddress)(IClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *GetSubnetMask)(IClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *SetSubnetMask)(IClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *GetNetworkInfo)(IClusCfgClusterInfo *This,IClusCfgNetworkInfo **ppiccniOut);
      HRESULT (WINAPI *SetNetworkInfo)(IClusCfgClusterInfo *This,IClusCfgNetworkInfo *piccniIn);
      HRESULT (WINAPI *GetClusterServiceAccountCredentials)(IClusCfgClusterInfo *This,IClusCfgCredentials **ppicccCredentialsOut);
      HRESULT (WINAPI *GetBindingString)(IClusCfgClusterInfo *This,BSTR *pbstrBindingStringOut);
      HRESULT (WINAPI *SetBindingString)(IClusCfgClusterInfo *This,LPCWSTR pcszBindingStringIn);
      HRESULT (WINAPI *GetMaxNodeCount)(IClusCfgClusterInfo *This,DWORD *pcMaxNodesOut);
    END_INTERFACE
  } IClusCfgClusterInfoVtbl;
  struct IClusCfgClusterInfo {
    CONST_VTBL struct IClusCfgClusterInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgClusterInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgClusterInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgClusterInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgClusterInfo_SetCommitMode(This,ecmNewModeIn) (This)->lpVtbl->SetCommitMode(This,ecmNewModeIn)
#define IClusCfgClusterInfo_GetCommitMode(This,pecmCurrentModeOut) (This)->lpVtbl->GetCommitMode(This,pecmCurrentModeOut)
#define IClusCfgClusterInfo_GetName(This,pbstrNameOut) (This)->lpVtbl->GetName(This,pbstrNameOut)
#define IClusCfgClusterInfo_SetName(This,pcszNameIn) (This)->lpVtbl->SetName(This,pcszNameIn)
#define IClusCfgClusterInfo_GetIPAddress(This,pulDottedQuadOut) (This)->lpVtbl->GetIPAddress(This,pulDottedQuadOut)
#define IClusCfgClusterInfo_SetIPAddress(This,ulDottedQuadIn) (This)->lpVtbl->SetIPAddress(This,ulDottedQuadIn)
#define IClusCfgClusterInfo_GetSubnetMask(This,pulDottedQuadOut) (This)->lpVtbl->GetSubnetMask(This,pulDottedQuadOut)
#define IClusCfgClusterInfo_SetSubnetMask(This,ulDottedQuadIn) (This)->lpVtbl->SetSubnetMask(This,ulDottedQuadIn)
#define IClusCfgClusterInfo_GetNetworkInfo(This,ppiccniOut) (This)->lpVtbl->GetNetworkInfo(This,ppiccniOut)
#define IClusCfgClusterInfo_SetNetworkInfo(This,piccniIn) (This)->lpVtbl->SetNetworkInfo(This,piccniIn)
#define IClusCfgClusterInfo_GetClusterServiceAccountCredentials(This,ppicccCredentialsOut) (This)->lpVtbl->GetClusterServiceAccountCredentials(This,ppicccCredentialsOut)
#define IClusCfgClusterInfo_GetBindingString(This,pbstrBindingStringOut) (This)->lpVtbl->GetBindingString(This,pbstrBindingStringOut)
#define IClusCfgClusterInfo_SetBindingString(This,pcszBindingStringIn) (This)->lpVtbl->SetBindingString(This,pcszBindingStringIn)
#define IClusCfgClusterInfo_GetMaxNodeCount(This,pcMaxNodesOut) (This)->lpVtbl->GetMaxNodeCount(This,pcMaxNodesOut)
#endif
#endif
  HRESULT WINAPI IClusCfgClusterInfo_SetCommitMode_Proxy(IClusCfgClusterInfo *This,ECommitMode ecmNewModeIn);
  void __RPC_STUB IClusCfgClusterInfo_SetCommitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetCommitMode_Proxy(IClusCfgClusterInfo *This,ECommitMode *pecmCurrentModeOut);
  void __RPC_STUB IClusCfgClusterInfo_GetCommitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetName_Proxy(IClusCfgClusterInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB IClusCfgClusterInfo_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_SetName_Proxy(IClusCfgClusterInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgClusterInfo_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetIPAddress_Proxy(IClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB IClusCfgClusterInfo_GetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_SetIPAddress_Proxy(IClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB IClusCfgClusterInfo_SetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetSubnetMask_Proxy(IClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB IClusCfgClusterInfo_GetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_SetSubnetMask_Proxy(IClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB IClusCfgClusterInfo_SetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetNetworkInfo_Proxy(IClusCfgClusterInfo *This,IClusCfgNetworkInfo **ppiccniOut);
  void __RPC_STUB IClusCfgClusterInfo_GetNetworkInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_SetNetworkInfo_Proxy(IClusCfgClusterInfo *This,IClusCfgNetworkInfo *piccniIn);
  void __RPC_STUB IClusCfgClusterInfo_SetNetworkInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetClusterServiceAccountCredentials_Proxy(IClusCfgClusterInfo *This,IClusCfgCredentials **ppicccCredentialsOut);
  void __RPC_STUB IClusCfgClusterInfo_GetClusterServiceAccountCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetBindingString_Proxy(IClusCfgClusterInfo *This,BSTR *pbstrBindingStringOut);
  void __RPC_STUB IClusCfgClusterInfo_GetBindingString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_SetBindingString_Proxy(IClusCfgClusterInfo *This,LPCWSTR pcszBindingStringIn);
  void __RPC_STUB IClusCfgClusterInfo_SetBindingString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgClusterInfo_GetMaxNodeCount_Proxy(IClusCfgClusterInfo *This,DWORD *pcMaxNodesOut);
  void __RPC_STUB IClusCfgClusterInfo_GetMaxNodeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgClusterInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgClusterInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgClusterInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgClusterInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_SetCommitMode(ECommitMode ecmNewModeIn) = 0;
    virtual HRESULT WINAPI Finish_SetCommitMode(void) = 0;
    virtual HRESULT WINAPI Begin_GetCommitMode(void) = 0;
    virtual HRESULT WINAPI Finish_GetCommitMode(ECommitMode *pecmCurrentModeOut) = 0;
    virtual HRESULT WINAPI Begin_GetName(void) = 0;
    virtual HRESULT WINAPI Finish_GetName(BSTR *pbstrNameOut) = 0;
    virtual HRESULT WINAPI Begin_SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI Finish_SetName(void) = 0;
    virtual HRESULT WINAPI Begin_GetIPAddress(void) = 0;
    virtual HRESULT WINAPI Finish_GetIPAddress(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI Begin_SetIPAddress(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI Finish_SetIPAddress(void) = 0;
    virtual HRESULT WINAPI Begin_GetSubnetMask(void) = 0;
    virtual HRESULT WINAPI Finish_GetSubnetMask(ULONG *pulDottedQuadOut) = 0;
    virtual HRESULT WINAPI Begin_SetSubnetMask(ULONG ulDottedQuadIn) = 0;
    virtual HRESULT WINAPI Finish_SetSubnetMask(void) = 0;
    virtual HRESULT WINAPI Begin_GetNetworkInfo(void) = 0;
    virtual HRESULT WINAPI Finish_GetNetworkInfo(IClusCfgNetworkInfo **ppiccniOut) = 0;
    virtual HRESULT WINAPI Begin_SetNetworkInfo(IClusCfgNetworkInfo *piccniIn) = 0;
    virtual HRESULT WINAPI Finish_SetNetworkInfo(void) = 0;
    virtual HRESULT WINAPI Begin_GetClusterServiceAccountCredentials(void) = 0;
    virtual HRESULT WINAPI Finish_GetClusterServiceAccountCredentials(IClusCfgCredentials **ppicccCredentialsOut) = 0;
    virtual HRESULT WINAPI Begin_GetBindingString(void) = 0;
    virtual HRESULT WINAPI Finish_GetBindingString(BSTR *pbstrBindingStringOut) = 0;
    virtual HRESULT WINAPI Begin_SetBindingString(LPCWSTR pcszBindingStringIn) = 0;
    virtual HRESULT WINAPI Finish_SetBindingString(void) = 0;
    virtual HRESULT WINAPI Begin_GetMaxNodeCount(void) = 0;
    virtual HRESULT WINAPI Finish_GetMaxNodeCount(DWORD *pcMaxNodesOut) = 0;
  };
#else
  typedef struct AsyncIClusCfgClusterInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgClusterInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgClusterInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_SetCommitMode)(AsyncIClusCfgClusterInfo *This,ECommitMode ecmNewModeIn);
      HRESULT (WINAPI *Finish_SetCommitMode)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_GetCommitMode)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetCommitMode)(AsyncIClusCfgClusterInfo *This,ECommitMode *pecmCurrentModeOut);
      HRESULT (WINAPI *Begin_GetName)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetName)(AsyncIClusCfgClusterInfo *This,BSTR *pbstrNameOut);
      HRESULT (WINAPI *Begin_SetName)(AsyncIClusCfgClusterInfo *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *Finish_SetName)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_GetIPAddress)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetIPAddress)(AsyncIClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *Begin_SetIPAddress)(AsyncIClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *Finish_SetIPAddress)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_GetSubnetMask)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetSubnetMask)(AsyncIClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
      HRESULT (WINAPI *Begin_SetSubnetMask)(AsyncIClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
      HRESULT (WINAPI *Finish_SetSubnetMask)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_GetNetworkInfo)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetNetworkInfo)(AsyncIClusCfgClusterInfo *This,IClusCfgNetworkInfo **ppiccniOut);
      HRESULT (WINAPI *Begin_SetNetworkInfo)(AsyncIClusCfgClusterInfo *This,IClusCfgNetworkInfo *piccniIn);
      HRESULT (WINAPI *Finish_SetNetworkInfo)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_GetClusterServiceAccountCredentials)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetClusterServiceAccountCredentials)(AsyncIClusCfgClusterInfo *This,IClusCfgCredentials **ppicccCredentialsOut);
      HRESULT (WINAPI *Begin_GetBindingString)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetBindingString)(AsyncIClusCfgClusterInfo *This,BSTR *pbstrBindingStringOut);
      HRESULT (WINAPI *Begin_SetBindingString)(AsyncIClusCfgClusterInfo *This,LPCWSTR pcszBindingStringIn);
      HRESULT (WINAPI *Finish_SetBindingString)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Begin_GetMaxNodeCount)(AsyncIClusCfgClusterInfo *This);
      HRESULT (WINAPI *Finish_GetMaxNodeCount)(AsyncIClusCfgClusterInfo *This,DWORD *pcMaxNodesOut);
    END_INTERFACE
  } AsyncIClusCfgClusterInfoVtbl;
  struct AsyncIClusCfgClusterInfo {
    CONST_VTBL struct AsyncIClusCfgClusterInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgClusterInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgClusterInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgClusterInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgClusterInfo_Begin_SetCommitMode(This,ecmNewModeIn) (This)->lpVtbl->Begin_SetCommitMode(This,ecmNewModeIn)
#define AsyncIClusCfgClusterInfo_Finish_SetCommitMode(This) (This)->lpVtbl->Finish_SetCommitMode(This)
#define AsyncIClusCfgClusterInfo_Begin_GetCommitMode(This) (This)->lpVtbl->Begin_GetCommitMode(This)
#define AsyncIClusCfgClusterInfo_Finish_GetCommitMode(This,pecmCurrentModeOut) (This)->lpVtbl->Finish_GetCommitMode(This,pecmCurrentModeOut)
#define AsyncIClusCfgClusterInfo_Begin_GetName(This) (This)->lpVtbl->Begin_GetName(This)
#define AsyncIClusCfgClusterInfo_Finish_GetName(This,pbstrNameOut) (This)->lpVtbl->Finish_GetName(This,pbstrNameOut)
#define AsyncIClusCfgClusterInfo_Begin_SetName(This,pcszNameIn) (This)->lpVtbl->Begin_SetName(This,pcszNameIn)
#define AsyncIClusCfgClusterInfo_Finish_SetName(This) (This)->lpVtbl->Finish_SetName(This)
#define AsyncIClusCfgClusterInfo_Begin_GetIPAddress(This) (This)->lpVtbl->Begin_GetIPAddress(This)
#define AsyncIClusCfgClusterInfo_Finish_GetIPAddress(This,pulDottedQuadOut) (This)->lpVtbl->Finish_GetIPAddress(This,pulDottedQuadOut)
#define AsyncIClusCfgClusterInfo_Begin_SetIPAddress(This,ulDottedQuadIn) (This)->lpVtbl->Begin_SetIPAddress(This,ulDottedQuadIn)
#define AsyncIClusCfgClusterInfo_Finish_SetIPAddress(This) (This)->lpVtbl->Finish_SetIPAddress(This)
#define AsyncIClusCfgClusterInfo_Begin_GetSubnetMask(This) (This)->lpVtbl->Begin_GetSubnetMask(This)
#define AsyncIClusCfgClusterInfo_Finish_GetSubnetMask(This,pulDottedQuadOut) (This)->lpVtbl->Finish_GetSubnetMask(This,pulDottedQuadOut)
#define AsyncIClusCfgClusterInfo_Begin_SetSubnetMask(This,ulDottedQuadIn) (This)->lpVtbl->Begin_SetSubnetMask(This,ulDottedQuadIn)
#define AsyncIClusCfgClusterInfo_Finish_SetSubnetMask(This) (This)->lpVtbl->Finish_SetSubnetMask(This)
#define AsyncIClusCfgClusterInfo_Begin_GetNetworkInfo(This) (This)->lpVtbl->Begin_GetNetworkInfo(This)
#define AsyncIClusCfgClusterInfo_Finish_GetNetworkInfo(This,ppiccniOut) (This)->lpVtbl->Finish_GetNetworkInfo(This,ppiccniOut)
#define AsyncIClusCfgClusterInfo_Begin_SetNetworkInfo(This,piccniIn) (This)->lpVtbl->Begin_SetNetworkInfo(This,piccniIn)
#define AsyncIClusCfgClusterInfo_Finish_SetNetworkInfo(This) (This)->lpVtbl->Finish_SetNetworkInfo(This)
#define AsyncIClusCfgClusterInfo_Begin_GetClusterServiceAccountCredentials(This) (This)->lpVtbl->Begin_GetClusterServiceAccountCredentials(This)
#define AsyncIClusCfgClusterInfo_Finish_GetClusterServiceAccountCredentials(This,ppicccCredentialsOut) (This)->lpVtbl->Finish_GetClusterServiceAccountCredentials(This,ppicccCredentialsOut)
#define AsyncIClusCfgClusterInfo_Begin_GetBindingString(This) (This)->lpVtbl->Begin_GetBindingString(This)
#define AsyncIClusCfgClusterInfo_Finish_GetBindingString(This,pbstrBindingStringOut) (This)->lpVtbl->Finish_GetBindingString(This,pbstrBindingStringOut)
#define AsyncIClusCfgClusterInfo_Begin_SetBindingString(This,pcszBindingStringIn) (This)->lpVtbl->Begin_SetBindingString(This,pcszBindingStringIn)
#define AsyncIClusCfgClusterInfo_Finish_SetBindingString(This) (This)->lpVtbl->Finish_SetBindingString(This)
#define AsyncIClusCfgClusterInfo_Begin_GetMaxNodeCount(This) (This)->lpVtbl->Begin_GetMaxNodeCount(This)
#define AsyncIClusCfgClusterInfo_Finish_GetMaxNodeCount(This,pcMaxNodesOut) (This)->lpVtbl->Finish_GetMaxNodeCount(This,pcMaxNodesOut)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_SetCommitMode_Proxy(AsyncIClusCfgClusterInfo *This,ECommitMode ecmNewModeIn);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_SetCommitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_SetCommitMode_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_SetCommitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetCommitMode_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetCommitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetCommitMode_Proxy(AsyncIClusCfgClusterInfo *This,ECommitMode *pecmCurrentModeOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetCommitMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetName_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetName_Proxy(AsyncIClusCfgClusterInfo *This,BSTR *pbstrNameOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_SetName_Proxy(AsyncIClusCfgClusterInfo *This,LPCWSTR pcszNameIn);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_SetName_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetIPAddress_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetIPAddress_Proxy(AsyncIClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_SetIPAddress_Proxy(AsyncIClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_SetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_SetIPAddress_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_SetIPAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetSubnetMask_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetSubnetMask_Proxy(AsyncIClusCfgClusterInfo *This,ULONG *pulDottedQuadOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_SetSubnetMask_Proxy(AsyncIClusCfgClusterInfo *This,ULONG ulDottedQuadIn);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_SetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_SetSubnetMask_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_SetSubnetMask_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetNetworkInfo_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetNetworkInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetNetworkInfo_Proxy(AsyncIClusCfgClusterInfo *This,IClusCfgNetworkInfo **ppiccniOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetNetworkInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_SetNetworkInfo_Proxy(AsyncIClusCfgClusterInfo *This,IClusCfgNetworkInfo *piccniIn);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_SetNetworkInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_SetNetworkInfo_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_SetNetworkInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetClusterServiceAccountCredentials_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetClusterServiceAccountCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetClusterServiceAccountCredentials_Proxy(AsyncIClusCfgClusterInfo *This,IClusCfgCredentials **ppicccCredentialsOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetClusterServiceAccountCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetBindingString_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetBindingString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetBindingString_Proxy(AsyncIClusCfgClusterInfo *This,BSTR *pbstrBindingStringOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetBindingString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_SetBindingString_Proxy(AsyncIClusCfgClusterInfo *This,LPCWSTR pcszBindingStringIn);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_SetBindingString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_SetBindingString_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_SetBindingString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Begin_GetMaxNodeCount_Proxy(AsyncIClusCfgClusterInfo *This);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Begin_GetMaxNodeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgClusterInfo_Finish_GetMaxNodeCount_Proxy(AsyncIClusCfgClusterInfo *This,DWORD *pcMaxNodesOut);
  void __RPC_STUB AsyncIClusCfgClusterInfo_Finish_GetMaxNodeCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgInitialize_INTERFACE_DEFINED__
#define __IClusCfgInitialize_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgInitialize;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgInitialize : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(IUnknown *punkCallbackIn,LCID lcidIn) = 0;
  };
#else
  typedef struct IClusCfgInitializeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgInitialize *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgInitialize *This);
      ULONG (WINAPI *Release)(IClusCfgInitialize *This);
      HRESULT (WINAPI *Initialize)(IClusCfgInitialize *This,IUnknown *punkCallbackIn,LCID lcidIn);
    END_INTERFACE
  } IClusCfgInitializeVtbl;
  struct IClusCfgInitialize {
    CONST_VTBL struct IClusCfgInitializeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgInitialize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgInitialize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgInitialize_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgInitialize_Initialize(This,punkCallbackIn,lcidIn) (This)->lpVtbl->Initialize(This,punkCallbackIn,lcidIn)
#endif
#endif
  HRESULT WINAPI IClusCfgInitialize_Initialize_Proxy(IClusCfgInitialize *This,IUnknown *punkCallbackIn,LCID lcidIn);
  void __RPC_STUB IClusCfgInitialize_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgInitialize_INTERFACE_DEFINED__
#define __AsyncIClusCfgInitialize_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgInitialize;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgInitialize : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Initialize(IUnknown *punkCallbackIn,LCID lcidIn) = 0;
    virtual HRESULT WINAPI Finish_Initialize(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgInitializeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgInitialize *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgInitialize *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgInitialize *This);
      HRESULT (WINAPI *Begin_Initialize)(AsyncIClusCfgInitialize *This,IUnknown *punkCallbackIn,LCID lcidIn);
      HRESULT (WINAPI *Finish_Initialize)(AsyncIClusCfgInitialize *This);
    END_INTERFACE
  } AsyncIClusCfgInitializeVtbl;
  struct AsyncIClusCfgInitialize {
    CONST_VTBL struct AsyncIClusCfgInitializeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgInitialize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgInitialize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgInitialize_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgInitialize_Begin_Initialize(This,punkCallbackIn,lcidIn) (This)->lpVtbl->Begin_Initialize(This,punkCallbackIn,lcidIn)
#define AsyncIClusCfgInitialize_Finish_Initialize(This) (This)->lpVtbl->Finish_Initialize(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgInitialize_Begin_Initialize_Proxy(AsyncIClusCfgInitialize *This,IUnknown *punkCallbackIn,LCID lcidIn);
  void __RPC_STUB AsyncIClusCfgInitialize_Begin_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgInitialize_Finish_Initialize_Proxy(AsyncIClusCfgInitialize *This);
  void __RPC_STUB AsyncIClusCfgInitialize_Finish_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgCallback_INTERFACE_DEFINED__
#define __IClusCfgCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI SendStatusReport(LPCWSTR pcszNodeNameIn,CLSID clsidTaskMajorIn,CLSID clsidTaskMinorIn,ULONG ulMinIn,ULONG ulMaxIn,ULONG ulCurrentIn,HRESULT hrStatusIn,LPCWSTR pcszDescriptionIn,FILETIME *pftTimeIn,LPCWSTR pcszReferenceIn) = 0;
  };
#else
  typedef struct IClusCfgCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgCallback *This);
      ULONG (WINAPI *Release)(IClusCfgCallback *This);
      HRESULT (WINAPI *SendStatusReport)(IClusCfgCallback *This,LPCWSTR pcszNodeNameIn,CLSID clsidTaskMajorIn,CLSID clsidTaskMinorIn,ULONG ulMinIn,ULONG ulMaxIn,ULONG ulCurrentIn,HRESULT hrStatusIn,LPCWSTR pcszDescriptionIn,FILETIME *pftTimeIn,LPCWSTR pcszReferenceIn);
    END_INTERFACE
  } IClusCfgCallbackVtbl;
  struct IClusCfgCallback {
    CONST_VTBL struct IClusCfgCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgCallback_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgCallback_SendStatusReport(This,pcszNodeNameIn,clsidTaskMajorIn,clsidTaskMinorIn,ulMinIn,ulMaxIn,ulCurrentIn,hrStatusIn,pcszDescriptionIn,pftTimeIn,pcszReferenceIn) (This)->lpVtbl->SendStatusReport(This,pcszNodeNameIn,clsidTaskMajorIn,clsidTaskMinorIn,ulMinIn,ulMaxIn,ulCurrentIn,hrStatusIn,pcszDescriptionIn,pftTimeIn,pcszReferenceIn)
#endif
#endif
  HRESULT WINAPI IClusCfgCallback_SendStatusReport_Proxy(IClusCfgCallback *This,LPCWSTR pcszNodeNameIn,CLSID clsidTaskMajorIn,CLSID clsidTaskMinorIn,ULONG ulMinIn,ULONG ulMaxIn,ULONG ulCurrentIn,HRESULT hrStatusIn,LPCWSTR pcszDescriptionIn,FILETIME *pftTimeIn,LPCWSTR pcszReferenceIn);
  void __RPC_STUB IClusCfgCallback_SendStatusReport_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgCallback_INTERFACE_DEFINED__
#define __AsyncIClusCfgCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_SendStatusReport(LPCWSTR pcszNodeNameIn,CLSID clsidTaskMajorIn,CLSID clsidTaskMinorIn,ULONG ulMinIn,ULONG ulMaxIn,ULONG ulCurrentIn,HRESULT hrStatusIn,LPCWSTR pcszDescriptionIn,FILETIME *pftTimeIn,LPCWSTR pcszReferenceIn) = 0;
    virtual HRESULT WINAPI Finish_SendStatusReport(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgCallback *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgCallback *This);
      HRESULT (WINAPI *Begin_SendStatusReport)(AsyncIClusCfgCallback *This,LPCWSTR pcszNodeNameIn,CLSID clsidTaskMajorIn,CLSID clsidTaskMinorIn,ULONG ulMinIn,ULONG ulMaxIn,ULONG ulCurrentIn,HRESULT hrStatusIn,LPCWSTR pcszDescriptionIn,FILETIME *pftTimeIn,LPCWSTR pcszReferenceIn);
      HRESULT (WINAPI *Finish_SendStatusReport)(AsyncIClusCfgCallback *This);
    END_INTERFACE
  } AsyncIClusCfgCallbackVtbl;
  struct AsyncIClusCfgCallback {
    CONST_VTBL struct AsyncIClusCfgCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgCallback_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgCallback_Begin_SendStatusReport(This,pcszNodeNameIn,clsidTaskMajorIn,clsidTaskMinorIn,ulMinIn,ulMaxIn,ulCurrentIn,hrStatusIn,pcszDescriptionIn,pftTimeIn,pcszReferenceIn) (This)->lpVtbl->Begin_SendStatusReport(This,pcszNodeNameIn,clsidTaskMajorIn,clsidTaskMinorIn,ulMinIn,ulMaxIn,ulCurrentIn,hrStatusIn,pcszDescriptionIn,pftTimeIn,pcszReferenceIn)
#define AsyncIClusCfgCallback_Finish_SendStatusReport(This) (This)->lpVtbl->Finish_SendStatusReport(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgCallback_Begin_SendStatusReport_Proxy(AsyncIClusCfgCallback *This,LPCWSTR pcszNodeNameIn,CLSID clsidTaskMajorIn,CLSID clsidTaskMinorIn,ULONG ulMinIn,ULONG ulMaxIn,ULONG ulCurrentIn,HRESULT hrStatusIn,LPCWSTR pcszDescriptionIn,FILETIME *pftTimeIn,LPCWSTR pcszReferenceIn);
  void __RPC_STUB AsyncIClusCfgCallback_Begin_SendStatusReport_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCallback_Finish_SendStatusReport_Proxy(AsyncIClusCfgCallback *This);
  void __RPC_STUB AsyncIClusCfgCallback_Finish_SendStatusReport_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgCredentials_INTERFACE_DEFINED__
#define __IClusCfgCredentials_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgCredentials;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgCredentials : public IUnknown {
  public:
    virtual HRESULT WINAPI SetCredentials(LPCWSTR pcszUserIn,LPCWSTR pcszDomainIn,LPCWSTR pcszPasswordIn) = 0;
    virtual HRESULT WINAPI GetCredentials(BSTR *pbstrUserOut,BSTR *pbstrDomainOut,BSTR *pbstrPasswordOut) = 0;
    virtual HRESULT WINAPI GetIdentity(BSTR *pbstrUserOut,BSTR *pbstrDomainOut) = 0;
    virtual HRESULT WINAPI GetPassword(BSTR *pbstrPasswordOut) = 0;
    virtual HRESULT WINAPI AssignTo(IClusCfgCredentials *picccDestIn) = 0;
    virtual HRESULT WINAPI AssignFrom(IClusCfgCredentials *picccSourceIn) = 0;
  };
#else
  typedef struct IClusCfgCredentialsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgCredentials *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgCredentials *This);
      ULONG (WINAPI *Release)(IClusCfgCredentials *This);
      HRESULT (WINAPI *SetCredentials)(IClusCfgCredentials *This,LPCWSTR pcszUserIn,LPCWSTR pcszDomainIn,LPCWSTR pcszPasswordIn);
      HRESULT (WINAPI *GetCredentials)(IClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut,BSTR *pbstrPasswordOut);

      HRESULT (WINAPI *GetIdentity)(IClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut);
      HRESULT (WINAPI *GetPassword)(IClusCfgCredentials *This,BSTR *pbstrPasswordOut);
      HRESULT (WINAPI *AssignTo)(IClusCfgCredentials *This,IClusCfgCredentials *picccDestIn);
      HRESULT (WINAPI *AssignFrom)(IClusCfgCredentials *This,IClusCfgCredentials *picccSourceIn);
    END_INTERFACE
  } IClusCfgCredentialsVtbl;
  struct IClusCfgCredentials {
    CONST_VTBL struct IClusCfgCredentialsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgCredentials_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgCredentials_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgCredentials_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgCredentials_SetCredentials(This,pcszUserIn,pcszDomainIn,pcszPasswordIn) (This)->lpVtbl->SetCredentials(This,pcszUserIn,pcszDomainIn,pcszPasswordIn)
#define IClusCfgCredentials_GetCredentials(This,pbstrUserOut,pbstrDomainOut,pbstrPasswordOut) (This)->lpVtbl->GetCredentials(This,pbstrUserOut,pbstrDomainOut,pbstrPasswordOut)
#define IClusCfgCredentials_GetIdentity(This,pbstrUserOut,pbstrDomainOut) (This)->lpVtbl->GetIdentity(This,pbstrUserOut,pbstrDomainOut)
#define IClusCfgCredentials_GetPassword(This,pbstrPasswordOut) (This)->lpVtbl->GetPassword(This,pbstrPasswordOut)
#define IClusCfgCredentials_AssignTo(This,picccDestIn) (This)->lpVtbl->AssignTo(This,picccDestIn)
#define IClusCfgCredentials_AssignFrom(This,picccSourceIn) (This)->lpVtbl->AssignFrom(This,picccSourceIn)
#endif
#endif
  HRESULT WINAPI IClusCfgCredentials_SetCredentials_Proxy(IClusCfgCredentials *This,LPCWSTR pcszUserIn,LPCWSTR pcszDomainIn,LPCWSTR pcszPasswordIn);
  void __RPC_STUB IClusCfgCredentials_SetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCredentials_GetCredentials_Proxy(IClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut,BSTR *pbstrPasswordOut);
  void __RPC_STUB IClusCfgCredentials_GetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCredentials_GetIdentity_Proxy(IClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut);
  void __RPC_STUB IClusCfgCredentials_GetIdentity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCredentials_GetPassword_Proxy(IClusCfgCredentials *This,BSTR *pbstrPasswordOut);
  void __RPC_STUB IClusCfgCredentials_GetPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCredentials_AssignTo_Proxy(IClusCfgCredentials *This,IClusCfgCredentials *picccDestIn);
  void __RPC_STUB IClusCfgCredentials_AssignTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgCredentials_AssignFrom_Proxy(IClusCfgCredentials *This,IClusCfgCredentials *picccSourceIn);
  void __RPC_STUB IClusCfgCredentials_AssignFrom_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgCredentials_INTERFACE_DEFINED__
#define __AsyncIClusCfgCredentials_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgCredentials;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgCredentials : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_SetCredentials(LPCWSTR pcszUserIn,LPCWSTR pcszDomainIn,LPCWSTR pcszPasswordIn) = 0;
    virtual HRESULT WINAPI Finish_SetCredentials(void) = 0;
    virtual HRESULT WINAPI Begin_GetCredentials(void) = 0;
    virtual HRESULT WINAPI Finish_GetCredentials(BSTR *pbstrUserOut,BSTR *pbstrDomainOut,BSTR *pbstrPasswordOut) = 0;
    virtual HRESULT WINAPI Begin_GetIdentity(void) = 0;
    virtual HRESULT WINAPI Finish_GetIdentity(BSTR *pbstrUserOut,BSTR *pbstrDomainOut) = 0;
    virtual HRESULT WINAPI Begin_GetPassword(void) = 0;
    virtual HRESULT WINAPI Finish_GetPassword(BSTR *pbstrPasswordOut) = 0;
    virtual HRESULT WINAPI Begin_AssignTo(IClusCfgCredentials *picccDestIn) = 0;
    virtual HRESULT WINAPI Finish_AssignTo(void) = 0;
    virtual HRESULT WINAPI Begin_AssignFrom(IClusCfgCredentials *picccSourceIn) = 0;
    virtual HRESULT WINAPI Finish_AssignFrom(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgCredentialsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgCredentials *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgCredentials *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgCredentials *This);
      HRESULT (WINAPI *Begin_SetCredentials)(AsyncIClusCfgCredentials *This,LPCWSTR pcszUserIn,LPCWSTR pcszDomainIn,LPCWSTR pcszPasswordIn);
      HRESULT (WINAPI *Finish_SetCredentials)(AsyncIClusCfgCredentials *This);
      HRESULT (WINAPI *Begin_GetCredentials)(AsyncIClusCfgCredentials *This);
      HRESULT (WINAPI *Finish_GetCredentials)(AsyncIClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut,BSTR *pbstrPasswordOut);
      HRESULT (WINAPI *Begin_GetIdentity)(AsyncIClusCfgCredentials *This);
      HRESULT (WINAPI *Finish_GetIdentity)(AsyncIClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut);
      HRESULT (WINAPI *Begin_GetPassword)(AsyncIClusCfgCredentials *This);
      HRESULT (WINAPI *Finish_GetPassword)(AsyncIClusCfgCredentials *This,BSTR *pbstrPasswordOut);
      HRESULT (WINAPI *Begin_AssignTo)(AsyncIClusCfgCredentials *This,IClusCfgCredentials *picccDestIn);
      HRESULT (WINAPI *Finish_AssignTo)(AsyncIClusCfgCredentials *This);
      HRESULT (WINAPI *Begin_AssignFrom)(AsyncIClusCfgCredentials *This,IClusCfgCredentials *picccSourceIn);
      HRESULT (WINAPI *Finish_AssignFrom)(AsyncIClusCfgCredentials *This);
    END_INTERFACE
  } AsyncIClusCfgCredentialsVtbl;
  struct AsyncIClusCfgCredentials {
    CONST_VTBL struct AsyncIClusCfgCredentialsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgCredentials_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgCredentials_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgCredentials_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgCredentials_Begin_SetCredentials(This,pcszUserIn,pcszDomainIn,pcszPasswordIn) (This)->lpVtbl->Begin_SetCredentials(This,pcszUserIn,pcszDomainIn,pcszPasswordIn)
#define AsyncIClusCfgCredentials_Finish_SetCredentials(This) (This)->lpVtbl->Finish_SetCredentials(This)
#define AsyncIClusCfgCredentials_Begin_GetCredentials(This) (This)->lpVtbl->Begin_GetCredentials(This)
#define AsyncIClusCfgCredentials_Finish_GetCredentials(This,pbstrUserOut,pbstrDomainOut,pbstrPasswordOut) (This)->lpVtbl->Finish_GetCredentials(This,pbstrUserOut,pbstrDomainOut,pbstrPasswordOut)
#define AsyncIClusCfgCredentials_Begin_GetIdentity(This) (This)->lpVtbl->Begin_GetIdentity(This)
#define AsyncIClusCfgCredentials_Finish_GetIdentity(This,pbstrUserOut,pbstrDomainOut) (This)->lpVtbl->Finish_GetIdentity(This,pbstrUserOut,pbstrDomainOut)
#define AsyncIClusCfgCredentials_Begin_GetPassword(This) (This)->lpVtbl->Begin_GetPassword(This)
#define AsyncIClusCfgCredentials_Finish_GetPassword(This,pbstrPasswordOut) (This)->lpVtbl->Finish_GetPassword(This,pbstrPasswordOut)
#define AsyncIClusCfgCredentials_Begin_AssignTo(This,picccDestIn) (This)->lpVtbl->Begin_AssignTo(This,picccDestIn)
#define AsyncIClusCfgCredentials_Finish_AssignTo(This) (This)->lpVtbl->Finish_AssignTo(This)
#define AsyncIClusCfgCredentials_Begin_AssignFrom(This,picccSourceIn) (This)->lpVtbl->Begin_AssignFrom(This,picccSourceIn)
#define AsyncIClusCfgCredentials_Finish_AssignFrom(This) (This)->lpVtbl->Finish_AssignFrom(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgCredentials_Begin_SetCredentials_Proxy(AsyncIClusCfgCredentials *This,LPCWSTR pcszUserIn,LPCWSTR pcszDomainIn,LPCWSTR pcszPasswordIn);
  void __RPC_STUB AsyncIClusCfgCredentials_Begin_SetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Finish_SetCredentials_Proxy(AsyncIClusCfgCredentials *This);
  void __RPC_STUB AsyncIClusCfgCredentials_Finish_SetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Begin_GetCredentials_Proxy(AsyncIClusCfgCredentials *This);
  void __RPC_STUB AsyncIClusCfgCredentials_Begin_GetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Finish_GetCredentials_Proxy(AsyncIClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut,BSTR *pbstrPasswordOut);
  void __RPC_STUB AsyncIClusCfgCredentials_Finish_GetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Begin_GetIdentity_Proxy(AsyncIClusCfgCredentials *This);
  void __RPC_STUB AsyncIClusCfgCredentials_Begin_GetIdentity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Finish_GetIdentity_Proxy(AsyncIClusCfgCredentials *This,BSTR *pbstrUserOut,BSTR *pbstrDomainOut);
  void __RPC_STUB AsyncIClusCfgCredentials_Finish_GetIdentity_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Begin_GetPassword_Proxy(AsyncIClusCfgCredentials *This);
  void __RPC_STUB AsyncIClusCfgCredentials_Begin_GetPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Finish_GetPassword_Proxy(AsyncIClusCfgCredentials *This,BSTR *pbstrPasswordOut);
  void __RPC_STUB AsyncIClusCfgCredentials_Finish_GetPassword_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Begin_AssignTo_Proxy(AsyncIClusCfgCredentials *This,IClusCfgCredentials *picccDestIn);
  void __RPC_STUB AsyncIClusCfgCredentials_Begin_AssignTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Finish_AssignTo_Proxy(AsyncIClusCfgCredentials *This);
  void __RPC_STUB AsyncIClusCfgCredentials_Finish_AssignTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Begin_AssignFrom_Proxy(AsyncIClusCfgCredentials *This,IClusCfgCredentials *picccSourceIn);
  void __RPC_STUB AsyncIClusCfgCredentials_Begin_AssignFrom_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgCredentials_Finish_AssignFrom_Proxy(AsyncIClusCfgCredentials *This);
  void __RPC_STUB AsyncIClusCfgCredentials_Finish_AssignFrom_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgCapabilities_INTERFACE_DEFINED__
#define __IClusCfgCapabilities_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgCapabilities;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgCapabilities : public IUnknown {
  public:
    virtual HRESULT WINAPI CanNodeBeClustered(void) = 0;
  };
#else
  typedef struct IClusCfgCapabilitiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgCapabilities *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgCapabilities *This);
      ULONG (WINAPI *Release)(IClusCfgCapabilities *This);
      HRESULT (WINAPI *CanNodeBeClustered)(IClusCfgCapabilities *This);
    END_INTERFACE
  } IClusCfgCapabilitiesVtbl;
  struct IClusCfgCapabilities {
    CONST_VTBL struct IClusCfgCapabilitiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgCapabilities_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgCapabilities_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgCapabilities_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgCapabilities_CanNodeBeClustered(This) (This)->lpVtbl->CanNodeBeClustered(This)
#endif
#endif
  HRESULT WINAPI IClusCfgCapabilities_CanNodeBeClustered_Proxy(IClusCfgCapabilities *This);
  void __RPC_STUB IClusCfgCapabilities_CanNodeBeClustered_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgManagedResourceCfg_INTERFACE_DEFINED__
#define __IClusCfgManagedResourceCfg_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgManagedResourceCfg;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgManagedResourceCfg : public IUnknown {
  public:
    virtual HRESULT WINAPI PreCreate(IUnknown *punkServicesIn) = 0;
    virtual HRESULT WINAPI Create(IUnknown *punkServicesIn) = 0;
    virtual HRESULT WINAPI PostCreate(IUnknown *punkServicesIn) = 0;
    virtual HRESULT WINAPI Evict(IUnknown *punkServicesIn) = 0;
  };
#else
  typedef struct IClusCfgManagedResourceCfgVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgManagedResourceCfg *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgManagedResourceCfg *This);
      ULONG (WINAPI *Release)(IClusCfgManagedResourceCfg *This);
      HRESULT (WINAPI *PreCreate)(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
      HRESULT (WINAPI *Create)(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
      HRESULT (WINAPI *PostCreate)(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
      HRESULT (WINAPI *Evict)(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
    END_INTERFACE
  } IClusCfgManagedResourceCfgVtbl;
  struct IClusCfgManagedResourceCfg {
    CONST_VTBL struct IClusCfgManagedResourceCfgVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgManagedResourceCfg_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgManagedResourceCfg_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgManagedResourceCfg_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgManagedResourceCfg_PreCreate(This,punkServicesIn) (This)->lpVtbl->PreCreate(This,punkServicesIn)
#define IClusCfgManagedResourceCfg_Create(This,punkServicesIn) (This)->lpVtbl->Create(This,punkServicesIn)
#define IClusCfgManagedResourceCfg_PostCreate(This,punkServicesIn) (This)->lpVtbl->PostCreate(This,punkServicesIn)
#define IClusCfgManagedResourceCfg_Evict(This,punkServicesIn) (This)->lpVtbl->Evict(This,punkServicesIn)
#endif
#endif
  HRESULT WINAPI IClusCfgManagedResourceCfg_PreCreate_Proxy(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
  void __RPC_STUB IClusCfgManagedResourceCfg_PreCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceCfg_Create_Proxy(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
  void __RPC_STUB IClusCfgManagedResourceCfg_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceCfg_PostCreate_Proxy(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
  void __RPC_STUB IClusCfgManagedResourceCfg_PostCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceCfg_Evict_Proxy(IClusCfgManagedResourceCfg *This,IUnknown *punkServicesIn);
  void __RPC_STUB IClusCfgManagedResourceCfg_Evict_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgResourcePreCreate_INTERFACE_DEFINED__
#define __IClusCfgResourcePreCreate_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgResourcePreCreate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgResourcePreCreate : public IUnknown {
  public:
    virtual HRESULT WINAPI SetDependency(LPCLSID pclsidDepResTypeIn,DWORD dfIn) = 0;
    virtual HRESULT WINAPI SetType(CLSID *pclsidIn) = 0;
    virtual HRESULT WINAPI SetClassType(CLSID *pclsidIn) = 0;
  };
#else
  typedef struct IClusCfgResourcePreCreateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgResourcePreCreate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgResourcePreCreate *This);
      ULONG (WINAPI *Release)(IClusCfgResourcePreCreate *This);
      HRESULT (WINAPI *SetDependency)(IClusCfgResourcePreCreate *This,LPCLSID pclsidDepResTypeIn,DWORD dfIn);
      HRESULT (WINAPI *SetType)(IClusCfgResourcePreCreate *This,CLSID *pclsidIn);
      HRESULT (WINAPI *SetClassType)(IClusCfgResourcePreCreate *This,CLSID *pclsidIn);
    END_INTERFACE
  } IClusCfgResourcePreCreateVtbl;
  struct IClusCfgResourcePreCreate {
    CONST_VTBL struct IClusCfgResourcePreCreateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgResourcePreCreate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgResourcePreCreate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgResourcePreCreate_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgResourcePreCreate_SetDependency(This,pclsidDepResTypeIn,dfIn) (This)->lpVtbl->SetDependency(This,pclsidDepResTypeIn,dfIn)
#define IClusCfgResourcePreCreate_SetType(This,pclsidIn) (This)->lpVtbl->SetType(This,pclsidIn)
#define IClusCfgResourcePreCreate_SetClassType(This,pclsidIn) (This)->lpVtbl->SetClassType(This,pclsidIn)
#endif
#endif
  HRESULT WINAPI IClusCfgResourcePreCreate_SetDependency_Proxy(IClusCfgResourcePreCreate *This,LPCLSID pclsidDepResTypeIn,DWORD dfIn);
  void __RPC_STUB IClusCfgResourcePreCreate_SetDependency_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourcePreCreate_SetType_Proxy(IClusCfgResourcePreCreate *This,CLSID *pclsidIn);
  void __RPC_STUB IClusCfgResourcePreCreate_SetType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourcePreCreate_SetClassType_Proxy(IClusCfgResourcePreCreate *This,CLSID *pclsidIn);
  void __RPC_STUB IClusCfgResourcePreCreate_SetClassType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgResourceCreate_INTERFACE_DEFINED__
#define __IClusCfgResourceCreate_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgResourceCreate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgResourceCreate : public IUnknown {
  public:
    virtual HRESULT WINAPI SetPropertyBinary(LPCWSTR pcszNameIn,const DWORD cbSizeIn,const BYTE *pbyteIn) = 0;
    virtual HRESULT WINAPI SetPropertyDWORD(LPCWSTR pcszNameIn,const DWORD dwDWORDIn) = 0;
    virtual HRESULT WINAPI SetPropertyString(LPCWSTR pcszNameIn,LPCWSTR pcszStringIn) = 0;
    virtual HRESULT WINAPI SetPropertyExpandString(LPCWSTR pcszNameIn,LPCWSTR pcszStringIn) = 0;
    virtual HRESULT WINAPI SetPropertyMultiString(LPCWSTR pcszNameIn,const DWORD cbMultiStringIn,LPCWSTR pcszMultiStringIn) = 0;
    virtual HRESULT WINAPI SetPropertyUnsignedLargeInt(LPCWSTR pcszNameIn,const ULARGE_INTEGER ulIntIn) = 0;
    virtual HRESULT WINAPI SetPropertyLong(LPCWSTR pcszNameIn,const LONG lLongIn) = 0;
    virtual HRESULT WINAPI SetPropertySecurityDescriptor(LPCWSTR pcszNameIn,const SECURITY_DESCRIPTOR *pcsdIn) = 0;
    virtual HRESULT WINAPI SetPropertyLargeInt(LPCWSTR pcszNameIn,const LARGE_INTEGER lIntIn) = 0;
    virtual HRESULT WINAPI SendResourceControl(DWORD dwControlCodeIn,LPVOID lpBufferIn,DWORD cbBufferSizeIn) = 0;
  };
#else
  typedef struct IClusCfgResourceCreateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgResourceCreate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgResourceCreate *This);
      ULONG (WINAPI *Release)(IClusCfgResourceCreate *This);
      HRESULT (WINAPI *SetPropertyBinary)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const DWORD cbSizeIn,const BYTE *pbyteIn);
      HRESULT (WINAPI *SetPropertyDWORD)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const DWORD dwDWORDIn);
      HRESULT (WINAPI *SetPropertyString)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,LPCWSTR pcszStringIn);
      HRESULT (WINAPI *SetPropertyExpandString)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,LPCWSTR pcszStringIn);
      HRESULT (WINAPI *SetPropertyMultiString)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const DWORD cbMultiStringIn,LPCWSTR pcszMultiStringIn);
      HRESULT (WINAPI *SetPropertyUnsignedLargeInt)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const ULARGE_INTEGER ulIntIn);
      HRESULT (WINAPI *SetPropertyLong)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const LONG lLongIn);
      HRESULT (WINAPI *SetPropertySecurityDescriptor)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const SECURITY_DESCRIPTOR *pcsdIn);
      HRESULT (WINAPI *SetPropertyLargeInt)(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const LARGE_INTEGER lIntIn);
      HRESULT (WINAPI *SendResourceControl)(IClusCfgResourceCreate *This,DWORD dwControlCodeIn,LPVOID lpBufferIn,DWORD cbBufferSizeIn);
    END_INTERFACE
  } IClusCfgResourceCreateVtbl;
  struct IClusCfgResourceCreate {
    CONST_VTBL struct IClusCfgResourceCreateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgResourceCreate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgResourceCreate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgResourceCreate_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgResourceCreate_SetPropertyBinary(This,pcszNameIn,cbSizeIn,pbyteIn) (This)->lpVtbl->SetPropertyBinary(This,pcszNameIn,cbSizeIn,pbyteIn)
#define IClusCfgResourceCreate_SetPropertyDWORD(This,pcszNameIn,dwDWORDIn) (This)->lpVtbl->SetPropertyDWORD(This,pcszNameIn,dwDWORDIn)
#define IClusCfgResourceCreate_SetPropertyString(This,pcszNameIn,pcszStringIn) (This)->lpVtbl->SetPropertyString(This,pcszNameIn,pcszStringIn)
#define IClusCfgResourceCreate_SetPropertyExpandString(This,pcszNameIn,pcszStringIn) (This)->lpVtbl->SetPropertyExpandString(This,pcszNameIn,pcszStringIn)
#define IClusCfgResourceCreate_SetPropertyMultiString(This,pcszNameIn,cbMultiStringIn,pcszMultiStringIn) (This)->lpVtbl->SetPropertyMultiString(This,pcszNameIn,cbMultiStringIn,pcszMultiStringIn)
#define IClusCfgResourceCreate_SetPropertyUnsignedLargeInt(This,pcszNameIn,ulIntIn) (This)->lpVtbl->SetPropertyUnsignedLargeInt(This,pcszNameIn,ulIntIn)
#define IClusCfgResourceCreate_SetPropertyLong(This,pcszNameIn,lLongIn) (This)->lpVtbl->SetPropertyLong(This,pcszNameIn,lLongIn)
#define IClusCfgResourceCreate_SetPropertySecurityDescriptor(This,pcszNameIn,pcsdIn) (This)->lpVtbl->SetPropertySecurityDescriptor(This,pcszNameIn,pcsdIn)
#define IClusCfgResourceCreate_SetPropertyLargeInt(This,pcszNameIn,lIntIn) (This)->lpVtbl->SetPropertyLargeInt(This,pcszNameIn,lIntIn)
#define IClusCfgResourceCreate_SendResourceControl(This,dwControlCodeIn,lpBufferIn,cbBufferSizeIn) (This)->lpVtbl->SendResourceControl(This,dwControlCodeIn,lpBufferIn,cbBufferSizeIn)
#endif
#endif
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyBinary_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const DWORD cbSizeIn,const BYTE *pbyteIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyBinary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyDWORD_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const DWORD dwDWORDIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyDWORD_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyString_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,LPCWSTR pcszStringIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyExpandString_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,LPCWSTR pcszStringIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyExpandString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyMultiString_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const DWORD cbMultiStringIn,LPCWSTR pcszMultiStringIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyMultiString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyUnsignedLargeInt_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const ULARGE_INTEGER ulIntIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyUnsignedLargeInt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyLong_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const LONG lLongIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyLong_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertySecurityDescriptor_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const SECURITY_DESCRIPTOR *pcsdIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertySecurityDescriptor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SetPropertyLargeInt_Proxy(IClusCfgResourceCreate *This,LPCWSTR pcszNameIn,const LARGE_INTEGER lIntIn);
  void __RPC_STUB IClusCfgResourceCreate_SetPropertyLargeInt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceCreate_SendResourceControl_Proxy(IClusCfgResourceCreate *This,DWORD dwControlCodeIn,LPVOID lpBufferIn,DWORD cbBufferSizeIn);
  void __RPC_STUB IClusCfgResourceCreate_SendResourceControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgResourcePostCreate_INTERFACE_DEFINED__
#define __IClusCfgResourcePostCreate_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgResourcePostCreate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgResourcePostCreate : public IUnknown {
  public:
    virtual HRESULT WINAPI ChangeName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI SendResourceControl(DWORD dwControlCodeIn,LPVOID lpBufferIn,DWORD cbBufferSizeIn,LPVOID lBufferInout,DWORD cbOutBufferSizeIn,LPDWORD lpcbBytesReturnedOut) = 0;
  };
#else
  typedef struct IClusCfgResourcePostCreateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgResourcePostCreate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgResourcePostCreate *This);
      ULONG (WINAPI *Release)(IClusCfgResourcePostCreate *This);
      HRESULT (WINAPI *ChangeName)(IClusCfgResourcePostCreate *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *SendResourceControl)(IClusCfgResourcePostCreate *This,DWORD dwControlCodeIn,LPVOID lpBufferIn,DWORD cbBufferSizeIn,LPVOID lBufferInout,DWORD cbOutBufferSizeIn,LPDWORD lpcbBytesReturnedOut);
    END_INTERFACE
  } IClusCfgResourcePostCreateVtbl;
  struct IClusCfgResourcePostCreate {
    CONST_VTBL struct IClusCfgResourcePostCreateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgResourcePostCreate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgResourcePostCreate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgResourcePostCreate_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgResourcePostCreate_ChangeName(This,pcszNameIn) (This)->lpVtbl->ChangeName(This,pcszNameIn)
#define IClusCfgResourcePostCreate_SendResourceControl(This,dwControlCodeIn,lpBufferIn,cbBufferSizeIn,lBufferInout,cbOutBufferSizeIn,lpcbBytesReturnedOut) (This)->lpVtbl->SendResourceControl(This,dwControlCodeIn,lpBufferIn,cbBufferSizeIn,lBufferInout,cbOutBufferSizeIn,lpcbBytesReturnedOut)
#endif
#endif
  HRESULT WINAPI IClusCfgResourcePostCreate_ChangeName_Proxy(IClusCfgResourcePostCreate *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgResourcePostCreate_ChangeName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourcePostCreate_SendResourceControl_Proxy(IClusCfgResourcePostCreate *This,DWORD dwControlCodeIn,LPVOID lpBufferIn,DWORD cbBufferSizeIn,LPVOID lBufferInout,DWORD cbOutBufferSizeIn,LPDWORD lpcbBytesReturnedOut);
  void __RPC_STUB IClusCfgResourcePostCreate_SendResourceControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgGroupCfg_INTERFACE_DEFINED__
#define __IClusCfgGroupCfg_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgGroupCfg;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgGroupCfg : public IUnknown {
  public:
    virtual HRESULT WINAPI SetName(LPCWSTR pcszNameIn) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pbstrNameOut) = 0;
  };
#else
  typedef struct IClusCfgGroupCfgVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgGroupCfg *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgGroupCfg *This);
      ULONG (WINAPI *Release)(IClusCfgGroupCfg *This);
      HRESULT (WINAPI *SetName)(IClusCfgGroupCfg *This,LPCWSTR pcszNameIn);
      HRESULT (WINAPI *GetName)(IClusCfgGroupCfg *This,BSTR *pbstrNameOut);
    END_INTERFACE
  } IClusCfgGroupCfgVtbl;
  struct IClusCfgGroupCfg {
    CONST_VTBL struct IClusCfgGroupCfgVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgGroupCfg_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgGroupCfg_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgGroupCfg_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgGroupCfg_SetName(This,pcszNameIn) (This)->lpVtbl->SetName(This,pcszNameIn)
#define IClusCfgGroupCfg_GetName(This,pbstrNameOut) (This)->lpVtbl->GetName(This,pbstrNameOut)
#endif
#endif
  HRESULT WINAPI IClusCfgGroupCfg_SetName_Proxy(IClusCfgGroupCfg *This,LPCWSTR pcszNameIn);
  void __RPC_STUB IClusCfgGroupCfg_SetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgGroupCfg_GetName_Proxy(IClusCfgGroupCfg *This,BSTR *pbstrNameOut);
  void __RPC_STUB IClusCfgGroupCfg_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgMemberSetChangeListener_INTERFACE_DEFINED__
#define __IClusCfgMemberSetChangeListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgMemberSetChangeListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgMemberSetChangeListener : public IUnknown {
  public:
    virtual HRESULT WINAPI Notify(IUnknown *punkClusterInfoIn) = 0;
  };
#else
  typedef struct IClusCfgMemberSetChangeListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgMemberSetChangeListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgMemberSetChangeListener *This);
      ULONG (WINAPI *Release)(IClusCfgMemberSetChangeListener *This);
      HRESULT (WINAPI *Notify)(IClusCfgMemberSetChangeListener *This,IUnknown *punkClusterInfoIn);
    END_INTERFACE
  } IClusCfgMemberSetChangeListenerVtbl;
  struct IClusCfgMemberSetChangeListener {
    CONST_VTBL struct IClusCfgMemberSetChangeListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgMemberSetChangeListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgMemberSetChangeListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgMemberSetChangeListener_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgMemberSetChangeListener_Notify(This,punkClusterInfoIn) (This)->lpVtbl->Notify(This,punkClusterInfoIn)
#endif
#endif
  HRESULT WINAPI IClusCfgMemberSetChangeListener_Notify_Proxy(IClusCfgMemberSetChangeListener *This,IUnknown *punkClusterInfoIn);
  void __RPC_STUB IClusCfgMemberSetChangeListener_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgMemberSetChangeListener_INTERFACE_DEFINED__
#define __AsyncIClusCfgMemberSetChangeListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgMemberSetChangeListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgMemberSetChangeListener : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Notify(IUnknown *punkClusterInfoIn) = 0;
    virtual HRESULT WINAPI Finish_Notify(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgMemberSetChangeListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgMemberSetChangeListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgMemberSetChangeListener *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgMemberSetChangeListener *This);
      HRESULT (WINAPI *Begin_Notify)(AsyncIClusCfgMemberSetChangeListener *This,IUnknown *punkClusterInfoIn);
      HRESULT (WINAPI *Finish_Notify)(AsyncIClusCfgMemberSetChangeListener *This);
    END_INTERFACE
  } AsyncIClusCfgMemberSetChangeListenerVtbl;
  struct AsyncIClusCfgMemberSetChangeListener {
    CONST_VTBL struct AsyncIClusCfgMemberSetChangeListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgMemberSetChangeListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgMemberSetChangeListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgMemberSetChangeListener_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgMemberSetChangeListener_Begin_Notify(This,punkClusterInfoIn) (This)->lpVtbl->Begin_Notify(This,punkClusterInfoIn)
#define AsyncIClusCfgMemberSetChangeListener_Finish_Notify(This) (This)->lpVtbl->Finish_Notify(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgMemberSetChangeListener_Begin_Notify_Proxy(AsyncIClusCfgMemberSetChangeListener *This,IUnknown *punkClusterInfoIn);
  void __RPC_STUB AsyncIClusCfgMemberSetChangeListener_Begin_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgMemberSetChangeListener_Finish_Notify_Proxy(AsyncIClusCfgMemberSetChangeListener *This);
  void __RPC_STUB AsyncIClusCfgMemberSetChangeListener_Finish_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgResourceTypeInfo_INTERFACE_DEFINED__
#define __IClusCfgResourceTypeInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgResourceTypeInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgResourceTypeInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI CommitChanges(IUnknown *punkClusterInfoIn,IUnknown *punkResTypeServicesIn) = 0;
    virtual HRESULT WINAPI GetTypeName(BSTR *pbstrTypeNameOut) = 0;
    virtual HRESULT WINAPI GetTypeGUID(GUID *pguidGUIDOut) = 0;
  };
#else
  typedef struct IClusCfgResourceTypeInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgResourceTypeInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgResourceTypeInfo *This);
      ULONG (WINAPI *Release)(IClusCfgResourceTypeInfo *This);
      HRESULT (WINAPI *CommitChanges)(IClusCfgResourceTypeInfo *This,IUnknown *punkClusterInfoIn,IUnknown *punkResTypeServicesIn);
      HRESULT (WINAPI *GetTypeName)(IClusCfgResourceTypeInfo *This,BSTR *pbstrTypeNameOut);
      HRESULT (WINAPI *GetTypeGUID)(IClusCfgResourceTypeInfo *This,GUID *pguidGUIDOut);
    END_INTERFACE
  } IClusCfgResourceTypeInfoVtbl;
  struct IClusCfgResourceTypeInfo {
    CONST_VTBL struct IClusCfgResourceTypeInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgResourceTypeInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgResourceTypeInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgResourceTypeInfo_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgResourceTypeInfo_CommitChanges(This,punkClusterInfoIn,punkResTypeServicesIn) (This)->lpVtbl->CommitChanges(This,punkClusterInfoIn,punkResTypeServicesIn)
#define IClusCfgResourceTypeInfo_GetTypeName(This,pbstrTypeNameOut) (This)->lpVtbl->GetTypeName(This,pbstrTypeNameOut)
#define IClusCfgResourceTypeInfo_GetTypeGUID(This,pguidGUIDOut) (This)->lpVtbl->GetTypeGUID(This,pguidGUIDOut)
#endif
#endif
  HRESULT WINAPI IClusCfgResourceTypeInfo_CommitChanges_Proxy(IClusCfgResourceTypeInfo *This,IUnknown *punkClusterInfoIn,IUnknown *punkResTypeServicesIn);
  void __RPC_STUB IClusCfgResourceTypeInfo_CommitChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceTypeInfo_GetTypeName_Proxy(IClusCfgResourceTypeInfo *This,BSTR *pbstrTypeNameOut);
  void __RPC_STUB IClusCfgResourceTypeInfo_GetTypeName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceTypeInfo_GetTypeGUID_Proxy(IClusCfgResourceTypeInfo *This,GUID *pguidGUIDOut);
  void __RPC_STUB IClusCfgResourceTypeInfo_GetTypeGUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgResourceTypeInfo_INTERFACE_DEFINED__
#define __AsyncIClusCfgResourceTypeInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgResourceTypeInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgResourceTypeInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_CommitChanges(IUnknown *punkClusterInfoIn,IUnknown *punkResTypeServicesIn) = 0;
    virtual HRESULT WINAPI Finish_CommitChanges(void) = 0;
    virtual HRESULT WINAPI Begin_GetTypeName(void) = 0;
    virtual HRESULT WINAPI Finish_GetTypeName(BSTR *pbstrTypeNameOut) = 0;
    virtual HRESULT WINAPI Begin_GetTypeGUID(void) = 0;
    virtual HRESULT WINAPI Finish_GetTypeGUID(GUID *pguidGUIDOut) = 0;
  };
#else
  typedef struct AsyncIClusCfgResourceTypeInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgResourceTypeInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgResourceTypeInfo *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgResourceTypeInfo *This);
      HRESULT (WINAPI *Begin_CommitChanges)(AsyncIClusCfgResourceTypeInfo *This,IUnknown *punkClusterInfoIn,IUnknown *punkResTypeServicesIn);
      HRESULT (WINAPI *Finish_CommitChanges)(AsyncIClusCfgResourceTypeInfo *This);
      HRESULT (WINAPI *Begin_GetTypeName)(AsyncIClusCfgResourceTypeInfo *This);
      HRESULT (WINAPI *Finish_GetTypeName)(AsyncIClusCfgResourceTypeInfo *This,BSTR *pbstrTypeNameOut);
      HRESULT (WINAPI *Begin_GetTypeGUID)(AsyncIClusCfgResourceTypeInfo *This);
      HRESULT (WINAPI *Finish_GetTypeGUID)(AsyncIClusCfgResourceTypeInfo *This,GUID *pguidGUIDOut);
    END_INTERFACE
  } AsyncIClusCfgResourceTypeInfoVtbl;
  struct AsyncIClusCfgResourceTypeInfo {
    CONST_VTBL struct AsyncIClusCfgResourceTypeInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgResourceTypeInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgResourceTypeInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgResourceTypeInfo_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgResourceTypeInfo_Begin_CommitChanges(This,punkClusterInfoIn,punkResTypeServicesIn) (This)->lpVtbl->Begin_CommitChanges(This,punkClusterInfoIn,punkResTypeServicesIn)
#define AsyncIClusCfgResourceTypeInfo_Finish_CommitChanges(This) (This)->lpVtbl->Finish_CommitChanges(This)
#define AsyncIClusCfgResourceTypeInfo_Begin_GetTypeName(This) (This)->lpVtbl->Begin_GetTypeName(This)
#define AsyncIClusCfgResourceTypeInfo_Finish_GetTypeName(This,pbstrTypeNameOut) (This)->lpVtbl->Finish_GetTypeName(This,pbstrTypeNameOut)
#define AsyncIClusCfgResourceTypeInfo_Begin_GetTypeGUID(This) (This)->lpVtbl->Begin_GetTypeGUID(This)
#define AsyncIClusCfgResourceTypeInfo_Finish_GetTypeGUID(This,pguidGUIDOut) (This)->lpVtbl->Finish_GetTypeGUID(This,pguidGUIDOut)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgResourceTypeInfo_Begin_CommitChanges_Proxy(AsyncIClusCfgResourceTypeInfo *This,IUnknown *punkClusterInfoIn,IUnknown *punkResTypeServicesIn);
  void __RPC_STUB AsyncIClusCfgResourceTypeInfo_Begin_CommitChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeInfo_Finish_CommitChanges_Proxy(AsyncIClusCfgResourceTypeInfo *This);
  void __RPC_STUB AsyncIClusCfgResourceTypeInfo_Finish_CommitChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeInfo_Begin_GetTypeName_Proxy(AsyncIClusCfgResourceTypeInfo *This);
  void __RPC_STUB AsyncIClusCfgResourceTypeInfo_Begin_GetTypeName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeInfo_Finish_GetTypeName_Proxy(AsyncIClusCfgResourceTypeInfo *This,BSTR *pbstrTypeNameOut);
  void __RPC_STUB AsyncIClusCfgResourceTypeInfo_Finish_GetTypeName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeInfo_Begin_GetTypeGUID_Proxy(AsyncIClusCfgResourceTypeInfo *This);
  void __RPC_STUB AsyncIClusCfgResourceTypeInfo_Begin_GetTypeGUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeInfo_Finish_GetTypeGUID_Proxy(AsyncIClusCfgResourceTypeInfo *This,GUID *pguidGUIDOut);
  void __RPC_STUB AsyncIClusCfgResourceTypeInfo_Finish_GetTypeGUID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgResourceTypeCreate_INTERFACE_DEFINED__
#define __IClusCfgResourceTypeCreate_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgResourceTypeCreate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgResourceTypeCreate : public IUnknown {
  public:
    virtual HRESULT WINAPI Create(const WCHAR *pcszResTypeNameIn,const WCHAR *pcszResTypeDisplayNameIn,const WCHAR *pcszResDllNameIn,DWORD dwLooksAliveIntervalIn,DWORD dwIsAliveIntervalIn) = 0;
    virtual HRESULT WINAPI RegisterAdminExtensions(const WCHAR *pcszResTypeNameIn,ULONG cExtClsidCountIn,const CLSID *rgclsidExtClsidsIn) = 0;
  };
#else
  typedef struct IClusCfgResourceTypeCreateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgResourceTypeCreate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgResourceTypeCreate *This);
      ULONG (WINAPI *Release)(IClusCfgResourceTypeCreate *This);
      HRESULT (WINAPI *Create)(IClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,const WCHAR *pcszResTypeDisplayNameIn,const WCHAR *pcszResDllNameIn,DWORD dwLooksAliveIntervalIn,DWORD dwIsAliveIntervalIn);
      HRESULT (WINAPI *RegisterAdminExtensions)(IClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,ULONG cExtClsidCountIn,const CLSID *rgclsidExtClsidsIn);
    END_INTERFACE
  } IClusCfgResourceTypeCreateVtbl;
  struct IClusCfgResourceTypeCreate {
    CONST_VTBL struct IClusCfgResourceTypeCreateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgResourceTypeCreate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgResourceTypeCreate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgResourceTypeCreate_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgResourceTypeCreate_Create(This,pcszResTypeNameIn,pcszResTypeDisplayNameIn,pcszResDllNameIn,dwLooksAliveIntervalIn,dwIsAliveIntervalIn) (This)->lpVtbl->Create(This,pcszResTypeNameIn,pcszResTypeDisplayNameIn,pcszResDllNameIn,dwLooksAliveIntervalIn,dwIsAliveIntervalIn)
#define IClusCfgResourceTypeCreate_RegisterAdminExtensions(This,pcszResTypeNameIn,cExtClsidCountIn,rgclsidExtClsidsIn) (This)->lpVtbl->RegisterAdminExtensions(This,pcszResTypeNameIn,cExtClsidCountIn,rgclsidExtClsidsIn)
#endif
#endif
  HRESULT WINAPI IClusCfgResourceTypeCreate_Create_Proxy(IClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,const WCHAR *pcszResTypeDisplayNameIn,const WCHAR *pcszResDllNameIn,DWORD dwLooksAliveIntervalIn,DWORD dwIsAliveIntervalIn);
  void __RPC_STUB IClusCfgResourceTypeCreate_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgResourceTypeCreate_RegisterAdminExtensions_Proxy(IClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,ULONG cExtClsidCountIn,const CLSID *rgclsidExtClsidsIn);
  void __RPC_STUB IClusCfgResourceTypeCreate_RegisterAdminExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgResourceTypeCreate_INTERFACE_DEFINED__
#define __AsyncIClusCfgResourceTypeCreate_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgResourceTypeCreate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgResourceTypeCreate : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Create(const WCHAR *pcszResTypeNameIn,const WCHAR *pcszResTypeDisplayNameIn,const WCHAR *pcszResDllNameIn,DWORD dwLooksAliveIntervalIn,DWORD dwIsAliveIntervalIn) = 0;
    virtual HRESULT WINAPI Finish_Create(void) = 0;
    virtual HRESULT WINAPI Begin_RegisterAdminExtensions(const WCHAR *pcszResTypeNameIn,ULONG cExtClsidCountIn,const CLSID *rgclsidExtClsidsIn) = 0;
    virtual HRESULT WINAPI Finish_RegisterAdminExtensions(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgResourceTypeCreateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgResourceTypeCreate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgResourceTypeCreate *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgResourceTypeCreate *This);
      HRESULT (WINAPI *Begin_Create)(AsyncIClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,const WCHAR *pcszResTypeDisplayNameIn,const WCHAR *pcszResDllNameIn,DWORD dwLooksAliveIntervalIn,DWORD dwIsAliveIntervalIn);
      HRESULT (WINAPI *Finish_Create)(AsyncIClusCfgResourceTypeCreate *This);
      HRESULT (WINAPI *Begin_RegisterAdminExtensions)(AsyncIClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,ULONG cExtClsidCountIn,const CLSID *rgclsidExtClsidsIn);
      HRESULT (WINAPI *Finish_RegisterAdminExtensions)(AsyncIClusCfgResourceTypeCreate *This);
    END_INTERFACE
  } AsyncIClusCfgResourceTypeCreateVtbl;
  struct AsyncIClusCfgResourceTypeCreate {
    CONST_VTBL struct AsyncIClusCfgResourceTypeCreateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgResourceTypeCreate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgResourceTypeCreate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgResourceTypeCreate_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgResourceTypeCreate_Begin_Create(This,pcszResTypeNameIn,pcszResTypeDisplayNameIn,pcszResDllNameIn,dwLooksAliveIntervalIn,dwIsAliveIntervalIn) (This)->lpVtbl->Begin_Create(This,pcszResTypeNameIn,pcszResTypeDisplayNameIn,pcszResDllNameIn,dwLooksAliveIntervalIn,dwIsAliveIntervalIn)
#define AsyncIClusCfgResourceTypeCreate_Finish_Create(This) (This)->lpVtbl->Finish_Create(This)
#define AsyncIClusCfgResourceTypeCreate_Begin_RegisterAdminExtensions(This,pcszResTypeNameIn,cExtClsidCountIn,rgclsidExtClsidsIn) (This)->lpVtbl->Begin_RegisterAdminExtensions(This,pcszResTypeNameIn,cExtClsidCountIn,rgclsidExtClsidsIn)
#define AsyncIClusCfgResourceTypeCreate_Finish_RegisterAdminExtensions(This) (This)->lpVtbl->Finish_RegisterAdminExtensions(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgResourceTypeCreate_Begin_Create_Proxy(AsyncIClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,const WCHAR *pcszResTypeDisplayNameIn,const WCHAR *pcszResDllNameIn,DWORD dwLooksAliveIntervalIn,DWORD dwIsAliveIntervalIn);
  void __RPC_STUB AsyncIClusCfgResourceTypeCreate_Begin_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeCreate_Finish_Create_Proxy(AsyncIClusCfgResourceTypeCreate *This);
  void __RPC_STUB AsyncIClusCfgResourceTypeCreate_Finish_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeCreate_Begin_RegisterAdminExtensions_Proxy(AsyncIClusCfgResourceTypeCreate *This,const WCHAR *pcszResTypeNameIn,ULONG cExtClsidCountIn,const CLSID *rgclsidExtClsidsIn);
  void __RPC_STUB AsyncIClusCfgResourceTypeCreate_Begin_RegisterAdminExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgResourceTypeCreate_Finish_RegisterAdminExtensions_Proxy(AsyncIClusCfgResourceTypeCreate *This);
  void __RPC_STUB AsyncIClusCfgResourceTypeCreate_Finish_RegisterAdminExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgEvictCleanup_INTERFACE_DEFINED__
#define __IClusCfgEvictCleanup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgEvictCleanup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgEvictCleanup : public IUnknown {
  public:
    virtual HRESULT WINAPI CleanupLocalNode(DWORD dwDelayIn) = 0;
    virtual HRESULT WINAPI CleanupRemoteNode(const WCHAR *pcszEvictedNodeNameIn,DWORD dwDelayIn) = 0;
  };
#else
  typedef struct IClusCfgEvictCleanupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgEvictCleanup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgEvictCleanup *This);
      ULONG (WINAPI *Release)(IClusCfgEvictCleanup *This);
      HRESULT (WINAPI *CleanupLocalNode)(IClusCfgEvictCleanup *This,DWORD dwDelayIn);
      HRESULT (WINAPI *CleanupRemoteNode)(IClusCfgEvictCleanup *This,const WCHAR *pcszEvictedNodeNameIn,DWORD dwDelayIn);
    END_INTERFACE
  } IClusCfgEvictCleanupVtbl;
  struct IClusCfgEvictCleanup {
    CONST_VTBL struct IClusCfgEvictCleanupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgEvictCleanup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgEvictCleanup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgEvictCleanup_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgEvictCleanup_CleanupLocalNode(This,dwDelayIn) (This)->lpVtbl->CleanupLocalNode(This,dwDelayIn)
#define IClusCfgEvictCleanup_CleanupRemoteNode(This,pcszEvictedNodeNameIn,dwDelayIn) (This)->lpVtbl->CleanupRemoteNode(This,pcszEvictedNodeNameIn,dwDelayIn)
#endif
#endif
  HRESULT WINAPI IClusCfgEvictCleanup_CleanupLocalNode_Proxy(IClusCfgEvictCleanup *This,DWORD dwDelayIn);
  void __RPC_STUB IClusCfgEvictCleanup_CleanupLocalNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgEvictCleanup_CleanupRemoteNode_Proxy(IClusCfgEvictCleanup *This,const WCHAR *pcszEvictedNodeNameIn,DWORD dwDelayIn);
  void __RPC_STUB IClusCfgEvictCleanup_CleanupRemoteNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgEvictCleanup_INTERFACE_DEFINED__
#define __AsyncIClusCfgEvictCleanup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgEvictCleanup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgEvictCleanup : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_CleanupLocalNode(DWORD dwDelayIn) = 0;
    virtual HRESULT WINAPI Finish_CleanupLocalNode(void) = 0;
    virtual HRESULT WINAPI Begin_CleanupRemoteNode(const WCHAR *pcszEvictedNodeNameIn,DWORD dwDelayIn) = 0;
    virtual HRESULT WINAPI Finish_CleanupRemoteNode(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgEvictCleanupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgEvictCleanup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgEvictCleanup *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgEvictCleanup *This);
      HRESULT (WINAPI *Begin_CleanupLocalNode)(AsyncIClusCfgEvictCleanup *This,DWORD dwDelayIn);
      HRESULT (WINAPI *Finish_CleanupLocalNode)(AsyncIClusCfgEvictCleanup *This);
      HRESULT (WINAPI *Begin_CleanupRemoteNode)(AsyncIClusCfgEvictCleanup *This,const WCHAR *pcszEvictedNodeNameIn,DWORD dwDelayIn);
      HRESULT (WINAPI *Finish_CleanupRemoteNode)(AsyncIClusCfgEvictCleanup *This);
    END_INTERFACE
  } AsyncIClusCfgEvictCleanupVtbl;
  struct AsyncIClusCfgEvictCleanup {
    CONST_VTBL struct AsyncIClusCfgEvictCleanupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgEvictCleanup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgEvictCleanup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgEvictCleanup_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgEvictCleanup_Begin_CleanupLocalNode(This,dwDelayIn) (This)->lpVtbl->Begin_CleanupLocalNode(This,dwDelayIn)
#define AsyncIClusCfgEvictCleanup_Finish_CleanupLocalNode(This) (This)->lpVtbl->Finish_CleanupLocalNode(This)
#define AsyncIClusCfgEvictCleanup_Begin_CleanupRemoteNode(This,pcszEvictedNodeNameIn,dwDelayIn) (This)->lpVtbl->Begin_CleanupRemoteNode(This,pcszEvictedNodeNameIn,dwDelayIn)
#define AsyncIClusCfgEvictCleanup_Finish_CleanupRemoteNode(This) (This)->lpVtbl->Finish_CleanupRemoteNode(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgEvictCleanup_Begin_CleanupLocalNode_Proxy(AsyncIClusCfgEvictCleanup *This,DWORD dwDelayIn);
  void __RPC_STUB AsyncIClusCfgEvictCleanup_Begin_CleanupLocalNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgEvictCleanup_Finish_CleanupLocalNode_Proxy(AsyncIClusCfgEvictCleanup *This);
  void __RPC_STUB AsyncIClusCfgEvictCleanup_Finish_CleanupLocalNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgEvictCleanup_Begin_CleanupRemoteNode_Proxy(AsyncIClusCfgEvictCleanup *This,const WCHAR *pcszEvictedNodeNameIn,DWORD dwDelayIn);
  void __RPC_STUB AsyncIClusCfgEvictCleanup_Begin_CleanupRemoteNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgEvictCleanup_Finish_CleanupRemoteNode_Proxy(AsyncIClusCfgEvictCleanup *This);
  void __RPC_STUB AsyncIClusCfgEvictCleanup_Finish_CleanupRemoteNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgStartupListener_INTERFACE_DEFINED__
#define __IClusCfgStartupListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgStartupListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgStartupListener : public IUnknown {
  public:
    virtual HRESULT WINAPI Notify(IUnknown *punkIn) = 0;
  };
#else
  typedef struct IClusCfgStartupListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgStartupListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgStartupListener *This);
      ULONG (WINAPI *Release)(IClusCfgStartupListener *This);
      HRESULT (WINAPI *Notify)(IClusCfgStartupListener *This,IUnknown *punkIn);
    END_INTERFACE
  } IClusCfgStartupListenerVtbl;
  struct IClusCfgStartupListener {
    CONST_VTBL struct IClusCfgStartupListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgStartupListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgStartupListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgStartupListener_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgStartupListener_Notify(This,punkIn) (This)->lpVtbl->Notify(This,punkIn)
#endif
#endif
  HRESULT WINAPI IClusCfgStartupListener_Notify_Proxy(IClusCfgStartupListener *This,IUnknown *punkIn);
  void __RPC_STUB IClusCfgStartupListener_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgStartupListener_INTERFACE_DEFINED__
#define __AsyncIClusCfgStartupListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgStartupListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgStartupListener : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_Notify(IUnknown *punkIn) = 0;
    virtual HRESULT WINAPI Finish_Notify(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgStartupListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgStartupListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgStartupListener *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgStartupListener *This);
      HRESULT (WINAPI *Begin_Notify)(AsyncIClusCfgStartupListener *This,IUnknown *punkIn);
      HRESULT (WINAPI *Finish_Notify)(AsyncIClusCfgStartupListener *This);
    END_INTERFACE
  } AsyncIClusCfgStartupListenerVtbl;
  struct AsyncIClusCfgStartupListener {
    CONST_VTBL struct AsyncIClusCfgStartupListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgStartupListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgStartupListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgStartupListener_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgStartupListener_Begin_Notify(This,punkIn) (This)->lpVtbl->Begin_Notify(This,punkIn)
#define AsyncIClusCfgStartupListener_Finish_Notify(This) (This)->lpVtbl->Finish_Notify(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgStartupListener_Begin_Notify_Proxy(AsyncIClusCfgStartupListener *This,IUnknown *punkIn);
  void __RPC_STUB AsyncIClusCfgStartupListener_Begin_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgStartupListener_Finish_Notify_Proxy(AsyncIClusCfgStartupListener *This);
  void __RPC_STUB AsyncIClusCfgStartupListener_Finish_Notify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgStartupNotify_INTERFACE_DEFINED__
#define __IClusCfgStartupNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgStartupNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgStartupNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI SendNotifications(void) = 0;
  };
#else
  typedef struct IClusCfgStartupNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgStartupNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgStartupNotify *This);
      ULONG (WINAPI *Release)(IClusCfgStartupNotify *This);
      HRESULT (WINAPI *SendNotifications)(IClusCfgStartupNotify *This);
    END_INTERFACE
  } IClusCfgStartupNotifyVtbl;
  struct IClusCfgStartupNotify {
    CONST_VTBL struct IClusCfgStartupNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgStartupNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgStartupNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgStartupNotify_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgStartupNotify_SendNotifications(This) (This)->lpVtbl->SendNotifications(This)
#endif
#endif
  HRESULT WINAPI IClusCfgStartupNotify_SendNotifications_Proxy(IClusCfgStartupNotify *This);
  void __RPC_STUB IClusCfgStartupNotify_SendNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgStartupNotify_INTERFACE_DEFINED__
#define __AsyncIClusCfgStartupNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgStartupNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgStartupNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_SendNotifications(void) = 0;
    virtual HRESULT WINAPI Finish_SendNotifications(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgStartupNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgStartupNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgStartupNotify *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgStartupNotify *This);
      HRESULT (WINAPI *Begin_SendNotifications)(AsyncIClusCfgStartupNotify *This);
      HRESULT (WINAPI *Finish_SendNotifications)(AsyncIClusCfgStartupNotify *This);
    END_INTERFACE
  } AsyncIClusCfgStartupNotifyVtbl;
  struct AsyncIClusCfgStartupNotify {
    CONST_VTBL struct AsyncIClusCfgStartupNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgStartupNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgStartupNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgStartupNotify_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgStartupNotify_Begin_SendNotifications(This) (This)->lpVtbl->Begin_SendNotifications(This)
#define AsyncIClusCfgStartupNotify_Finish_SendNotifications(This) (This)->lpVtbl->Finish_SendNotifications(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgStartupNotify_Begin_SendNotifications_Proxy(AsyncIClusCfgStartupNotify *This);
  void __RPC_STUB AsyncIClusCfgStartupNotify_Begin_SendNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgStartupNotify_Finish_SendNotifications_Proxy(AsyncIClusCfgStartupNotify *This);
  void __RPC_STUB AsyncIClusCfgStartupNotify_Finish_SendNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgManagedResourceData_INTERFACE_DEFINED__
#define __IClusCfgManagedResourceData_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgManagedResourceData;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgManagedResourceData : public IUnknown {
  public:
    virtual HRESULT WINAPI GetResourcePrivateData(BYTE *pbBufferOut,DWORD *pcbBufferInout) = 0;
    virtual HRESULT WINAPI SetResourcePrivateData(const BYTE *pcbBufferIn,DWORD cbBufferIn) = 0;
  };
#else
  typedef struct IClusCfgManagedResourceDataVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgManagedResourceData *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgManagedResourceData *This);
      ULONG (WINAPI *Release)(IClusCfgManagedResourceData *This);
      HRESULT (WINAPI *GetResourcePrivateData)(IClusCfgManagedResourceData *This,BYTE *pbBufferOut,DWORD *pcbBufferInout);
      HRESULT (WINAPI *SetResourcePrivateData)(IClusCfgManagedResourceData *This,const BYTE *pcbBufferIn,DWORD cbBufferIn);
    END_INTERFACE
  } IClusCfgManagedResourceDataVtbl;
  struct IClusCfgManagedResourceData {
    CONST_VTBL struct IClusCfgManagedResourceDataVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgManagedResourceData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgManagedResourceData_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgManagedResourceData_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgManagedResourceData_GetResourcePrivateData(This,pbBufferOut,pcbBufferInout) (This)->lpVtbl->GetResourcePrivateData(This,pbBufferOut,pcbBufferInout)
#define IClusCfgManagedResourceData_SetResourcePrivateData(This,pcbBufferIn,cbBufferIn) (This)->lpVtbl->SetResourcePrivateData(This,pcbBufferIn,cbBufferIn)
#endif
#endif
  HRESULT WINAPI IClusCfgManagedResourceData_GetResourcePrivateData_Proxy(IClusCfgManagedResourceData *This,BYTE *pbBufferOut,DWORD *pcbBufferInout);
  void __RPC_STUB IClusCfgManagedResourceData_GetResourcePrivateData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgManagedResourceData_SetResourcePrivateData_Proxy(IClusCfgManagedResourceData *This,const BYTE *pcbBufferIn,DWORD cbBufferIn);
  void __RPC_STUB IClusCfgManagedResourceData_SetResourcePrivateData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgVerifyQuorum_INTERFACE_DEFINED__
#define __IClusCfgVerifyQuorum_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgVerifyQuorum;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgVerifyQuorum : public IUnknown {
  public:
    virtual HRESULT WINAPI PrepareToHostQuorumResource(void) = 0;
    virtual HRESULT WINAPI Cleanup(EClusCfgCleanupReason cccrReasonIn) = 0;
    virtual HRESULT WINAPI IsMultiNodeCapable(void) = 0;
    virtual HRESULT WINAPI SetMultiNodeCapable(WINBOOL fMultiNodeCapableIn) = 0;
  };
#else
  typedef struct IClusCfgVerifyQuorumVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgVerifyQuorum *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgVerifyQuorum *This);
      ULONG (WINAPI *Release)(IClusCfgVerifyQuorum *This);
      HRESULT (WINAPI *PrepareToHostQuorumResource)(IClusCfgVerifyQuorum *This);
      HRESULT (WINAPI *Cleanup)(IClusCfgVerifyQuorum *This,EClusCfgCleanupReason cccrReasonIn);
      HRESULT (WINAPI *IsMultiNodeCapable)(IClusCfgVerifyQuorum *This);
      HRESULT (WINAPI *SetMultiNodeCapable)(IClusCfgVerifyQuorum *This,WINBOOL fMultiNodeCapableIn);
    END_INTERFACE
  } IClusCfgVerifyQuorumVtbl;
  struct IClusCfgVerifyQuorum {
    CONST_VTBL struct IClusCfgVerifyQuorumVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgVerifyQuorum_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgVerifyQuorum_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgVerifyQuorum_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgVerifyQuorum_PrepareToHostQuorumResource(This) (This)->lpVtbl->PrepareToHostQuorumResource(This)
#define IClusCfgVerifyQuorum_Cleanup(This,cccrReasonIn) (This)->lpVtbl->Cleanup(This,cccrReasonIn)
#define IClusCfgVerifyQuorum_IsMultiNodeCapable(This) (This)->lpVtbl->IsMultiNodeCapable(This)
#define IClusCfgVerifyQuorum_SetMultiNodeCapable(This,fMultiNodeCapableIn) (This)->lpVtbl->SetMultiNodeCapable(This,fMultiNodeCapableIn)
#endif
#endif
  HRESULT WINAPI IClusCfgVerifyQuorum_PrepareToHostQuorumResource_Proxy(IClusCfgVerifyQuorum *This);
  void __RPC_STUB IClusCfgVerifyQuorum_PrepareToHostQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgVerifyQuorum_Cleanup_Proxy(IClusCfgVerifyQuorum *This,EClusCfgCleanupReason cccrReasonIn);
  void __RPC_STUB IClusCfgVerifyQuorum_Cleanup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgVerifyQuorum_IsMultiNodeCapable_Proxy(IClusCfgVerifyQuorum *This);
  void __RPC_STUB IClusCfgVerifyQuorum_IsMultiNodeCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IClusCfgVerifyQuorum_SetMultiNodeCapable_Proxy(IClusCfgVerifyQuorum *This,WINBOOL fMultiNodeCapableIn);
  void __RPC_STUB IClusCfgVerifyQuorum_SetMultiNodeCapable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgEvictListener_INTERFACE_DEFINED__
#define __IClusCfgEvictListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgEvictListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgEvictListener : public IUnknown {
  public:
    virtual HRESULT WINAPI EvictNotify(LPCWSTR pcszNodeNameIn) = 0;
  };
#else
  typedef struct IClusCfgEvictListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgEvictListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgEvictListener *This);
      ULONG (WINAPI *Release)(IClusCfgEvictListener *This);
      HRESULT (WINAPI *EvictNotify)(IClusCfgEvictListener *This,LPCWSTR pcszNodeNameIn);
    END_INTERFACE
  } IClusCfgEvictListenerVtbl;
  struct IClusCfgEvictListener {
    CONST_VTBL struct IClusCfgEvictListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgEvictListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgEvictListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgEvictListener_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgEvictListener_EvictNotify(This,pcszNodeNameIn) (This)->lpVtbl->EvictNotify(This,pcszNodeNameIn)
#endif
#endif
  HRESULT WINAPI IClusCfgEvictListener_EvictNotify_Proxy(IClusCfgEvictListener *This,LPCWSTR pcszNodeNameIn);
  void __RPC_STUB IClusCfgEvictListener_EvictNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgEvictListener_INTERFACE_DEFINED__
#define __AsyncIClusCfgEvictListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgEvictListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgEvictListener : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_EvictNotify(LPCWSTR pcszNodeNameIn) = 0;
    virtual HRESULT WINAPI Finish_EvictNotify(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgEvictListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgEvictListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgEvictListener *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgEvictListener *This);
      HRESULT (WINAPI *Begin_EvictNotify)(AsyncIClusCfgEvictListener *This,LPCWSTR pcszNodeNameIn);
      HRESULT (WINAPI *Finish_EvictNotify)(AsyncIClusCfgEvictListener *This);
    END_INTERFACE
  } AsyncIClusCfgEvictListenerVtbl;
  struct AsyncIClusCfgEvictListener {
    CONST_VTBL struct AsyncIClusCfgEvictListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgEvictListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgEvictListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgEvictListener_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgEvictListener_Begin_EvictNotify(This,pcszNodeNameIn) (This)->lpVtbl->Begin_EvictNotify(This,pcszNodeNameIn)
#define AsyncIClusCfgEvictListener_Finish_EvictNotify(This) (This)->lpVtbl->Finish_EvictNotify(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgEvictListener_Begin_EvictNotify_Proxy(AsyncIClusCfgEvictListener *This,LPCWSTR pcszNodeNameIn);
  void __RPC_STUB AsyncIClusCfgEvictListener_Begin_EvictNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgEvictListener_Finish_EvictNotify_Proxy(AsyncIClusCfgEvictListener *This);
  void __RPC_STUB AsyncIClusCfgEvictListener_Finish_EvictNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IClusCfgEvictNotify_INTERFACE_DEFINED__
#define __IClusCfgEvictNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IClusCfgEvictNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IClusCfgEvictNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI SendNotifications(LPCWSTR pcszNodeNameIn) = 0;
  };
#else
  typedef struct IClusCfgEvictNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IClusCfgEvictNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IClusCfgEvictNotify *This);
      ULONG (WINAPI *Release)(IClusCfgEvictNotify *This);
      HRESULT (WINAPI *SendNotifications)(IClusCfgEvictNotify *This,LPCWSTR pcszNodeNameIn);
    END_INTERFACE
  } IClusCfgEvictNotifyVtbl;
  struct IClusCfgEvictNotify {
    CONST_VTBL struct IClusCfgEvictNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IClusCfgEvictNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IClusCfgEvictNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IClusCfgEvictNotify_Release(This) (This)->lpVtbl->Release(This)
#define IClusCfgEvictNotify_SendNotifications(This,pcszNodeNameIn) (This)->lpVtbl->SendNotifications(This,pcszNodeNameIn)
#endif
#endif
  HRESULT WINAPI IClusCfgEvictNotify_SendNotifications_Proxy(IClusCfgEvictNotify *This,LPCWSTR pcszNodeNameIn);
  void __RPC_STUB IClusCfgEvictNotify_SendNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIClusCfgEvictNotify_INTERFACE_DEFINED__
#define __AsyncIClusCfgEvictNotify_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIClusCfgEvictNotify;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIClusCfgEvictNotify : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_SendNotifications(LPCWSTR pcszNodeNameIn) = 0;
    virtual HRESULT WINAPI Finish_SendNotifications(void) = 0;
  };
#else
  typedef struct AsyncIClusCfgEvictNotifyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIClusCfgEvictNotify *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIClusCfgEvictNotify *This);
      ULONG (WINAPI *Release)(AsyncIClusCfgEvictNotify *This);
      HRESULT (WINAPI *Begin_SendNotifications)(AsyncIClusCfgEvictNotify *This,LPCWSTR pcszNodeNameIn);
      HRESULT (WINAPI *Finish_SendNotifications)(AsyncIClusCfgEvictNotify *This);
    END_INTERFACE
  } AsyncIClusCfgEvictNotifyVtbl;
  struct AsyncIClusCfgEvictNotify {
    CONST_VTBL struct AsyncIClusCfgEvictNotifyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIClusCfgEvictNotify_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIClusCfgEvictNotify_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIClusCfgEvictNotify_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIClusCfgEvictNotify_Begin_SendNotifications(This,pcszNodeNameIn) (This)->lpVtbl->Begin_SendNotifications(This,pcszNodeNameIn)
#define AsyncIClusCfgEvictNotify_Finish_SendNotifications(This) (This)->lpVtbl->Finish_SendNotifications(This)
#endif
#endif
  HRESULT WINAPI AsyncIClusCfgEvictNotify_Begin_SendNotifications_Proxy(AsyncIClusCfgEvictNotify *This,LPCWSTR pcszNodeNameIn);
  void __RPC_STUB AsyncIClusCfgEvictNotify_Begin_SendNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIClusCfgEvictNotify_Finish_SendNotifications_Proxy(AsyncIClusCfgEvictNotify *This);
  void __RPC_STUB AsyncIClusCfgEvictNotify_Finish_SendNotifications_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
