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

#ifndef __msclus_h__
#define __msclus_h__

#ifndef __ClusApplication_FWD_DEFINED__
#define __ClusApplication_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusApplication ClusApplication;
#else
typedef struct ClusApplication ClusApplication;
#endif
#endif

#ifndef __Cluster_FWD_DEFINED__
#define __Cluster_FWD_DEFINED__
#ifdef __cplusplus
typedef class Cluster Cluster;
#else
typedef struct Cluster Cluster;
#endif
#endif

#ifndef __ClusVersion_FWD_DEFINED__
#define __ClusVersion_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusVersion ClusVersion;
#else
typedef struct ClusVersion ClusVersion;
#endif
#endif

#ifndef __ClusResType_FWD_DEFINED__
#define __ClusResType_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResType ClusResType;
#else
typedef struct ClusResType ClusResType;
#endif
#endif

#ifndef __ClusProperty_FWD_DEFINED__
#define __ClusProperty_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusProperty ClusProperty;
#else
typedef struct ClusProperty ClusProperty;
#endif
#endif

#ifndef __ClusProperties_FWD_DEFINED__
#define __ClusProperties_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusProperties ClusProperties;
#else
typedef struct ClusProperties ClusProperties;
#endif
#endif

#ifndef __DomainNames_FWD_DEFINED__
#define __DomainNames_FWD_DEFINED__
#ifdef __cplusplus
typedef class DomainNames DomainNames;
#else
typedef struct DomainNames DomainNames;
#endif
#endif

#ifndef __ClusNetwork_FWD_DEFINED__
#define __ClusNetwork_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNetwork ClusNetwork;
#else
typedef struct ClusNetwork ClusNetwork;
#endif
#endif

#ifndef __ClusNetInterface_FWD_DEFINED__
#define __ClusNetInterface_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNetInterface ClusNetInterface;
#else
typedef struct ClusNetInterface ClusNetInterface;
#endif
#endif

#ifndef __ClusNetInterfaces_FWD_DEFINED__
#define __ClusNetInterfaces_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNetInterfaces ClusNetInterfaces;
#else
typedef struct ClusNetInterfaces ClusNetInterfaces;
#endif
#endif

#ifndef __ClusResDependencies_FWD_DEFINED__
#define __ClusResDependencies_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResDependencies ClusResDependencies;
#else
typedef struct ClusResDependencies ClusResDependencies;
#endif
#endif

#ifndef __ClusResGroupResources_FWD_DEFINED__
#define __ClusResGroupResources_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResGroupResources ClusResGroupResources;
#else
typedef struct ClusResGroupResources ClusResGroupResources;
#endif
#endif

#ifndef __ClusResTypeResources_FWD_DEFINED__
#define __ClusResTypeResources_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResTypeResources ClusResTypeResources;
#else
typedef struct ClusResTypeResources ClusResTypeResources;
#endif
#endif

#ifndef __ClusResGroupPreferredOwnerNodes_FWD_DEFINED__
#define __ClusResGroupPreferredOwnerNodes_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResGroupPreferredOwnerNodes ClusResGroupPreferredOwnerNodes;
#else
typedef struct ClusResGroupPreferredOwnerNodes ClusResGroupPreferredOwnerNodes;
#endif
#endif

#ifndef __ClusResPossibleOwnerNodes_FWD_DEFINED__
#define __ClusResPossibleOwnerNodes_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResPossibleOwnerNodes ClusResPossibleOwnerNodes;
#else
typedef struct ClusResPossibleOwnerNodes ClusResPossibleOwnerNodes;
#endif
#endif

#ifndef __ClusNetworks_FWD_DEFINED__
#define __ClusNetworks_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNetworks ClusNetworks;
#else
typedef struct ClusNetworks ClusNetworks;
#endif
#endif

#ifndef __ClusNetworkNetInterfaces_FWD_DEFINED__
#define __ClusNetworkNetInterfaces_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNetworkNetInterfaces ClusNetworkNetInterfaces;
#else
typedef struct ClusNetworkNetInterfaces ClusNetworkNetInterfaces;
#endif
#endif

#ifndef __ClusNodeNetInterfaces_FWD_DEFINED__
#define __ClusNodeNetInterfaces_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNodeNetInterfaces ClusNodeNetInterfaces;
#else
typedef struct ClusNodeNetInterfaces ClusNodeNetInterfaces;
#endif
#endif

#ifndef __ClusRefObject_FWD_DEFINED__
#define __ClusRefObject_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusRefObject ClusRefObject;
#else
typedef struct ClusRefObject ClusRefObject;
#endif
#endif

#ifndef __ClusterNames_FWD_DEFINED__
#define __ClusterNames_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusterNames ClusterNames;
#else
typedef struct ClusterNames ClusterNames;
#endif
#endif

#ifndef __ClusNode_FWD_DEFINED__
#define __ClusNode_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNode ClusNode;
#else
typedef struct ClusNode ClusNode;
#endif
#endif

#ifndef __ClusNodes_FWD_DEFINED__
#define __ClusNodes_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusNodes ClusNodes;
#else
typedef struct ClusNodes ClusNodes;
#endif
#endif

#ifndef __ClusResGroup_FWD_DEFINED__
#define __ClusResGroup_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResGroup ClusResGroup;
#else
typedef struct ClusResGroup ClusResGroup;
#endif
#endif

#ifndef __ClusResGroups_FWD_DEFINED__
#define __ClusResGroups_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResGroups ClusResGroups;
#else
typedef struct ClusResGroups ClusResGroups;
#endif
#endif

#ifndef __ClusResource_FWD_DEFINED__
#define __ClusResource_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResource ClusResource;
#else
typedef struct ClusResource ClusResource;
#endif
#endif

#ifndef __ClusResources_FWD_DEFINED__
#define __ClusResources_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResources ClusResources;
#else
typedef struct ClusResources ClusResources;
#endif
#endif

#ifndef __ClusResTypes_FWD_DEFINED__
#define __ClusResTypes_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResTypes ClusResTypes;
#else
typedef struct ClusResTypes ClusResTypes;
#endif
#endif

#ifndef __ClusResTypePossibleOwnerNodes_FWD_DEFINED__
#define __ClusResTypePossibleOwnerNodes_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResTypePossibleOwnerNodes ClusResTypePossibleOwnerNodes;
#else
typedef struct ClusResTypePossibleOwnerNodes ClusResTypePossibleOwnerNodes;
#endif
#endif

#ifndef __ClusPropertyValue_FWD_DEFINED__
#define __ClusPropertyValue_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusPropertyValue ClusPropertyValue;
#else
typedef struct ClusPropertyValue ClusPropertyValue;
#endif
#endif

#ifndef __ClusPropertyValues_FWD_DEFINED__
#define __ClusPropertyValues_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusPropertyValues ClusPropertyValues;
#else
typedef struct ClusPropertyValues ClusPropertyValues;
#endif
#endif

#ifndef __ClusPropertyValueData_FWD_DEFINED__
#define __ClusPropertyValueData_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusPropertyValueData ClusPropertyValueData;
#else
typedef struct ClusPropertyValueData ClusPropertyValueData;
#endif
#endif

#ifndef __ClusPartition_FWD_DEFINED__
#define __ClusPartition_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusPartition ClusPartition;
#else
typedef struct ClusPartition ClusPartition;
#endif
#endif

#ifndef __ClusPartitions_FWD_DEFINED__
#define __ClusPartitions_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusPartitions ClusPartitions;
#else
typedef struct ClusPartitions ClusPartitions;
#endif
#endif

#ifndef __ClusDisk_FWD_DEFINED__
#define __ClusDisk_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusDisk ClusDisk;
#else
typedef struct ClusDisk ClusDisk;
#endif
#endif

#ifndef __ClusDisks_FWD_DEFINED__
#define __ClusDisks_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusDisks ClusDisks;
#else
typedef struct ClusDisks ClusDisks;
#endif
#endif

#ifndef __ClusScsiAddress_FWD_DEFINED__
#define __ClusScsiAddress_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusScsiAddress ClusScsiAddress;
#else
typedef struct ClusScsiAddress ClusScsiAddress;
#endif
#endif

#ifndef __ClusRegistryKeys_FWD_DEFINED__
#define __ClusRegistryKeys_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusRegistryKeys ClusRegistryKeys;
#else
typedef struct ClusRegistryKeys ClusRegistryKeys;
#endif
#endif

#ifndef __ClusCryptoKeys_FWD_DEFINED__
#define __ClusCryptoKeys_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusCryptoKeys ClusCryptoKeys;
#else
typedef struct ClusCryptoKeys ClusCryptoKeys;
#endif
#endif

#ifndef __ClusResDependents_FWD_DEFINED__
#define __ClusResDependents_FWD_DEFINED__
#ifdef __cplusplus
typedef class ClusResDependents ClusResDependents;
#else
typedef struct ClusResDependents ClusResDependents;
#endif
#endif

#ifndef __ISClusApplication_FWD_DEFINED__
#define __ISClusApplication_FWD_DEFINED__
typedef struct ISClusApplication ISClusApplication;
#endif

#ifndef __ISDomainNames_FWD_DEFINED__
#define __ISDomainNames_FWD_DEFINED__
typedef struct ISDomainNames ISDomainNames;
#endif

#ifndef __ISClusterNames_FWD_DEFINED__
#define __ISClusterNames_FWD_DEFINED__
typedef struct ISClusterNames ISClusterNames;
#endif

#ifndef __ISClusRefObject_FWD_DEFINED__
#define __ISClusRefObject_FWD_DEFINED__
typedef struct ISClusRefObject ISClusRefObject;
#endif

#ifndef __ISClusVersion_FWD_DEFINED__
#define __ISClusVersion_FWD_DEFINED__
typedef struct ISClusVersion ISClusVersion;
#endif

#ifndef __ISCluster_FWD_DEFINED__
#define __ISCluster_FWD_DEFINED__
typedef struct ISCluster ISCluster;
#endif

#ifndef __ISClusNode_FWD_DEFINED__
#define __ISClusNode_FWD_DEFINED__
typedef struct ISClusNode ISClusNode;
#endif

#ifndef __ISClusNodes_FWD_DEFINED__
#define __ISClusNodes_FWD_DEFINED__
typedef struct ISClusNodes ISClusNodes;
#endif

#ifndef __ISClusNetwork_FWD_DEFINED__
#define __ISClusNetwork_FWD_DEFINED__
typedef struct ISClusNetwork ISClusNetwork;
#endif

#ifndef __ISClusNetworks_FWD_DEFINED__
#define __ISClusNetworks_FWD_DEFINED__
typedef struct ISClusNetworks ISClusNetworks;
#endif

#ifndef __ISClusNetInterface_FWD_DEFINED__
#define __ISClusNetInterface_FWD_DEFINED__
typedef struct ISClusNetInterface ISClusNetInterface;
#endif

#ifndef __ISClusNetInterfaces_FWD_DEFINED__
#define __ISClusNetInterfaces_FWD_DEFINED__
typedef struct ISClusNetInterfaces ISClusNetInterfaces;
#endif

#ifndef __ISClusNodeNetInterfaces_FWD_DEFINED__
#define __ISClusNodeNetInterfaces_FWD_DEFINED__
typedef struct ISClusNodeNetInterfaces ISClusNodeNetInterfaces;
#endif

#ifndef __ISClusNetworkNetInterfaces_FWD_DEFINED__
#define __ISClusNetworkNetInterfaces_FWD_DEFINED__
typedef struct ISClusNetworkNetInterfaces ISClusNetworkNetInterfaces;
#endif

#ifndef __ISClusResGroup_FWD_DEFINED__
#define __ISClusResGroup_FWD_DEFINED__
typedef struct ISClusResGroup ISClusResGroup;
#endif

#ifndef __ISClusResGroups_FWD_DEFINED__
#define __ISClusResGroups_FWD_DEFINED__
typedef struct ISClusResGroups ISClusResGroups;
#endif

#ifndef __ISClusResource_FWD_DEFINED__
#define __ISClusResource_FWD_DEFINED__
typedef struct ISClusResource ISClusResource;
#endif

#ifndef __ISClusResDependencies_FWD_DEFINED__
#define __ISClusResDependencies_FWD_DEFINED__
typedef struct ISClusResDependencies ISClusResDependencies;
#endif

#ifndef __ISClusResGroupResources_FWD_DEFINED__
#define __ISClusResGroupResources_FWD_DEFINED__
typedef struct ISClusResGroupResources ISClusResGroupResources;
#endif

#ifndef __ISClusResTypeResources_FWD_DEFINED__
#define __ISClusResTypeResources_FWD_DEFINED__
typedef struct ISClusResTypeResources ISClusResTypeResources;
#endif

#ifndef __ISClusResources_FWD_DEFINED__
#define __ISClusResources_FWD_DEFINED__
typedef struct ISClusResources ISClusResources;
#endif

#ifndef __ISClusResGroupPreferredOwnerNodes_FWD_DEFINED__
#define __ISClusResGroupPreferredOwnerNodes_FWD_DEFINED__
typedef struct ISClusResGroupPreferredOwnerNodes ISClusResGroupPreferredOwnerNodes;
#endif

#ifndef __ISClusResPossibleOwnerNodes_FWD_DEFINED__
#define __ISClusResPossibleOwnerNodes_FWD_DEFINED__
typedef struct ISClusResPossibleOwnerNodes ISClusResPossibleOwnerNodes;
#endif

#ifndef __ISClusResTypePossibleOwnerNodes_FWD_DEFINED__
#define __ISClusResTypePossibleOwnerNodes_FWD_DEFINED__
typedef struct ISClusResTypePossibleOwnerNodes ISClusResTypePossibleOwnerNodes;
#endif

#ifndef __ISClusResType_FWD_DEFINED__
#define __ISClusResType_FWD_DEFINED__
typedef struct ISClusResType ISClusResType;
#endif

#ifndef __ISClusResTypes_FWD_DEFINED__
#define __ISClusResTypes_FWD_DEFINED__
typedef struct ISClusResTypes ISClusResTypes;
#endif

#ifndef __ISClusProperty_FWD_DEFINED__
#define __ISClusProperty_FWD_DEFINED__
typedef struct ISClusProperty ISClusProperty;
#endif

#ifndef __ISClusPropertyValue_FWD_DEFINED__
#define __ISClusPropertyValue_FWD_DEFINED__
typedef struct ISClusPropertyValue ISClusPropertyValue;
#endif

#ifndef __ISClusPropertyValues_FWD_DEFINED__
#define __ISClusPropertyValues_FWD_DEFINED__
typedef struct ISClusPropertyValues ISClusPropertyValues;
#endif

#ifndef __ISClusProperties_FWD_DEFINED__
#define __ISClusProperties_FWD_DEFINED__
typedef struct ISClusProperties ISClusProperties;
#endif

#ifndef __ISClusPropertyValueData_FWD_DEFINED__
#define __ISClusPropertyValueData_FWD_DEFINED__
typedef struct ISClusPropertyValueData ISClusPropertyValueData;
#endif

#ifndef __ISClusPartition_FWD_DEFINED__
#define __ISClusPartition_FWD_DEFINED__
typedef struct ISClusPartition ISClusPartition;
#endif

#ifndef __ISClusPartitions_FWD_DEFINED__
#define __ISClusPartitions_FWD_DEFINED__
typedef struct ISClusPartitions ISClusPartitions;
#endif

#ifndef __ISClusDisk_FWD_DEFINED__
#define __ISClusDisk_FWD_DEFINED__
typedef struct ISClusDisk ISClusDisk;
#endif

#ifndef __ISClusDisks_FWD_DEFINED__
#define __ISClusDisks_FWD_DEFINED__
typedef struct ISClusDisks ISClusDisks;
#endif

#ifndef __ISClusScsiAddress_FWD_DEFINED__
#define __ISClusScsiAddress_FWD_DEFINED__
typedef struct ISClusScsiAddress ISClusScsiAddress;
#endif

#ifndef __ISClusRegistryKeys_FWD_DEFINED__
#define __ISClusRegistryKeys_FWD_DEFINED__
typedef struct ISClusRegistryKeys ISClusRegistryKeys;
#endif

#ifndef __ISClusCryptoKeys_FWD_DEFINED__
#define __ISClusCryptoKeys_FWD_DEFINED__
typedef struct ISClusCryptoKeys ISClusCryptoKeys;
#endif

#ifndef __ISClusResDependents_FWD_DEFINED__
#define __ISClusResDependents_FWD_DEFINED__
typedef struct ISClusResDependents ISClusResDependents;
#endif

