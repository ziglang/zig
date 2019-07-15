/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifndef _RESAPI_DEFINES_
#define _RESAPI_DEFINES_

#include <windows.h>
#include <winsvc.h>
#include <clusapi.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _NO_W32_PSEUDO_MODIFIERS
#ifndef IN
#define IN
#endif
#ifndef OUT
#define OUT
#endif
#ifndef OPTIONAL
#define OPTIONAL
#endif
#endif

#define STARTUP_ROUTINE "Startup"

#define CLRES_V1_FUNCTION_SIZE sizeof(CLRES_V1_FUNCTIONS)
#define CLRES_VERSION_V1_00 0x100

#define CLRES_V1_FUNCTION_TABLE(_Name, _Version, _Prefix, _Arbitrate, _Release, _ResControl, _ResTypeControl) CLRES_FUNCTION_TABLE _Name = { CLRES_V1_FUNCTION_SIZE, _Version, _Prefix##Open, _Prefix##Close, _Prefix##Online, _Prefix##Offline, _Prefix##Terminate, _Prefix##LooksAlive, _Prefix##IsAlive, _Arbitrate, _Release, _ResControl, _ResTypeControl }

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
#define STARTUP_EX_ROUTINE "StartupEx"

#define CLRES_V2_FUNCTION_SIZE sizeof (CLRES_V2_FUNCTIONS)
#define CLRES_VERSION_V2_00 0x200
#define CLRES_V2_FUNCTION_TABLE_SET(_Name, _Version, _Prefix, _Arbitrate, _Release, _ResControl, _ResTypeControl, _LooksAlive, _IsAlive, _Cancel) _Name.TableSize = CLRES_V2_FUNCTION_SIZE; _Name.Version = _Version; _Name.V2Functions.Open = _Prefix##OpenV2; _Name.V2Functions.Close = _Prefix##Close; _Name.V2Functions.Online = _Prefix##OnlineV2; _Name.V2Functions.Offline = _Prefix##OfflineV2; _Name.V2Functions.Terminate = _Prefix##Terminate; _Name.V2Functions.LooksAlive= _LooksAlive; _Name.V2Functions.IsAlive = _IsAlive; _Name.V2Functions.Arbitrate = _Arbitrate; _Name.V2Functions.Release = _Release; _Name.V2Functions.ResourceControl = _ResControl; _Name.V2Functions.ResourceTypeControl = _ResTypeControl; _Name.V2Functions.Cancel = _Cancel;
#endif
#endif

#ifndef _RESAPI_
#define _RESAPI_

#ifndef FIELD_OFFSET
#define FIELD_OFFSET(type, field) ((LONG) __builtin_offsetof(Type, Field))
#endif

#define ClusterResourceCannotComeOnlineOnThisNode (CLUSTER_RESOURCE_STATE) (ClusterResourcePending - 1)
#define ClusterResourceCannotComeOnlineOnAnyNode (CLUSTER_RESOURCE_STATE) (ClusterResourcePending - 2)

#define ResUtilInitializeResourceStatus(_resource_status_) ZeroMemory (_resource_status_, sizeof (RESOURCE_STATUS))

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
#define CLUSCTL_GET_OPERATION_CONTEXT_PARAMS_VERSION_1 1

#define CLUSRES_GET_OPERATION_CONTEXT_FLAGS { CLUSRES_NAME_GET_OPERATION_CONTEXT_FLAGS, NULL, CLUSPROP_FORMAT_DWORD, 0, 0, 0xffffffff, RESUTIL_PROPITEM_REQUIRED, 0 }
#define CLUSRES_NAME_GET_OPERATION_CONTEXT_FLAGS L"Flags"

#define RESOURCE_SPECIFIC_STATUS_PROP_ITEM { CLUSREG_NAME_RES_STATUS, NULL, CLUSPROP_FORMAT_SZ, 0, 0, 0, RESUTIL_PROPITEM_IN_MEMORY, 0 }
#define RESOURCE_SPECIFIC_DATA1_PROP_ITEM { CLUSREG_NAME_RES_DATA1, NULL, CLUSPROP_FORMAT_ULARGE_INTEGER, 0, 0, 0, RESUTIL_PROPITEM_READ_ONLY | RESUTIL_PROPITEM_IN_MEMORY, 0 }
#define RESOURCE_SPECIFIC_DATA2_PROP_ITEM { CLUSREG_NAME_RES_DATA2, NULL, CLUSPROP_FORMAT_ULARGE_INTEGER, 0, 0, 0, RESUTIL_PROPITEM_READ_ONLY | RESUTIL_PROPITEM_IN_MEMORY, 0 }

#define CLUSRESDLL_STATUS_OFFLINE_BUSY 0x00000001
#define CLUSRESDLL_STATUS_OFFLINE_SOURCE_THROTTLED 0x00000002
#define CLUSRESDLL_STATUS_OFFLINE_DESTINATION_THROTTLED 0x00000004
#define CLUSRESDLL_STATUS_OFFLINE_DESTINATION_REJECTED 0x00000008
#define CLUSRESDLL_STATUS_INSUFFICIENT_MEMORY 0x00000010
#define CLUSRESDLL_STATUS_INSUFFICIENT_PROCESSOR 0x00000020
#define CLUSRESDLL_STATUS_INSUFFICIENT_OTHER_RESOURCES 0x00000040
#define CLUSRESDLL_STATUS_INVALID_PARAMETERS 0x00000080

#define ResUtilInitializeResourceStatusEx(_resource_status_) ZeroMemory (_resource_status_, sizeof (RESOURCE_STATUS_EX))

#define CLUS_RESDLL_OPEN_RECOVER_MONITOR_STATE 0x00000001
#define CLUS_RESDLL_ONLINE_RECOVER_MONITOR_STATE 0x00000001
#define CLUS_RESDLL_ONLINE_IGNORE_RESOURCE_STATUS 0x00000002
#define CLUS_RESDLL_ONLINE_RETURN_TO_SOURCE_NODE_ON_ERROR 0x00000004
#define CLUS_RESDLL_ONLINE_RESTORE_ONLINE_STATE 0x00000008

#define CLUS_RESDLL_OFFLINE_IGNORE_RESOURCE_STATUS 0x00000001
#define CLUS_RESDLL_OFFLINE_RETURN_TO_SOURCE_NODE_ON_ERROR 0x00000002
#define CLUS_RESDLL_OFFLINE_QUEUE_ENABLED 0x00000004
#define CLUS_RESDLL_OFFLINE_RETURNING_TO_SOURCE_NODE_BECAUSE_OF_ERROR 0x00000008
#define CLUS_RESDLL_OFFLINE_DUE_TO_EMBEDDED_FAILURE 0x00000010
#endif