#include "basetsd.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _CLUSTER_API_TYPES_
#define _CLUSTER_API_TYPES_

  typedef struct _HCLUSTER *HCLUSTER;
  typedef struct _HNODE *HNODE;
  typedef struct _HRESOURCE *HRESOURCE;
  typedef struct _HGROUP *HGROUP;
  typedef struct _HNETWORK *HNETWORK;
  typedef struct _HNETINTERFACE *HNETINTERFACE;
  typedef struct _HCHANGE *HCHANGE;
  typedef struct _HCLUSENUM *HCLUSENUM;
  typedef struct _HGROUPENUM *HGROUPENUM;
  typedef struct _HRESENUM *HRESENUM;
  typedef struct _HNETWORKENUM *HNETWORKENUM;
  typedef struct _HNODEENUM *HNODEENUM;
  typedef struct _HRESTYPEENUM *HRESTYPEENUM;

  typedef enum CLUSTER_QUORUM_TYPE {
    OperationalQuorum = 0,ModifyQuorum = OperationalQuorum + 1
  } CLUSTER_QUORUM_TYPE;

  typedef enum NODE_CLUSTER_STATE {
    ClusterStateNotInstalled = 0,ClusterStateNotConfigured = 0x1,ClusterStateNotRunning = 0x1 | 0x2,ClusterStateRunning = 0x1 | 0x2 | 0x10
  } NODE_CLUSTER_STATE;

  typedef enum CLUSTER_RESOURCE_STATE_CHANGE_REASON {
    eResourceStateChangeReasonUnknown = 0,eResourceStateChangeReasonMove,
    eResourceStateChangeReasonFailover,eResourceStateChangeReasonFailedMove,
    eResourceStateChangeReasonShutdown,eResourceStateChangeReasonRundown
  } CLUSTER_RESOURCE_STATE_CHANGE_REASON;

  typedef enum CLUSTER_SET_PASSWORD_FLAGS {
    CLUSTER_SET_PASSWORD_IGNORE_DOWN_NODES = 1
  } CLUSTER_SET_PASSWORD_FLAGS;

  typedef enum CLUSTER_CHANGE {
    CLUSTER_CHANGE_NODE_STATE = 0x1,CLUSTER_CHANGE_NODE_DELETED = 0x2,CLUSTER_CHANGE_NODE_ADDED = 0x4,CLUSTER_CHANGE_NODE_PROPERTY = 0x8,
    CLUSTER_CHANGE_REGISTRY_NAME = 0x10,CLUSTER_CHANGE_REGISTRY_ATTRIBUTES = 0x20,CLUSTER_CHANGE_REGISTRY_VALUE = 0x40,
    CLUSTER_CHANGE_REGISTRY_SUBTREE = 0x80,CLUSTER_CHANGE_RESOURCE_STATE = 0x100,CLUSTER_CHANGE_RESOURCE_DELETED = 0x200,
    CLUSTER_CHANGE_RESOURCE_ADDED = 0x400,CLUSTER_CHANGE_RESOURCE_PROPERTY = 0x800,CLUSTER_CHANGE_GROUP_STATE = 0x1000,
    CLUSTER_CHANGE_GROUP_DELETED = 0x2000,CLUSTER_CHANGE_GROUP_ADDED = 0x4000,CLUSTER_CHANGE_GROUP_PROPERTY = 0x8000,
    CLUSTER_CHANGE_RESOURCE_TYPE_DELETED = 0x10000,CLUSTER_CHANGE_RESOURCE_TYPE_ADDED = 0x20000,CLUSTER_CHANGE_RESOURCE_TYPE_PROPERTY = 0x40000,
    CLUSTER_CHANGE_CLUSTER_RECONNECT = 0x80000,CLUSTER_CHANGE_NETWORK_STATE = 0x100000,CLUSTER_CHANGE_NETWORK_DELETED = 0x200000,
    CLUSTER_CHANGE_NETWORK_ADDED = 0x400000,CLUSTER_CHANGE_NETWORK_PROPERTY = 0x800000,CLUSTER_CHANGE_NETINTERFACE_STATE = 0x1000000,
    CLUSTER_CHANGE_NETINTERFACE_DELETED = 0x2000000,CLUSTER_CHANGE_NETINTERFACE_ADDED = 0x4000000,CLUSTER_CHANGE_NETINTERFACE_PROPERTY = 0x8000000,
    CLUSTER_CHANGE_QUORUM_STATE = 0x10000000,CLUSTER_CHANGE_CLUSTER_STATE = 0x20000000,CLUSTER_CHANGE_CLUSTER_PROPERTY = 0x40000000,
    CLUSTER_CHANGE_HANDLE_CLOSE = 0x80000000,
    CLUSTER_CHANGE_ALL = CLUSTER_CHANGE_NODE_STATE | CLUSTER_CHANGE_NODE_DELETED | CLUSTER_CHANGE_NODE_ADDED | CLUSTER_CHANGE_NODE_PROPERTY | CLUSTER_CHANGE_REGISTRY_NAME | CLUSTER_CHANGE_REGISTRY_ATTRIBUTES | CLUSTER_CHANGE_REGISTRY_VALUE | CLUSTER_CHANGE_REGISTRY_SUBTREE | CLUSTER_CHANGE_RESOURCE_STATE | CLUSTER_CHANGE_RESOURCE_DELETED | CLUSTER_CHANGE_RESOURCE_ADDED | CLUSTER_CHANGE_RESOURCE_PROPERTY | CLUSTER_CHANGE_GROUP_STATE | CLUSTER_CHANGE_GROUP_DELETED | CLUSTER_CHANGE_GROUP_ADDED | CLUSTER_CHANGE_GROUP_PROPERTY | CLUSTER_CHANGE_RESOURCE_TYPE_DELETED | CLUSTER_CHANGE_RESOURCE_TYPE_ADDED | CLUSTER_CHANGE_RESOURCE_TYPE_PROPERTY | CLUSTER_CHANGE_NETWORK_STATE | CLUSTER_CHANGE_NETWORK_DELETED | CLUSTER_CHANGE_NETWORK_ADDED | CLUSTER_CHANGE_NETWORK_PROPERTY | CLUSTER_CHANGE_NETINTERFACE_STATE | CLUSTER_CHANGE_NETINTERFACE_DELETED | CLUSTER_CHANGE_NETINTERFACE_ADDED | CLUSTER_CHANGE_NETINTERFACE_PROPERTY | CLUSTER_CHANGE_QUORUM_STATE | CLUSTER_CHANGE_CLUSTER_STATE | CLUSTER_CHANGE_CLUSTER_PROPERTY | CLUSTER_CHANGE_CLUSTER_RECONNECT | CLUSTER_CHANGE_HANDLE_CLOSE
  } CLUSTER_CHANGE;

  typedef enum CLUSTER_ENUM {
    CLUSTER_ENUM_NODE = 0x1,CLUSTER_ENUM_RESTYPE = 0x2,CLUSTER_ENUM_RESOURCE = 0x4,CLUSTER_ENUM_GROUP = 0x8,CLUSTER_ENUM_NETWORK = 0x10,
    CLUSTER_ENUM_NETINTERFACE = 0x20,CLUSTER_ENUM_INTERNAL_NETWORK = 0x80000000,
    CLUSTER_ENUM_ALL = CLUSTER_ENUM_NODE | CLUSTER_ENUM_RESTYPE | CLUSTER_ENUM_RESOURCE | CLUSTER_ENUM_GROUP | CLUSTER_ENUM_NETWORK | CLUSTER_ENUM_NETINTERFACE
  } CLUSTER_ENUM;

  typedef enum CLUSTER_NODE_ENUM {
    CLUSTER_NODE_ENUM_NETINTERFACES = 0x1,CLUSTER_NODE_ENUM_ALL = CLUSTER_NODE_ENUM_NETINTERFACES
  } CLUSTER_NODE_ENUM;

  typedef enum CLUSTER_NODE_STATE {
    ClusterNodeStateUnknown = -1,
    ClusterNodeUp = 0,ClusterNodeDown,ClusterNodePaused,ClusterNodeJoining
  } CLUSTER_NODE_STATE;

  typedef enum CLUSTER_GROUP_ENUM {
    CLUSTER_GROUP_ENUM_CONTAINS = 0x1,CLUSTER_GROUP_ENUM_NODES = 0x2,CLUSTER_GROUP_ENUM_ALL = CLUSTER_GROUP_ENUM_CONTAINS | CLUSTER_GROUP_ENUM_NODES
  } CLUSTER_GROUP_ENUM;

  typedef enum CLUSTER_GROUP_STATE {
    ClusterGroupStateUnknown = -1,
    ClusterGroupOnline = 0,ClusterGroupOffline,ClusterGroupFailed,
    ClusterGroupPartialOnline,ClusterGroupPending
  } CLUSTER_GROUP_STATE;

  typedef enum CLUSTER_GROUP_AUTOFAILBACK_TYPE {
    ClusterGroupPreventFailback = 0,ClusterGroupAllowFailback,ClusterGroupFailbackTypeCount
  } CLUSTER_GROUP_AUTOFAILBACK_TYPE;

  typedef enum CLUSTER_GROUP_AUTOFAILBACK_TYPE CGAFT;

  typedef enum CLUSTER_RESOURCE_STATE {
    ClusterResourceStateUnknown = -1,
    ClusterResourceInherited = 0,ClusterResourceInitializing,ClusterResourceOnline,
    ClusterResourceOffline,ClusterResourceFailed,
    ClusterResourcePending = 128,ClusterResourceOnlinePending = 129,ClusterResourceOfflinePending = 130
  } CLUSTER_RESOURCE_STATE;

  typedef enum CLUSTER_RESOURCE_RESTART_ACTION {
    ClusterResourceDontRestart = 0,ClusterResourceRestartNoNotify,
    ClusterResourceRestartNotify,ClusterResourceRestartActionCount
  } CLUSTER_RESOURCE_RESTART_ACTION;

  typedef enum CLUSTER_RESOURCE_RESTART_ACTION CRRA;

  typedef enum CLUSTER_RESOURCE_CREATE_FLAGS {
    CLUSTER_RESOURCE_DEFAULT_MONITOR = 0,CLUSTER_RESOURCE_SEPARATE_MONITOR = 1,CLUSTER_RESOURCE_VALID_FLAGS = CLUSTER_RESOURCE_SEPARATE_MONITOR
  } CLUSTER_RESOURCE_CREATE_FLAGS;

  typedef enum CLUSTER_PROPERTY_TYPE {
    CLUSPROP_TYPE_UNKNOWN = -1,
    CLUSPROP_TYPE_ENDMARK = 0,CLUSPROP_TYPE_LIST_VALUE,CLUSPROP_TYPE_RESCLASS,CLUSPROP_TYPE_RESERVED1,
    CLUSPROP_TYPE_NAME,CLUSPROP_TYPE_SIGNATURE,CLUSPROP_TYPE_SCSI_ADDRESS,CLUSPROP_TYPE_DISK_NUMBER,
    CLUSPROP_TYPE_PARTITION_INFO,CLUSPROP_TYPE_FTSET_INFO,CLUSPROP_TYPE_DISK_SERIALNUMBER,
    CLUSPROP_TYPE_USER = 32768
  } CLUSTER_PROPERTY_TYPE;

  typedef enum CLUSTER_PROPERTY_FORMAT {
    CLUSPROP_FORMAT_UNKNOWN = 0,CLUSPROP_FORMAT_BINARY,CLUSPROP_FORMAT_DWORD,
    CLUSPROP_FORMAT_SZ,CLUSPROP_FORMAT_EXPAND_SZ,CLUSPROP_FORMAT_MULTI_SZ,CLUSPROP_FORMAT_ULARGE_INTEGER,
    CLUSPROP_FORMAT_LONG,CLUSPROP_FORMAT_EXPANDED_SZ,CLUSPROP_FORMAT_SECURITY_DESCRIPTOR,
    CLUSPROP_FORMAT_LARGE_INTEGER,CLUSPROP_FORMAT_WORD,
    CLUSPROP_FORMAT_USER = 32768
  } CLUSTER_PROPERTY_FORMAT;

  typedef enum CLUSTER_PROPERTY_SYNTAX {
    CLUSPROP_SYNTAX_ENDMARK = (DWORD)(CLUSPROP_TYPE_ENDMARK << 16 | CLUSPROP_FORMAT_UNKNOWN),
    CLUSPROP_SYNTAX_NAME = (DWORD)(CLUSPROP_TYPE_NAME << 16 | CLUSPROP_FORMAT_SZ),
    CLUSPROP_SYNTAX_RESCLASS = (DWORD)(CLUSPROP_TYPE_RESCLASS << 16 | CLUSPROP_FORMAT_DWORD),
    CLUSPROP_SYNTAX_LIST_VALUE_SZ = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_SZ),
    CLUSPROP_SYNTAX_LIST_VALUE_EXPAND_SZ = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_EXPAND_SZ),
    CLUSPROP_SYNTAX_LIST_VALUE_DWORD = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_DWORD),
    CLUSPROP_SYNTAX_LIST_VALUE_BINARY = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_BINARY),
    CLUSPROP_SYNTAX_LIST_VALUE_MULTI_SZ = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_MULTI_SZ),
    CLUSPROP_SYNTAX_LIST_VALUE_LONG = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_LONG),
    CLUSPROP_SYNTAX_LIST_VALUE_EXPANDED_SZ = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_EXPANDED_SZ),
    CLUSPROP_SYNTAX_LIST_VALUE_SECURITY_DESCRIPTOR = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_SECURITY_DESCRIPTOR),
    CLUSPROP_SYNTAX_LIST_VALUE_LARGE_INTEGER = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_LARGE_INTEGER),
    CLUSPROP_SYNTAX_LIST_VALUE_ULARGE_INTEGER = (DWORD)(CLUSPROP_TYPE_LIST_VALUE << 16 | CLUSPROP_FORMAT_ULARGE_INTEGER),
    CLUSPROP_SYNTAX_DISK_SIGNATURE = (DWORD)(CLUSPROP_TYPE_SIGNATURE << 16 | CLUSPROP_FORMAT_DWORD),
    CLUSPROP_SYNTAX_SCSI_ADDRESS = (DWORD)(CLUSPROP_TYPE_SCSI_ADDRESS << 16 | CLUSPROP_FORMAT_DWORD),
    CLUSPROP_SYNTAX_DISK_NUMBER = (DWORD)(CLUSPROP_TYPE_DISK_NUMBER << 16 | CLUSPROP_FORMAT_DWORD),
    CLUSPROP_SYNTAX_PARTITION_INFO = (DWORD)(CLUSPROP_TYPE_PARTITION_INFO << 16 | CLUSPROP_FORMAT_BINARY),
    CLUSPROP_SYNTAX_FTSET_INFO = (DWORD)(CLUSPROP_TYPE_FTSET_INFO << 16 | CLUSPROP_FORMAT_BINARY),
    CLUSPROP_SYNTAX_DISK_SERIALNUMBER = (DWORD)(CLUSPROP_TYPE_DISK_SERIALNUMBER << 16 | CLUSPROP_FORMAT_SZ)
  } CLUSTER_PROPERTY_SYNTAX;

  typedef enum CLUSTER_CONTROL_OBJECT {
    CLUS_OBJECT_INVALID = 0,CLUS_OBJECT_RESOURCE,CLUS_OBJECT_RESOURCE_TYPE,CLUS_OBJECT_GROUP,
    CLUS_OBJECT_NODE,CLUS_OBJECT_NETWORK,CLUS_OBJECT_NETINTERFACE,CLUS_OBJECT_CLUSTER,
    CLUS_OBJECT_USER = 128
  } CLUSTER_CONTROL_OBJECT;

  typedef enum CLCTL_CODES {
    CLCTL_UNKNOWN = 0 << 0 | 0 + 0 << 2 | 0 << 22,CLCTL_GET_CHARACTERISTICS = 0x1 << 0 | 0 + 1 << 2 | 0 << 22,
    CLCTL_GET_FLAGS = 0x1 << 0 | 0 + 2 << 2 | 0 << 22,CLCTL_GET_CLASS_INFO = 0x1 << 0 | 0 + 3 << 2 | 0 << 22,
    CLCTL_GET_REQUIRED_DEPENDENCIES = 0x1 << 0 | 0 + 4 << 2 | 0 << 22,CLCTL_GET_ARB_TIMEOUT = 0x1 << 0 | 0 + 5 << 2 | 0 << 22,
    CLCTL_GET_NAME = 0x1 << 0 | 0 + 10 << 2 | 0 << 22,CLCTL_GET_RESOURCE_TYPE = 0x1 << 0 | 0 + 11 << 2 | 0 << 22,
    CLCTL_GET_NODE = 0x1 << 0 | 0 + 12 << 2 | 0 << 22,CLCTL_GET_NETWORK = 0x1 << 0 | 0 + 13 << 2 | 0 << 22,
    CLCTL_GET_ID = 0x1 << 0 | 0 + 14 << 2 | 0 << 22,CLCTL_GET_FQDN = 0x1 << 0 | 0 + 15 << 2 | 0 << 22,
    CLCTL_GET_CLUSTER_SERVICE_ACCOUNT_NAME = 0x1 << 0 | 0 + 16 << 2 | 0 << 22,CLCTL_ENUM_COMMON_PROPERTIES = 0x1 << 0 | 0 + 20 << 2 | 0 << 22,
    CLCTL_GET_RO_COMMON_PROPERTIES = 0x1 << 0 | 0 + 21 << 2 | 0 << 22,CLCTL_GET_COMMON_PROPERTIES = 0x1 << 0 | 0 + 22 << 2 | 0 << 22,
    CLCTL_SET_COMMON_PROPERTIES = 0x2 << 0 | 0 + 23 << 2 | 0x1 << 22,CLCTL_VALIDATE_COMMON_PROPERTIES = 0x1 << 0 | 0 + 24 << 2 | 0 << 22,
    CLCTL_GET_COMMON_PROPERTY_FMTS = 0x1 << 0 | 0 + 25 << 2 | 0 << 22,CLCTL_GET_COMMON_RESOURCE_PROPERTY_FMTS = 0x1 << 0 | 0 + 26 << 2 | 0 << 22,
    CLCTL_ENUM_PRIVATE_PROPERTIES = 0x1 << 0 | 0 + 30 << 2 | 0 << 22,CLCTL_GET_RO_PRIVATE_PROPERTIES = 0x1 << 0 | 0 + 31 << 2 | 0 << 22,
    CLCTL_GET_PRIVATE_PROPERTIES = 0x1 << 0 | 0 + 32 << 2 | 0 << 22,CLCTL_SET_PRIVATE_PROPERTIES = 0x2 << 0 | 0 + 33 << 2 | 0x1 << 22,
    CLCTL_VALIDATE_PRIVATE_PROPERTIES = 0x1 << 0 | 0 + 34 << 2 | 0 << 22,CLCTL_GET_PRIVATE_PROPERTY_FMTS = 0x1 << 0 | 0 + 35 << 2 | 0 << 22,
    CLCTL_GET_PRIVATE_RESOURCE_PROPERTY_FMTS = 0x1 << 0 | 0 + 36 << 2 | 0 << 22,CLCTL_ADD_REGISTRY_CHECKPOINT = 0x2 << 0 | 0 + 40 << 2 | 0x1 << 22,
    CLCTL_DELETE_REGISTRY_CHECKPOINT = 0x2 << 0 | 0 + 41 << 2 | 0x1 << 22,CLCTL_GET_REGISTRY_CHECKPOINTS = 0x1 << 0 | 0 + 42 << 2 | 0 << 22,
    CLCTL_ADD_CRYPTO_CHECKPOINT = 0x2 << 0 | 0 + 43 << 2 | 0x1 << 22,CLCTL_DELETE_CRYPTO_CHECKPOINT = 0x2 << 0 | 0 + 44 << 2 | 0x1 << 22,
    CLCTL_GET_CRYPTO_CHECKPOINTS = 0x1 << 0 | 0 + 45 << 2 | 0 << 22,CLCTL_RESOURCE_UPGRADE_DLL = 0x2 << 0 | 0 + 46 << 2 | 0x1 << 22,
    CLCTL_ADD_REGISTRY_CHECKPOINT_64BIT = 0x2 << 0 | 0 + 47 << 2 | 0x1 << 22,CLCTL_ADD_REGISTRY_CHECKPOINT_32BIT = 0x2 << 0 | 0 + 48 << 2 | 0x1 << 22,
    CLCTL_GET_LOADBAL_PROCESS_LIST = 0x1 << 0 | 0 + 50 << 2 | 0 << 22,CLCTL_GET_NETWORK_NAME = 0x1 << 0 | 0 + 90 << 2 | 0 << 22,
    CLCTL_NETNAME_GET_VIRTUAL_SERVER_TOKEN = 0x1 << 0 | 0 + 91 << 2 | 0 << 22,CLCTL_NETNAME_REGISTER_DNS_RECORDS = 0x2 << 0 | 0 + 92 << 2 | 0 << 22,
    CLCTL_STORAGE_GET_DISK_INFO = 0x1 << 0 | 0 + 100 << 2 | 0 << 22,CLCTL_STORAGE_GET_AVAILABLE_DISKS = 0x1 << 0 | 0 + 101 << 2 | 0 << 22,
    CLCTL_STORAGE_IS_PATH_VALID = 0x1 << 0 | 0 + 102 << 2 | 0 << 22,CLCTL_STORAGE_GET_ALL_AVAILABLE_DISKS = 0x1 << 0 | 0 + 103 << 2 | 0 << 22 | 1 << 23,
    CLCTL_QUERY_DELETE = 0x1 << 0 | 0 + 110 << 2 | 0 << 22,CLCTL_QUERY_MAINTENANCE_MODE = 0x1 << 0 | 0 + 120 << 2 | 0 << 22,
    CLCTL_SET_MAINTENANCE_MODE = 0x2 << 0 | 0 + 121 << 2 | 0x1 << 22,CLCTL_DELETE = 0x2 << 0 | 1 << 20 | 0 + 1 << 2 | 0x1 << 22,
    CLCTL_INSTALL_NODE = 0x2 << 0 | 1 << 20 | 0 + 2 << 2 | 0x1 << 22,CLCTL_EVICT_NODE = 0x2 << 0 | 1 << 20 | 0 + 3 << 2 | 0x1 << 22,
    CLCTL_ADD_DEPENDENCY = 0x2 << 0 | 1 << 20 | 0 + 4 << 2 | 0x1 << 22,CLCTL_REMOVE_DEPENDENCY = 0x2 << 0 | 1 << 20 | 0 + 5 << 2 | 0x1 << 22,
    CLCTL_ADD_OWNER = 0x2 << 0 | 1 << 20 | 0 + 6 << 2 | 0x1 << 22,CLCTL_REMOVE_OWNER = 0x2 << 0 | 1 << 20 | 0 + 7 << 2 | 0x1 << 22,
    CLCTL_SET_NAME = 0x2 << 0 | 1 << 20 | 0 + 9 << 2 | 0x1 << 22,CLCTL_CLUSTER_NAME_CHANGED = 0x2 << 0 | 1 << 20 | 0 + 10 << 2 | 0x1 << 22,
    CLCTL_CLUSTER_VERSION_CHANGED = 0x2 << 0 | 1 << 20 | 0 + 11 << 2 | 0x1 << 22,CLCTL_FIXUP_ON_UPGRADE = 0x2 << 0 | 1 << 20 | 0 + 12 << 2 | 0x1 << 22,
    CLCTL_STARTING_PHASE1 = 0x2 << 0 | 1 << 20 | 0 + 13 << 2 | 0x1 << 22,CLCTL_STARTING_PHASE2 = 0x2 << 0 | 1 << 20 | 0 + 14 << 2 | 0x1 << 22,
    CLCTL_HOLD_IO = 0x2 << 0 | 1 << 20 | 0 + 15 << 2 | 0x1 << 22,CLCTL_RESUME_IO = 0x2 << 0 | 1 << 20 | 0 + 16 << 2 | 0x1 << 22,
    CLCTL_FORCE_QUORUM = 0x2 << 0 | 1 << 20 | 0 + 17 << 2 | 0x1 << 22,CLCTL_INITIALIZE = 0x2 << 0 | 1 << 20 | 0 + 18 << 2 | 0x1 << 22,
    CLCTL_STATE_CHANGE_REASON = 0x2 << 0 | 1 << 20 | 0 + 19 << 2 | 0x1 << 22
  } CLCTL_CODES;

  typedef enum CLUSCTL_RESOURCE_CODES {
    CLUSCTL_RESOURCE_UNKNOWN = CLUS_OBJECT_RESOURCE << 24 | CLCTL_UNKNOWN,
    CLUSCTL_RESOURCE_GET_CHARACTERISTICS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_CHARACTERISTICS,
    CLUSCTL_RESOURCE_GET_FLAGS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_FLAGS,
    CLUSCTL_RESOURCE_GET_CLASS_INFO = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_CLASS_INFO,
    CLUSCTL_RESOURCE_GET_REQUIRED_DEPENDENCIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_REQUIRED_DEPENDENCIES,
    CLUSCTL_RESOURCE_GET_NAME = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_NAME,CLUSCTL_RESOURCE_GET_ID = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_ID,
    CLUSCTL_RESOURCE_GET_RESOURCE_TYPE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_RESOURCE_TYPE,
    CLUSCTL_RESOURCE_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_GET_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_SET_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_RESOURCE_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS,
    CLUSCTL_RESOURCE_ADD_REGISTRY_CHECKPOINT = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ADD_REGISTRY_CHECKPOINT,
    CLUSCTL_RESOURCE_DELETE_REGISTRY_CHECKPOINT = CLUS_OBJECT_RESOURCE << 24 | CLCTL_DELETE_REGISTRY_CHECKPOINT,
    CLUSCTL_RESOURCE_GET_REGISTRY_CHECKPOINTS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_REGISTRY_CHECKPOINTS,
    CLUSCTL_RESOURCE_ADD_CRYPTO_CHECKPOINT = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ADD_CRYPTO_CHECKPOINT,
    CLUSCTL_RESOURCE_DELETE_CRYPTO_CHECKPOINT = CLUS_OBJECT_RESOURCE << 24 | CLCTL_DELETE_CRYPTO_CHECKPOINT,
    CLUSCTL_RESOURCE_GET_CRYPTO_CHECKPOINTS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_CRYPTO_CHECKPOINTS,
    CLUSCTL_RESOURCE_GET_LOADBAL_PROCESS_LIST = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_LOADBAL_PROCESS_LIST,
    CLUSCTL_RESOURCE_GET_NETWORK_NAME = CLUS_OBJECT_RESOURCE << 24 | CLCTL_GET_NETWORK_NAME,
    CLUSCTL_RESOURCE_NETNAME_GET_VIRTUAL_SERVER_TOKEN = CLUS_OBJECT_RESOURCE << 24 | CLCTL_NETNAME_GET_VIRTUAL_SERVER_TOKEN,
    CLUSCTL_RESOURCE_NETNAME_REGISTER_DNS_RECORDS = CLUS_OBJECT_RESOURCE << 24 | CLCTL_NETNAME_REGISTER_DNS_RECORDS,
    CLUSCTL_RESOURCE_STORAGE_GET_DISK_INFO = CLUS_OBJECT_RESOURCE << 24 | CLCTL_STORAGE_GET_DISK_INFO,
    CLUSCTL_RESOURCE_STORAGE_IS_PATH_VALID = CLUS_OBJECT_RESOURCE << 24 | CLCTL_STORAGE_IS_PATH_VALID,
    CLUSCTL_RESOURCE_QUERY_DELETE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_QUERY_DELETE,
    CLUSCTL_RESOURCE_UPGRADE_DLL = CLUS_OBJECT_RESOURCE << 24 | CLCTL_RESOURCE_UPGRADE_DLL,
    CLUSCTL_RESOURCE_ADD_REGISTRY_CHECKPOINT_64BIT = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ADD_REGISTRY_CHECKPOINT_64BIT,
    CLUSCTL_RESOURCE_ADD_REGISTRY_CHECKPOINT_32BIT = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ADD_REGISTRY_CHECKPOINT_32BIT,
    CLUSCTL_RESOURCE_QUERY_MAINTENANCE_MODE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_QUERY_MAINTENANCE_MODE,
    CLUSCTL_RESOURCE_SET_MAINTENANCE_MODE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_SET_MAINTENANCE_MODE,
    CLUSCTL_RESOURCE_DELETE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_DELETE,CLUSCTL_RESOURCE_INSTALL_NODE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_INSTALL_NODE,
    CLUSCTL_RESOURCE_EVICT_NODE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_EVICT_NODE,
    CLUSCTL_RESOURCE_ADD_DEPENDENCY = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ADD_DEPENDENCY,
    CLUSCTL_RESOURCE_REMOVE_DEPENDENCY = CLUS_OBJECT_RESOURCE << 24 | CLCTL_REMOVE_DEPENDENCY,
    CLUSCTL_RESOURCE_ADD_OWNER = CLUS_OBJECT_RESOURCE << 24 | CLCTL_ADD_OWNER,
    CLUSCTL_RESOURCE_REMOVE_OWNER = CLUS_OBJECT_RESOURCE << 24 | CLCTL_REMOVE_OWNER,
    CLUSCTL_RESOURCE_SET_NAME = CLUS_OBJECT_RESOURCE << 24 | CLCTL_SET_NAME,
    CLUSCTL_RESOURCE_CLUSTER_NAME_CHANGED = CLUS_OBJECT_RESOURCE << 24 | CLCTL_CLUSTER_NAME_CHANGED,
    CLUSCTL_RESOURCE_CLUSTER_VERSION_CHANGED = CLUS_OBJECT_RESOURCE << 24 | CLCTL_CLUSTER_VERSION_CHANGED,
    CLUSCTL_RESOURCE_FORCE_QUORUM = CLUS_OBJECT_RESOURCE << 24 | CLCTL_FORCE_QUORUM,
    CLUSCTL_RESOURCE_INITIALIZE = CLUS_OBJECT_RESOURCE << 24 | CLCTL_INITIALIZE,
    CLUSCTL_RESOURCE_STATE_CHANGE_REASON = CLUS_OBJECT_RESOURCE << 24 | CLCTL_STATE_CHANGE_REASON
  } CLUSCTL_RESOURCE_CODES;

  typedef enum CLUSCTL_RESOURCE_TYPE_CODES {
    CLUSCTL_RESOURCE_TYPE_UNKNOWN = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_UNKNOWN,
    CLUSCTL_RESOURCE_TYPE_GET_CHARACTERISTICS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_CHARACTERISTICS,
    CLUSCTL_RESOURCE_TYPE_GET_FLAGS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_FLAGS,
    CLUSCTL_RESOURCE_TYPE_GET_CLASS_INFO = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_CLASS_INFO,
    CLUSCTL_RESOURCE_TYPE_GET_REQUIRED_DEPENDENCIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_REQUIRED_DEPENDENCIES,
    CLUSCTL_RESOURCE_TYPE_GET_ARB_TIMEOUT = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_ARB_TIMEOUT,
    CLUSCTL_RESOURCE_TYPE_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_GET_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_SET_COMMON_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_RESOURCE_TYPE_GET_COMMON_RESOURCE_PROPERTY_FMTS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_COMMON_RESOURCE_PROPERTY_FMTS,
    CLUSCTL_RESOURCE_TYPE_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_RESOURCE_TYPE_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS,
    CLUSCTL_RESOURCE_TYPE_GET_PRIVATE_RESOURCE_PROPERTY_FMTS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_PRIVATE_RESOURCE_PROPERTY_FMTS,
    CLUSCTL_RESOURCE_TYPE_GET_REGISTRY_CHECKPOINTS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_REGISTRY_CHECKPOINTS,
    CLUSCTL_RESOURCE_TYPE_GET_CRYPTO_CHECKPOINTS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_GET_CRYPTO_CHECKPOINTS,
    CLUSCTL_RESOURCE_TYPE_STORAGE_GET_AVAILABLE_DISKS = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_STORAGE_GET_AVAILABLE_DISKS,
    CLUSCTL_RESOURCE_TYPE_QUERY_DELETE = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_QUERY_DELETE,
    CLUSCTL_RESOURCE_TYPE_INSTALL_NODE = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_INSTALL_NODE,
    CLUSCTL_RESOURCE_TYPE_EVICT_NODE = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_EVICT_NODE,
    CLUSCTL_RESOURCE_TYPE_CLUSTER_VERSION_CHANGED = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_CLUSTER_VERSION_CHANGED,
    CLUSCTL_RESOURCE_TYPE_FIXUP_ON_UPGRADE = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_FIXUP_ON_UPGRADE,
    CLUSCTL_RESOURCE_TYPE_STARTING_PHASE1 = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_STARTING_PHASE1,
    CLUSCTL_RESOURCE_TYPE_STARTING_PHASE2 = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_STARTING_PHASE2,
    CLUSCTL_RESOURCE_TYPE_HOLD_IO = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_HOLD_IO,
    CLUSCTL_RESOURCE_TYPE_RESUME_IO = CLUS_OBJECT_RESOURCE_TYPE << 24 | CLCTL_RESUME_IO
  } CLUSCTL_RESOURCE_TYPE_CODES;

  typedef enum CLUSCTL_GROUP_CODES {
    CLUSCTL_GROUP_UNKNOWN = CLUS_OBJECT_GROUP << 24 | CLCTL_UNKNOWN,
    CLUSCTL_GROUP_GET_CHARACTERISTICS = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_CHARACTERISTICS,
    CLUSCTL_GROUP_GET_FLAGS = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_FLAGS,
    CLUSCTL_GROUP_GET_NAME = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_NAME,
    CLUSCTL_GROUP_GET_ID = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_ID,
    CLUSCTL_GROUP_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_GROUP_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_GROUP_GET_COMMON_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_GROUP_SET_COMMON_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_GROUP_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_GROUP_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_GROUP_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_GROUP_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_GROUP_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_GROUP_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_GROUP << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_GROUP_QUERY_DELETE = CLUS_OBJECT_GROUP << 24 | CLCTL_QUERY_DELETE,
    CLUSCTL_GROUP_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_GROUP_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_GROUP << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS
  } CLUSCTL_GROUP_CODES;

  typedef enum CLUSCTL_NODE_CODES {
    CLUSCTL_NODE_UNKNOWN = CLUS_OBJECT_NODE << 24 | CLCTL_UNKNOWN,CLUSCTL_NODE_GET_CHARACTERISTICS = CLUS_OBJECT_NODE << 24 | CLCTL_GET_CHARACTERISTICS,
    CLUSCTL_NODE_GET_FLAGS = CLUS_OBJECT_NODE << 24 | CLCTL_GET_FLAGS,CLUSCTL_NODE_GET_NAME = CLUS_OBJECT_NODE << 24 | CLCTL_GET_NAME,
    CLUSCTL_NODE_GET_ID = CLUS_OBJECT_NODE << 24 | CLCTL_GET_ID,
    CLUSCTL_NODE_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_NODE_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_NODE_GET_COMMON_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_NODE_SET_COMMON_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_NODE_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_NODE_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_NODE_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_NODE_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_NODE_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_NODE_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_NODE << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_NODE_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_NODE << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_NODE_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_NODE << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS,
    CLUSCTL_NODE_GET_CLUSTER_SERVICE_ACCOUNT_NAME = CLUS_OBJECT_NODE << 24 | CLCTL_GET_CLUSTER_SERVICE_ACCOUNT_NAME
  } CLUSCTL_NODE_CODES;

  typedef enum CLUSCTL_NETWORK_CODES {
    CLUSCTL_NETWORK_UNKNOWN = CLUS_OBJECT_NETWORK << 24 | CLCTL_UNKNOWN,
    CLUSCTL_NETWORK_GET_CHARACTERISTICS = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_CHARACTERISTICS,
    CLUSCTL_NETWORK_GET_FLAGS = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_FLAGS,
    CLUSCTL_NETWORK_GET_NAME = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_NAME,CLUSCTL_NETWORK_GET_ID = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_ID,
    CLUSCTL_NETWORK_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_NETWORK_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_NETWORK_GET_COMMON_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_NETWORK_SET_COMMON_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_NETWORK_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_NETWORK_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_NETWORK_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_NETWORK_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_NETWORK_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_NETWORK_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_NETWORK << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_NETWORK_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_NETWORK_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_NETWORK << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS
  } CLUSCTL_NETWORK_CODES;

  typedef enum CLUSCTL_NETINTERFACE_CODES {
    CLUSCTL_NETINTERFACE_UNKNOWN = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_UNKNOWN,
    CLUSCTL_NETINTERFACE_GET_CHARACTERISTICS = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_CHARACTERISTICS,
    CLUSCTL_NETINTERFACE_GET_FLAGS = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_FLAGS,
    CLUSCTL_NETINTERFACE_GET_NAME = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_NAME,
    CLUSCTL_NETINTERFACE_GET_ID = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_ID,
    CLUSCTL_NETINTERFACE_GET_NODE = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_NODE,
    CLUSCTL_NETINTERFACE_GET_NETWORK = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_NETWORK,
    CLUSCTL_NETINTERFACE_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_NETINTERFACE_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_NETINTERFACE_GET_COMMON_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_NETINTERFACE_SET_COMMON_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_NETINTERFACE_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_NETINTERFACE_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_NETINTERFACE_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_NETINTERFACE_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_NETINTERFACE_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_NETINTERFACE_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_NETINTERFACE_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_NETINTERFACE_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_NETINTERFACE << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS
  } CLUSCTL_NETINTERFACE_CODES;

  typedef enum CLUSCTL_CLUSTER_CODES {
    CLUSCTL_CLUSTER_UNKNOWN = CLUS_OBJECT_CLUSTER << 24 | CLCTL_UNKNOWN,
    CLUSCTL_CLUSTER_GET_FQDN = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_FQDN,
    CLUSCTL_CLUSTER_ENUM_COMMON_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_ENUM_COMMON_PROPERTIES,
    CLUSCTL_CLUSTER_GET_RO_COMMON_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_RO_COMMON_PROPERTIES,
    CLUSCTL_CLUSTER_GET_COMMON_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_COMMON_PROPERTIES,
    CLUSCTL_CLUSTER_SET_COMMON_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_SET_COMMON_PROPERTIES,
    CLUSCTL_CLUSTER_VALIDATE_COMMON_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_VALIDATE_COMMON_PROPERTIES,
    CLUSCTL_CLUSTER_ENUM_PRIVATE_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_ENUM_PRIVATE_PROPERTIES,
    CLUSCTL_CLUSTER_GET_RO_PRIVATE_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_RO_PRIVATE_PROPERTIES,
    CLUSCTL_CLUSTER_GET_PRIVATE_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_PRIVATE_PROPERTIES,
    CLUSCTL_CLUSTER_SET_PRIVATE_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_SET_PRIVATE_PROPERTIES,
    CLUSCTL_CLUSTER_VALIDATE_PRIVATE_PROPERTIES = CLUS_OBJECT_CLUSTER << 24 | CLCTL_VALIDATE_PRIVATE_PROPERTIES,
    CLUSCTL_CLUSTER_GET_COMMON_PROPERTY_FMTS = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_COMMON_PROPERTY_FMTS,
    CLUSCTL_CLUSTER_GET_PRIVATE_PROPERTY_FMTS = CLUS_OBJECT_CLUSTER << 24 | CLCTL_GET_PRIVATE_PROPERTY_FMTS
  } CLUSCTL_CLUSTER_CODES;

  typedef enum CLUSTER_RESOURCE_CLASS {
    CLUS_RESCLASS_UNKNOWN = 0,CLUS_RESCLASS_STORAGE,
    CLUS_RESCLASS_USER = 32768
  } CLUSTER_RESOURCE_CLASS;

  typedef enum CLUS_RESSUBCLASS {
    CLUS_RESSUBCLASS_SHARED = 0x80000000
  } CLUS_RESSUBCLASS;

  typedef enum CLUS_CHARACTERISTICS {
    CLUS_CHAR_UNKNOWN = 0,CLUS_CHAR_QUORUM = 0x1,CLUS_CHAR_DELETE_REQUIRES_ALL_NODES = 0x2,CLUS_CHAR_LOCAL_QUORUM = 0x4,
    CLUS_CHAR_LOCAL_QUORUM_DEBUG = 0x8,CLUS_CHAR_REQUIRES_STATE_CHANGE_REASON = 0x10
  } CLUS_CHARACTERISTICS;

  typedef enum CLUS_FLAGS {
    CLUS_FLAG_CORE = 0x1
  } CLUS_FLAGS;

  typedef enum CLUSPROP_PIFLAGS {
    CLUSPROP_PIFLAG_STICKY = 0x1,CLUSPROP_PIFLAG_REMOVABLE = 0x2,CLUSPROP_PIFLAG_USABLE = 0x4,CLUSPROP_PIFLAG_DEFAULT_QUORUM = 0x8
  } CLUSPROP_PIFLAGS;

  typedef enum CLUSTER_RESOURCE_ENUM {
    CLUSTER_RESOURCE_ENUM_DEPENDS = 0x1,CLUSTER_RESOURCE_ENUM_PROVIDES = 0x2,CLUSTER_RESOURCE_ENUM_NODES = 0x4,
    CLUSTER_RESOURCE_ENUM_ALL = CLUSTER_RESOURCE_ENUM_DEPENDS | CLUSTER_RESOURCE_ENUM_PROVIDES | CLUSTER_RESOURCE_ENUM_NODES
  } CLUSTER_RESOURCE_ENUM;

  typedef enum CLUSTER_RESOURCE_TYPE_ENUM {
    CLUSTER_RESOURCE_TYPE_ENUM_NODES = 0x1,CLUSTER_RESOURCE_TYPE_ENUM_ALL = CLUSTER_RESOURCE_TYPE_ENUM_NODES
  } CLUSTER_RESOURCE_TYPE_ENUM;

  typedef enum CLUSTER_NETWORK_ENUM {
    CLUSTER_NETWORK_ENUM_NETINTERFACES = 0x1,CLUSTER_NETWORK_ENUM_ALL = CLUSTER_NETWORK_ENUM_NETINTERFACES
  } CLUSTER_NETWORK_ENUM;

  typedef enum CLUSTER_NETWORK_STATE {
    ClusterNetworkStateUnknown = -1,
    ClusterNetworkUnavailable = 0,ClusterNetworkDown,ClusterNetworkPartitioned,ClusterNetworkUp
  } CLUSTER_NETWORK_STATE;

  typedef enum CLUSTER_NETWORK_ROLE {
    ClusterNetworkRoleNone = 0,ClusterNetworkRoleInternalUse = 0x1,ClusterNetworkRoleClientAccess = 0x2,ClusterNetworkRoleInternalAndClient = 0x3
  } CLUSTER_NETWORK_ROLE;

  typedef enum CLUSTER_NETINTERFACE_STATE {
    ClusterNetInterfaceStateUnknown = -1,
    ClusterNetInterfaceUnavailable = 0,ClusterNetInterfaceFailed,ClusterNetInterfaceUnreachable,
    ClusterNetInterfaceUp
  } CLUSTER_NETINTERFACE_STATE;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_msclus_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msclus_0000_v0_0_s_ifspec;

#ifndef __MSClusterLib_LIBRARY_DEFINED__
#define __MSClusterLib_LIBRARY_DEFINED__
  typedef CLUSTER_QUORUM_TYPE _CLUSTER_QUORUM_TYPE;
  typedef NODE_CLUSTER_STATE _NODE_CLUSTER_STATE;
  typedef CLUSTER_RESOURCE_STATE_CHANGE_REASON _CLUSTER_RESOURCE_STATE_CHANGE_REASON;
  typedef CLUSTER_SET_PASSWORD_FLAGS _CLUSTER_SET_PASSWORD_FLAGS;
  typedef CLUSTER_CHANGE _CLUSTER_CHANGE;
  typedef CLUSTER_ENUM _CLUSTER_ENUM;
  typedef CLUSTER_NODE_ENUM _CLUSTER_NODE_ENUM;
  typedef CLUSTER_NODE_STATE _CLUSTER_NODE_STATE;
  typedef CLUSTER_GROUP_ENUM _CLUSTER_GROUP_ENUM;
  typedef CLUSTER_GROUP_STATE _CLUSTER_GROUP_STATE;
  typedef CLUSTER_GROUP_AUTOFAILBACK_TYPE _CLUSTER_GROUP_AUTOFAILBACK_TYPE;
  typedef CLUSTER_RESOURCE_STATE _CLUSTER_RESOURCE_STATE;
  typedef CLUSTER_RESOURCE_RESTART_ACTION _CLUSTER_RESOURCE_RESTART_ACTION;
  typedef CLUSTER_RESOURCE_CREATE_FLAGS _CLUSTER_RESOURCE_CREATE_FLAGS;
  typedef CLUSTER_PROPERTY_TYPE _CLUSTER_PROPERTY_TYPE;
  typedef CLUSTER_PROPERTY_FORMAT _CLUSTER_PROPERTY_FORMAT;
  typedef CLUSTER_PROPERTY_SYNTAX _CLUSTER_PROPERTY_SYNTAX;
  typedef CLUSTER_CONTROL_OBJECT _CLUSTER_CONTROL_OBJECT;
  typedef CLCTL_CODES _CLCTL_CODES;
  typedef CLUSCTL_RESOURCE_CODES _CLUSCTL_RESOURCE_CODES;
  typedef CLUSCTL_RESOURCE_TYPE_CODES _CLUSCTL_RESOURCE_TYPE_CODES;
  typedef CLUSCTL_GROUP_CODES _CLUSCTL_GROUP_CODES;
  typedef CLUSCTL_NODE_CODES _CLUSCTL_NODE_CODES;
  typedef CLUSCTL_NETWORK_CODES _CLUSCTL_NETWORK_CODES;
  typedef CLUSCTL_NETINTERFACE_CODES _CLUSCTL_NETINTERFACE_CODES;
  typedef CLUSCTL_CLUSTER_CODES _CLUSCTL_CLUSTER_CODES;
  typedef CLUSTER_RESOURCE_CLASS _CLUSTER_RESOURCE_CLASS;
  typedef CLUS_RESSUBCLASS _CLUS_RESSUBCLASS;
  typedef CLUS_CHARACTERISTICS _CLUS_CHARACTERISTICS;
  typedef CLUS_FLAGS _CLUS_FLAGS;
  typedef CLUSPROP_PIFLAGS _CLUSPROP_PIFLAGS;
  typedef CLUSTER_RESOURCE_ENUM _CLUSTER_RESOURCE_ENUM;
  typedef CLUSTER_RESOURCE_TYPE_ENUM _CLUSTER_RESOURCE_TYPE_ENUM;
  typedef CLUSTER_NETWORK_ENUM _CLUSTER_NETWORK_ENUM;
  typedef CLUSTER_NETWORK_STATE _CLUSTER_NETWORK_STATE;
  typedef CLUSTER_NETWORK_ROLE _CLUSTER_NETWORK_ROLE;
  typedef CLUSTER_NETINTERFACE_STATE _CLUSTER_NETINTERFACE_STATE;

  EXTERN_C const IID LIBID_MSClusterLib;
  EXTERN_C const CLSID CLSID_ClusApplication;
#ifdef __cplusplus
  class ClusApplication;
#endif
  EXTERN_C const CLSID CLSID_Cluster;
#ifdef __cplusplus
  class Cluster;
#endif
  EXTERN_C const CLSID CLSID_ClusVersion;
#ifdef __cplusplus
  class ClusVersion;
#endif
  EXTERN_C const CLSID CLSID_ClusResType;
#ifdef __cplusplus
  class ClusResType;
#endif
  EXTERN_C const CLSID CLSID_ClusProperty;
#ifdef __cplusplus
  class ClusProperty;
#endif
  EXTERN_C const CLSID CLSID_ClusProperties;
#ifdef __cplusplus
  class ClusProperties;
#endif
  EXTERN_C const CLSID CLSID_DomainNames;
#ifdef __cplusplus
  class DomainNames;
#endif
  EXTERN_C const CLSID CLSID_ClusNetwork;
#ifdef __cplusplus
  class ClusNetwork;
#endif
  EXTERN_C const CLSID CLSID_ClusNetInterface;
#ifdef __cplusplus
  class ClusNetInterface;
#endif
  EXTERN_C const CLSID CLSID_ClusNetInterfaces;
#ifdef __cplusplus
  class ClusNetInterfaces;
#endif
  EXTERN_C const CLSID CLSID_ClusResDependencies;
#ifdef __cplusplus
  class ClusResDependencies;
#endif
  EXTERN_C const CLSID CLSID_ClusResGroupResources;
#ifdef __cplusplus
  class ClusResGroupResources;
#endif
  EXTERN_C const CLSID CLSID_ClusResTypeResources;
#ifdef __cplusplus
  class ClusResTypeResources;
#endif
  EXTERN_C const CLSID CLSID_ClusResGroupPreferredOwnerNodes;
#ifdef __cplusplus
  class ClusResGroupPreferredOwnerNodes;
#endif
  EXTERN_C const CLSID CLSID_ClusResPossibleOwnerNodes;
#ifdef __cplusplus
  class ClusResPossibleOwnerNodes;
#endif
  EXTERN_C const CLSID CLSID_ClusNetworks;
#ifdef __cplusplus
  class ClusNetworks;
#endif
  EXTERN_C const CLSID CLSID_ClusNetworkNetInterfaces;
#ifdef __cplusplus
  class ClusNetworkNetInterfaces;
#endif
  EXTERN_C const CLSID CLSID_ClusNodeNetInterfaces;
#ifdef __cplusplus
  class ClusNodeNetInterfaces;
#endif
  EXTERN_C const CLSID CLSID_ClusRefObject;
#ifdef __cplusplus
  class ClusRefObject;
#endif
  EXTERN_C const CLSID CLSID_ClusterNames;
#ifdef __cplusplus
  class ClusterNames;
#endif
  EXTERN_C const CLSID CLSID_ClusNode;
#ifdef __cplusplus
  class ClusNode;
#endif
  EXTERN_C const CLSID CLSID_ClusNodes;
#ifdef __cplusplus
  class ClusNodes;
#endif
  EXTERN_C const CLSID CLSID_ClusResGroup;
#ifdef __cplusplus
  class ClusResGroup;
#endif
  EXTERN_C const CLSID CLSID_ClusResGroups;
#ifdef __cplusplus
  class ClusResGroups;
#endif
  EXTERN_C const CLSID CLSID_ClusResource;
#ifdef __cplusplus
  class ClusResource;
#endif
  EXTERN_C const CLSID CLSID_ClusResources;
#ifdef __cplusplus
  class ClusResources;
#endif
  EXTERN_C const CLSID CLSID_ClusResTypes;
#ifdef __cplusplus
  class ClusResTypes;
#endif
  EXTERN_C const CLSID CLSID_ClusResTypePossibleOwnerNodes;
#ifdef __cplusplus
  class ClusResTypePossibleOwnerNodes;
#endif
  EXTERN_C const CLSID CLSID_ClusPropertyValue;
#ifdef __cplusplus
  class ClusPropertyValue;
#endif
  EXTERN_C const CLSID CLSID_ClusPropertyValues;
#ifdef __cplusplus
  class ClusPropertyValues;
#endif
  EXTERN_C const CLSID CLSID_ClusPropertyValueData;
#ifdef __cplusplus
  class ClusPropertyValueData;
#endif
  EXTERN_C const CLSID CLSID_ClusPartition;
#ifdef __cplusplus
  class ClusPartition;
#endif
  EXTERN_C const CLSID CLSID_ClusPartitions;
#ifdef __cplusplus
  class ClusPartitions;
#endif
  EXTERN_C const CLSID CLSID_ClusDisk;
#ifdef __cplusplus
  class ClusDisk;
#endif
  EXTERN_C const CLSID CLSID_ClusDisks;
#ifdef __cplusplus
  class ClusDisks;
#endif
  EXTERN_C const CLSID CLSID_ClusScsiAddress;
#ifdef __cplusplus
  class ClusScsiAddress;
#endif
  EXTERN_C const CLSID CLSID_ClusRegistryKeys;
#ifdef __cplusplus
  class ClusRegistryKeys;
#endif
  EXTERN_C const CLSID CLSID_ClusCryptoKeys;
#ifdef __cplusplus
  class ClusCryptoKeys;
#endif
  EXTERN_C const CLSID CLSID_ClusResDependents;
#ifdef __cplusplus
  class ClusResDependents;
#endif
#endif

#ifndef __ISClusApplication_INTERFACE_DEFINED__
#define __ISClusApplication_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusApplication;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusApplication : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DomainNames(ISDomainNames **ppDomains) = 0;
    virtual HRESULT WINAPI get_ClusterNames(BSTR bstrDomainName,ISClusterNames **ppClusters) = 0;
    virtual HRESULT WINAPI OpenCluster(BSTR bstrClusterName,ISCluster **pCluster) = 0;
  };
#else
  typedef struct ISClusApplicationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusApplication *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusApplication *This);
      ULONG (WINAPI *Release)(ISClusApplication *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusApplication *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusApplication *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusApplication *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusApplication *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DomainNames)(ISClusApplication *This,ISDomainNames **ppDomains);
      HRESULT (WINAPI *get_ClusterNames)(ISClusApplication *This,BSTR bstrDomainName,ISClusterNames **ppClusters);
      HRESULT (WINAPI *OpenCluster)(ISClusApplication *This,BSTR bstrClusterName,ISCluster **pCluster);
    END_INTERFACE
  } ISClusApplicationVtbl;
  struct ISClusApplication {
    CONST_VTBL struct ISClusApplicationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusApplication_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusApplication_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusApplication_Release(This) (This)->lpVtbl->Release(This)
#define ISClusApplication_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusApplication_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusApplication_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusApplication_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusApplication_get_DomainNames(This,ppDomains) (This)->lpVtbl->get_DomainNames(This,ppDomains)
#define ISClusApplication_get_ClusterNames(This,bstrDomainName,ppClusters) (This)->lpVtbl->get_ClusterNames(This,bstrDomainName,ppClusters)
#define ISClusApplication_OpenCluster(This,bstrClusterName,pCluster) (This)->lpVtbl->OpenCluster(This,bstrClusterName,pCluster)
#endif
#endif
  HRESULT WINAPI ISClusApplication_get_DomainNames_Proxy(ISClusApplication *This,ISDomainNames **ppDomains);
  void __RPC_STUB ISClusApplication_get_DomainNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusApplication_get_ClusterNames_Proxy(ISClusApplication *This,BSTR bstrDomainName,ISClusterNames **ppClusters);
  void __RPC_STUB ISClusApplication_get_ClusterNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusApplication_OpenCluster_Proxy(ISClusApplication *This,BSTR bstrClusterName,ISCluster **pCluster);
  void __RPC_STUB ISClusApplication_OpenCluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISDomainNames_INTERFACE_DEFINED__
#define __ISDomainNames_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISDomainNames;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISDomainNames : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,BSTR *pbstrDomainName) = 0;
  };
#else
  typedef struct ISDomainNamesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISDomainNames *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISDomainNames *This);
      ULONG (WINAPI *Release)(ISDomainNames *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISDomainNames *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISDomainNames *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISDomainNames *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISDomainNames *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISDomainNames *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISDomainNames *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISDomainNames *This);
      HRESULT (WINAPI *get_Item)(ISDomainNames *This,VARIANT varIndex,BSTR *pbstrDomainName);
    END_INTERFACE
  } ISDomainNamesVtbl;
  struct ISDomainNames {
    CONST_VTBL struct ISDomainNamesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISDomainNames_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISDomainNames_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISDomainNames_Release(This) (This)->lpVtbl->Release(This)
#define ISDomainNames_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISDomainNames_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISDomainNames_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISDomainNames_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISDomainNames_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISDomainNames_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISDomainNames_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISDomainNames_get_Item(This,varIndex,pbstrDomainName) (This)->lpVtbl->get_Item(This,varIndex,pbstrDomainName)
#endif
#endif
  HRESULT WINAPI ISDomainNames_get_Count_Proxy(ISDomainNames *This,__LONG32 *plCount);
  void __RPC_STUB ISDomainNames_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISDomainNames_get__NewEnum_Proxy(ISDomainNames *This,IUnknown **retval);
  void __RPC_STUB ISDomainNames_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISDomainNames_Refresh_Proxy(ISDomainNames *This);
  void __RPC_STUB ISDomainNames_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISDomainNames_get_Item_Proxy(ISDomainNames *This,VARIANT varIndex,BSTR *pbstrDomainName);
  void __RPC_STUB ISDomainNames_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusterNames_INTERFACE_DEFINED__
#define __ISClusterNames_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusterNames;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusterNames : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,BSTR *pbstrClusterName) = 0;
    virtual HRESULT WINAPI get_DomainName(BSTR *pbstrDomainName) = 0;
  };
#else
  typedef struct ISClusterNamesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusterNames *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusterNames *This);
      ULONG (WINAPI *Release)(ISClusterNames *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusterNames *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusterNames *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusterNames *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusterNames *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusterNames *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusterNames *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusterNames *This);
      HRESULT (WINAPI *get_Item)(ISClusterNames *This,VARIANT varIndex,BSTR *pbstrClusterName);
      HRESULT (WINAPI *get_DomainName)(ISClusterNames *This,BSTR *pbstrDomainName);
    END_INTERFACE
  } ISClusterNamesVtbl;
  struct ISClusterNames {
    CONST_VTBL struct ISClusterNamesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusterNames_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusterNames_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusterNames_Release(This) (This)->lpVtbl->Release(This)
#define ISClusterNames_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusterNames_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusterNames_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusterNames_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusterNames_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusterNames_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusterNames_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusterNames_get_Item(This,varIndex,pbstrClusterName) (This)->lpVtbl->get_Item(This,varIndex,pbstrClusterName)
#define ISClusterNames_get_DomainName(This,pbstrDomainName) (This)->lpVtbl->get_DomainName(This,pbstrDomainName)
#endif
#endif
  HRESULT WINAPI ISClusterNames_get_Count_Proxy(ISClusterNames *This,__LONG32 *plCount);
  void __RPC_STUB ISClusterNames_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusterNames_get__NewEnum_Proxy(ISClusterNames *This,IUnknown **retval);
  void __RPC_STUB ISClusterNames_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusterNames_Refresh_Proxy(ISClusterNames *This);
  void __RPC_STUB ISClusterNames_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusterNames_get_Item_Proxy(ISClusterNames *This,VARIANT varIndex,BSTR *pbstrClusterName);
  void __RPC_STUB ISClusterNames_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusterNames_get_DomainName_Proxy(ISClusterNames *This,BSTR *pbstrDomainName);
  void __RPC_STUB ISClusterNames_get_DomainName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusRefObject_INTERFACE_DEFINED__
#define __ISClusRefObject_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusRefObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusRefObject : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
  };
#else
  typedef struct ISClusRefObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusRefObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusRefObject *This);
      ULONG (WINAPI *Release)(ISClusRefObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusRefObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusRefObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusRefObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusRefObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Handle)(ISClusRefObject *This,ULONG_PTR *phandle);
    END_INTERFACE
  } ISClusRefObjectVtbl;
  struct ISClusRefObject {
    CONST_VTBL struct ISClusRefObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusRefObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusRefObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusRefObject_Release(This) (This)->lpVtbl->Release(This)
#define ISClusRefObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusRefObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusRefObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusRefObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusRefObject_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#endif
#endif
  HRESULT WINAPI ISClusRefObject_get_Handle_Proxy(ISClusRefObject *This,ULONG_PTR *phandle);
  void __RPC_STUB ISClusRefObject_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusVersion_INTERFACE_DEFINED__
#define __ISClusVersion_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusVersion;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusVersion : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pbstrClusterName) = 0;
    virtual HRESULT WINAPI get_MajorVersion(__LONG32 *pnMajorVersion) = 0;
    virtual HRESULT WINAPI get_MinorVersion(__LONG32 *pnMinorVersion) = 0;
    virtual HRESULT WINAPI get_BuildNumber(SHORT *pnBuildNumber) = 0;
    virtual HRESULT WINAPI get_VendorId(BSTR *pbstrVendorId) = 0;
    virtual HRESULT WINAPI get_CSDVersion(BSTR *pbstrCSDVersion) = 0;
    virtual HRESULT WINAPI get_ClusterHighestVersion(__LONG32 *pnClusterHighestVersion) = 0;
    virtual HRESULT WINAPI get_ClusterLowestVersion(__LONG32 *pnClusterLowestVersion) = 0;
    virtual HRESULT WINAPI get_Flags(__LONG32 *pnFlags) = 0;
    virtual HRESULT WINAPI get_MixedVersion(VARIANT *pvarMixedVersion) = 0;
  };