#define RESUTIL_PROPITEM_READ_ONLY 0x00000001
#define RESUTIL_PROPITEM_REQUIRED 0x00000002
#define RESUTIL_PROPITEM_SIGNED 0x00000004
#define RESUTIL_PROPITEM_IN_MEMORY 0x00000008

  typedef enum LOG_LEVEL {
    LOG_INFORMATION,
    LOG_WARNING,
    LOG_ERROR,
    LOG_SEVERE
  } LOG_LEVEL,*PLOG_LEVEL;

  typedef enum _RESOURCE_EXIT_STATE {
    ResourceExitStateContinue,
    ResourceExitStateTerminate,
    ResourceExitStateMax
  } RESOURCE_EXIT_STATE;

  typedef enum _CLUSTER_ROLE {
    ClusterRoleDHCP,
    ClusterRoleDTC,
    ClusterRoleFileServer,
    ClusterRoleGenericApplication,
    ClusterRoleGenericScript,
    ClusterRoleGenericService,
    ClusterRoleISCSINameServer,
    ClusterRoleMSMQ,
    ClusterRoleNFS,
    ClusterRolePrintServer,
    ClusterRoleStandAloneNamespaceServer,
    ClusterRoleVolumeShadowCopyServiceTask,
    ClusterRoleWINS,
    ClusterRoleTaskScheduler,
    ClusterRoleNetworkFileSystem,
    ClusterRoleDFSReplicatedFolder,
    ClusterRoleDistributedFileSystem,
    ClusterRoleDistributedNetworkName,
    ClusterRoleFileShare,
    ClusterRoleFileShareWitness,
    ClusterRoleHardDisk,
    ClusterRoleIPAddress,
    ClusterRoleIPV6Address,
    ClusterRoleIPV6TunnelAddress,
    ClusterRoleISCSITargetServer,
    ClusterRoleNetworkName,
    ClusterRolePhysicalDisk,
    ClusterRoleSODAFileServer,
    ClusterRoleStoragePool,
    ClusterRoleVirtualMachine,
    ClusterRoleVirtualMachineConfiguration,
    ClusterRoleVirtualMachineReplicaBroker
  } CLUSTER_ROLE;

  typedef enum _CLUSTER_ROLE_STATE {
    ClusterRoleUnknown = -1,
    ClusterRoleClustered,
    ClusterRoleUnclustered
  } CLUSTER_ROLE_STATE;

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  typedef enum VM_RESDLL_CONTEXT {
    VmResdllContextTurnOff = 0,
    VmResdllContextSave = 1,
    VmResdllContextShutdown = 2,
    VmResdllContextShutdownForce = 3,
    VmResdllContextLiveMigration = 4
  } VM_RESDLL_CONTEXT,*PVM_RESDLL_CONTEXT;

  typedef enum RESDLL_CONTEXT_OPERATION_TYPE {
    ResdllContextOperationTypeFailback,
    ResdllContextOperationTypeDrain,
    ResdllContextOperationTypeDrainFailure,
    ResdllContextOperationTypeEmbeddedFailure,
    ResdllContextOperationTypePreemption
  } RESDLL_CONTEXT_OPERATION_TYPE,*PRESDLL_CONTEXT_OPERATION_TYPE;
#endif

  typedef PVOID RESID;
  typedef HANDLE RESOURCE_HANDLE;

  typedef struct RESOURCE_STATUS {
    CLUSTER_RESOURCE_STATE ResourceState;
    DWORD CheckPoint;
    DWORD WaitHint;
    HANDLE EventHandle;
  } RESOURCE_STATUS,*PRESOURCE_STATUS;

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  struct NodeUtilizationInfoElement {
    ULONGLONG Id;
    ULONGLONG AvailableMemory;
    ULONGLONG AvailableMemoryAfterReclamation;
  };

  struct ResourceUtilizationInfoElement {
    ULONGLONG PhysicalNumaId;
    ULONGLONG CurrentMemory;
  };

  typedef struct GET_OPERATION_CONTEXT_PARAMS {
    DWORD Size;
    DWORD Version;
    RESDLL_CONTEXT_OPERATION_TYPE Type;
    DWORD Priority;
  } GET_OPERATION_CONTEXT_PARAMS,*PGET_OPERATION_CONTEXT_PARAMS;

  typedef struct RESOURCE_STATUS_EX {
    CLUSTER_RESOURCE_STATE ResourceState;
    DWORD CheckPoint;
    HANDLE EventHandle;
    DWORD ApplicationSpecificErrorCode;
    DWORD Flags;
  } RESOURCE_STATUS_EX,*PRESOURCE_STATUS_EX;

  typedef DWORD (_stdcall *PSET_RESOURCE_STATUS_ROUTINE_EX) (RESOURCE_HANDLE ResourceHandle, PRESOURCE_STATUS_EX ResourceStatus);
#endif

  typedef DWORD (_stdcall *PSET_RESOURCE_STATUS_ROUTINE) (RESOURCE_HANDLE ResourceHandle, PRESOURCE_STATUS ResourceStatus);
  typedef VOID (_stdcall *PQUORUM_RESOURCE_LOST) (RESOURCE_HANDLE Resource);
  typedef VOID (_stdcall *PLOG_EVENT_ROUTINE) (RESOURCE_HANDLE ResourceHandle, LOG_LEVEL LogLevel, LPCWSTR FormatString,...);
  typedef RESID (_stdcall *POPEN_ROUTINE) (LPCWSTR ResourceName, HKEY ResourceKey, RESOURCE_HANDLE ResourceHandle);
  typedef VOID (_stdcall *PCLOSE_ROUTINE) (RESID Resource);
  typedef DWORD (_stdcall *PONLINE_ROUTINE) (RESID Resource, LPHANDLE EventHandle);
  typedef DWORD (_stdcall *POFFLINE_ROUTINE) (RESID Resource);
  typedef VOID (_stdcall *PTERMINATE_ROUTINE) (RESID Resource);
  typedef WINBOOL (_stdcall *PIS_ALIVE_ROUTINE) (RESID Resource);
  typedef WINBOOL (_stdcall *PLOOKS_ALIVE_ROUTINE) (RESID Resource);
  typedef DWORD (_stdcall *PARBITRATE_ROUTINE) (RESID Resource, PQUORUM_RESOURCE_LOST LostQuorumResource);
  typedef DWORD (_stdcall *PRELEASE_ROUTINE) (RESID Resource);
  typedef DWORD (_stdcall *PRESOURCE_CONTROL_ROUTINE) (RESID Resource, DWORD ControlCode, PVOID InBuffer, DWORD InBufferSize, PVOID OutBuffer, DWORD OutBufferSize, LPDWORD BytesReturned);
  typedef DWORD (_stdcall *PRESOURCE_TYPE_CONTROL_ROUTINE) (LPCWSTR ResourceTypeName, DWORD ControlCode, PVOID InBuffer, DWORD InBufferSize, PVOID OutBuffer, DWORD OutBufferSize, LPDWORD BytesReturned);

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  typedef RESID (_stdcall *POPEN_V2_ROUTINE) (LPCWSTR ResourceName, HKEY ResourceKey, RESOURCE_HANDLE ResourceHandle, DWORD OpenFlags);
  typedef DWORD (_stdcall *PONLINE_V2_ROUTINE) (RESID Resource, LPHANDLE EventHandle, DWORD OnlineFlags, PBYTE InBuffer, DWORD InBufferSize, DWORD Reserved);
  typedef DWORD (_stdcall *POFFLINE_V2_ROUTINE) (RESID Resource, LPCWSTR DestinationNodeName, DWORD OfflineFlags, PBYTE InBuffer, DWORD InBufferSize, DWORD Reserved);
  typedef DWORD (_stdcall *PCANCEL_ROUTINE) (RESID Resource, DWORD CancelFlags_RESERVED);