#else
  typedef struct ISClusVersionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusVersion *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusVersion *This);
      ULONG (WINAPI *Release)(ISClusVersion *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusVersion *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusVersion *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusVersion *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusVersion *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ISClusVersion *This,BSTR *pbstrClusterName);
      HRESULT (WINAPI *get_MajorVersion)(ISClusVersion *This,__LONG32 *pnMajorVersion);
      HRESULT (WINAPI *get_MinorVersion)(ISClusVersion *This,__LONG32 *pnMinorVersion);
      HRESULT (WINAPI *get_BuildNumber)(ISClusVersion *This,SHORT *pnBuildNumber);
      HRESULT (WINAPI *get_VendorId)(ISClusVersion *This,BSTR *pbstrVendorId);
      HRESULT (WINAPI *get_CSDVersion)(ISClusVersion *This,BSTR *pbstrCSDVersion);
      HRESULT (WINAPI *get_ClusterHighestVersion)(ISClusVersion *This,__LONG32 *pnClusterHighestVersion);
      HRESULT (WINAPI *get_ClusterLowestVersion)(ISClusVersion *This,__LONG32 *pnClusterLowestVersion);
      HRESULT (WINAPI *get_Flags)(ISClusVersion *This,__LONG32 *pnFlags);
      HRESULT (WINAPI *get_MixedVersion)(ISClusVersion *This,VARIANT *pvarMixedVersion);
    END_INTERFACE
  } ISClusVersionVtbl;
  struct ISClusVersion {
    CONST_VTBL struct ISClusVersionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusVersion_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusVersion_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusVersion_Release(This) (This)->lpVtbl->Release(This)
#define ISClusVersion_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusVersion_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusVersion_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusVersion_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusVersion_get_Name(This,pbstrClusterName) (This)->lpVtbl->get_Name(This,pbstrClusterName)
#define ISClusVersion_get_MajorVersion(This,pnMajorVersion) (This)->lpVtbl->get_MajorVersion(This,pnMajorVersion)
#define ISClusVersion_get_MinorVersion(This,pnMinorVersion) (This)->lpVtbl->get_MinorVersion(This,pnMinorVersion)
#define ISClusVersion_get_BuildNumber(This,pnBuildNumber) (This)->lpVtbl->get_BuildNumber(This,pnBuildNumber)
#define ISClusVersion_get_VendorId(This,pbstrVendorId) (This)->lpVtbl->get_VendorId(This,pbstrVendorId)
#define ISClusVersion_get_CSDVersion(This,pbstrCSDVersion) (This)->lpVtbl->get_CSDVersion(This,pbstrCSDVersion)
#define ISClusVersion_get_ClusterHighestVersion(This,pnClusterHighestVersion) (This)->lpVtbl->get_ClusterHighestVersion(This,pnClusterHighestVersion)
#define ISClusVersion_get_ClusterLowestVersion(This,pnClusterLowestVersion) (This)->lpVtbl->get_ClusterLowestVersion(This,pnClusterLowestVersion)
#define ISClusVersion_get_Flags(This,pnFlags) (This)->lpVtbl->get_Flags(This,pnFlags)
#define ISClusVersion_get_MixedVersion(This,pvarMixedVersion) (This)->lpVtbl->get_MixedVersion(This,pvarMixedVersion)
#endif
#endif
  HRESULT WINAPI ISClusVersion_get_Name_Proxy(ISClusVersion *This,BSTR *pbstrClusterName);
  void __RPC_STUB ISClusVersion_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_MajorVersion_Proxy(ISClusVersion *This,__LONG32 *pnMajorVersion);
  void __RPC_STUB ISClusVersion_get_MajorVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_MinorVersion_Proxy(ISClusVersion *This,__LONG32 *pnMinorVersion);
  void __RPC_STUB ISClusVersion_get_MinorVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_BuildNumber_Proxy(ISClusVersion *This,SHORT *pnBuildNumber);
  void __RPC_STUB ISClusVersion_get_BuildNumber_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_VendorId_Proxy(ISClusVersion *This,BSTR *pbstrVendorId);
  void __RPC_STUB ISClusVersion_get_VendorId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_CSDVersion_Proxy(ISClusVersion *This,BSTR *pbstrCSDVersion);
  void __RPC_STUB ISClusVersion_get_CSDVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_ClusterHighestVersion_Proxy(ISClusVersion *This,__LONG32 *pnClusterHighestVersion);
  void __RPC_STUB ISClusVersion_get_ClusterHighestVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_ClusterLowestVersion_Proxy(ISClusVersion *This,__LONG32 *pnClusterLowestVersion);
  void __RPC_STUB ISClusVersion_get_ClusterLowestVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_Flags_Proxy(ISClusVersion *This,__LONG32 *pnFlags);
  void __RPC_STUB ISClusVersion_get_Flags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusVersion_get_MixedVersion_Proxy(ISClusVersion *This,VARIANT *pvarMixedVersion);
  void __RPC_STUB ISClusVersion_get_MixedVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISCluster_INTERFACE_DEFINED__
#define __ISCluster_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISCluster;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCluster : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
    virtual HRESULT WINAPI Open(BSTR bstrClusterName) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrClusterName) = 0;
    virtual HRESULT WINAPI get_Version(ISClusVersion **ppClusVersion) = 0;
    virtual HRESULT WINAPI put_QuorumResource(ISClusResource *pClusterResource) = 0;
    virtual HRESULT WINAPI get_QuorumResource(ISClusResource **pClusterResource) = 0;
    virtual HRESULT WINAPI get_QuorumLogSize(__LONG32 *pnLogSize) = 0;
    virtual HRESULT WINAPI put_QuorumLogSize(__LONG32 nLogSize) = 0;
    virtual HRESULT WINAPI get_QuorumPath(BSTR *ppPath) = 0;
    virtual HRESULT WINAPI put_QuorumPath(BSTR pPath) = 0;
    virtual HRESULT WINAPI get_Nodes(ISClusNodes **ppNodes) = 0;
    virtual HRESULT WINAPI get_ResourceGroups(ISClusResGroups **ppClusterResourceGroups) = 0;
    virtual HRESULT WINAPI get_Resources(ISClusResources **ppClusterResources) = 0;
    virtual HRESULT WINAPI get_ResourceTypes(ISClusResTypes **ppResourceTypes) = 0;
    virtual HRESULT WINAPI get_Networks(ISClusNetworks **ppNetworks) = 0;
    virtual HRESULT WINAPI get_NetInterfaces(ISClusNetInterfaces **ppNetInterfaces) = 0;
  };