#endif

  typedef struct CLRES_V1_FUNCTIONS {
    POPEN_ROUTINE Open;
    PCLOSE_ROUTINE Close;
    PONLINE_ROUTINE Online;
    POFFLINE_ROUTINE Offline;
    PTERMINATE_ROUTINE Terminate;
    PLOOKS_ALIVE_ROUTINE LooksAlive;
    PIS_ALIVE_ROUTINE IsAlive;
    PARBITRATE_ROUTINE Arbitrate;
    PRELEASE_ROUTINE Release;
    PRESOURCE_CONTROL_ROUTINE ResourceControl;
    PRESOURCE_TYPE_CONTROL_ROUTINE ResourceTypeControl;
  } CLRES_V1_FUNCTIONS,*PCLRES_V1_FUNCTIONS;

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  typedef struct CLRES_V2_FUNCTIONS {
    POPEN_V2_ROUTINE Open;
    PCLOSE_ROUTINE Close;
    PONLINE_V2_ROUTINE Online;
    POFFLINE_V2_ROUTINE Offline;
    PTERMINATE_ROUTINE Terminate;
    PLOOKS_ALIVE_ROUTINE LooksAlive;
    PIS_ALIVE_ROUTINE IsAlive;
    PARBITRATE_ROUTINE Arbitrate;
    PRELEASE_ROUTINE Release;
    PRESOURCE_CONTROL_ROUTINE ResourceControl;
    PRESOURCE_TYPE_CONTROL_ROUTINE ResourceTypeControl;
    PCANCEL_ROUTINE Cancel;
  } CLRES_V2_FUNCTIONS,*PCLRES_V2_FUNCTIONS;
#endif

  typedef struct CLRES_FUNCTION_TABLE {
    DWORD TableSize;
    DWORD Version;
    __C89_NAMELESS union {
      CLRES_V1_FUNCTIONS V1Functions;
#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
      CLRES_V2_FUNCTIONS V2Functions;
#endif
    } DUMMYUNIONNAME;
  } CLRES_FUNCTION_TABLE,*PCLRES_FUNCTION_TABLE;

  typedef struct RESUTIL_LARGEINT_DATA {
    LARGE_INTEGER Default;
    LARGE_INTEGER Minimum;
    LARGE_INTEGER Maximum;
  } RESUTIL_LARGEINT_DATA,*PRESUTIL_LARGEINT_DATA;

  typedef struct RESUTIL_ULARGEINT_DATA {
    ULARGE_INTEGER Default;
    ULARGE_INTEGER Minimum;
    ULARGE_INTEGER Maximum;
  } RESUTIL_ULARGEINT_DATA,*PRESUTIL_ULARGEINT_DATA;

  typedef struct RESUTIL_FILETIME_DATA {
    FILETIME Default;
    FILETIME Minimum;
    FILETIME Maximum;
  } RESUTIL_FILETIME_DATA,*PRESUTIL_FILETIME_DATA;

  typedef struct RESUTIL_PROPERTY_ITEM {
    LPWSTR Name;
    LPWSTR KeyName;
    DWORD Format;
    __C89_NAMELESS union {
      DWORD_PTR DefaultPtr;
      DWORD Default;
      LPVOID lpDefault;
      PRESUTIL_LARGEINT_DATA LargeIntData;
      PRESUTIL_ULARGEINT_DATA ULargeIntData;
      PRESUTIL_FILETIME_DATA FileTimeData;
    } DUMMYUNIONNAME;
    DWORD Minimum;
    DWORD Maximum;
    DWORD Flags;
    DWORD Offset;
  } RESUTIL_PROPERTY_ITEM,*PRESUTIL_PROPERTY_ITEM;

  typedef struct CLUS_WORKER {
    HANDLE hThread;
    WINBOOL Terminate;
  } CLUS_WORKER,*PCLUS_WORKER;

  typedef DWORD (_stdcall *PSTARTUP_ROUTINE) (LPCWSTR ResourceType, DWORD MinVersionSupported, DWORD MaxVersionSupported, PSET_RESOURCE_STATUS_ROUTINE SetResourceStatus, PLOG_EVENT_ROUTINE LogEvent, PCLRES_FUNCTION_TABLE *FunctionTable);

#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  typedef DWORD (_stdcall *PSET_RESOURCE_LOCKED_MODE_ROUTINE) (RESOURCE_HANDLE ResourceHandle, WINBOOL LockedModeEnabled, DWORD LockedModeReason);
  typedef DWORD (_stdcall *PSIGNAL_FAILURE_ROUTINE) (RESOURCE_HANDLE ResourceHandle, WINBOOL IsEmbeddedFailure, DWORD ApplicationSpecificErrorCode);
  typedef DWORD (_stdcall *PSET_RESOURCE_INMEMORY_NODELOCAL_PROPERTIES_ROUTINE) (RESOURCE_HANDLE ResourceHandle, unsigned char *propertyListBuffer, DWORD propertyListBufferSize);

  typedef struct CLRES_CALLBACK_FUNCTION_TABLE {
    PLOG_EVENT_ROUTINE LogEvent;
    PSET_RESOURCE_STATUS_ROUTINE_EX SetResourceStatusEx;
    PSET_RESOURCE_LOCKED_MODE_ROUTINE SetResourceLockedMode;
    PSIGNAL_FAILURE_ROUTINE SignalFailure;
    PSET_RESOURCE_INMEMORY_NODELOCAL_PROPERTIES_ROUTINE SetResourceInMemoryNodeLocalProperties;
  } CLRES_CALLBACK_FUNCTION_TABLE,*PCLRES_CALLBACK_FUNCTION_TABLE;

  typedef DWORD (_stdcall *PSTARTUP_EX_ROUTINE) (LPCWSTR ResourceType, DWORD MinVersionSupported, DWORD MaxVersionSupported, PCLRES_CALLBACK_FUNCTION_TABLE MonitorCallbackFunctions, PCLRES_FUNCTION_TABLE *ResourceDllInterfaceFunctions);