#else
  typedef struct ISClusterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCluster *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCluster *This);
      ULONG (WINAPI *Release)(ISCluster *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCluster *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCluster *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCluster *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCluster *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISCluster *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISCluster *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISCluster *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISCluster *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Handle)(ISCluster *This,ULONG_PTR *phandle);
      HRESULT (WINAPI *Open)(ISCluster *This,BSTR bstrClusterName);
      HRESULT (WINAPI *get_Name)(ISCluster *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(ISCluster *This,BSTR bstrClusterName);
      HRESULT (WINAPI *get_Version)(ISCluster *This,ISClusVersion **ppClusVersion);
      HRESULT (WINAPI *put_QuorumResource)(ISCluster *This,ISClusResource *pClusterResource);
      HRESULT (WINAPI *get_QuorumResource)(ISCluster *This,ISClusResource **pClusterResource);
      HRESULT (WINAPI *get_QuorumLogSize)(ISCluster *This,__LONG32 *pnLogSize);
      HRESULT (WINAPI *put_QuorumLogSize)(ISCluster *This,__LONG32 nLogSize);
      HRESULT (WINAPI *get_QuorumPath)(ISCluster *This,BSTR *ppPath);
      HRESULT (WINAPI *put_QuorumPath)(ISCluster *This,BSTR pPath);
      HRESULT (WINAPI *get_Nodes)(ISCluster *This,ISClusNodes **ppNodes);
      HRESULT (WINAPI *get_ResourceGroups)(ISCluster *This,ISClusResGroups **ppClusterResourceGroups);
      HRESULT (WINAPI *get_Resources)(ISCluster *This,ISClusResources **ppClusterResources);
      HRESULT (WINAPI *get_ResourceTypes)(ISCluster *This,ISClusResTypes **ppResourceTypes);
      HRESULT (WINAPI *get_Networks)(ISCluster *This,ISClusNetworks **ppNetworks);
      HRESULT (WINAPI *get_NetInterfaces)(ISCluster *This,ISClusNetInterfaces **ppNetInterfaces);
    END_INTERFACE
  } ISClusterVtbl;
  struct ISCluster {
    CONST_VTBL struct ISClusterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCluster_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCluster_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCluster_Release(This) (This)->lpVtbl->Release(This)
#define ISCluster_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCluster_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCluster_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCluster_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCluster_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISCluster_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISCluster_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISCluster_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISCluster_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#define ISCluster_Open(This,bstrClusterName) (This)->lpVtbl->Open(This,bstrClusterName)
#define ISCluster_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISCluster_put_Name(This,bstrClusterName) (This)->lpVtbl->put_Name(This,bstrClusterName)
#define ISCluster_get_Version(This,ppClusVersion) (This)->lpVtbl->get_Version(This,ppClusVersion)
#define ISCluster_put_QuorumResource(This,pClusterResource) (This)->lpVtbl->put_QuorumResource(This,pClusterResource)
#define ISCluster_get_QuorumResource(This,pClusterResource) (This)->lpVtbl->get_QuorumResource(This,pClusterResource)
#define ISCluster_get_QuorumLogSize(This,pnLogSize) (This)->lpVtbl->get_QuorumLogSize(This,pnLogSize)
#define ISCluster_put_QuorumLogSize(This,nLogSize) (This)->lpVtbl->put_QuorumLogSize(This,nLogSize)
#define ISCluster_get_QuorumPath(This,ppPath) (This)->lpVtbl->get_QuorumPath(This,ppPath)
#define ISCluster_put_QuorumPath(This,pPath) (This)->lpVtbl->put_QuorumPath(This,pPath)
#define ISCluster_get_Nodes(This,ppNodes) (This)->lpVtbl->get_Nodes(This,ppNodes)
#define ISCluster_get_ResourceGroups(This,ppClusterResourceGroups) (This)->lpVtbl->get_ResourceGroups(This,ppClusterResourceGroups)
#define ISCluster_get_Resources(This,ppClusterResources) (This)->lpVtbl->get_Resources(This,ppClusterResources)
#define ISCluster_get_ResourceTypes(This,ppResourceTypes) (This)->lpVtbl->get_ResourceTypes(This,ppResourceTypes)
#define ISCluster_get_Networks(This,ppNetworks) (This)->lpVtbl->get_Networks(This,ppNetworks)
#define ISCluster_get_NetInterfaces(This,ppNetInterfaces) (This)->lpVtbl->get_NetInterfaces(This,ppNetInterfaces)
#endif
#endif
  HRESULT WINAPI ISCluster_get_CommonProperties_Proxy(ISCluster *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISCluster_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_PrivateProperties_Proxy(ISCluster *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISCluster_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_CommonROProperties_Proxy(ISCluster *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISCluster_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_PrivateROProperties_Proxy(ISCluster *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISCluster_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_Handle_Proxy(ISCluster *This,ULONG_PTR *phandle);
  void __RPC_STUB ISCluster_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_Open_Proxy(ISCluster *This,BSTR bstrClusterName);
  void __RPC_STUB ISCluster_Open_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_Name_Proxy(ISCluster *This,BSTR *pbstrName);
  void __RPC_STUB ISCluster_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_put_Name_Proxy(ISCluster *This,BSTR bstrClusterName);
  void __RPC_STUB ISCluster_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_Version_Proxy(ISCluster *This,ISClusVersion **ppClusVersion);
  void __RPC_STUB ISCluster_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_put_QuorumResource_Proxy(ISCluster *This,ISClusResource *pClusterResource);
  void __RPC_STUB ISCluster_put_QuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_QuorumResource_Proxy(ISCluster *This,ISClusResource **pClusterResource);
  void __RPC_STUB ISCluster_get_QuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_QuorumLogSize_Proxy(ISCluster *This,__LONG32 *pnLogSize);
  void __RPC_STUB ISCluster_get_QuorumLogSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_put_QuorumLogSize_Proxy(ISCluster *This,__LONG32 nLogSize);
  void __RPC_STUB ISCluster_put_QuorumLogSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_QuorumPath_Proxy(ISCluster *This,BSTR *ppPath);
  void __RPC_STUB ISCluster_get_QuorumPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_put_QuorumPath_Proxy(ISCluster *This,BSTR pPath);
  void __RPC_STUB ISCluster_put_QuorumPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_Nodes_Proxy(ISCluster *This,ISClusNodes **ppNodes);
  void __RPC_STUB ISCluster_get_Nodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_ResourceGroups_Proxy(ISCluster *This,ISClusResGroups **ppClusterResourceGroups);
  void __RPC_STUB ISCluster_get_ResourceGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_Resources_Proxy(ISCluster *This,ISClusResources **ppClusterResources);
  void __RPC_STUB ISCluster_get_Resources_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_ResourceTypes_Proxy(ISCluster *This,ISClusResTypes **ppResourceTypes);
  void __RPC_STUB ISCluster_get_ResourceTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_Networks_Proxy(ISCluster *This,ISClusNetworks **ppNetworks);
  void __RPC_STUB ISCluster_get_Networks_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCluster_get_NetInterfaces_Proxy(ISCluster *This,ISClusNetInterfaces **ppNetInterfaces);
  void __RPC_STUB ISCluster_get_NetInterfaces_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNode_INTERFACE_DEFINED__
#define __ISClusNode_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNode;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNode : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
    virtual HRESULT WINAPI get_NodeID(BSTR *pbstrNodeID) = 0;
    virtual HRESULT WINAPI get_State(CLUSTER_NODE_STATE *dwState) = 0;
    virtual HRESULT WINAPI Pause(void) = 0;
    virtual HRESULT WINAPI Resume(void) = 0;
    virtual HRESULT WINAPI Evict(void) = 0;
    virtual HRESULT WINAPI get_ResourceGroups(ISClusResGroups **ppResourceGroups) = 0;
    virtual HRESULT WINAPI get_Cluster(ISCluster **ppCluster) = 0;
    virtual HRESULT WINAPI get_NetInterfaces(ISClusNodeNetInterfaces **ppClusNetInterfaces) = 0;
  };
#else
  typedef struct ISClusNodeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNode *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNode *This);
      ULONG (WINAPI *Release)(ISClusNode *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNode *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNode *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNode *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNode *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISClusNode *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISClusNode *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISClusNode *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISClusNode *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Name)(ISClusNode *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_Handle)(ISClusNode *This,ULONG_PTR *phandle);
      HRESULT (WINAPI *get_NodeID)(ISClusNode *This,BSTR *pbstrNodeID);
      HRESULT (WINAPI *get_State)(ISClusNode *This,CLUSTER_NODE_STATE *dwState);
      HRESULT (WINAPI *Pause)(ISClusNode *This);
      HRESULT (WINAPI *Resume)(ISClusNode *This);
      HRESULT (WINAPI *Evict)(ISClusNode *This);
      HRESULT (WINAPI *get_ResourceGroups)(ISClusNode *This,ISClusResGroups **ppResourceGroups);
      HRESULT (WINAPI *get_Cluster)(ISClusNode *This,ISCluster **ppCluster);
      HRESULT (WINAPI *get_NetInterfaces)(ISClusNode *This,ISClusNodeNetInterfaces **ppClusNetInterfaces);
    END_INTERFACE
  } ISClusNodeVtbl;
  struct ISClusNode {
    CONST_VTBL struct ISClusNodeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNode_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNode_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNode_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNode_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNode_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNode_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNode_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNode_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISClusNode_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISClusNode_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISClusNode_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISClusNode_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusNode_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#define ISClusNode_get_NodeID(This,pbstrNodeID) (This)->lpVtbl->get_NodeID(This,pbstrNodeID)
#define ISClusNode_get_State(This,dwState) (This)->lpVtbl->get_State(This,dwState)
#define ISClusNode_Pause(This) (This)->lpVtbl->Pause(This)
#define ISClusNode_Resume(This) (This)->lpVtbl->Resume(This)
#define ISClusNode_Evict(This) (This)->lpVtbl->Evict(This)
#define ISClusNode_get_ResourceGroups(This,ppResourceGroups) (This)->lpVtbl->get_ResourceGroups(This,ppResourceGroups)
#define ISClusNode_get_Cluster(This,ppCluster) (This)->lpVtbl->get_Cluster(This,ppCluster)
#define ISClusNode_get_NetInterfaces(This,ppClusNetInterfaces) (This)->lpVtbl->get_NetInterfaces(This,ppClusNetInterfaces)
#endif
#endif
  HRESULT WINAPI ISClusNode_get_CommonProperties_Proxy(ISClusNode *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNode_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_PrivateProperties_Proxy(ISClusNode *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNode_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_CommonROProperties_Proxy(ISClusNode *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNode_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_PrivateROProperties_Proxy(ISClusNode *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNode_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_Name_Proxy(ISClusNode *This,BSTR *pbstrName);
  void __RPC_STUB ISClusNode_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_Handle_Proxy(ISClusNode *This,ULONG_PTR *phandle);
  void __RPC_STUB ISClusNode_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_NodeID_Proxy(ISClusNode *This,BSTR *pbstrNodeID);
  void __RPC_STUB ISClusNode_get_NodeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_State_Proxy(ISClusNode *This,CLUSTER_NODE_STATE *dwState);
  void __RPC_STUB ISClusNode_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_Pause_Proxy(ISClusNode *This);
  void __RPC_STUB ISClusNode_Pause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_Resume_Proxy(ISClusNode *This);
  void __RPC_STUB ISClusNode_Resume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_Evict_Proxy(ISClusNode *This);
  void __RPC_STUB ISClusNode_Evict_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_ResourceGroups_Proxy(ISClusNode *This,ISClusResGroups **ppResourceGroups);
  void __RPC_STUB ISClusNode_get_ResourceGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_Cluster_Proxy(ISClusNode *This,ISCluster **ppCluster);
  void __RPC_STUB ISClusNode_get_Cluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNode_get_NetInterfaces_Proxy(ISClusNode *This,ISClusNodeNetInterfaces **ppClusNetInterfaces);
  void __RPC_STUB ISClusNode_get_NetInterfaces_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNodes_INTERFACE_DEFINED__
#define __ISClusNodes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNodes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNodes : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNode **ppNode) = 0;
  };
#else
  typedef struct ISClusNodesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNodes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNodes *This);
      ULONG (WINAPI *Release)(ISClusNodes *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNodes *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNodes *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNodes *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNodes *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusNodes *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusNodes *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusNodes *This);
      HRESULT (WINAPI *get_Item)(ISClusNodes *This,VARIANT varIndex,ISClusNode **ppNode);
    END_INTERFACE
  } ISClusNodesVtbl;
  struct ISClusNodes {
    CONST_VTBL struct ISClusNodesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNodes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNodes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNodes_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNodes_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNodes_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNodes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNodes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNodes_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusNodes_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusNodes_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusNodes_get_Item(This,varIndex,ppNode) (This)->lpVtbl->get_Item(This,varIndex,ppNode)
#endif
#endif
  HRESULT WINAPI ISClusNodes_get_Count_Proxy(ISClusNodes *This,__LONG32 *plCount);
  void __RPC_STUB ISClusNodes_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNodes_get__NewEnum_Proxy(ISClusNodes *This,IUnknown **retval);
  void __RPC_STUB ISClusNodes_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNodes_Refresh_Proxy(ISClusNodes *This);
  void __RPC_STUB ISClusNodes_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNodes_get_Item_Proxy(ISClusNodes *This,VARIANT varIndex,ISClusNode **ppNode);
  void __RPC_STUB ISClusNodes_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNetwork_INTERFACE_DEFINED__
#define __ISClusNetwork_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNetwork;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNetwork : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrNetworkName) = 0;
    virtual HRESULT WINAPI get_NetworkID(BSTR *pbstrNetworkID) = 0;
    virtual HRESULT WINAPI get_State(CLUSTER_NETWORK_STATE *dwState) = 0;
    virtual HRESULT WINAPI get_NetInterfaces(ISClusNetworkNetInterfaces **ppClusNetInterfaces) = 0;
    virtual HRESULT WINAPI get_Cluster(ISCluster **ppCluster) = 0;
  };
#else
  typedef struct ISClusNetworkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNetwork *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNetwork *This);
      ULONG (WINAPI *Release)(ISClusNetwork *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNetwork *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNetwork *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNetwork *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNetwork *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISClusNetwork *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISClusNetwork *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISClusNetwork *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISClusNetwork *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Handle)(ISClusNetwork *This,ULONG_PTR *phandle);
      HRESULT (WINAPI *get_Name)(ISClusNetwork *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(ISClusNetwork *This,BSTR bstrNetworkName);
      HRESULT (WINAPI *get_NetworkID)(ISClusNetwork *This,BSTR *pbstrNetworkID);
      HRESULT (WINAPI *get_State)(ISClusNetwork *This,CLUSTER_NETWORK_STATE *dwState);
      HRESULT (WINAPI *get_NetInterfaces)(ISClusNetwork *This,ISClusNetworkNetInterfaces **ppClusNetInterfaces);
      HRESULT (WINAPI *get_Cluster)(ISClusNetwork *This,ISCluster **ppCluster);
    END_INTERFACE
  } ISClusNetworkVtbl;
  struct ISClusNetwork {
    CONST_VTBL struct ISClusNetworkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNetwork_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNetwork_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNetwork_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNetwork_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNetwork_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNetwork_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNetwork_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNetwork_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISClusNetwork_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISClusNetwork_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISClusNetwork_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISClusNetwork_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#define ISClusNetwork_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusNetwork_put_Name(This,bstrNetworkName) (This)->lpVtbl->put_Name(This,bstrNetworkName)
#define ISClusNetwork_get_NetworkID(This,pbstrNetworkID) (This)->lpVtbl->get_NetworkID(This,pbstrNetworkID)
#define ISClusNetwork_get_State(This,dwState) (This)->lpVtbl->get_State(This,dwState)
#define ISClusNetwork_get_NetInterfaces(This,ppClusNetInterfaces) (This)->lpVtbl->get_NetInterfaces(This,ppClusNetInterfaces)
#define ISClusNetwork_get_Cluster(This,ppCluster) (This)->lpVtbl->get_Cluster(This,ppCluster)
#endif
#endif
  HRESULT WINAPI ISClusNetwork_get_CommonProperties_Proxy(ISClusNetwork *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetwork_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_PrivateProperties_Proxy(ISClusNetwork *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetwork_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_CommonROProperties_Proxy(ISClusNetwork *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetwork_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_PrivateROProperties_Proxy(ISClusNetwork *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetwork_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_Handle_Proxy(ISClusNetwork *This,ULONG_PTR *phandle);
  void __RPC_STUB ISClusNetwork_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_Name_Proxy(ISClusNetwork *This,BSTR *pbstrName);
  void __RPC_STUB ISClusNetwork_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_put_Name_Proxy(ISClusNetwork *This,BSTR bstrNetworkName);
  void __RPC_STUB ISClusNetwork_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_NetworkID_Proxy(ISClusNetwork *This,BSTR *pbstrNetworkID);
  void __RPC_STUB ISClusNetwork_get_NetworkID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_State_Proxy(ISClusNetwork *This,CLUSTER_NETWORK_STATE *dwState);
  void __RPC_STUB ISClusNetwork_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_NetInterfaces_Proxy(ISClusNetwork *This,ISClusNetworkNetInterfaces **ppClusNetInterfaces);
  void __RPC_STUB ISClusNetwork_get_NetInterfaces_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetwork_get_Cluster_Proxy(ISClusNetwork *This,ISCluster **ppCluster);
  void __RPC_STUB ISClusNetwork_get_Cluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNetworks_INTERFACE_DEFINED__
#define __ISClusNetworks_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNetworks;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNetworks : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNetwork **ppClusNetwork) = 0;
  };
#else
  typedef struct ISClusNetworksVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNetworks *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNetworks *This);
      ULONG (WINAPI *Release)(ISClusNetworks *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNetworks *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNetworks *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNetworks *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNetworks *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusNetworks *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusNetworks *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusNetworks *This);
      HRESULT (WINAPI *get_Item)(ISClusNetworks *This,VARIANT varIndex,ISClusNetwork **ppClusNetwork);
    END_INTERFACE
  } ISClusNetworksVtbl;
  struct ISClusNetworks {
    CONST_VTBL struct ISClusNetworksVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNetworks_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNetworks_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNetworks_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNetworks_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNetworks_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNetworks_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNetworks_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNetworks_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusNetworks_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusNetworks_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusNetworks_get_Item(This,varIndex,ppClusNetwork) (This)->lpVtbl->get_Item(This,varIndex,ppClusNetwork)
#endif
#endif
  HRESULT WINAPI ISClusNetworks_get_Count_Proxy(ISClusNetworks *This,__LONG32 *plCount);
  void __RPC_STUB ISClusNetworks_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetworks_get__NewEnum_Proxy(ISClusNetworks *This,IUnknown **retval);
  void __RPC_STUB ISClusNetworks_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetworks_Refresh_Proxy(ISClusNetworks *This);
  void __RPC_STUB ISClusNetworks_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetworks_get_Item_Proxy(ISClusNetworks *This,VARIANT varIndex,ISClusNetwork **ppClusNetwork);
  void __RPC_STUB ISClusNetworks_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNetInterface_INTERFACE_DEFINED__
#define __ISClusNetInterface_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNetInterface;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNetInterface : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
    virtual HRESULT WINAPI get_State(CLUSTER_NETINTERFACE_STATE *dwState) = 0;
    virtual HRESULT WINAPI get_Cluster(ISCluster **ppCluster) = 0;
  };
#else
  typedef struct ISClusNetInterfaceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNetInterface *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNetInterface *This);
      ULONG (WINAPI *Release)(ISClusNetInterface *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNetInterface *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNetInterface *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNetInterface *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNetInterface *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISClusNetInterface *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISClusNetInterface *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISClusNetInterface *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISClusNetInterface *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Name)(ISClusNetInterface *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_Handle)(ISClusNetInterface *This,ULONG_PTR *phandle);
      HRESULT (WINAPI *get_State)(ISClusNetInterface *This,CLUSTER_NETINTERFACE_STATE *dwState);
      HRESULT (WINAPI *get_Cluster)(ISClusNetInterface *This,ISCluster **ppCluster);
    END_INTERFACE
  } ISClusNetInterfaceVtbl;
  struct ISClusNetInterface {
    CONST_VTBL struct ISClusNetInterfaceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNetInterface_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNetInterface_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNetInterface_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNetInterface_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNetInterface_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNetInterface_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNetInterface_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNetInterface_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISClusNetInterface_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISClusNetInterface_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISClusNetInterface_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISClusNetInterface_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusNetInterface_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#define ISClusNetInterface_get_State(This,dwState) (This)->lpVtbl->get_State(This,dwState)
#define ISClusNetInterface_get_Cluster(This,ppCluster) (This)->lpVtbl->get_Cluster(This,ppCluster)
#endif
#endif
  HRESULT WINAPI ISClusNetInterface_get_CommonProperties_Proxy(ISClusNetInterface *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetInterface_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_PrivateProperties_Proxy(ISClusNetInterface *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetInterface_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_CommonROProperties_Proxy(ISClusNetInterface *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetInterface_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_PrivateROProperties_Proxy(ISClusNetInterface *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusNetInterface_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_Name_Proxy(ISClusNetInterface *This,BSTR *pbstrName);
  void __RPC_STUB ISClusNetInterface_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_Handle_Proxy(ISClusNetInterface *This,ULONG_PTR *phandle);
  void __RPC_STUB ISClusNetInterface_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_State_Proxy(ISClusNetInterface *This,CLUSTER_NETINTERFACE_STATE *dwState);
  void __RPC_STUB ISClusNetInterface_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterface_get_Cluster_Proxy(ISClusNetInterface *This,ISCluster **ppCluster);
  void __RPC_STUB ISClusNetInterface_get_Cluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNetInterfaces_INTERFACE_DEFINED__
#define __ISClusNetInterfaces_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNetInterfaces;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNetInterfaces : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNetInterface **ppClusNetInterface) = 0;
  };
#else
  typedef struct ISClusNetInterfacesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNetInterfaces *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNetInterfaces *This);
      ULONG (WINAPI *Release)(ISClusNetInterfaces *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNetInterfaces *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNetInterfaces *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNetInterfaces *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNetInterfaces *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusNetInterfaces *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusNetInterfaces *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusNetInterfaces *This);
      HRESULT (WINAPI *get_Item)(ISClusNetInterfaces *This,VARIANT varIndex,ISClusNetInterface **ppClusNetInterface);
    END_INTERFACE
  } ISClusNetInterfacesVtbl;
  struct ISClusNetInterfaces {
    CONST_VTBL struct ISClusNetInterfacesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNetInterfaces_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNetInterfaces_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNetInterfaces_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNetInterfaces_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNetInterfaces_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNetInterfaces_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNetInterfaces_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNetInterfaces_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusNetInterfaces_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusNetInterfaces_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusNetInterfaces_get_Item(This,varIndex,ppClusNetInterface) (This)->lpVtbl->get_Item(This,varIndex,ppClusNetInterface)
#endif
#endif
  HRESULT WINAPI ISClusNetInterfaces_get_Count_Proxy(ISClusNetInterfaces *This,__LONG32 *plCount);
  void __RPC_STUB ISClusNetInterfaces_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterfaces_get__NewEnum_Proxy(ISClusNetInterfaces *This,IUnknown **retval);
  void __RPC_STUB ISClusNetInterfaces_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterfaces_Refresh_Proxy(ISClusNetInterfaces *This);
  void __RPC_STUB ISClusNetInterfaces_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetInterfaces_get_Item_Proxy(ISClusNetInterfaces *This,VARIANT varIndex,ISClusNetInterface **ppClusNetInterface);
  void __RPC_STUB ISClusNetInterfaces_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNodeNetInterfaces_INTERFACE_DEFINED__
#define __ISClusNodeNetInterfaces_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNodeNetInterfaces;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNodeNetInterfaces : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNetInterface **ppClusNetInterface) = 0;
  };
#else
  typedef struct ISClusNodeNetInterfacesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNodeNetInterfaces *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNodeNetInterfaces *This);
      ULONG (WINAPI *Release)(ISClusNodeNetInterfaces *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNodeNetInterfaces *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNodeNetInterfaces *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNodeNetInterfaces *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNodeNetInterfaces *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusNodeNetInterfaces *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusNodeNetInterfaces *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusNodeNetInterfaces *This);
      HRESULT (WINAPI *get_Item)(ISClusNodeNetInterfaces *This,VARIANT varIndex,ISClusNetInterface **ppClusNetInterface);
    END_INTERFACE
  } ISClusNodeNetInterfacesVtbl;
  struct ISClusNodeNetInterfaces {
    CONST_VTBL struct ISClusNodeNetInterfacesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNodeNetInterfaces_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNodeNetInterfaces_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNodeNetInterfaces_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNodeNetInterfaces_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNodeNetInterfaces_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNodeNetInterfaces_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNodeNetInterfaces_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNodeNetInterfaces_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusNodeNetInterfaces_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusNodeNetInterfaces_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusNodeNetInterfaces_get_Item(This,varIndex,ppClusNetInterface) (This)->lpVtbl->get_Item(This,varIndex,ppClusNetInterface)
#endif
#endif
  HRESULT WINAPI ISClusNodeNetInterfaces_get_Count_Proxy(ISClusNodeNetInterfaces *This,__LONG32 *plCount);
  void __RPC_STUB ISClusNodeNetInterfaces_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNodeNetInterfaces_get__NewEnum_Proxy(ISClusNodeNetInterfaces *This,IUnknown **retval);
  void __RPC_STUB ISClusNodeNetInterfaces_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNodeNetInterfaces_Refresh_Proxy(ISClusNodeNetInterfaces *This);
  void __RPC_STUB ISClusNodeNetInterfaces_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNodeNetInterfaces_get_Item_Proxy(ISClusNodeNetInterfaces *This,VARIANT varIndex,ISClusNetInterface **ppClusNetInterface);
  void __RPC_STUB ISClusNodeNetInterfaces_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusNetworkNetInterfaces_INTERFACE_DEFINED__
#define __ISClusNetworkNetInterfaces_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusNetworkNetInterfaces;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusNetworkNetInterfaces : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNetInterface **ppClusNetInterface) = 0;
  };
#else
  typedef struct ISClusNetworkNetInterfacesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusNetworkNetInterfaces *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusNetworkNetInterfaces *This);
      ULONG (WINAPI *Release)(ISClusNetworkNetInterfaces *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusNetworkNetInterfaces *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusNetworkNetInterfaces *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusNetworkNetInterfaces *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusNetworkNetInterfaces *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusNetworkNetInterfaces *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusNetworkNetInterfaces *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusNetworkNetInterfaces *This);
      HRESULT (WINAPI *get_Item)(ISClusNetworkNetInterfaces *This,VARIANT varIndex,ISClusNetInterface **ppClusNetInterface);
    END_INTERFACE
  } ISClusNetworkNetInterfacesVtbl;
  struct ISClusNetworkNetInterfaces {
    CONST_VTBL struct ISClusNetworkNetInterfacesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusNetworkNetInterfaces_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusNetworkNetInterfaces_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusNetworkNetInterfaces_Release(This) (This)->lpVtbl->Release(This)
#define ISClusNetworkNetInterfaces_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusNetworkNetInterfaces_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusNetworkNetInterfaces_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusNetworkNetInterfaces_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusNetworkNetInterfaces_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusNetworkNetInterfaces_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusNetworkNetInterfaces_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusNetworkNetInterfaces_get_Item(This,varIndex,ppClusNetInterface) (This)->lpVtbl->get_Item(This,varIndex,ppClusNetInterface)
#endif
#endif
  HRESULT WINAPI ISClusNetworkNetInterfaces_get_Count_Proxy(ISClusNetworkNetInterfaces *This,__LONG32 *plCount);
  void __RPC_STUB ISClusNetworkNetInterfaces_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetworkNetInterfaces_get__NewEnum_Proxy(ISClusNetworkNetInterfaces *This,IUnknown **retval);
  void __RPC_STUB ISClusNetworkNetInterfaces_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetworkNetInterfaces_Refresh_Proxy(ISClusNetworkNetInterfaces *This);
  void __RPC_STUB ISClusNetworkNetInterfaces_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusNetworkNetInterfaces_get_Item_Proxy(ISClusNetworkNetInterfaces *This,VARIANT varIndex,ISClusNetInterface **ppClusNetInterface);
  void __RPC_STUB ISClusNetworkNetInterfaces_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResGroup_INTERFACE_DEFINED__
#define __ISClusResGroup_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResGroup : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrGroupName) = 0;
    virtual HRESULT WINAPI get_State(CLUSTER_GROUP_STATE *dwState) = 0;
    virtual HRESULT WINAPI get_OwnerNode(ISClusNode **ppOwnerNode) = 0;
    virtual HRESULT WINAPI get_Resources(ISClusResGroupResources **ppClusterGroupResources) = 0;
    virtual HRESULT WINAPI get_PreferredOwnerNodes(ISClusResGroupPreferredOwnerNodes **ppOwnerNodes) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI Online(VARIANT varTimeout,VARIANT varNode,VARIANT *pvarPending) = 0;
    virtual HRESULT WINAPI Move(VARIANT varTimeout,VARIANT varNode,VARIANT *pvarPending) = 0;
    virtual HRESULT WINAPI Offline(VARIANT varTimeout,VARIANT *pvarPending) = 0;
    virtual HRESULT WINAPI get_Cluster(ISCluster **ppCluster) = 0;
  };
#else
  typedef struct ISClusResGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResGroup *This);
      ULONG (WINAPI *Release)(ISClusResGroup *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResGroup *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResGroup *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResGroup *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResGroup *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISClusResGroup *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISClusResGroup *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISClusResGroup *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISClusResGroup *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Handle)(ISClusResGroup *This,ULONG_PTR *phandle);
      HRESULT (WINAPI *get_Name)(ISClusResGroup *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(ISClusResGroup *This,BSTR bstrGroupName);
      HRESULT (WINAPI *get_State)(ISClusResGroup *This,CLUSTER_GROUP_STATE *dwState);
      HRESULT (WINAPI *get_OwnerNode)(ISClusResGroup *This,ISClusNode **ppOwnerNode);
      HRESULT (WINAPI *get_Resources)(ISClusResGroup *This,ISClusResGroupResources **ppClusterGroupResources);
      HRESULT (WINAPI *get_PreferredOwnerNodes)(ISClusResGroup *This,ISClusResGroupPreferredOwnerNodes **ppOwnerNodes);
      HRESULT (WINAPI *Delete)(ISClusResGroup *This);
      HRESULT (WINAPI *Online)(ISClusResGroup *This,VARIANT varTimeout,VARIANT varNode,VARIANT *pvarPending);
      HRESULT (WINAPI *Move)(ISClusResGroup *This,VARIANT varTimeout,VARIANT varNode,VARIANT *pvarPending);
      HRESULT (WINAPI *Offline)(ISClusResGroup *This,VARIANT varTimeout,VARIANT *pvarPending);
      HRESULT (WINAPI *get_Cluster)(ISClusResGroup *This,ISCluster **ppCluster);
    END_INTERFACE
  } ISClusResGroupVtbl;
  struct ISClusResGroup {
    CONST_VTBL struct ISClusResGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResGroup_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResGroup_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResGroup_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResGroup_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResGroup_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResGroup_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISClusResGroup_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISClusResGroup_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISClusResGroup_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISClusResGroup_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#define ISClusResGroup_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusResGroup_put_Name(This,bstrGroupName) (This)->lpVtbl->put_Name(This,bstrGroupName)
#define ISClusResGroup_get_State(This,dwState) (This)->lpVtbl->get_State(This,dwState)
#define ISClusResGroup_get_OwnerNode(This,ppOwnerNode) (This)->lpVtbl->get_OwnerNode(This,ppOwnerNode)
#define ISClusResGroup_get_Resources(This,ppClusterGroupResources) (This)->lpVtbl->get_Resources(This,ppClusterGroupResources)
#define ISClusResGroup_get_PreferredOwnerNodes(This,ppOwnerNodes) (This)->lpVtbl->get_PreferredOwnerNodes(This,ppOwnerNodes)
#define ISClusResGroup_Delete(This) (This)->lpVtbl->Delete(This)
#define ISClusResGroup_Online(This,varTimeout,varNode,pvarPending) (This)->lpVtbl->Online(This,varTimeout,varNode,pvarPending)
#define ISClusResGroup_Move(This,varTimeout,varNode,pvarPending) (This)->lpVtbl->Move(This,varTimeout,varNode,pvarPending)
#define ISClusResGroup_Offline(This,varTimeout,pvarPending) (This)->lpVtbl->Offline(This,varTimeout,pvarPending)
#define ISClusResGroup_get_Cluster(This,ppCluster) (This)->lpVtbl->get_Cluster(This,ppCluster)
#endif
#endif
  HRESULT WINAPI ISClusResGroup_get_CommonProperties_Proxy(ISClusResGroup *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResGroup_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_PrivateProperties_Proxy(ISClusResGroup *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResGroup_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_CommonROProperties_Proxy(ISClusResGroup *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResGroup_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_PrivateROProperties_Proxy(ISClusResGroup *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResGroup_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_Handle_Proxy(ISClusResGroup *This,ULONG_PTR *phandle);
  void __RPC_STUB ISClusResGroup_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_Name_Proxy(ISClusResGroup *This,BSTR *pbstrName);
  void __RPC_STUB ISClusResGroup_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_put_Name_Proxy(ISClusResGroup *This,BSTR bstrGroupName);
  void __RPC_STUB ISClusResGroup_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_State_Proxy(ISClusResGroup *This,CLUSTER_GROUP_STATE *dwState);
  void __RPC_STUB ISClusResGroup_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_OwnerNode_Proxy(ISClusResGroup *This,ISClusNode **ppOwnerNode);
  void __RPC_STUB ISClusResGroup_get_OwnerNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_Resources_Proxy(ISClusResGroup *This,ISClusResGroupResources **ppClusterGroupResources);
  void __RPC_STUB ISClusResGroup_get_Resources_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_PreferredOwnerNodes_Proxy(ISClusResGroup *This,ISClusResGroupPreferredOwnerNodes **ppOwnerNodes);
  void __RPC_STUB ISClusResGroup_get_PreferredOwnerNodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_Delete_Proxy(ISClusResGroup *This);
  void __RPC_STUB ISClusResGroup_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_Online_Proxy(ISClusResGroup *This,VARIANT varTimeout,VARIANT varNode,VARIANT *pvarPending);
  void __RPC_STUB ISClusResGroup_Online_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_Move_Proxy(ISClusResGroup *This,VARIANT varTimeout,VARIANT varNode,VARIANT *pvarPending);
  void __RPC_STUB ISClusResGroup_Move_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_Offline_Proxy(ISClusResGroup *This,VARIANT varTimeout,VARIANT *pvarPending);
  void __RPC_STUB ISClusResGroup_Offline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroup_get_Cluster_Proxy(ISClusResGroup *This,ISCluster **ppCluster);
  void __RPC_STUB ISClusResGroup_get_Cluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResGroups_INTERFACE_DEFINED__
#define __ISClusResGroups_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResGroups;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResGroups : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResGroup **ppClusResGroup) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceGroupName,ISClusResGroup **ppResourceGroup) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResGroupsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResGroups *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResGroups *This);
      ULONG (WINAPI *Release)(ISClusResGroups *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResGroups *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResGroups *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResGroups *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResGroups *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResGroups *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResGroups *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResGroups *This);
      HRESULT (WINAPI *get_Item)(ISClusResGroups *This,VARIANT varIndex,ISClusResGroup **ppClusResGroup);
      HRESULT (WINAPI *CreateItem)(ISClusResGroups *This,BSTR bstrResourceGroupName,ISClusResGroup **ppResourceGroup);
      HRESULT (WINAPI *DeleteItem)(ISClusResGroups *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResGroupsVtbl;
  struct ISClusResGroups {
    CONST_VTBL struct ISClusResGroupsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResGroups_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResGroups_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResGroups_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResGroups_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResGroups_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResGroups_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResGroups_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResGroups_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResGroups_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResGroups_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResGroups_get_Item(This,varIndex,ppClusResGroup) (This)->lpVtbl->get_Item(This,varIndex,ppClusResGroup)
#define ISClusResGroups_CreateItem(This,bstrResourceGroupName,ppResourceGroup) (This)->lpVtbl->CreateItem(This,bstrResourceGroupName,ppResourceGroup)
#define ISClusResGroups_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResGroups_get_Count_Proxy(ISClusResGroups *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResGroups_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroups_get__NewEnum_Proxy(ISClusResGroups *This,IUnknown **retval);
  void __RPC_STUB ISClusResGroups_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroups_Refresh_Proxy(ISClusResGroups *This);
  void __RPC_STUB ISClusResGroups_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroups_get_Item_Proxy(ISClusResGroups *This,VARIANT varIndex,ISClusResGroup **ppClusResGroup);
  void __RPC_STUB ISClusResGroups_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroups_CreateItem_Proxy(ISClusResGroups *This,BSTR bstrResourceGroupName,ISClusResGroup **ppResourceGroup);
  void __RPC_STUB ISClusResGroups_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroups_DeleteItem_Proxy(ISClusResGroups *This,VARIANT varIndex);
  void __RPC_STUB ISClusResGroups_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResource_INTERFACE_DEFINED__
#define __ISClusResource_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResource;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResource : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Handle(ULONG_PTR *phandle) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR bstrResourceName) = 0;
    virtual HRESULT WINAPI get_State(CLUSTER_RESOURCE_STATE *dwState) = 0;
    virtual HRESULT WINAPI get_CoreFlag(CLUS_FLAGS *dwCoreFlag) = 0;
    virtual HRESULT WINAPI BecomeQuorumResource(BSTR bstrDevicePath,__LONG32 lMaxLogSize) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI Fail(void) = 0;
    virtual HRESULT WINAPI Online(__LONG32 nTimeout,VARIANT *pvarPending) = 0;
    virtual HRESULT WINAPI Offline(__LONG32 nTimeout,VARIANT *pvarPending) = 0;
    virtual HRESULT WINAPI ChangeResourceGroup(ISClusResGroup *pResourceGroup) = 0;
    virtual HRESULT WINAPI AddResourceNode(ISClusNode *pNode) = 0;
    virtual HRESULT WINAPI RemoveResourceNode(ISClusNode *pNode) = 0;
    virtual HRESULT WINAPI CanResourceBeDependent(ISClusResource *pResource,VARIANT *pvarDependent) = 0;
    virtual HRESULT WINAPI get_PossibleOwnerNodes(ISClusResPossibleOwnerNodes **ppOwnerNodes) = 0;
    virtual HRESULT WINAPI get_Dependencies(ISClusResDependencies **ppResDependencies) = 0;
    virtual HRESULT WINAPI get_Dependents(ISClusResDependents **ppResDependents) = 0;
    virtual HRESULT WINAPI get_Group(ISClusResGroup **ppResGroup) = 0;
    virtual HRESULT WINAPI get_OwnerNode(ISClusNode **ppOwnerNode) = 0;
    virtual HRESULT WINAPI get_Cluster(ISCluster **ppCluster) = 0;
    virtual HRESULT WINAPI get_ClassInfo(CLUSTER_RESOURCE_CLASS *prcClassInfo) = 0;
    virtual HRESULT WINAPI get_Disk(ISClusDisk **ppDisk) = 0;
    virtual HRESULT WINAPI get_RegistryKeys(ISClusRegistryKeys **ppRegistryKeys) = 0;
    virtual HRESULT WINAPI get_CryptoKeys(ISClusCryptoKeys **ppCryptoKeys) = 0;
    virtual HRESULT WINAPI get_TypeName(BSTR *pbstrTypeName) = 0;
    virtual HRESULT WINAPI get_Type(ISClusResType **ppResourceType) = 0;
    virtual HRESULT WINAPI get_MaintenanceMode(WINBOOL *pbMaintenanceMode) = 0;
    virtual HRESULT WINAPI put_MaintenanceMode(WINBOOL bMaintenanceMode) = 0;
  };
#else
  typedef struct ISClusResourceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResource *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResource *This);
      ULONG (WINAPI *Release)(ISClusResource *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResource *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResource *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResource *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResource *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISClusResource *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISClusResource *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISClusResource *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISClusResource *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Handle)(ISClusResource *This,ULONG_PTR *phandle);
      HRESULT (WINAPI *get_Name)(ISClusResource *This,BSTR *pbstrName);
      HRESULT (WINAPI *put_Name)(ISClusResource *This,BSTR bstrResourceName);
      HRESULT (WINAPI *get_State)(ISClusResource *This,CLUSTER_RESOURCE_STATE *dwState);
      HRESULT (WINAPI *get_CoreFlag)(ISClusResource *This,CLUS_FLAGS *dwCoreFlag);
      HRESULT (WINAPI *BecomeQuorumResource)(ISClusResource *This,BSTR bstrDevicePath,__LONG32 lMaxLogSize);
      HRESULT (WINAPI *Delete)(ISClusResource *This);
      HRESULT (WINAPI *Fail)(ISClusResource *This);
      HRESULT (WINAPI *Online)(ISClusResource *This,__LONG32 nTimeout,VARIANT *pvarPending);
      HRESULT (WINAPI *Offline)(ISClusResource *This,__LONG32 nTimeout,VARIANT *pvarPending);
      HRESULT (WINAPI *ChangeResourceGroup)(ISClusResource *This,ISClusResGroup *pResourceGroup);
      HRESULT (WINAPI *AddResourceNode)(ISClusResource *This,ISClusNode *pNode);
      HRESULT (WINAPI *RemoveResourceNode)(ISClusResource *This,ISClusNode *pNode);
      HRESULT (WINAPI *CanResourceBeDependent)(ISClusResource *This,ISClusResource *pResource,VARIANT *pvarDependent);
      HRESULT (WINAPI *get_PossibleOwnerNodes)(ISClusResource *This,ISClusResPossibleOwnerNodes **ppOwnerNodes);
      HRESULT (WINAPI *get_Dependencies)(ISClusResource *This,ISClusResDependencies **ppResDependencies);
      HRESULT (WINAPI *get_Dependents)(ISClusResource *This,ISClusResDependents **ppResDependents);
      HRESULT (WINAPI *get_Group)(ISClusResource *This,ISClusResGroup **ppResGroup);
      HRESULT (WINAPI *get_OwnerNode)(ISClusResource *This,ISClusNode **ppOwnerNode);
      HRESULT (WINAPI *get_Cluster)(ISClusResource *This,ISCluster **ppCluster);
      HRESULT (WINAPI *get_ClassInfo)(ISClusResource *This,CLUSTER_RESOURCE_CLASS *prcClassInfo);
      HRESULT (WINAPI *get_Disk)(ISClusResource *This,ISClusDisk **ppDisk);
      HRESULT (WINAPI *get_RegistryKeys)(ISClusResource *This,ISClusRegistryKeys **ppRegistryKeys);
      HRESULT (WINAPI *get_CryptoKeys)(ISClusResource *This,ISClusCryptoKeys **ppCryptoKeys);
      HRESULT (WINAPI *get_TypeName)(ISClusResource *This,BSTR *pbstrTypeName);
      HRESULT (WINAPI *get_Type)(ISClusResource *This,ISClusResType **ppResourceType);
      HRESULT (WINAPI *get_MaintenanceMode)(ISClusResource *This,WINBOOL *pbMaintenanceMode);
      HRESULT (WINAPI *put_MaintenanceMode)(ISClusResource *This,WINBOOL bMaintenanceMode);
    END_INTERFACE
  } ISClusResourceVtbl;
  struct ISClusResource {
    CONST_VTBL struct ISClusResourceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResource_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResource_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResource_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResource_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResource_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResource_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISClusResource_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISClusResource_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISClusResource_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISClusResource_get_Handle(This,phandle) (This)->lpVtbl->get_Handle(This,phandle)
#define ISClusResource_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusResource_put_Name(This,bstrResourceName) (This)->lpVtbl->put_Name(This,bstrResourceName)
#define ISClusResource_get_State(This,dwState) (This)->lpVtbl->get_State(This,dwState)
#define ISClusResource_get_CoreFlag(This,dwCoreFlag) (This)->lpVtbl->get_CoreFlag(This,dwCoreFlag)
#define ISClusResource_BecomeQuorumResource(This,bstrDevicePath,lMaxLogSize) (This)->lpVtbl->BecomeQuorumResource(This,bstrDevicePath,lMaxLogSize)
#define ISClusResource_Delete(This) (This)->lpVtbl->Delete(This)
#define ISClusResource_Fail(This) (This)->lpVtbl->Fail(This)
#define ISClusResource_Online(This,nTimeout,pvarPending) (This)->lpVtbl->Online(This,nTimeout,pvarPending)
#define ISClusResource_Offline(This,nTimeout,pvarPending) (This)->lpVtbl->Offline(This,nTimeout,pvarPending)
#define ISClusResource_ChangeResourceGroup(This,pResourceGroup) (This)->lpVtbl->ChangeResourceGroup(This,pResourceGroup)
#define ISClusResource_AddResourceNode(This,pNode) (This)->lpVtbl->AddResourceNode(This,pNode)
#define ISClusResource_RemoveResourceNode(This,pNode) (This)->lpVtbl->RemoveResourceNode(This,pNode)
#define ISClusResource_CanResourceBeDependent(This,pResource,pvarDependent) (This)->lpVtbl->CanResourceBeDependent(This,pResource,pvarDependent)
#define ISClusResource_get_PossibleOwnerNodes(This,ppOwnerNodes) (This)->lpVtbl->get_PossibleOwnerNodes(This,ppOwnerNodes)
#define ISClusResource_get_Dependencies(This,ppResDependencies) (This)->lpVtbl->get_Dependencies(This,ppResDependencies)
#define ISClusResource_get_Dependents(This,ppResDependents) (This)->lpVtbl->get_Dependents(This,ppResDependents)
#define ISClusResource_get_Group(This,ppResGroup) (This)->lpVtbl->get_Group(This,ppResGroup)
#define ISClusResource_get_OwnerNode(This,ppOwnerNode) (This)->lpVtbl->get_OwnerNode(This,ppOwnerNode)
#define ISClusResource_get_Cluster(This,ppCluster) (This)->lpVtbl->get_Cluster(This,ppCluster)
#define ISClusResource_get_ClassInfo(This,prcClassInfo) (This)->lpVtbl->get_ClassInfo(This,prcClassInfo)
#define ISClusResource_get_Disk(This,ppDisk) (This)->lpVtbl->get_Disk(This,ppDisk)
#define ISClusResource_get_RegistryKeys(This,ppRegistryKeys) (This)->lpVtbl->get_RegistryKeys(This,ppRegistryKeys)
#define ISClusResource_get_CryptoKeys(This,ppCryptoKeys) (This)->lpVtbl->get_CryptoKeys(This,ppCryptoKeys)
#define ISClusResource_get_TypeName(This,pbstrTypeName) (This)->lpVtbl->get_TypeName(This,pbstrTypeName)
#define ISClusResource_get_Type(This,ppResourceType) (This)->lpVtbl->get_Type(This,ppResourceType)
#define ISClusResource_get_MaintenanceMode(This,pbMaintenanceMode) (This)->lpVtbl->get_MaintenanceMode(This,pbMaintenanceMode)
#define ISClusResource_put_MaintenanceMode(This,bMaintenanceMode) (This)->lpVtbl->put_MaintenanceMode(This,bMaintenanceMode)
#endif
#endif
  HRESULT WINAPI ISClusResource_get_CommonProperties_Proxy(ISClusResource *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResource_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_PrivateProperties_Proxy(ISClusResource *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResource_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_CommonROProperties_Proxy(ISClusResource *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResource_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_PrivateROProperties_Proxy(ISClusResource *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResource_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Handle_Proxy(ISClusResource *This,ULONG_PTR *phandle);
  void __RPC_STUB ISClusResource_get_Handle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Name_Proxy(ISClusResource *This,BSTR *pbstrName);
  void __RPC_STUB ISClusResource_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_put_Name_Proxy(ISClusResource *This,BSTR bstrResourceName);
  void __RPC_STUB ISClusResource_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_State_Proxy(ISClusResource *This,CLUSTER_RESOURCE_STATE *dwState);
  void __RPC_STUB ISClusResource_get_State_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_CoreFlag_Proxy(ISClusResource *This,CLUS_FLAGS *dwCoreFlag);
  void __RPC_STUB ISClusResource_get_CoreFlag_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_BecomeQuorumResource_Proxy(ISClusResource *This,BSTR bstrDevicePath,__LONG32 lMaxLogSize);
  void __RPC_STUB ISClusResource_BecomeQuorumResource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_Delete_Proxy(ISClusResource *This);
  void __RPC_STUB ISClusResource_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_Fail_Proxy(ISClusResource *This);
  void __RPC_STUB ISClusResource_Fail_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_Online_Proxy(ISClusResource *This,__LONG32 nTimeout,VARIANT *pvarPending);
  void __RPC_STUB ISClusResource_Online_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_Offline_Proxy(ISClusResource *This,__LONG32 nTimeout,VARIANT *pvarPending);
  void __RPC_STUB ISClusResource_Offline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_ChangeResourceGroup_Proxy(ISClusResource *This,ISClusResGroup *pResourceGroup);
  void __RPC_STUB ISClusResource_ChangeResourceGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_AddResourceNode_Proxy(ISClusResource *This,ISClusNode *pNode);
  void __RPC_STUB ISClusResource_AddResourceNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_RemoveResourceNode_Proxy(ISClusResource *This,ISClusNode *pNode);
  void __RPC_STUB ISClusResource_RemoveResourceNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_CanResourceBeDependent_Proxy(ISClusResource *This,ISClusResource *pResource,VARIANT *pvarDependent);
  void __RPC_STUB ISClusResource_CanResourceBeDependent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_PossibleOwnerNodes_Proxy(ISClusResource *This,ISClusResPossibleOwnerNodes **ppOwnerNodes);
  void __RPC_STUB ISClusResource_get_PossibleOwnerNodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Dependencies_Proxy(ISClusResource *This,ISClusResDependencies **ppResDependencies);
  void __RPC_STUB ISClusResource_get_Dependencies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Dependents_Proxy(ISClusResource *This,ISClusResDependents **ppResDependents);
  void __RPC_STUB ISClusResource_get_Dependents_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Group_Proxy(ISClusResource *This,ISClusResGroup **ppResGroup);
  void __RPC_STUB ISClusResource_get_Group_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_OwnerNode_Proxy(ISClusResource *This,ISClusNode **ppOwnerNode);
  void __RPC_STUB ISClusResource_get_OwnerNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Cluster_Proxy(ISClusResource *This,ISCluster **ppCluster);
  void __RPC_STUB ISClusResource_get_Cluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_ClassInfo_Proxy(ISClusResource *This,CLUSTER_RESOURCE_CLASS *prcClassInfo);
  void __RPC_STUB ISClusResource_get_ClassInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Disk_Proxy(ISClusResource *This,ISClusDisk **ppDisk);
  void __RPC_STUB ISClusResource_get_Disk_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_RegistryKeys_Proxy(ISClusResource *This,ISClusRegistryKeys **ppRegistryKeys);
  void __RPC_STUB ISClusResource_get_RegistryKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_CryptoKeys_Proxy(ISClusResource *This,ISClusCryptoKeys **ppCryptoKeys);
  void __RPC_STUB ISClusResource_get_CryptoKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_TypeName_Proxy(ISClusResource *This,BSTR *pbstrTypeName);
  void __RPC_STUB ISClusResource_get_TypeName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_Type_Proxy(ISClusResource *This,ISClusResType **ppResourceType);
  void __RPC_STUB ISClusResource_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_get_MaintenanceMode_Proxy(ISClusResource *This,WINBOOL *pbMaintenanceMode);
  void __RPC_STUB ISClusResource_get_MaintenanceMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResource_put_MaintenanceMode_Proxy(ISClusResource *This,WINBOOL bMaintenanceMode);
  void __RPC_STUB ISClusResource_put_MaintenanceMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResDependencies_INTERFACE_DEFINED__
#define __ISClusResDependencies_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResDependencies;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResDependencies : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResource **ppClusResource) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
    virtual HRESULT WINAPI AddItem(ISClusResource *pResource) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResDependenciesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResDependencies *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResDependencies *This);
      ULONG (WINAPI *Release)(ISClusResDependencies *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResDependencies *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResDependencies *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResDependencies *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResDependencies *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResDependencies *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResDependencies *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResDependencies *This);
      HRESULT (WINAPI *get_Item)(ISClusResDependencies *This,VARIANT varIndex,ISClusResource **ppClusResource);
      HRESULT (WINAPI *CreateItem)(ISClusResDependencies *This,BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
      HRESULT (WINAPI *DeleteItem)(ISClusResDependencies *This,VARIANT varIndex);
      HRESULT (WINAPI *AddItem)(ISClusResDependencies *This,ISClusResource *pResource);
      HRESULT (WINAPI *RemoveItem)(ISClusResDependencies *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResDependenciesVtbl;
  struct ISClusResDependencies {
    CONST_VTBL struct ISClusResDependenciesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResDependencies_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResDependencies_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResDependencies_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResDependencies_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResDependencies_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResDependencies_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResDependencies_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResDependencies_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResDependencies_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResDependencies_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResDependencies_get_Item(This,varIndex,ppClusResource) (This)->lpVtbl->get_Item(This,varIndex,ppClusResource)
#define ISClusResDependencies_CreateItem(This,bstrResourceName,bstrResourceType,dwFlags,ppClusterResource) (This)->lpVtbl->CreateItem(This,bstrResourceName,bstrResourceType,dwFlags,ppClusterResource)
#define ISClusResDependencies_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#define ISClusResDependencies_AddItem(This,pResource) (This)->lpVtbl->AddItem(This,pResource)
#define ISClusResDependencies_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResDependencies_get_Count_Proxy(ISClusResDependencies *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResDependencies_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_get__NewEnum_Proxy(ISClusResDependencies *This,IUnknown **retval);
  void __RPC_STUB ISClusResDependencies_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_Refresh_Proxy(ISClusResDependencies *This);
  void __RPC_STUB ISClusResDependencies_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_get_Item_Proxy(ISClusResDependencies *This,VARIANT varIndex,ISClusResource **ppClusResource);
  void __RPC_STUB ISClusResDependencies_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_CreateItem_Proxy(ISClusResDependencies *This,BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
  void __RPC_STUB ISClusResDependencies_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_DeleteItem_Proxy(ISClusResDependencies *This,VARIANT varIndex);
  void __RPC_STUB ISClusResDependencies_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_AddItem_Proxy(ISClusResDependencies *This,ISClusResource *pResource);
  void __RPC_STUB ISClusResDependencies_AddItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependencies_RemoveItem_Proxy(ISClusResDependencies *This,VARIANT varIndex);
  void __RPC_STUB ISClusResDependencies_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResGroupResources_INTERFACE_DEFINED__
#define __ISClusResGroupResources_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResGroupResources;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResGroupResources : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResource **ppClusResource) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResGroupResourcesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResGroupResources *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResGroupResources *This);
      ULONG (WINAPI *Release)(ISClusResGroupResources *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResGroupResources *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResGroupResources *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResGroupResources *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResGroupResources *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResGroupResources *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResGroupResources *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResGroupResources *This);
      HRESULT (WINAPI *get_Item)(ISClusResGroupResources *This,VARIANT varIndex,ISClusResource **ppClusResource);
      HRESULT (WINAPI *CreateItem)(ISClusResGroupResources *This,BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
      HRESULT (WINAPI *DeleteItem)(ISClusResGroupResources *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResGroupResourcesVtbl;
  struct ISClusResGroupResources {
    CONST_VTBL struct ISClusResGroupResourcesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResGroupResources_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResGroupResources_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResGroupResources_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResGroupResources_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResGroupResources_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResGroupResources_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResGroupResources_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResGroupResources_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResGroupResources_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResGroupResources_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResGroupResources_get_Item(This,varIndex,ppClusResource) (This)->lpVtbl->get_Item(This,varIndex,ppClusResource)
#define ISClusResGroupResources_CreateItem(This,bstrResourceName,bstrResourceType,dwFlags,ppClusterResource) (This)->lpVtbl->CreateItem(This,bstrResourceName,bstrResourceType,dwFlags,ppClusterResource)
#define ISClusResGroupResources_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResGroupResources_get_Count_Proxy(ISClusResGroupResources *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResGroupResources_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupResources_get__NewEnum_Proxy(ISClusResGroupResources *This,IUnknown **retval);
  void __RPC_STUB ISClusResGroupResources_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupResources_Refresh_Proxy(ISClusResGroupResources *This);
  void __RPC_STUB ISClusResGroupResources_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupResources_get_Item_Proxy(ISClusResGroupResources *This,VARIANT varIndex,ISClusResource **ppClusResource);
  void __RPC_STUB ISClusResGroupResources_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupResources_CreateItem_Proxy(ISClusResGroupResources *This,BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
  void __RPC_STUB ISClusResGroupResources_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupResources_DeleteItem_Proxy(ISClusResGroupResources *This,VARIANT varIndex);
  void __RPC_STUB ISClusResGroupResources_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResTypeResources_INTERFACE_DEFINED__
#define __ISClusResTypeResources_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResTypeResources;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResTypeResources : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResource **ppClusResource) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceName,BSTR bstrGroupName,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResTypeResourcesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResTypeResources *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResTypeResources *This);
      ULONG (WINAPI *Release)(ISClusResTypeResources *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResTypeResources *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResTypeResources *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResTypeResources *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResTypeResources *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResTypeResources *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResTypeResources *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResTypeResources *This);
      HRESULT (WINAPI *get_Item)(ISClusResTypeResources *This,VARIANT varIndex,ISClusResource **ppClusResource);
      HRESULT (WINAPI *CreateItem)(ISClusResTypeResources *This,BSTR bstrResourceName,BSTR bstrGroupName,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
      HRESULT (WINAPI *DeleteItem)(ISClusResTypeResources *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResTypeResourcesVtbl;
  struct ISClusResTypeResources {
    CONST_VTBL struct ISClusResTypeResourcesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResTypeResources_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResTypeResources_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResTypeResources_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResTypeResources_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResTypeResources_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResTypeResources_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResTypeResources_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResTypeResources_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResTypeResources_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResTypeResources_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResTypeResources_get_Item(This,varIndex,ppClusResource) (This)->lpVtbl->get_Item(This,varIndex,ppClusResource)
#define ISClusResTypeResources_CreateItem(This,bstrResourceName,bstrGroupName,dwFlags,ppClusterResource) (This)->lpVtbl->CreateItem(This,bstrResourceName,bstrGroupName,dwFlags,ppClusterResource)
#define ISClusResTypeResources_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResTypeResources_get_Count_Proxy(ISClusResTypeResources *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResTypeResources_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypeResources_get__NewEnum_Proxy(ISClusResTypeResources *This,IUnknown **retval);
  void __RPC_STUB ISClusResTypeResources_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypeResources_Refresh_Proxy(ISClusResTypeResources *This);
  void __RPC_STUB ISClusResTypeResources_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypeResources_get_Item_Proxy(ISClusResTypeResources *This,VARIANT varIndex,ISClusResource **ppClusResource);
  void __RPC_STUB ISClusResTypeResources_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypeResources_CreateItem_Proxy(ISClusResTypeResources *This,BSTR bstrResourceName,BSTR bstrGroupName,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
  void __RPC_STUB ISClusResTypeResources_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypeResources_DeleteItem_Proxy(ISClusResTypeResources *This,VARIANT varIndex);
  void __RPC_STUB ISClusResTypeResources_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResources_INTERFACE_DEFINED__
#define __ISClusResources_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResources;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResources : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResource **ppClusResource) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceName,BSTR bstrResourceType,BSTR bstrGroupName,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResourcesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResources *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResources *This);
      ULONG (WINAPI *Release)(ISClusResources *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResources *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResources *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResources *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResources *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResources *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResources *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResources *This);
      HRESULT (WINAPI *get_Item)(ISClusResources *This,VARIANT varIndex,ISClusResource **ppClusResource);
      HRESULT (WINAPI *CreateItem)(ISClusResources *This,BSTR bstrResourceName,BSTR bstrResourceType,BSTR bstrGroupName,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
      HRESULT (WINAPI *DeleteItem)(ISClusResources *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResourcesVtbl;
  struct ISClusResources {
    CONST_VTBL struct ISClusResourcesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResources_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResources_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResources_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResources_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResources_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResources_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResources_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResources_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResources_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResources_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResources_get_Item(This,varIndex,ppClusResource) (This)->lpVtbl->get_Item(This,varIndex,ppClusResource)
#define ISClusResources_CreateItem(This,bstrResourceName,bstrResourceType,bstrGroupName,dwFlags,ppClusterResource) (This)->lpVtbl->CreateItem(This,bstrResourceName,bstrResourceType,bstrGroupName,dwFlags,ppClusterResource)
#define ISClusResources_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResources_get_Count_Proxy(ISClusResources *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResources_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResources_get__NewEnum_Proxy(ISClusResources *This,IUnknown **retval);
  void __RPC_STUB ISClusResources_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResources_Refresh_Proxy(ISClusResources *This);
  void __RPC_STUB ISClusResources_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResources_get_Item_Proxy(ISClusResources *This,VARIANT varIndex,ISClusResource **ppClusResource);
  void __RPC_STUB ISClusResources_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResources_CreateItem_Proxy(ISClusResources *This,BSTR bstrResourceName,BSTR bstrResourceType,BSTR bstrGroupName,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
  void __RPC_STUB ISClusResources_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResources_DeleteItem_Proxy(ISClusResources *This,VARIANT varIndex);
  void __RPC_STUB ISClusResources_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResGroupPreferredOwnerNodes_INTERFACE_DEFINED__
#define __ISClusResGroupPreferredOwnerNodes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResGroupPreferredOwnerNodes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResGroupPreferredOwnerNodes : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNode **ppNode) = 0;
    virtual HRESULT WINAPI InsertItem(ISClusNode *pNode,__LONG32 nPosition) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
    virtual HRESULT WINAPI get_Modified(VARIANT *pvarModified) = 0;
    virtual HRESULT WINAPI SaveChanges(void) = 0;
    virtual HRESULT WINAPI AddItem(ISClusNode *pNode) = 0;
  };
#else
  typedef struct ISClusResGroupPreferredOwnerNodesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResGroupPreferredOwnerNodes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResGroupPreferredOwnerNodes *This);
      ULONG (WINAPI *Release)(ISClusResGroupPreferredOwnerNodes *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResGroupPreferredOwnerNodes *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResGroupPreferredOwnerNodes *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResGroupPreferredOwnerNodes *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResGroupPreferredOwnerNodes *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResGroupPreferredOwnerNodes *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResGroupPreferredOwnerNodes *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResGroupPreferredOwnerNodes *This);
      HRESULT (WINAPI *get_Item)(ISClusResGroupPreferredOwnerNodes *This,VARIANT varIndex,ISClusNode **ppNode);
      HRESULT (WINAPI *InsertItem)(ISClusResGroupPreferredOwnerNodes *This,ISClusNode *pNode,__LONG32 nPosition);
      HRESULT (WINAPI *RemoveItem)(ISClusResGroupPreferredOwnerNodes *This,VARIANT varIndex);
      HRESULT (WINAPI *get_Modified)(ISClusResGroupPreferredOwnerNodes *This,VARIANT *pvarModified);
      HRESULT (WINAPI *SaveChanges)(ISClusResGroupPreferredOwnerNodes *This);
      HRESULT (WINAPI *AddItem)(ISClusResGroupPreferredOwnerNodes *This,ISClusNode *pNode);
    END_INTERFACE
  } ISClusResGroupPreferredOwnerNodesVtbl;
  struct ISClusResGroupPreferredOwnerNodes {
    CONST_VTBL struct ISClusResGroupPreferredOwnerNodesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResGroupPreferredOwnerNodes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResGroupPreferredOwnerNodes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResGroupPreferredOwnerNodes_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResGroupPreferredOwnerNodes_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResGroupPreferredOwnerNodes_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResGroupPreferredOwnerNodes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResGroupPreferredOwnerNodes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResGroupPreferredOwnerNodes_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResGroupPreferredOwnerNodes_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResGroupPreferredOwnerNodes_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResGroupPreferredOwnerNodes_get_Item(This,varIndex,ppNode) (This)->lpVtbl->get_Item(This,varIndex,ppNode)
#define ISClusResGroupPreferredOwnerNodes_InsertItem(This,pNode,nPosition) (This)->lpVtbl->InsertItem(This,pNode,nPosition)
#define ISClusResGroupPreferredOwnerNodes_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#define ISClusResGroupPreferredOwnerNodes_get_Modified(This,pvarModified) (This)->lpVtbl->get_Modified(This,pvarModified)
#define ISClusResGroupPreferredOwnerNodes_SaveChanges(This) (This)->lpVtbl->SaveChanges(This)
#define ISClusResGroupPreferredOwnerNodes_AddItem(This,pNode) (This)->lpVtbl->AddItem(This,pNode)
#endif
#endif
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_get_Count_Proxy(ISClusResGroupPreferredOwnerNodes *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_get__NewEnum_Proxy(ISClusResGroupPreferredOwnerNodes *This,IUnknown **retval);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_Refresh_Proxy(ISClusResGroupPreferredOwnerNodes *This);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_get_Item_Proxy(ISClusResGroupPreferredOwnerNodes *This,VARIANT varIndex,ISClusNode **ppNode);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_InsertItem_Proxy(ISClusResGroupPreferredOwnerNodes *This,ISClusNode *pNode,__LONG32 nPosition);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_InsertItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_RemoveItem_Proxy(ISClusResGroupPreferredOwnerNodes *This,VARIANT varIndex);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_get_Modified_Proxy(ISClusResGroupPreferredOwnerNodes *This,VARIANT *pvarModified);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_get_Modified_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_SaveChanges_Proxy(ISClusResGroupPreferredOwnerNodes *This);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_SaveChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResGroupPreferredOwnerNodes_AddItem_Proxy(ISClusResGroupPreferredOwnerNodes *This,ISClusNode *pNode);
  void __RPC_STUB ISClusResGroupPreferredOwnerNodes_AddItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResPossibleOwnerNodes_INTERFACE_DEFINED__
#define __ISClusResPossibleOwnerNodes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResPossibleOwnerNodes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResPossibleOwnerNodes : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNode **ppNode) = 0;
    virtual HRESULT WINAPI AddItem(ISClusNode *pNode) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
    virtual HRESULT WINAPI get_Modified(VARIANT *pvarModified) = 0;
  };
#else
  typedef struct ISClusResPossibleOwnerNodesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResPossibleOwnerNodes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResPossibleOwnerNodes *This);
      ULONG (WINAPI *Release)(ISClusResPossibleOwnerNodes *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResPossibleOwnerNodes *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResPossibleOwnerNodes *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResPossibleOwnerNodes *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResPossibleOwnerNodes *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResPossibleOwnerNodes *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResPossibleOwnerNodes *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResPossibleOwnerNodes *This);
      HRESULT (WINAPI *get_Item)(ISClusResPossibleOwnerNodes *This,VARIANT varIndex,ISClusNode **ppNode);
      HRESULT (WINAPI *AddItem)(ISClusResPossibleOwnerNodes *This,ISClusNode *pNode);
      HRESULT (WINAPI *RemoveItem)(ISClusResPossibleOwnerNodes *This,VARIANT varIndex);
      HRESULT (WINAPI *get_Modified)(ISClusResPossibleOwnerNodes *This,VARIANT *pvarModified);
    END_INTERFACE
  } ISClusResPossibleOwnerNodesVtbl;
  struct ISClusResPossibleOwnerNodes {
    CONST_VTBL struct ISClusResPossibleOwnerNodesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResPossibleOwnerNodes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResPossibleOwnerNodes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResPossibleOwnerNodes_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResPossibleOwnerNodes_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResPossibleOwnerNodes_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResPossibleOwnerNodes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResPossibleOwnerNodes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResPossibleOwnerNodes_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResPossibleOwnerNodes_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResPossibleOwnerNodes_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResPossibleOwnerNodes_get_Item(This,varIndex,ppNode) (This)->lpVtbl->get_Item(This,varIndex,ppNode)
#define ISClusResPossibleOwnerNodes_AddItem(This,pNode) (This)->lpVtbl->AddItem(This,pNode)
#define ISClusResPossibleOwnerNodes_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#define ISClusResPossibleOwnerNodes_get_Modified(This,pvarModified) (This)->lpVtbl->get_Modified(This,pvarModified)
#endif
#endif
  HRESULT WINAPI ISClusResPossibleOwnerNodes_get_Count_Proxy(ISClusResPossibleOwnerNodes *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResPossibleOwnerNodes_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResPossibleOwnerNodes_get__NewEnum_Proxy(ISClusResPossibleOwnerNodes *This,IUnknown **retval);
  void __RPC_STUB ISClusResPossibleOwnerNodes_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResPossibleOwnerNodes_Refresh_Proxy(ISClusResPossibleOwnerNodes *This);
  void __RPC_STUB ISClusResPossibleOwnerNodes_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResPossibleOwnerNodes_get_Item_Proxy(ISClusResPossibleOwnerNodes *This,VARIANT varIndex,ISClusNode **ppNode);
  void __RPC_STUB ISClusResPossibleOwnerNodes_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResPossibleOwnerNodes_AddItem_Proxy(ISClusResPossibleOwnerNodes *This,ISClusNode *pNode);
  void __RPC_STUB ISClusResPossibleOwnerNodes_AddItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResPossibleOwnerNodes_RemoveItem_Proxy(ISClusResPossibleOwnerNodes *This,VARIANT varIndex);
  void __RPC_STUB ISClusResPossibleOwnerNodes_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResPossibleOwnerNodes_get_Modified_Proxy(ISClusResPossibleOwnerNodes *This,VARIANT *pvarModified);
  void __RPC_STUB ISClusResPossibleOwnerNodes_get_Modified_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResTypePossibleOwnerNodes_INTERFACE_DEFINED__
#define __ISClusResTypePossibleOwnerNodes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResTypePossibleOwnerNodes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResTypePossibleOwnerNodes : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusNode **ppNode) = 0;
  };
#else
  typedef struct ISClusResTypePossibleOwnerNodesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResTypePossibleOwnerNodes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResTypePossibleOwnerNodes *This);
      ULONG (WINAPI *Release)(ISClusResTypePossibleOwnerNodes *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResTypePossibleOwnerNodes *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResTypePossibleOwnerNodes *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResTypePossibleOwnerNodes *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResTypePossibleOwnerNodes *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResTypePossibleOwnerNodes *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResTypePossibleOwnerNodes *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResTypePossibleOwnerNodes *This);
      HRESULT (WINAPI *get_Item)(ISClusResTypePossibleOwnerNodes *This,VARIANT varIndex,ISClusNode **ppNode);
    END_INTERFACE
  } ISClusResTypePossibleOwnerNodesVtbl;
  struct ISClusResTypePossibleOwnerNodes {
    CONST_VTBL struct ISClusResTypePossibleOwnerNodesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResTypePossibleOwnerNodes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResTypePossibleOwnerNodes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResTypePossibleOwnerNodes_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResTypePossibleOwnerNodes_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResTypePossibleOwnerNodes_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResTypePossibleOwnerNodes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResTypePossibleOwnerNodes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResTypePossibleOwnerNodes_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResTypePossibleOwnerNodes_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResTypePossibleOwnerNodes_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResTypePossibleOwnerNodes_get_Item(This,varIndex,ppNode) (This)->lpVtbl->get_Item(This,varIndex,ppNode)
#endif
#endif
  HRESULT WINAPI ISClusResTypePossibleOwnerNodes_get_Count_Proxy(ISClusResTypePossibleOwnerNodes *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResTypePossibleOwnerNodes_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypePossibleOwnerNodes_get__NewEnum_Proxy(ISClusResTypePossibleOwnerNodes *This,IUnknown **retval);
  void __RPC_STUB ISClusResTypePossibleOwnerNodes_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypePossibleOwnerNodes_Refresh_Proxy(ISClusResTypePossibleOwnerNodes *This);
  void __RPC_STUB ISClusResTypePossibleOwnerNodes_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypePossibleOwnerNodes_get_Item_Proxy(ISClusResTypePossibleOwnerNodes *This,VARIANT varIndex,ISClusNode **ppNode);
  void __RPC_STUB ISClusResTypePossibleOwnerNodes_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResType_INTERFACE_DEFINED__
#define __ISClusResType_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResType;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResType : public IDispatch {
  public:
    virtual HRESULT WINAPI get_CommonProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_CommonROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_PrivateROProperties(ISClusProperties **ppProperties) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI Delete(void) = 0;
    virtual HRESULT WINAPI get_Cluster(ISCluster **ppCluster) = 0;
    virtual HRESULT WINAPI get_Resources(ISClusResTypeResources **ppClusterResTypeResources) = 0;
    virtual HRESULT WINAPI get_PossibleOwnerNodes(ISClusResTypePossibleOwnerNodes **ppOwnerNodes) = 0;
    virtual HRESULT WINAPI get_AvailableDisks(ISClusDisks **ppAvailableDisks) = 0;
  };
#else
  typedef struct ISClusResTypeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResType *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResType *This);
      ULONG (WINAPI *Release)(ISClusResType *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResType *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResType *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResType *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResType *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_CommonProperties)(ISClusResType *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateProperties)(ISClusResType *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_CommonROProperties)(ISClusResType *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_PrivateROProperties)(ISClusResType *This,ISClusProperties **ppProperties);
      HRESULT (WINAPI *get_Name)(ISClusResType *This,BSTR *pbstrName);
      HRESULT (WINAPI *Delete)(ISClusResType *This);
      HRESULT (WINAPI *get_Cluster)(ISClusResType *This,ISCluster **ppCluster);
      HRESULT (WINAPI *get_Resources)(ISClusResType *This,ISClusResTypeResources **ppClusterResTypeResources);
      HRESULT (WINAPI *get_PossibleOwnerNodes)(ISClusResType *This,ISClusResTypePossibleOwnerNodes **ppOwnerNodes);
      HRESULT (WINAPI *get_AvailableDisks)(ISClusResType *This,ISClusDisks **ppAvailableDisks);
    END_INTERFACE
  } ISClusResTypeVtbl;
  struct ISClusResType {
    CONST_VTBL struct ISClusResTypeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResType_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResType_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResType_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResType_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResType_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResType_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResType_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResType_get_CommonProperties(This,ppProperties) (This)->lpVtbl->get_CommonProperties(This,ppProperties)
#define ISClusResType_get_PrivateProperties(This,ppProperties) (This)->lpVtbl->get_PrivateProperties(This,ppProperties)
#define ISClusResType_get_CommonROProperties(This,ppProperties) (This)->lpVtbl->get_CommonROProperties(This,ppProperties)
#define ISClusResType_get_PrivateROProperties(This,ppProperties) (This)->lpVtbl->get_PrivateROProperties(This,ppProperties)
#define ISClusResType_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusResType_Delete(This) (This)->lpVtbl->Delete(This)
#define ISClusResType_get_Cluster(This,ppCluster) (This)->lpVtbl->get_Cluster(This,ppCluster)
#define ISClusResType_get_Resources(This,ppClusterResTypeResources) (This)->lpVtbl->get_Resources(This,ppClusterResTypeResources)
#define ISClusResType_get_PossibleOwnerNodes(This,ppOwnerNodes) (This)->lpVtbl->get_PossibleOwnerNodes(This,ppOwnerNodes)
#define ISClusResType_get_AvailableDisks(This,ppAvailableDisks) (This)->lpVtbl->get_AvailableDisks(This,ppAvailableDisks)
#endif
#endif
  HRESULT WINAPI ISClusResType_get_CommonProperties_Proxy(ISClusResType *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResType_get_CommonProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_PrivateProperties_Proxy(ISClusResType *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResType_get_PrivateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_CommonROProperties_Proxy(ISClusResType *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResType_get_CommonROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_PrivateROProperties_Proxy(ISClusResType *This,ISClusProperties **ppProperties);
  void __RPC_STUB ISClusResType_get_PrivateROProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_Name_Proxy(ISClusResType *This,BSTR *pbstrName);
  void __RPC_STUB ISClusResType_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_Delete_Proxy(ISClusResType *This);
  void __RPC_STUB ISClusResType_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_Cluster_Proxy(ISClusResType *This,ISCluster **ppCluster);
  void __RPC_STUB ISClusResType_get_Cluster_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_Resources_Proxy(ISClusResType *This,ISClusResTypeResources **ppClusterResTypeResources);
  void __RPC_STUB ISClusResType_get_Resources_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_PossibleOwnerNodes_Proxy(ISClusResType *This,ISClusResTypePossibleOwnerNodes **ppOwnerNodes);
  void __RPC_STUB ISClusResType_get_PossibleOwnerNodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResType_get_AvailableDisks_Proxy(ISClusResType *This,ISClusDisks **ppAvailableDisks);
  void __RPC_STUB ISClusResType_get_AvailableDisks_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResTypes_INTERFACE_DEFINED__
#define __ISClusResTypes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResTypes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResTypes : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResType **ppClusResType) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceTypeName,BSTR bstrDisplayName,BSTR bstrResourceTypeDll,__LONG32 dwLooksAlivePollInterval,__LONG32 dwIsAlivePollInterval,ISClusResType **ppResourceType) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResTypesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResTypes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResTypes *This);
      ULONG (WINAPI *Release)(ISClusResTypes *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResTypes *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResTypes *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResTypes *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResTypes *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResTypes *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResTypes *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResTypes *This);
      HRESULT (WINAPI *get_Item)(ISClusResTypes *This,VARIANT varIndex,ISClusResType **ppClusResType);
      HRESULT (WINAPI *CreateItem)(ISClusResTypes *This,BSTR bstrResourceTypeName,BSTR bstrDisplayName,BSTR bstrResourceTypeDll,__LONG32 dwLooksAlivePollInterval,__LONG32 dwIsAlivePollInterval,ISClusResType **ppResourceType);
      HRESULT (WINAPI *DeleteItem)(ISClusResTypes *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResTypesVtbl;
  struct ISClusResTypes {
    CONST_VTBL struct ISClusResTypesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResTypes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResTypes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResTypes_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResTypes_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResTypes_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResTypes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResTypes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResTypes_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResTypes_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResTypes_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResTypes_get_Item(This,varIndex,ppClusResType) (This)->lpVtbl->get_Item(This,varIndex,ppClusResType)
#define ISClusResTypes_CreateItem(This,bstrResourceTypeName,bstrDisplayName,bstrResourceTypeDll,dwLooksAlivePollInterval,dwIsAlivePollInterval,ppResourceType) (This)->lpVtbl->CreateItem(This,bstrResourceTypeName,bstrDisplayName,bstrResourceTypeDll,dwLooksAlivePollInterval,dwIsAlivePollInterval,ppResourceType)
#define ISClusResTypes_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResTypes_get_Count_Proxy(ISClusResTypes *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResTypes_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypes_get__NewEnum_Proxy(ISClusResTypes *This,IUnknown **retval);
  void __RPC_STUB ISClusResTypes_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypes_Refresh_Proxy(ISClusResTypes *This);
  void __RPC_STUB ISClusResTypes_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypes_get_Item_Proxy(ISClusResTypes *This,VARIANT varIndex,ISClusResType **ppClusResType);
  void __RPC_STUB ISClusResTypes_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypes_CreateItem_Proxy(ISClusResTypes *This,BSTR bstrResourceTypeName,BSTR bstrDisplayName,BSTR bstrResourceTypeDll,__LONG32 dwLooksAlivePollInterval,__LONG32 dwIsAlivePollInterval,ISClusResType **ppResourceType);
  void __RPC_STUB ISClusResTypes_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResTypes_DeleteItem_Proxy(ISClusResTypes *This,VARIANT varIndex);
  void __RPC_STUB ISClusResTypes_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusProperty_INTERFACE_DEFINED__
#define __ISClusProperty_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusProperty;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusProperty : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(BSTR *pbstrName) = 0;
    virtual HRESULT WINAPI get_Length(__LONG32 *pLength) = 0;
    virtual HRESULT WINAPI get_ValueCount(__LONG32 *pCount) = 0;
    virtual HRESULT WINAPI get_Values(ISClusPropertyValues **ppClusterPropertyValues) = 0;
    virtual HRESULT WINAPI get_Value(VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI put_Value(VARIANT varValue) = 0;
    virtual HRESULT WINAPI get_Type(CLUSTER_PROPERTY_TYPE *pType) = 0;
    virtual HRESULT WINAPI put_Type(CLUSTER_PROPERTY_TYPE Type) = 0;
    virtual HRESULT WINAPI get_Format(CLUSTER_PROPERTY_FORMAT *pFormat) = 0;
    virtual HRESULT WINAPI put_Format(CLUSTER_PROPERTY_FORMAT Format) = 0;
    virtual HRESULT WINAPI get_ReadOnly(VARIANT *pvarReadOnly) = 0;
    virtual HRESULT WINAPI get_Private(VARIANT *pvarPrivate) = 0;
    virtual HRESULT WINAPI get_Common(VARIANT *pvarCommon) = 0;
    virtual HRESULT WINAPI get_Modified(VARIANT *pvarModified) = 0;
    virtual HRESULT WINAPI UseDefaultValue(void) = 0;
  };
#else
  typedef struct ISClusPropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusProperty *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusProperty *This);
      ULONG (WINAPI *Release)(ISClusProperty *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusProperty *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusProperty *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusProperty *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusProperty *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(ISClusProperty *This,BSTR *pbstrName);
      HRESULT (WINAPI *get_Length)(ISClusProperty *This,__LONG32 *pLength);
      HRESULT (WINAPI *get_ValueCount)(ISClusProperty *This,__LONG32 *pCount);
      HRESULT (WINAPI *get_Values)(ISClusProperty *This,ISClusPropertyValues **ppClusterPropertyValues);
      HRESULT (WINAPI *get_Value)(ISClusProperty *This,VARIANT *pvarValue);
      HRESULT (WINAPI *put_Value)(ISClusProperty *This,VARIANT varValue);
      HRESULT (WINAPI *get_Type)(ISClusProperty *This,CLUSTER_PROPERTY_TYPE *pType);
      HRESULT (WINAPI *put_Type)(ISClusProperty *This,CLUSTER_PROPERTY_TYPE Type);
      HRESULT (WINAPI *get_Format)(ISClusProperty *This,CLUSTER_PROPERTY_FORMAT *pFormat);
      HRESULT (WINAPI *put_Format)(ISClusProperty *This,CLUSTER_PROPERTY_FORMAT Format);
      HRESULT (WINAPI *get_ReadOnly)(ISClusProperty *This,VARIANT *pvarReadOnly);
      HRESULT (WINAPI *get_Private)(ISClusProperty *This,VARIANT *pvarPrivate);
      HRESULT (WINAPI *get_Common)(ISClusProperty *This,VARIANT *pvarCommon);
      HRESULT (WINAPI *get_Modified)(ISClusProperty *This,VARIANT *pvarModified);
      HRESULT (WINAPI *UseDefaultValue)(ISClusProperty *This);
    END_INTERFACE
  } ISClusPropertyVtbl;
  struct ISClusProperty {
    CONST_VTBL struct ISClusPropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusProperty_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusProperty_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusProperty_Release(This) (This)->lpVtbl->Release(This)
#define ISClusProperty_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusProperty_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusProperty_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusProperty_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusProperty_get_Name(This,pbstrName) (This)->lpVtbl->get_Name(This,pbstrName)
#define ISClusProperty_get_Length(This,pLength) (This)->lpVtbl->get_Length(This,pLength)
#define ISClusProperty_get_ValueCount(This,pCount) (This)->lpVtbl->get_ValueCount(This,pCount)
#define ISClusProperty_get_Values(This,ppClusterPropertyValues) (This)->lpVtbl->get_Values(This,ppClusterPropertyValues)
#define ISClusProperty_get_Value(This,pvarValue) (This)->lpVtbl->get_Value(This,pvarValue)
#define ISClusProperty_put_Value(This,varValue) (This)->lpVtbl->put_Value(This,varValue)
#define ISClusProperty_get_Type(This,pType) (This)->lpVtbl->get_Type(This,pType)
#define ISClusProperty_put_Type(This,Type) (This)->lpVtbl->put_Type(This,Type)
#define ISClusProperty_get_Format(This,pFormat) (This)->lpVtbl->get_Format(This,pFormat)
#define ISClusProperty_put_Format(This,Format) (This)->lpVtbl->put_Format(This,Format)
#define ISClusProperty_get_ReadOnly(This,pvarReadOnly) (This)->lpVtbl->get_ReadOnly(This,pvarReadOnly)
#define ISClusProperty_get_Private(This,pvarPrivate) (This)->lpVtbl->get_Private(This,pvarPrivate)
#define ISClusProperty_get_Common(This,pvarCommon) (This)->lpVtbl->get_Common(This,pvarCommon)
#define ISClusProperty_get_Modified(This,pvarModified) (This)->lpVtbl->get_Modified(This,pvarModified)
#define ISClusProperty_UseDefaultValue(This) (This)->lpVtbl->UseDefaultValue(This)
#endif
#endif
  HRESULT WINAPI ISClusProperty_get_Name_Proxy(ISClusProperty *This,BSTR *pbstrName);
  void __RPC_STUB ISClusProperty_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Length_Proxy(ISClusProperty *This,__LONG32 *pLength);
  void __RPC_STUB ISClusProperty_get_Length_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_ValueCount_Proxy(ISClusProperty *This,__LONG32 *pCount);
  void __RPC_STUB ISClusProperty_get_ValueCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Values_Proxy(ISClusProperty *This,ISClusPropertyValues **ppClusterPropertyValues);
  void __RPC_STUB ISClusProperty_get_Values_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Value_Proxy(ISClusProperty *This,VARIANT *pvarValue);
  void __RPC_STUB ISClusProperty_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_put_Value_Proxy(ISClusProperty *This,VARIANT varValue);
  void __RPC_STUB ISClusProperty_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Type_Proxy(ISClusProperty *This,CLUSTER_PROPERTY_TYPE *pType);
  void __RPC_STUB ISClusProperty_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_put_Type_Proxy(ISClusProperty *This,CLUSTER_PROPERTY_TYPE Type);
  void __RPC_STUB ISClusProperty_put_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Format_Proxy(ISClusProperty *This,CLUSTER_PROPERTY_FORMAT *pFormat);
  void __RPC_STUB ISClusProperty_get_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_put_Format_Proxy(ISClusProperty *This,CLUSTER_PROPERTY_FORMAT Format);
  void __RPC_STUB ISClusProperty_put_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_ReadOnly_Proxy(ISClusProperty *This,VARIANT *pvarReadOnly);
  void __RPC_STUB ISClusProperty_get_ReadOnly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Private_Proxy(ISClusProperty *This,VARIANT *pvarPrivate);
  void __RPC_STUB ISClusProperty_get_Private_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Common_Proxy(ISClusProperty *This,VARIANT *pvarCommon);
  void __RPC_STUB ISClusProperty_get_Common_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_get_Modified_Proxy(ISClusProperty *This,VARIANT *pvarModified);
  void __RPC_STUB ISClusProperty_get_Modified_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperty_UseDefaultValue_Proxy(ISClusProperty *This);
  void __RPC_STUB ISClusProperty_UseDefaultValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusPropertyValue_INTERFACE_DEFINED__
#define __ISClusPropertyValue_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusPropertyValue;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusPropertyValue : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Value(VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI put_Value(VARIANT varValue) = 0;
    virtual HRESULT WINAPI get_Type(CLUSTER_PROPERTY_TYPE *pType) = 0;
    virtual HRESULT WINAPI put_Type(CLUSTER_PROPERTY_TYPE Type) = 0;
    virtual HRESULT WINAPI get_Format(CLUSTER_PROPERTY_FORMAT *pFormat) = 0;
    virtual HRESULT WINAPI put_Format(CLUSTER_PROPERTY_FORMAT Format) = 0;
    virtual HRESULT WINAPI get_Length(__LONG32 *pLength) = 0;
    virtual HRESULT WINAPI get_DataCount(__LONG32 *pCount) = 0;
    virtual HRESULT WINAPI get_Data(ISClusPropertyValueData **ppClusterPropertyValueData) = 0;
  };
#else
  typedef struct ISClusPropertyValueVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusPropertyValue *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusPropertyValue *This);
      ULONG (WINAPI *Release)(ISClusPropertyValue *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusPropertyValue *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusPropertyValue *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusPropertyValue *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusPropertyValue *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Value)(ISClusPropertyValue *This,VARIANT *pvarValue);
      HRESULT (WINAPI *put_Value)(ISClusPropertyValue *This,VARIANT varValue);
      HRESULT (WINAPI *get_Type)(ISClusPropertyValue *This,CLUSTER_PROPERTY_TYPE *pType);
      HRESULT (WINAPI *put_Type)(ISClusPropertyValue *This,CLUSTER_PROPERTY_TYPE Type);
      HRESULT (WINAPI *get_Format)(ISClusPropertyValue *This,CLUSTER_PROPERTY_FORMAT *pFormat);
      HRESULT (WINAPI *put_Format)(ISClusPropertyValue *This,CLUSTER_PROPERTY_FORMAT Format);
      HRESULT (WINAPI *get_Length)(ISClusPropertyValue *This,__LONG32 *pLength);
      HRESULT (WINAPI *get_DataCount)(ISClusPropertyValue *This,__LONG32 *pCount);
      HRESULT (WINAPI *get_Data)(ISClusPropertyValue *This,ISClusPropertyValueData **ppClusterPropertyValueData);
    END_INTERFACE
  } ISClusPropertyValueVtbl;
  struct ISClusPropertyValue {
    CONST_VTBL struct ISClusPropertyValueVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusPropertyValue_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusPropertyValue_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusPropertyValue_Release(This) (This)->lpVtbl->Release(This)
#define ISClusPropertyValue_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusPropertyValue_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusPropertyValue_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusPropertyValue_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusPropertyValue_get_Value(This,pvarValue) (This)->lpVtbl->get_Value(This,pvarValue)
#define ISClusPropertyValue_put_Value(This,varValue) (This)->lpVtbl->put_Value(This,varValue)
#define ISClusPropertyValue_get_Type(This,pType) (This)->lpVtbl->get_Type(This,pType)
#define ISClusPropertyValue_put_Type(This,Type) (This)->lpVtbl->put_Type(This,Type)
#define ISClusPropertyValue_get_Format(This,pFormat) (This)->lpVtbl->get_Format(This,pFormat)
#define ISClusPropertyValue_put_Format(This,Format) (This)->lpVtbl->put_Format(This,Format)
#define ISClusPropertyValue_get_Length(This,pLength) (This)->lpVtbl->get_Length(This,pLength)
#define ISClusPropertyValue_get_DataCount(This,pCount) (This)->lpVtbl->get_DataCount(This,pCount)
#define ISClusPropertyValue_get_Data(This,ppClusterPropertyValueData) (This)->lpVtbl->get_Data(This,ppClusterPropertyValueData)
#endif
#endif
  HRESULT WINAPI ISClusPropertyValue_get_Value_Proxy(ISClusPropertyValue *This,VARIANT *pvarValue);
  void __RPC_STUB ISClusPropertyValue_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_put_Value_Proxy(ISClusPropertyValue *This,VARIANT varValue);
  void __RPC_STUB ISClusPropertyValue_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_get_Type_Proxy(ISClusPropertyValue *This,CLUSTER_PROPERTY_TYPE *pType);
  void __RPC_STUB ISClusPropertyValue_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_put_Type_Proxy(ISClusPropertyValue *This,CLUSTER_PROPERTY_TYPE Type);
  void __RPC_STUB ISClusPropertyValue_put_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_get_Format_Proxy(ISClusPropertyValue *This,CLUSTER_PROPERTY_FORMAT *pFormat);
  void __RPC_STUB ISClusPropertyValue_get_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_put_Format_Proxy(ISClusPropertyValue *This,CLUSTER_PROPERTY_FORMAT Format);
  void __RPC_STUB ISClusPropertyValue_put_Format_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_get_Length_Proxy(ISClusPropertyValue *This,__LONG32 *pLength);
  void __RPC_STUB ISClusPropertyValue_get_Length_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_get_DataCount_Proxy(ISClusPropertyValue *This,__LONG32 *pCount);
  void __RPC_STUB ISClusPropertyValue_get_DataCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValue_get_Data_Proxy(ISClusPropertyValue *This,ISClusPropertyValueData **ppClusterPropertyValueData);
  void __RPC_STUB ISClusPropertyValue_get_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusPropertyValues_INTERFACE_DEFINED__
#define __ISClusPropertyValues_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusPropertyValues;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusPropertyValues : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusPropertyValue **ppPropertyValue) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrName,VARIANT varValue,ISClusPropertyValue **ppPropertyValue) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusPropertyValuesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusPropertyValues *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusPropertyValues *This);
      ULONG (WINAPI *Release)(ISClusPropertyValues *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusPropertyValues *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusPropertyValues *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusPropertyValues *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusPropertyValues *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusPropertyValues *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusPropertyValues *This,IUnknown **retval);
      HRESULT (WINAPI *get_Item)(ISClusPropertyValues *This,VARIANT varIndex,ISClusPropertyValue **ppPropertyValue);
      HRESULT (WINAPI *CreateItem)(ISClusPropertyValues *This,BSTR bstrName,VARIANT varValue,ISClusPropertyValue **ppPropertyValue);
      HRESULT (WINAPI *RemoveItem)(ISClusPropertyValues *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusPropertyValuesVtbl;
  struct ISClusPropertyValues {
    CONST_VTBL struct ISClusPropertyValuesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusPropertyValues_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusPropertyValues_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusPropertyValues_Release(This) (This)->lpVtbl->Release(This)
#define ISClusPropertyValues_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusPropertyValues_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusPropertyValues_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusPropertyValues_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusPropertyValues_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusPropertyValues_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusPropertyValues_get_Item(This,varIndex,ppPropertyValue) (This)->lpVtbl->get_Item(This,varIndex,ppPropertyValue)
#define ISClusPropertyValues_CreateItem(This,bstrName,varValue,ppPropertyValue) (This)->lpVtbl->CreateItem(This,bstrName,varValue,ppPropertyValue)
#define ISClusPropertyValues_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusPropertyValues_get_Count_Proxy(ISClusPropertyValues *This,__LONG32 *plCount);
  void __RPC_STUB ISClusPropertyValues_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValues_get__NewEnum_Proxy(ISClusPropertyValues *This,IUnknown **retval);
  void __RPC_STUB ISClusPropertyValues_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValues_get_Item_Proxy(ISClusPropertyValues *This,VARIANT varIndex,ISClusPropertyValue **ppPropertyValue);
  void __RPC_STUB ISClusPropertyValues_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValues_CreateItem_Proxy(ISClusPropertyValues *This,BSTR bstrName,VARIANT varValue,ISClusPropertyValue **ppPropertyValue);
  void __RPC_STUB ISClusPropertyValues_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValues_RemoveItem_Proxy(ISClusPropertyValues *This,VARIANT varIndex);
  void __RPC_STUB ISClusPropertyValues_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusProperties_INTERFACE_DEFINED__
#define __ISClusProperties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusProperties : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusProperty **ppClusProperty) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrName,VARIANT varValue,ISClusProperty **pProperty) = 0;
    virtual HRESULT WINAPI UseDefaultValue(VARIANT varIndex) = 0;
    virtual HRESULT WINAPI SaveChanges(VARIANT *pvarStatusCode = 0) = 0;
    virtual HRESULT WINAPI get_ReadOnly(VARIANT *pvarReadOnly) = 0;
    virtual HRESULT WINAPI get_Private(VARIANT *pvarPrivate) = 0;
    virtual HRESULT WINAPI get_Common(VARIANT *pvarCommon) = 0;
    virtual HRESULT WINAPI get_Modified(VARIANT *pvarModified) = 0;
  };
#else
  typedef struct ISClusPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusProperties *This);
      ULONG (WINAPI *Release)(ISClusProperties *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusProperties *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusProperties *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusProperties *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusProperties *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusProperties *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusProperties *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusProperties *This);
      HRESULT (WINAPI *get_Item)(ISClusProperties *This,VARIANT varIndex,ISClusProperty **ppClusProperty);
      HRESULT (WINAPI *CreateItem)(ISClusProperties *This,BSTR bstrName,VARIANT varValue,ISClusProperty **pProperty);
      HRESULT (WINAPI *UseDefaultValue)(ISClusProperties *This,VARIANT varIndex);
      HRESULT (WINAPI *SaveChanges)(ISClusProperties *This,VARIANT *pvarStatusCode);
      HRESULT (WINAPI *get_ReadOnly)(ISClusProperties *This,VARIANT *pvarReadOnly);
      HRESULT (WINAPI *get_Private)(ISClusProperties *This,VARIANT *pvarPrivate);
      HRESULT (WINAPI *get_Common)(ISClusProperties *This,VARIANT *pvarCommon);
      HRESULT (WINAPI *get_Modified)(ISClusProperties *This,VARIANT *pvarModified);
    END_INTERFACE
  } ISClusPropertiesVtbl;
  struct ISClusProperties {
    CONST_VTBL struct ISClusPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusProperties_Release(This) (This)->lpVtbl->Release(This)
#define ISClusProperties_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusProperties_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusProperties_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusProperties_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusProperties_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusProperties_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusProperties_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusProperties_get_Item(This,varIndex,ppClusProperty) (This)->lpVtbl->get_Item(This,varIndex,ppClusProperty)
#define ISClusProperties_CreateItem(This,bstrName,varValue,pProperty) (This)->lpVtbl->CreateItem(This,bstrName,varValue,pProperty)
#define ISClusProperties_UseDefaultValue(This,varIndex) (This)->lpVtbl->UseDefaultValue(This,varIndex)
#define ISClusProperties_SaveChanges(This,pvarStatusCode) (This)->lpVtbl->SaveChanges(This,pvarStatusCode)
#define ISClusProperties_get_ReadOnly(This,pvarReadOnly) (This)->lpVtbl->get_ReadOnly(This,pvarReadOnly)
#define ISClusProperties_get_Private(This,pvarPrivate) (This)->lpVtbl->get_Private(This,pvarPrivate)
#define ISClusProperties_get_Common(This,pvarCommon) (This)->lpVtbl->get_Common(This,pvarCommon)
#define ISClusProperties_get_Modified(This,pvarModified) (This)->lpVtbl->get_Modified(This,pvarModified)
#endif
#endif
  HRESULT WINAPI ISClusProperties_get_Count_Proxy(ISClusProperties *This,__LONG32 *plCount);
  void __RPC_STUB ISClusProperties_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_get__NewEnum_Proxy(ISClusProperties *This,IUnknown **retval);
  void __RPC_STUB ISClusProperties_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_Refresh_Proxy(ISClusProperties *This);
  void __RPC_STUB ISClusProperties_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_get_Item_Proxy(ISClusProperties *This,VARIANT varIndex,ISClusProperty **ppClusProperty);
  void __RPC_STUB ISClusProperties_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_CreateItem_Proxy(ISClusProperties *This,BSTR bstrName,VARIANT varValue,ISClusProperty **pProperty);
  void __RPC_STUB ISClusProperties_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_UseDefaultValue_Proxy(ISClusProperties *This,VARIANT varIndex);
  void __RPC_STUB ISClusProperties_UseDefaultValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_SaveChanges_Proxy(ISClusProperties *This,VARIANT *pvarStatusCode);
  void __RPC_STUB ISClusProperties_SaveChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_get_ReadOnly_Proxy(ISClusProperties *This,VARIANT *pvarReadOnly);
  void __RPC_STUB ISClusProperties_get_ReadOnly_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_get_Private_Proxy(ISClusProperties *This,VARIANT *pvarPrivate);
  void __RPC_STUB ISClusProperties_get_Private_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_get_Common_Proxy(ISClusProperties *This,VARIANT *pvarCommon);
  void __RPC_STUB ISClusProperties_get_Common_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusProperties_get_Modified_Proxy(ISClusProperties *This,VARIANT *pvarModified);
  void __RPC_STUB ISClusProperties_get_Modified_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusPropertyValueData_INTERFACE_DEFINED__
#define __ISClusPropertyValueData_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusPropertyValueData;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusPropertyValueData : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI CreateItem(VARIANT varValue,VARIANT *pvarData) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusPropertyValueDataVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusPropertyValueData *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusPropertyValueData *This);
      ULONG (WINAPI *Release)(ISClusPropertyValueData *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusPropertyValueData *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusPropertyValueData *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusPropertyValueData *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusPropertyValueData *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusPropertyValueData *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusPropertyValueData *This,IUnknown **retval);
      HRESULT (WINAPI *get_Item)(ISClusPropertyValueData *This,VARIANT varIndex,VARIANT *pvarValue);
      HRESULT (WINAPI *CreateItem)(ISClusPropertyValueData *This,VARIANT varValue,VARIANT *pvarData);
      HRESULT (WINAPI *RemoveItem)(ISClusPropertyValueData *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusPropertyValueDataVtbl;
  struct ISClusPropertyValueData {
    CONST_VTBL struct ISClusPropertyValueDataVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusPropertyValueData_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusPropertyValueData_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusPropertyValueData_Release(This) (This)->lpVtbl->Release(This)
#define ISClusPropertyValueData_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusPropertyValueData_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusPropertyValueData_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusPropertyValueData_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusPropertyValueData_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusPropertyValueData_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusPropertyValueData_get_Item(This,varIndex,pvarValue) (This)->lpVtbl->get_Item(This,varIndex,pvarValue)
#define ISClusPropertyValueData_CreateItem(This,varValue,pvarData) (This)->lpVtbl->CreateItem(This,varValue,pvarData)
#define ISClusPropertyValueData_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusPropertyValueData_get_Count_Proxy(ISClusPropertyValueData *This,__LONG32 *plCount);
  void __RPC_STUB ISClusPropertyValueData_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValueData_get__NewEnum_Proxy(ISClusPropertyValueData *This,IUnknown **retval);
  void __RPC_STUB ISClusPropertyValueData_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValueData_get_Item_Proxy(ISClusPropertyValueData *This,VARIANT varIndex,VARIANT *pvarValue);
  void __RPC_STUB ISClusPropertyValueData_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValueData_CreateItem_Proxy(ISClusPropertyValueData *This,VARIANT varValue,VARIANT *pvarData);
  void __RPC_STUB ISClusPropertyValueData_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPropertyValueData_RemoveItem_Proxy(ISClusPropertyValueData *This,VARIANT varIndex);
  void __RPC_STUB ISClusPropertyValueData_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusPartition_INTERFACE_DEFINED__
#define __ISClusPartition_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusPartition;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusPartition : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Flags(__LONG32 *plFlags) = 0;
    virtual HRESULT WINAPI get_DeviceName(BSTR *pbstrDeviceName) = 0;
    virtual HRESULT WINAPI get_VolumeLabel(BSTR *pbstrVolumeLabel) = 0;
    virtual HRESULT WINAPI get_SerialNumber(__LONG32 *plSerialNumber) = 0;
    virtual HRESULT WINAPI get_MaximumComponentLength(__LONG32 *plMaximumComponentLength) = 0;
    virtual HRESULT WINAPI get_FileSystemFlags(__LONG32 *plFileSystemFlags) = 0;
    virtual HRESULT WINAPI get_FileSystem(BSTR *pbstrFileSystem) = 0;
  };
#else
  typedef struct ISClusPartitionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusPartition *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusPartition *This);
      ULONG (WINAPI *Release)(ISClusPartition *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusPartition *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusPartition *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusPartition *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusPartition *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Flags)(ISClusPartition *This,__LONG32 *plFlags);
      HRESULT (WINAPI *get_DeviceName)(ISClusPartition *This,BSTR *pbstrDeviceName);
      HRESULT (WINAPI *get_VolumeLabel)(ISClusPartition *This,BSTR *pbstrVolumeLabel);
      HRESULT (WINAPI *get_SerialNumber)(ISClusPartition *This,__LONG32 *plSerialNumber);
      HRESULT (WINAPI *get_MaximumComponentLength)(ISClusPartition *This,__LONG32 *plMaximumComponentLength);
      HRESULT (WINAPI *get_FileSystemFlags)(ISClusPartition *This,__LONG32 *plFileSystemFlags);
      HRESULT (WINAPI *get_FileSystem)(ISClusPartition *This,BSTR *pbstrFileSystem);
    END_INTERFACE
  } ISClusPartitionVtbl;
  struct ISClusPartition {
    CONST_VTBL struct ISClusPartitionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusPartition_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusPartition_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusPartition_Release(This) (This)->lpVtbl->Release(This)
#define ISClusPartition_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusPartition_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusPartition_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusPartition_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusPartition_get_Flags(This,plFlags) (This)->lpVtbl->get_Flags(This,plFlags)
#define ISClusPartition_get_DeviceName(This,pbstrDeviceName) (This)->lpVtbl->get_DeviceName(This,pbstrDeviceName)
#define ISClusPartition_get_VolumeLabel(This,pbstrVolumeLabel) (This)->lpVtbl->get_VolumeLabel(This,pbstrVolumeLabel)
#define ISClusPartition_get_SerialNumber(This,plSerialNumber) (This)->lpVtbl->get_SerialNumber(This,plSerialNumber)
#define ISClusPartition_get_MaximumComponentLength(This,plMaximumComponentLength) (This)->lpVtbl->get_MaximumComponentLength(This,plMaximumComponentLength)
#define ISClusPartition_get_FileSystemFlags(This,plFileSystemFlags) (This)->lpVtbl->get_FileSystemFlags(This,plFileSystemFlags)
#define ISClusPartition_get_FileSystem(This,pbstrFileSystem) (This)->lpVtbl->get_FileSystem(This,pbstrFileSystem)
#endif
#endif
  HRESULT WINAPI ISClusPartition_get_Flags_Proxy(ISClusPartition *This,__LONG32 *plFlags);
  void __RPC_STUB ISClusPartition_get_Flags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartition_get_DeviceName_Proxy(ISClusPartition *This,BSTR *pbstrDeviceName);
  void __RPC_STUB ISClusPartition_get_DeviceName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartition_get_VolumeLabel_Proxy(ISClusPartition *This,BSTR *pbstrVolumeLabel);
  void __RPC_STUB ISClusPartition_get_VolumeLabel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartition_get_SerialNumber_Proxy(ISClusPartition *This,__LONG32 *plSerialNumber);
  void __RPC_STUB ISClusPartition_get_SerialNumber_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartition_get_MaximumComponentLength_Proxy(ISClusPartition *This,__LONG32 *plMaximumComponentLength);
  void __RPC_STUB ISClusPartition_get_MaximumComponentLength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartition_get_FileSystemFlags_Proxy(ISClusPartition *This,__LONG32 *plFileSystemFlags);
  void __RPC_STUB ISClusPartition_get_FileSystemFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartition_get_FileSystem_Proxy(ISClusPartition *This,BSTR *pbstrFileSystem);
  void __RPC_STUB ISClusPartition_get_FileSystem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusPartitions_INTERFACE_DEFINED__
#define __ISClusPartitions_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusPartitions;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusPartitions : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusPartition **ppPartition) = 0;
  };
#else
  typedef struct ISClusPartitionsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusPartitions *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusPartitions *This);
      ULONG (WINAPI *Release)(ISClusPartitions *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusPartitions *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusPartitions *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusPartitions *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusPartitions *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusPartitions *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusPartitions *This,IUnknown **retval);
      HRESULT (WINAPI *get_Item)(ISClusPartitions *This,VARIANT varIndex,ISClusPartition **ppPartition);
    END_INTERFACE
  } ISClusPartitionsVtbl;
  struct ISClusPartitions {
    CONST_VTBL struct ISClusPartitionsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusPartitions_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusPartitions_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusPartitions_Release(This) (This)->lpVtbl->Release(This)
#define ISClusPartitions_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusPartitions_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusPartitions_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusPartitions_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusPartitions_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusPartitions_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusPartitions_get_Item(This,varIndex,ppPartition) (This)->lpVtbl->get_Item(This,varIndex,ppPartition)
#endif
#endif
  HRESULT WINAPI ISClusPartitions_get_Count_Proxy(ISClusPartitions *This,__LONG32 *plCount);
  void __RPC_STUB ISClusPartitions_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartitions_get__NewEnum_Proxy(ISClusPartitions *This,IUnknown **retval);
  void __RPC_STUB ISClusPartitions_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusPartitions_get_Item_Proxy(ISClusPartitions *This,VARIANT varIndex,ISClusPartition **ppPartition);
  void __RPC_STUB ISClusPartitions_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusDisk_INTERFACE_DEFINED__
#define __ISClusDisk_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusDisk;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusDisk : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Signature(__LONG32 *plSignature) = 0;
    virtual HRESULT WINAPI get_ScsiAddress(ISClusScsiAddress **ppScsiAddress) = 0;
    virtual HRESULT WINAPI get_DiskNumber(__LONG32 *plDiskNumber) = 0;
    virtual HRESULT WINAPI get_Partitions(ISClusPartitions **ppPartitions) = 0;
  };
#else
  typedef struct ISClusDiskVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusDisk *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusDisk *This);
      ULONG (WINAPI *Release)(ISClusDisk *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusDisk *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusDisk *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusDisk *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusDisk *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Signature)(ISClusDisk *This,__LONG32 *plSignature);
      HRESULT (WINAPI *get_ScsiAddress)(ISClusDisk *This,ISClusScsiAddress **ppScsiAddress);
      HRESULT (WINAPI *get_DiskNumber)(ISClusDisk *This,__LONG32 *plDiskNumber);
      HRESULT (WINAPI *get_Partitions)(ISClusDisk *This,ISClusPartitions **ppPartitions);
    END_INTERFACE
  } ISClusDiskVtbl;
  struct ISClusDisk {
    CONST_VTBL struct ISClusDiskVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusDisk_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusDisk_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusDisk_Release(This) (This)->lpVtbl->Release(This)
#define ISClusDisk_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusDisk_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusDisk_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusDisk_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusDisk_get_Signature(This,plSignature) (This)->lpVtbl->get_Signature(This,plSignature)
#define ISClusDisk_get_ScsiAddress(This,ppScsiAddress) (This)->lpVtbl->get_ScsiAddress(This,ppScsiAddress)
#define ISClusDisk_get_DiskNumber(This,plDiskNumber) (This)->lpVtbl->get_DiskNumber(This,plDiskNumber)
#define ISClusDisk_get_Partitions(This,ppPartitions) (This)->lpVtbl->get_Partitions(This,ppPartitions)
#endif
#endif
  HRESULT WINAPI ISClusDisk_get_Signature_Proxy(ISClusDisk *This,__LONG32 *plSignature);
  void __RPC_STUB ISClusDisk_get_Signature_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusDisk_get_ScsiAddress_Proxy(ISClusDisk *This,ISClusScsiAddress **ppScsiAddress);
  void __RPC_STUB ISClusDisk_get_ScsiAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusDisk_get_DiskNumber_Proxy(ISClusDisk *This,__LONG32 *plDiskNumber);
  void __RPC_STUB ISClusDisk_get_DiskNumber_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusDisk_get_Partitions_Proxy(ISClusDisk *This,ISClusPartitions **ppPartitions);
  void __RPC_STUB ISClusDisk_get_Partitions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusDisks_INTERFACE_DEFINED__
#define __ISClusDisks_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusDisks;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusDisks : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusDisk **ppDisk) = 0;
  };
#else
  typedef struct ISClusDisksVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusDisks *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusDisks *This);
      ULONG (WINAPI *Release)(ISClusDisks *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusDisks *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusDisks *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusDisks *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusDisks *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusDisks *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusDisks *This,IUnknown **retval);
      HRESULT (WINAPI *get_Item)(ISClusDisks *This,VARIANT varIndex,ISClusDisk **ppDisk);
    END_INTERFACE
  } ISClusDisksVtbl;
  struct ISClusDisks {
    CONST_VTBL struct ISClusDisksVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusDisks_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusDisks_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusDisks_Release(This) (This)->lpVtbl->Release(This)
#define ISClusDisks_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusDisks_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusDisks_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusDisks_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusDisks_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusDisks_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusDisks_get_Item(This,varIndex,ppDisk) (This)->lpVtbl->get_Item(This,varIndex,ppDisk)
#endif
#endif
  HRESULT WINAPI ISClusDisks_get_Count_Proxy(ISClusDisks *This,__LONG32 *plCount);
  void __RPC_STUB ISClusDisks_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusDisks_get__NewEnum_Proxy(ISClusDisks *This,IUnknown **retval);
  void __RPC_STUB ISClusDisks_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusDisks_get_Item_Proxy(ISClusDisks *This,VARIANT varIndex,ISClusDisk **ppDisk);
  void __RPC_STUB ISClusDisks_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusScsiAddress_INTERFACE_DEFINED__
#define __ISClusScsiAddress_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusScsiAddress;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusScsiAddress : public IDispatch {
  public:
    virtual HRESULT WINAPI get_PortNumber(VARIANT *pvarPortNumber) = 0;
    virtual HRESULT WINAPI get_PathId(VARIANT *pvarPathId) = 0;
    virtual HRESULT WINAPI get_TargetId(VARIANT *pvarTargetId) = 0;
    virtual HRESULT WINAPI get_Lun(VARIANT *pvarLun) = 0;
  };
#else
  typedef struct ISClusScsiAddressVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusScsiAddress *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusScsiAddress *This);
      ULONG (WINAPI *Release)(ISClusScsiAddress *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusScsiAddress *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusScsiAddress *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusScsiAddress *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusScsiAddress *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_PortNumber)(ISClusScsiAddress *This,VARIANT *pvarPortNumber);
      HRESULT (WINAPI *get_PathId)(ISClusScsiAddress *This,VARIANT *pvarPathId);
      HRESULT (WINAPI *get_TargetId)(ISClusScsiAddress *This,VARIANT *pvarTargetId);
      HRESULT (WINAPI *get_Lun)(ISClusScsiAddress *This,VARIANT *pvarLun);
    END_INTERFACE
  } ISClusScsiAddressVtbl;
  struct ISClusScsiAddress {
    CONST_VTBL struct ISClusScsiAddressVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusScsiAddress_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusScsiAddress_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusScsiAddress_Release(This) (This)->lpVtbl->Release(This)
#define ISClusScsiAddress_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusScsiAddress_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusScsiAddress_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusScsiAddress_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusScsiAddress_get_PortNumber(This,pvarPortNumber) (This)->lpVtbl->get_PortNumber(This,pvarPortNumber)
#define ISClusScsiAddress_get_PathId(This,pvarPathId) (This)->lpVtbl->get_PathId(This,pvarPathId)
#define ISClusScsiAddress_get_TargetId(This,pvarTargetId) (This)->lpVtbl->get_TargetId(This,pvarTargetId)
#define ISClusScsiAddress_get_Lun(This,pvarLun) (This)->lpVtbl->get_Lun(This,pvarLun)
#endif
#endif
  HRESULT WINAPI ISClusScsiAddress_get_PortNumber_Proxy(ISClusScsiAddress *This,VARIANT *pvarPortNumber);
  void __RPC_STUB ISClusScsiAddress_get_PortNumber_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusScsiAddress_get_PathId_Proxy(ISClusScsiAddress *This,VARIANT *pvarPathId);
  void __RPC_STUB ISClusScsiAddress_get_PathId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusScsiAddress_get_TargetId_Proxy(ISClusScsiAddress *This,VARIANT *pvarTargetId);
  void __RPC_STUB ISClusScsiAddress_get_TargetId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusScsiAddress_get_Lun_Proxy(ISClusScsiAddress *This,VARIANT *pvarLun);
  void __RPC_STUB ISClusScsiAddress_get_Lun_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusRegistryKeys_INTERFACE_DEFINED__
#define __ISClusRegistryKeys_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusRegistryKeys;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusRegistryKeys : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,BSTR *pbstrRegistryKey) = 0;
    virtual HRESULT WINAPI AddItem(BSTR bstrRegistryKey) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusRegistryKeysVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusRegistryKeys *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusRegistryKeys *This);
      ULONG (WINAPI *Release)(ISClusRegistryKeys *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusRegistryKeys *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusRegistryKeys *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusRegistryKeys *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusRegistryKeys *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusRegistryKeys *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusRegistryKeys *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusRegistryKeys *This);
      HRESULT (WINAPI *get_Item)(ISClusRegistryKeys *This,VARIANT varIndex,BSTR *pbstrRegistryKey);
      HRESULT (WINAPI *AddItem)(ISClusRegistryKeys *This,BSTR bstrRegistryKey);
      HRESULT (WINAPI *RemoveItem)(ISClusRegistryKeys *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusRegistryKeysVtbl;
  struct ISClusRegistryKeys {
    CONST_VTBL struct ISClusRegistryKeysVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusRegistryKeys_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusRegistryKeys_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusRegistryKeys_Release(This) (This)->lpVtbl->Release(This)
#define ISClusRegistryKeys_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusRegistryKeys_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusRegistryKeys_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusRegistryKeys_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusRegistryKeys_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusRegistryKeys_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusRegistryKeys_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusRegistryKeys_get_Item(This,varIndex,pbstrRegistryKey) (This)->lpVtbl->get_Item(This,varIndex,pbstrRegistryKey)
#define ISClusRegistryKeys_AddItem(This,bstrRegistryKey) (This)->lpVtbl->AddItem(This,bstrRegistryKey)
#define ISClusRegistryKeys_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusRegistryKeys_get_Count_Proxy(ISClusRegistryKeys *This,__LONG32 *plCount);
  void __RPC_STUB ISClusRegistryKeys_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusRegistryKeys_get__NewEnum_Proxy(ISClusRegistryKeys *This,IUnknown **retval);
  void __RPC_STUB ISClusRegistryKeys_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusRegistryKeys_Refresh_Proxy(ISClusRegistryKeys *This);
  void __RPC_STUB ISClusRegistryKeys_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusRegistryKeys_get_Item_Proxy(ISClusRegistryKeys *This,VARIANT varIndex,BSTR *pbstrRegistryKey);
  void __RPC_STUB ISClusRegistryKeys_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusRegistryKeys_AddItem_Proxy(ISClusRegistryKeys *This,BSTR bstrRegistryKey);
  void __RPC_STUB ISClusRegistryKeys_AddItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusRegistryKeys_RemoveItem_Proxy(ISClusRegistryKeys *This,VARIANT varIndex);
  void __RPC_STUB ISClusRegistryKeys_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusCryptoKeys_INTERFACE_DEFINED__
#define __ISClusCryptoKeys_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusCryptoKeys;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusCryptoKeys : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,BSTR *pbstrCyrptoKey) = 0;
    virtual HRESULT WINAPI AddItem(BSTR bstrCryptoKey) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusCryptoKeysVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusCryptoKeys *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusCryptoKeys *This);
      ULONG (WINAPI *Release)(ISClusCryptoKeys *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusCryptoKeys *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusCryptoKeys *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusCryptoKeys *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusCryptoKeys *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusCryptoKeys *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusCryptoKeys *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusCryptoKeys *This);
      HRESULT (WINAPI *get_Item)(ISClusCryptoKeys *This,VARIANT varIndex,BSTR *pbstrCyrptoKey);
      HRESULT (WINAPI *AddItem)(ISClusCryptoKeys *This,BSTR bstrCryptoKey);
      HRESULT (WINAPI *RemoveItem)(ISClusCryptoKeys *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusCryptoKeysVtbl;
  struct ISClusCryptoKeys {
    CONST_VTBL struct ISClusCryptoKeysVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusCryptoKeys_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusCryptoKeys_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusCryptoKeys_Release(This) (This)->lpVtbl->Release(This)
#define ISClusCryptoKeys_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusCryptoKeys_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusCryptoKeys_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusCryptoKeys_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusCryptoKeys_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusCryptoKeys_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusCryptoKeys_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusCryptoKeys_get_Item(This,varIndex,pbstrCyrptoKey) (This)->lpVtbl->get_Item(This,varIndex,pbstrCyrptoKey)
#define ISClusCryptoKeys_AddItem(This,bstrCryptoKey) (This)->lpVtbl->AddItem(This,bstrCryptoKey)
#define ISClusCryptoKeys_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusCryptoKeys_get_Count_Proxy(ISClusCryptoKeys *This,__LONG32 *plCount);
  void __RPC_STUB ISClusCryptoKeys_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusCryptoKeys_get__NewEnum_Proxy(ISClusCryptoKeys *This,IUnknown **retval);
  void __RPC_STUB ISClusCryptoKeys_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusCryptoKeys_Refresh_Proxy(ISClusCryptoKeys *This);
  void __RPC_STUB ISClusCryptoKeys_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusCryptoKeys_get_Item_Proxy(ISClusCryptoKeys *This,VARIANT varIndex,BSTR *pbstrCyrptoKey);
  void __RPC_STUB ISClusCryptoKeys_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusCryptoKeys_AddItem_Proxy(ISClusCryptoKeys *This,BSTR bstrCryptoKey);
  void __RPC_STUB ISClusCryptoKeys_AddItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusCryptoKeys_RemoveItem_Proxy(ISClusCryptoKeys *This,VARIANT varIndex);
  void __RPC_STUB ISClusCryptoKeys_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISClusResDependents_INTERFACE_DEFINED__
#define __ISClusResDependents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISClusResDependents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISClusResDependents : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT varIndex,ISClusResource **ppClusResource) = 0;
    virtual HRESULT WINAPI CreateItem(BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource) = 0;
    virtual HRESULT WINAPI DeleteItem(VARIANT varIndex) = 0;
    virtual HRESULT WINAPI AddItem(ISClusResource *pResource) = 0;
    virtual HRESULT WINAPI RemoveItem(VARIANT varIndex) = 0;
  };
#else
  typedef struct ISClusResDependentsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISClusResDependents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISClusResDependents *This);
      ULONG (WINAPI *Release)(ISClusResDependents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISClusResDependents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISClusResDependents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISClusResDependents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISClusResDependents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISClusResDependents *This,__LONG32 *plCount);
      HRESULT (WINAPI *get__NewEnum)(ISClusResDependents *This,IUnknown **retval);
      HRESULT (WINAPI *Refresh)(ISClusResDependents *This);
      HRESULT (WINAPI *get_Item)(ISClusResDependents *This,VARIANT varIndex,ISClusResource **ppClusResource);
      HRESULT (WINAPI *CreateItem)(ISClusResDependents *This,BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
      HRESULT (WINAPI *DeleteItem)(ISClusResDependents *This,VARIANT varIndex);
      HRESULT (WINAPI *AddItem)(ISClusResDependents *This,ISClusResource *pResource);
      HRESULT (WINAPI *RemoveItem)(ISClusResDependents *This,VARIANT varIndex);
    END_INTERFACE
  } ISClusResDependentsVtbl;
  struct ISClusResDependents {
    CONST_VTBL struct ISClusResDependentsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISClusResDependents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISClusResDependents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISClusResDependents_Release(This) (This)->lpVtbl->Release(This)
#define ISClusResDependents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISClusResDependents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISClusResDependents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISClusResDependents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISClusResDependents_get_Count(This,plCount) (This)->lpVtbl->get_Count(This,plCount)
#define ISClusResDependents_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ISClusResDependents_Refresh(This) (This)->lpVtbl->Refresh(This)
#define ISClusResDependents_get_Item(This,varIndex,ppClusResource) (This)->lpVtbl->get_Item(This,varIndex,ppClusResource)
#define ISClusResDependents_CreateItem(This,bstrResourceName,bstrResourceType,dwFlags,ppClusterResource) (This)->lpVtbl->CreateItem(This,bstrResourceName,bstrResourceType,dwFlags,ppClusterResource)
#define ISClusResDependents_DeleteItem(This,varIndex) (This)->lpVtbl->DeleteItem(This,varIndex)
#define ISClusResDependents_AddItem(This,pResource) (This)->lpVtbl->AddItem(This,pResource)
#define ISClusResDependents_RemoveItem(This,varIndex) (This)->lpVtbl->RemoveItem(This,varIndex)
#endif
#endif
  HRESULT WINAPI ISClusResDependents_get_Count_Proxy(ISClusResDependents *This,__LONG32 *plCount);
  void __RPC_STUB ISClusResDependents_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_get__NewEnum_Proxy(ISClusResDependents *This,IUnknown **retval);
  void __RPC_STUB ISClusResDependents_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_Refresh_Proxy(ISClusResDependents *This);
  void __RPC_STUB ISClusResDependents_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_get_Item_Proxy(ISClusResDependents *This,VARIANT varIndex,ISClusResource **ppClusResource);
  void __RPC_STUB ISClusResDependents_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_CreateItem_Proxy(ISClusResDependents *This,BSTR bstrResourceName,BSTR bstrResourceType,CLUSTER_RESOURCE_CREATE_FLAGS dwFlags,ISClusResource **ppClusterResource);
  void __RPC_STUB ISClusResDependents_CreateItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_DeleteItem_Proxy(ISClusResDependents *This,VARIANT varIndex);
  void __RPC_STUB ISClusResDependents_DeleteItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_AddItem_Proxy(ISClusResDependents *This,ISClusResource *pResource);
  void __RPC_STUB ISClusResDependents_AddItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISClusResDependents_RemoveItem_Proxy(ISClusResDependents *This,VARIANT varIndex);
  void __RPC_STUB ISClusResDependents_RemoveItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