#endif

  typedef enum RESOURCE_MONITOR_STATE {
    RmonInitializing,
    RmonIdle,
    RmonStartingResource,
    RmonInitializingResource,
    RmonOnlineResource,
    RmonOfflineResource,
    RmonShutdownResource,
    RmonDeletingResource,
    RmonIsAlivePoll,
    RmonLooksAlivePoll,
    RmonArbitrateResource,
    RmonReleaseResource,
    RmonResourceControl,
    RmonResourceTypeControl,
    RmonTerminateResource,
    RmonDeadlocked
  } RESOURCE_MONITOR_STATE;

  typedef struct MONITOR_STATE {
    LARGE_INTEGER LastUpdate;
    RESOURCE_MONITOR_STATE State;
    HANDLE ActiveResource;
    WINBOOL ResmonStop;
  } MONITOR_STATE,*PMONITOR_STATE;

  typedef DWORD (WINAPI *PRESUTIL_START_RESOURCE_SERVICE) (LPCWSTR pszServiceName, LPSC_HANDLE phServiceHandle);
  typedef DWORD (WINAPI *PRESUTIL_VERIFY_RESOURCE_SERVICE) (LPCWSTR pszServiceName);
  typedef DWORD (WINAPI *PRESUTIL_STOP_RESOURCE_SERVICE) (LPCWSTR pszServiceName);
  typedef DWORD (WINAPI *PRESUTIL_VERIFY_SERVICE) (SC_HANDLE hServiceHandle);
  typedef DWORD (WINAPI *PRESUTIL_STOP_SERVICE) (SC_HANDLE hServiceHandle);
  typedef DWORD (WINAPI *PRESUTIL_CREATE_DIRECTORY_TREE) (LPCWSTR pszPath);
  typedef WINBOOL (WINAPI *PRESUTIL_IS_PATH_VALID) (LPCWSTR pszPath);
  typedef DWORD (WINAPI *PRESUTIL_ENUM_PROPERTIES) (const PRESUTIL_PROPERTY_ITEM pPropertyTable, LPWSTR pszOutProperties, DWORD cbOutPropertiesSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_ENUM_PRIVATE_PROPERTIES) (HKEY hkeyClusterKey, LPWSTR pszOutProperties, DWORD cbOutPropertiesSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_GET_PROPERTIES) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, DWORD cbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_GET_ALL_PROPERTIES) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, DWORD cbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_GET_PRIVATE_PROPERTIES) (HKEY hkeyClusterKey, PVOID pOutPropertyList, DWORD cbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_GET_PROPERTY_SIZE) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTableItem, LPDWORD pcbOutPropertyListSize, LPDWORD pnPropertyCount);
  typedef DWORD (WINAPI *PRESUTIL_GET_PROPERTY) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTableItem, PVOID *pOutPropertyItem, LPDWORD pcbOutPropertyItemSize);
  typedef DWORD (WINAPI *PRESUTIL_VERIFY_PROPERTY_TABLE) (const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, WINBOOL bAllowUnknownProperties, const PVOID pInPropertyList, DWORD cbInPropertyListSize, LPBYTE pOutParams);
  typedef DWORD (WINAPI *PRESUTIL_SET_PROPERTY_TABLE) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, WINBOOL bAllowUnknownProperties, const PVOID pInPropertyList, DWORD cbInPropertyListSize, LPBYTE pOutParams);
  typedef DWORD (WINAPI *PRESUTIL_SET_PROPERTY_TABLE_EX) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, WINBOOL bAllowUnknownProperties, const PVOID pInPropertyList, DWORD cbInPropertyListSize, WINBOOL bForceWrite, LPBYTE pOutParams);
  typedef DWORD (WINAPI *PRESUTIL_SET_PROPERTY_PARAMETER_BLOCK) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, const LPBYTE pInParams, const PVOID pInPropertyList, DWORD cbInPropertyListSize, LPBYTE pOutParams);
  typedef DWORD (WINAPI *PRESUTIL_SET_PROPERTY_PARAMETER_BLOCK_EX) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, const LPBYTE pInParams, const PVOID pInPropertyList, DWORD cbInPropertyListSize, WINBOOL bForceWrite, LPBYTE pOutParams);
  typedef DWORD (WINAPI *PRESUTIL_SET_UNKNOWN_PROPERTIES) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, const PVOID pInPropertyList, DWORD cbInPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_GET_PROPERTIES_TO_PARAMETER_BLOCK) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, LPBYTE pOutParams, WINBOOL bCheckForRequiredProperties, LPWSTR *pszNameOfPropInError);
  typedef DWORD (WINAPI *PRESUTIL_GET_PROPERTIES_TO_PARAMETER_BLOCK) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, LPBYTE pOutParams, WINBOOL bCheckForRequiredProperties, LPWSTR *pszNameOfPropInError);
  typedef DWORD (WINAPI *PRESUTIL_PROPERTY_LIST_FROM_PARAMETER_BLOCK) (const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, LPDWORD pcbOutPropertyListSize, const LPBYTE pInParams, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_DUP_PARAMETER_BLOCK) (LPBYTE pOutParams, const LPBYTE pInParams, const PRESUTIL_PROPERTY_ITEM pPropertyTable);
  typedef void (WINAPI *PRESUTIL_FREE_PARAMETER_BLOCK) (LPBYTE pOutParams, const LPBYTE pInParams, const PRESUTIL_PROPERTY_ITEM pPropertyTable);
  typedef DWORD (WINAPI *PRESUTIL_ADD_UNKNOWN_PROPERTIES) (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, DWORD pcbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_SET_PRIVATE_PROPERTY_LIST) (HKEY hkeyClusterKey, const PVOID pInPropertyList, DWORD cbInPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_VERIFY_PRIVATE_PROPERTY_LIST) (const PVOID pInPropertyList, DWORD cbInPropertyListSize);
  typedef PWSTR (WINAPI *PRESUTIL_DUP_STRING) (LPCWSTR pszInString);
  typedef DWORD (WINAPI *PRESUTIL_GET_BINARY_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPBYTE *ppbOutValue, LPDWORD pcbOutValueSize);
  typedef LPWSTR (WINAPI *PRESUTIL_GET_SZ_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName);
  typedef LPWSTR (WINAPI *PRESUTIL_GET_EXPAND_SZ_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, WINBOOL bExpand);
  typedef DWORD (WINAPI *PRESUTIL_GET_DWORD_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPDWORD pdwOutValue, DWORD dwDefaultValue);
  typedef DWORD (WINAPI *PRESUTIL_GET_QWORD_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, PULONGLONG pqwOutValue, ULONGLONG qwDefaultValue);
  typedef DWORD (WINAPI *PRESUTIL_SET_BINARY_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, const LPBYTE pbNewValue, DWORD cbNewValueSize, LPBYTE *ppbOutValue, LPDWORD pcbOutValueSize);
  typedef DWORD (WINAPI *PRESUTIL_SET_SZ_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPCWSTR pszNewValue, LPWSTR *ppszOutString);
  typedef DWORD (WINAPI *PRESUTIL_SET_EXPAND_SZ_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPCWSTR pszNewValue, LPWSTR *ppszOutString);
  typedef DWORD (WINAPI *PRESUTIL_SET_MULTI_SZ_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPCWSTR pszNewValue, DWORD cbNewValueSize, LPWSTR *ppszOutValue, LPDWORD pcbOutValueSize);
  typedef DWORD (WINAPI *PRESUTIL_SET_DWORD_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, DWORD dwNewValue, LPDWORD pdwOutValue);
  typedef DWORD (WINAPI *PRESUTIL_SET_QWORD_VALUE) (HKEY hkeyClusterKey, LPCWSTR pszValueName, ULONGLONG qwNewValue, PULONGLONG pqwOutValue);
  typedef DWORD (WINAPI *PRESUTIL_GET_BINARY_PROPERTY) (LPBYTE *ppbOutValue, LPDWORD pcbOutValueSize, const PCLUSPROP_BINARY pValueStruct, const LPBYTE pbOldValue, DWORD cbOldValueSize, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_GET_SZ_PROPERTY) (LPWSTR *ppszOutValue, const PCLUSPROP_SZ pValueStruct, LPCWSTR pszOldValue, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_GET_MULTI_SZ_PROPERTY) (LPWSTR *ppszOutValue, LPDWORD pcbOutValueSize, const PCLUSPROP_SZ pValueStruct, LPCWSTR pszOldValue, DWORD cbOldValueSize, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_GET_DWORD_PROPERTY) (LPDWORD pdwOutValue, const PCLUSPROP_DWORD pValueStruct, DWORD dwOldValue, DWORD dwMinimum, DWORD dwMaximum, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_GET_LONG_PROPERTY) (LPLONG plOutValue, const PCLUSPROP_LONG pValueStruct, LONG lOldValue, LONG lMinimum, LONG lMaximum, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  typedef DWORD (WINAPI *PRESUTIL_GET_FILETIME_PROPERTY) (LPFILETIME pftOutValue, const PCLUSPROP_FILETIME pValueStruct, FILETIME ftOldValue, FILETIME ftMinimum, FILETIME ftMaximum, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  typedef LPVOID (WINAPI *PRESUTIL_GET_ENVIRONMENT_WITH_NET_NAME) (HRESOURCE hResource);
  typedef DWORD (WINAPI *PRESUTIL_FREE_ENVIRONMENT) (LPVOID lpEnvironment);
  typedef LPWSTR (WINAPI *PRESUTIL_EXPAND_ENVIRONMENT_STRINGS) (LPCWSTR pszSrc);
  typedef DWORD (WINAPI *PRESUTIL_SET_RESOURCE_SERVICE_ENVIRONMENT) (LPCWSTR pszServiceName, HRESOURCE hResource, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  typedef DWORD (WINAPI *PRESUTIL_REMOVE_RESOURCE_SERVICE_ENVIRONMENT) (LPCWSTR pszServiceName, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  typedef DWORD (WINAPI *PRESUTIL_SET_RESOURCE_SERVICE_START_PARAMETERS) (LPCWSTR pszServiceName, SC_HANDLE schSCMHandle, LPSC_HANDLE phService, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  typedef DWORD (WINAPI *PRESUTIL_FIND_SZ_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue);
  typedef DWORD (WINAPI *PRESUTIL_FIND_EXPAND_SZ_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue);
  typedef DWORD (WINAPI *PRESUTIL_FIND_EXPANDED_SZ_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue);
  typedef DWORD (WINAPI *PRESUTIL_FIND_DWORD_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPDWORD pdwPropertyValue);
  typedef DWORD (WINAPI *PRESUTIL_FIND_BINARY_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPBYTE *pbPropertyValue, LPDWORD pcbPropertyValueSize);
  typedef DWORD (WINAPI *PRESUTIL_FIND_MULTI_SZ_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue, LPDWORD pcbPropertyValueSize);
  typedef DWORD (WINAPI *PRESUTIL_FIND_LONG_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPLONG plPropertyValue);
  typedef DWORD (WINAPI *PRESUTIL_FIND_FILETIME_PROPERTY) (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPFILETIME pftPropertyValue);
  typedef DWORD (WINAPI *PWORKER_START_ROUTINE) (PCLUS_WORKER pWorker, LPVOID lpThreadParameter);
  typedef DWORD (WINAPI *PCLUSAPI_CLUS_WORKER_CREATE) (PCLUS_WORKER lpWorker, PWORKER_START_ROUTINE lpStartAddress, PVOID lpParameter);
  typedef WINBOOL (WINAPI *PCLUSAPIClusWorkerCheckTerminate) (PCLUS_WORKER lpWorker);
  typedef VOID (WINAPI *PCLUSAPI_CLUS_WORKER_TERMINATE) (PCLUS_WORKER lpWorker);
  typedef DWORD (*LPRESOURCE_CALLBACK) (HRESOURCE, HRESOURCE, PVOID);
  typedef DWORD (*LPRESOURCE_CALLBACK_EX) (HCLUSTER, HRESOURCE, HRESOURCE, PVOID);
  typedef WINBOOL (WINAPI *PRESUTIL_RESOURCES_EQUAL) (HRESOURCE hSelf, HRESOURCE hResource);
  typedef WINBOOL (WINAPI *PRESUTIL_RESOURCE_TYPES_EQUAL) (LPCWSTR lpszResourceTypeName, HRESOURCE hResource);
  typedef WINBOOL (WINAPI *PRESUTIL_IS_RESOURCE_CLASS_EQUAL) (PCLUS_RESOURCE_CLASS_INFO prci, HRESOURCE hResource);
  typedef DWORD (WINAPI *PRESUTIL_ENUM_RESOURCES) (HRESOURCE hSelf, LPCWSTR lpszResTypeName, LPRESOURCE_CALLBACK pResCallBack, PVOID pParameter);
  typedef DWORD (WINAPI *PRESUTIL_ENUM_RESOURCES_EX) (HCLUSTER hCluster, HRESOURCE hSelf, LPCWSTR lpszResTypeName, LPRESOURCE_CALLBACK_EX pResCallBack, PVOID pParameter);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENCY) (HANDLE hSelf, LPCWSTR lpszResourceType);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENCY_BY_NAME) (HCLUSTER hCluster, HANDLE hSelf, LPCWSTR lpszResourceType, WINBOOL bRecurse);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENCY_BY_CLASS) (HCLUSTER hCluster, HANDLE hSelf, PCLUS_RESOURCE_CLASS_INFO prci, WINBOOL bRecurse);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_NAME_DEPENDENCY) (LPCWSTR lpszResourceName, LPCWSTR lpszResourceType);
  typedef DWORD (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENTIP_ADDRESS_PROPS) (HRESOURCE hResource, LPWSTR pszAddress, DWORD *pcchAddress, LPWSTR pszSubnetMask, DWORD *pcchSubnetMask, LPWSTR pszNetwork, DWORD *pcchNetwork);
  typedef DWORD (WINAPI *PRESUTIL_FIND_DEPENDENT_DISK_RESOURCE_DRIVE_LETTER) (HCLUSTER hCluster, HRESOURCE hResource, LPWSTR pszDriveLetter, DWORD *pcchDriveLetter);
  typedef DWORD (WINAPI *PRESUTIL_TERMINATE_SERVICE_PROCESS_FROM_RES_DLL) (DWORD dwServicePid, WINBOOL bOffline, PDWORD pdwResourceState, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  typedef DWORD (WINAPI *PRESUTIL_GET_PROPERTY_FORMATS) (const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyFormatList, DWORD cbPropertyFormatListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  typedef DWORD (WINAPI *PRESUTIL_GET_CORE_CLUSTER_RESOURCES) (HCLUSTER hCluster, HRESOURCE *phClusterNameResource, HRESOURCE *phClusterIPAddressResource, HRESOURCE *phClusterQuorumResource);
  typedef DWORD (WINAPI *PRESUTIL_GET_RESOURCE_NAME) (HRESOURCE hResource, PWSTR pszResourceName, DWORD *pcchResourceNameInOut);
  typedef WINBOOL (WINAPI *PCLUSTER_IS_PATH_ON_SHARED_VOLUME) (LPCWSTR lpszPathName);
  typedef WINBOOL (WINAPI *PCLUSTER_GET_VOLUME_PATH_NAME) (LPCWSTR lpszFileName, LPWSTR lpszVolumePathName, DWORD cchBufferLength);
  typedef WINBOOL (WINAPI *PCLUSTER_GET_VOLUME_NAME_FOR_VOLUME_MOUNT_POINT) (LPCWSTR lpszVolumeMountPoint, LPWSTR lpszVolumeName, DWORD cchBufferLength);
  typedef DWORD (WINAPI *PCLUSTER_PREPARE_SHARED_VOLUME_FOR_BACKUP) (LPCWSTR lpszFileName, LPWSTR lpszVolumePathName, LPDWORD lpcchVolumePathName, LPWSTR lpszVolumeName, LPDWORD lpcchVolumeName);
  typedef DWORD (WINAPI *PCLUSTER_CLEAR_BACKUP_STATE_FOR_SHARED_VOLUME) (LPCWSTR lpszVolumePathName);
#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  typedef DWORD (WINAPI *PRESUTIL_SET_RESOURCE_SERVICE_START_PARAMETERS_EX) (LPCWSTR pszServiceName, SC_HANDLE schSCMHandle, LPSC_HANDLE phService, DWORD dwDesiredAccess, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  typedef DWORD (WINAPI *PRESUTIL_ENUM_RESOURCES_EX2) (HCLUSTER hCluster, HRESOURCE hSelf, LPCWSTR lpszResTypeName, LPRESOURCE_CALLBACK_EX pResCallBack, PVOID pParameter, DWORD dwDesiredAccess);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENCY_EX) (HANDLE hSelf, LPCWSTR lpszResourceType, DWORD dwDesiredAccess);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENCY_BY_NAME_EX) (HCLUSTER hCluster, HANDLE hSelf, LPCWSTR lpszResourceType, WINBOOL bRecurse, DWORD dwDesiredAccess);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_DEPENDENCY_BY_CLASS_EX) (HCLUSTER hCluster, HANDLE hSelf, PCLUS_RESOURCE_CLASS_INFO prci, WINBOOL bRecurse, DWORD dwDesiredAccess);
  typedef HRESOURCE (WINAPI *PRESUTIL_GET_RESOURCE_NAME_DEPENDENCY_EX) (LPCWSTR lpszResourceName, LPCWSTR lpszResourceType, DWORD dwDesiredAccess);
  typedef DWORD (WINAPI *PRESUTIL_GET_CORE_CLUSTER_RESOURCES_EX) (HCLUSTER hClusterIn, HRESOURCE *phClusterNameResourceOut, HRESOURCE *phClusterIPAddressResourceOut, HRESOURCE *phClusterQuorumResourceOut, DWORD dwDesiredAccess);
#endif

  DWORD WINAPI ResUtilStartResourceService (LPCWSTR pszServiceName, LPSC_HANDLE phServiceHandle);
  DWORD WINAPI ResUtilVerifyResourceService (LPCWSTR pszServiceName);
  DWORD WINAPI ResUtilStopResourceService (LPCWSTR pszServiceName);
  DWORD WINAPI ResUtilVerifyService (SC_HANDLE hServiceHandle);
  DWORD WINAPI ResUtilStopService (SC_HANDLE hServiceHandle);
  DWORD WINAPI ResUtilCreateDirectoryTree (LPCWSTR pszPath);
  WINBOOL WINAPI ResUtilIsPathValid (LPCWSTR pszPath);
  DWORD WINAPI ResUtilEnumProperties (const PRESUTIL_PROPERTY_ITEM pPropertyTable, LPWSTR pszOutProperties, DWORD cbOutPropertiesSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilEnumPrivateProperties (HKEY hkeyClusterKey, LPWSTR pszOutProperties, DWORD cbOutPropertiesSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilGetProperties (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, DWORD cbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilGetAllProperties (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, DWORD cbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilGetPrivateProperties (HKEY hkeyClusterKey, PVOID pOutPropertyList, DWORD cbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilGetPropertySize (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTableItem, LPDWORD pcbOutPropertyListSize, LPDWORD pnPropertyCount);
  DWORD WINAPI ResUtilGetProperty (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTableItem, PVOID *pOutPropertyItem, LPDWORD pcbOutPropertyItemSize);
  DWORD WINAPI ResUtilVerifyPropertyTable (const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, WINBOOL bAllowUnknownProperties, const PVOID pInPropertyList, DWORD cbInPropertyListSize, LPBYTE pOutParams);
  DWORD WINAPI ResUtilSetPropertyTable (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, WINBOOL bAllowUnknownProperties, const PVOID pInPropertyList, DWORD cbInPropertyListSize, LPBYTE pOutParams);
  DWORD WINAPI ResUtilSetPropertyTableEx (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, WINBOOL bAllowUnknownProperties, const PVOID pInPropertyList, DWORD cbInPropertyListSize, WINBOOL bForceWrite, LPBYTE pOutParams);
  DWORD WINAPI ResUtilSetPropertyParameterBlock (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, const LPBYTE pInParams, const PVOID pInPropertyList, DWORD cbInPropertyListSize, LPBYTE pOutParams);
  DWORD WINAPI ResUtilSetPropertyParameterBlockEx (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID Reserved, const LPBYTE pInParams, const PVOID pInPropertyList, DWORD cbInPropertyListSize, WINBOOL bForceWrite, LPBYTE pOutParams);
  DWORD WINAPI ResUtilSetUnknownProperties (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, const PVOID pInPropertyList, DWORD cbInPropertyListSize);
  DWORD WINAPI ResUtilGetPropertiesToParameterBlock (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, LPBYTE pOutParams, WINBOOL bCheckForRequiredProperties, LPWSTR *pszNameOfPropInError);
  DWORD WINAPI ResUtilPropertyListFromParameterBlock (const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, LPDWORD pcbOutPropertyListSize, const LPBYTE pInParams, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilDupParameterBlock (LPBYTE pOutParams, const LPBYTE pInParams, const PRESUTIL_PROPERTY_ITEM pPropertyTable);
  void WINAPI ResUtilFreeParameterBlock (LPBYTE pOutParams, const LPBYTE pInParams, const PRESUTIL_PROPERTY_ITEM pPropertyTable);
  DWORD WINAPI ResUtilAddUnknownProperties (HKEY hkeyClusterKey, const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyList, DWORD pcbOutPropertyListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilSetPrivatePropertyList (HKEY hkeyClusterKey, const PVOID pInPropertyList, DWORD cbInPropertyListSize);
  DWORD WINAPI ResUtilVerifyPrivatePropertyList (const PVOID pInPropertyList, DWORD cbInPropertyListSize);
  PWSTR WINAPI ResUtilDupString (LPCWSTR pszInString);
  DWORD WINAPI ResUtilGetBinaryValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPBYTE *ppbOutValue, LPDWORD pcbOutValueSize);
  LPWSTR WINAPI ResUtilGetSzValue (HKEY hkeyClusterKey, LPCWSTR pszValueName);
  LPWSTR WINAPI ResUtilGetExpandSzValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, WINBOOL bExpand);
  DWORD WINAPI ResUtilGetDwordValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPDWORD pdwOutValue, DWORD dwDefaultValue);
  DWORD WINAPI ResUtilGetQwordValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, PULONGLONG pqwOutValue, ULONGLONG qwDefaultValue);
  DWORD WINAPI ResUtilSetBinaryValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, const LPBYTE pbNewValue, DWORD cbNewValueSize, LPBYTE *ppbOutValue, LPDWORD pcbOutValueSize);
  DWORD WINAPI ResUtilSetSzValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPCWSTR pszNewValue, LPWSTR *ppszOutString);
  DWORD WINAPI ResUtilSetExpandSzValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPCWSTR pszNewValue, LPWSTR *ppszOutString);
  DWORD WINAPI ResUtilSetMultiSzValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPCWSTR pszNewValue, DWORD cbNewValueSize, LPWSTR *ppszOutValue, LPDWORD pcbOutValueSize);
  DWORD WINAPI ResUtilSetDwordValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, DWORD dwNewValue, LPDWORD pdwOutValue);
  DWORD WINAPI ResUtilSetQwordValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, ULONGLONG qwNewValue, PULONGLONG pqwOutValue);
  DWORD WINAPI ResUtilGetBinaryProperty (LPBYTE *ppbOutValue, LPDWORD pcbOutValueSize, const PCLUSPROP_BINARY pValueStruct, const LPBYTE pbOldValue, DWORD cbOldValueSize, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  DWORD WINAPI ResUtilGetSzProperty (LPWSTR *ppszOutValue, const PCLUSPROP_SZ pValueStruct, LPCWSTR pszOldValue, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  DWORD WINAPI ResUtilGetMultiSzProperty (LPWSTR *ppszOutValue, LPDWORD pcbOutValueSize, const PCLUSPROP_SZ pValueStruct, LPCWSTR pszOldValue, DWORD cbOldValueSize, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  DWORD WINAPI ResUtilGetDwordProperty (LPDWORD pdwOutValue, const PCLUSPROP_DWORD pValueStruct, DWORD dwOldValue, DWORD dwMinimum, DWORD dwMaximum, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  DWORD WINAPI ResUtilGetLongProperty (LPLONG plOutValue, const PCLUSPROP_LONG pValueStruct, LONG lOldValue, LONG lMinimum, LONG lMaximum, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  DWORD WINAPI ResUtilGetFileTimeProperty (LPFILETIME pftOutValue, const PCLUSPROP_FILETIME pValueStruct, FILETIME ftOldValue, FILETIME ftMinimum, FILETIME ftMaximum, LPBYTE *ppPropertyList, LPDWORD pcbPropertyListSize);
  LPVOID WINAPI ResUtilGetEnvironmentWithNetName (HRESOURCE hResource);
  DWORD WINAPI ResUtilFreeEnvironment (LPVOID lpEnvironment);
  LPWSTR WINAPI ResUtilExpandEnvironmentStrings (LPCWSTR pszSrc);
  DWORD WINAPI ResUtilSetResourceServiceEnvironment (LPCWSTR pszServiceName, HRESOURCE hResource, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  DWORD WINAPI ResUtilRemoveResourceServiceEnvironment (LPCWSTR pszServiceName, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  DWORD WINAPI ResUtilSetResourceServiceStartParameters (LPCWSTR pszServiceName, SC_HANDLE schSCMHandle, LPSC_HANDLE phService, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  DWORD WINAPI ResUtilFindSzProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue);
  DWORD WINAPI ResUtilFindExpandSzProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue);
  DWORD WINAPI ResUtilFindExpandedSzProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue);
  DWORD WINAPI ResUtilFindDwordProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPDWORD pdwPropertyValue);
  DWORD WINAPI ResUtilFindBinaryProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPBYTE *pbPropertyValue, LPDWORD pcbPropertyValueSize);
  DWORD WINAPI ResUtilFindMultiSzProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPWSTR *pszPropertyValue, LPDWORD pcbPropertyValueSize);
  DWORD WINAPI ResUtilFindLongProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPLONG plPropertyValue);
  DWORD WINAPI ResUtilFindFileTimeProperty (const PVOID pPropertyList, DWORD cbPropertyListSize, LPCWSTR pszPropertyName, LPFILETIME pftPropertyValue);
  DWORD WINAPI ClusWorkerCreate (PCLUS_WORKER lpWorker, PWORKER_START_ROUTINE lpStartAddress, PVOID lpParameter);
  WINBOOL WINAPI ClusWorkerCheckTerminate (PCLUS_WORKER lpWorker);
  VOID WINAPI ClusWorkerTerminate (PCLUS_WORKER lpWorker);
  WINBOOL WINAPI ResUtilResourcesEqual (HRESOURCE hSelf, HRESOURCE hResource);
  WINBOOL WINAPI ResUtilResourceTypesEqual (LPCWSTR lpszResourceTypeName, HRESOURCE hResource);
  WINBOOL WINAPI ResUtilIsResourceClassEqual (PCLUS_RESOURCE_CLASS_INFO prci, HRESOURCE hResource);
  DWORD WINAPI ResUtilEnumResources (HRESOURCE hSelf, LPCWSTR lpszResTypeName, LPRESOURCE_CALLBACK pResCallBack, PVOID pParameter);
  DWORD WINAPI ResUtilEnumResourcesEx (HCLUSTER hCluster, HRESOURCE hSelf, LPCWSTR lpszResTypeName, LPRESOURCE_CALLBACK_EX pResCallBack, PVOID pParameter);
  HRESOURCE WINAPI ResUtilGetResourceDependency (HANDLE hSelf, LPCWSTR lpszResourceType);
  HRESOURCE WINAPI ResUtilGetResourceDependencyByName (HCLUSTER hCluster, HANDLE hSelf, LPCWSTR lpszResourceType, WINBOOL bRecurse);
  HRESOURCE WINAPI ResUtilGetResourceDependencyByClass (HCLUSTER hCluster, HANDLE hSelf, PCLUS_RESOURCE_CLASS_INFO prci, WINBOOL bRecurse);
  HRESOURCE WINAPI ResUtilGetResourceNameDependency (LPCWSTR lpszResourceName, LPCWSTR lpszResourceType);
  DWORD WINAPI ResUtilGetResourceDependentIPAddressProps (HRESOURCE hResource, LPWSTR pszAddress, DWORD *pcchAddress, LPWSTR pszSubnetMask, DWORD *pcchSubnetMask, LPWSTR pszNetwork, DWORD *pcch_Network);
  DWORD WINAPI ResUtilFindDependentDiskResourceDriveLetter (HCLUSTER hCluster, HRESOURCE hResource, LPWSTR pszDriveLetter, DWORD *pcchDriveLetter);
  DWORD WINAPI ResUtilTerminateServiceProcessFromResDll (DWORD dwServicePid, WINBOOL bOffline, PDWORD pdwResourceState, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  DWORD WINAPI ResUtilGetPropertyFormats (const PRESUTIL_PROPERTY_ITEM pPropertyTable, PVOID pOutPropertyFormatList, DWORD cbPropertyFormatListSize, LPDWORD pcbBytesReturned, LPDWORD pcbRequired);
  DWORD WINAPI ResUtilGetCoreClusterResources (HCLUSTER hCluster, HRESOURCE *phClusterNameResource, HRESOURCE *phClusterIPAddressResource, HRESOURCE *phClusterQuorumResource);
  DWORD WINAPI ResUtilGetResourceName (HRESOURCE hResource, PWSTR pszResourceName, DWORD *pcchResourceNameInOut);
  CLUSTER_ROLE_STATE WINAPI ResUtilGetClusterRoleState (HCLUSTER hCluster, CLUSTER_ROLE eClusterRole);
  WINBOOL WINAPI ClusterIsPathOnSharedVolume (LPCWSTR lpszPathName);
  WINBOOL WINAPI ClusterGetVolumePathName (LPCWSTR lpszFileName, LPWSTR lpszVolumePathName, DWORD cchBufferLength);
  WINBOOL WINAPI ClusterGetVolumeNameForVolumeMountPoint (LPCWSTR lpszVolumeMountPoint, LPWSTR lpszVolumeName, DWORD cchBufferLength);
  DWORD WINAPI ClusterPrepareSharedVolumeForBackup (LPCWSTR lpszFileName, LPWSTR lpszVolumePathName, LPDWORD lpcchVolumePathName, LPWSTR lpszVolumeName, LPDWORD lpcchVolumeName);
  DWORD WINAPI ClusterClearBackupStateForSharedVolume (LPCWSTR lpszVolumePathName);
#if CLUSAPI_VERSION >= CLUSAPI_VERSION_WINDOWS8
  DWORD WINAPI ResUtilSetResourceServiceStartParametersEx (LPCWSTR pszServiceName, SC_HANDLE schSCMHandle, LPSC_HANDLE phService, DWORD dwDesiredAccess, PLOG_EVENT_ROUTINE pfnLogEvent, RESOURCE_HANDLE hResourceHandle);
  DWORD WINAPI ResUtilEnumResourcesEx2 (HCLUSTER hCluster, HRESOURCE hSelf, LPCWSTR lpszResTypeName, LPRESOURCE_CALLBACK_EX pResCallBack, PVOID pParameter, DWORD dwDesiredAccess);
  HRESOURCE WINAPI ResUtilGetResourceDependencyEx (HANDLE hSelf, LPCWSTR lpszResourceType, DWORD dwDesiredAccess);
  HRESOURCE WINAPI ResUtilGetResourceDependencyByNameEx (HCLUSTER hCluster, HANDLE hSelf, LPCWSTR lpszResourceType, WINBOOL bRecurse, DWORD dwDesiredAccess);
  HRESOURCE WINAPI ResUtilGetResourceDependencyByClassEx (HCLUSTER hCluster, HANDLE hSelf, PCLUS_RESOURCE_CLASS_INFO prci, WINBOOL bRecurse, DWORD dwDesiredAccess);
  HRESOURCE WINAPI ResUtilGetResourceNameDependencyEx (LPCWSTR lpszResourceName, LPCWSTR lpszResourceType, DWORD dwDesiredAccess);
  DWORD WINAPI ResUtilGetCoreClusterResourcesEx (HCLUSTER hClusterIn, HRESOURCE *phClusterNameResourceOut, HRESOURCE *phClusterQuorumResourceOut, DWORD dwDesiredAccess);
#endif

  FORCEINLINE DWORD WINAPI_INLINE ResUtilGetMultiSzValue (HKEY hkeyClusterKey, LPCWSTR pszValueName, LPWSTR *ppszOutValue, LPDWORD pcbOutValueSize) {
    return ResUtilGetBinaryValue (hkeyClusterKey, pszValueName,(LPBYTE *) ppszOutValue, pcbOutValueSize);
  }

#ifdef __cplusplus
}
#endif

#endif
#endif
