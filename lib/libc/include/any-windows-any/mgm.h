/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MGM_H_
#define _MGM_H_

typedef struct _MGM_IF_ENTRY {
  DWORD dwIfIndex;
  DWORD dwIfNextHopAddr;
  WINBOOL bIGMP;
  WINBOOL bIsEnabled;
} MGM_IF_ENTRY,*PMGM_IF_ENTRY;

typedef DWORD (*PMGM_RPF_CALLBACK)(DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,PDWORD pdwInIfIndex,PDWORD pdwInIfNextHopAddr,PDWORD pdwUpStreamNbr,DWORD dwHdrSize,PBYTE pbPacketHdr,PBYTE pbRoute);
typedef DWORD (*PMGM_CREATION_ALERT_CALLBACK)(DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,DWORD dwInIfIndex,DWORD dwInIfNextHopAddr,DWORD dwIfCount,PMGM_IF_ENTRY pmieOutIfList);
typedef DWORD (*PMGM_PRUNE_ALERT_CALLBACK)(DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,DWORD dwIfIndex,DWORD dwIfNextHopAddr,WINBOOL bMemberDelete,PDWORD pdwTimeout);
typedef DWORD (*PMGM_JOIN_ALERT_CALLBACK)(DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,WINBOOL bMemberUpdate);
typedef DWORD (*PMGM_WRONG_IF_CALLBACK)(DWORD dwSourceAddr,DWORD dwGroupAddr,DWORD dwIfIndex,DWORD dwIfNextHopAddr,DWORD dwHdrSize,PBYTE pbPacketHdr);
typedef DWORD (*PMGM_LOCAL_JOIN_CALLBACK) (DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,DWORD dwIfIndex,DWORD dwIfNextHopAddr);
typedef DWORD (*PMGM_LOCAL_LEAVE_CALLBACK) (DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,DWORD dwIfIndex,DWORD dwIfNextHopAddr);
typedef DWORD (*PMGM_DISABLE_IGMP_CALLBACK) (DWORD dwIfIndex,DWORD dwIfNextHopAddr);
typedef DWORD (*PMGM_ENABLE_IGMP_CALLBACK) (DWORD dwIfIndex,DWORD dwIfNextHopAddr);

typedef struct _ROUTING_PROTOCOL_CONFIG {
  DWORD dwCallbackFlags;
  PMGM_RPF_CALLBACK pfnRpfCallback;
  PMGM_CREATION_ALERT_CALLBACK pfnCreationAlertCallback;
  PMGM_PRUNE_ALERT_CALLBACK pfnPruneAlertCallback;
  PMGM_JOIN_ALERT_CALLBACK pfnJoinAlertCallback;
  PMGM_WRONG_IF_CALLBACK pfnWrongIfCallback;
  PMGM_LOCAL_JOIN_CALLBACK pfnLocalJoinCallback;
  PMGM_LOCAL_LEAVE_CALLBACK pfnLocalLeaveCallback;
  PMGM_DISABLE_IGMP_CALLBACK pfnDisableIgmpCallback;
  PMGM_ENABLE_IGMP_CALLBACK pfnEnableIgmpCallback;
} ROUTING_PROTOCOL_CONFIG,*PROUTING_PROTOCOL_CONFIG;

typedef enum _MGM_ENUM_TYPES {
  ANY_SOURCE = 0,ALL_SOURCES
} MGM_ENUM_TYPES;

typedef struct _SOURCE_GROUP_ENTRY {
  DWORD dwSourceAddr;
  DWORD dwSourceMask;
  DWORD dwGroupAddr;
  DWORD dwGroupMask;
} SOURCE_GROUP_ENTRY,*PSOURCE_GROUP_ENTRY;

#define MGM_JOIN_STATE_FLAG 0x00000001
#define MGM_FORWARD_STATE_FLAG 0x00000002

#define MGM_MFE_STATS_0 0x00000001
#define MGM_MFE_STATS_1 0x00000002

DWORD MgmRegisterMProtocol(PROUTING_PROTOCOL_CONFIG prpiInfo,DWORD dwProtocolId,DWORD dwComponentId,HANDLE *phProtocol);
DWORD MgmDeRegisterMProtocol(HANDLE hProtocol);
DWORD MgmTakeInterfaceOwnership(HANDLE hProtocol,DWORD dwIfIndex,DWORD dwIfNextHopAddr);
DWORD MgmReleaseInterfaceOwnership(HANDLE hProtocol,DWORD dwIfIndex,DWORD dwIfNextHopAddr);
DWORD MgmGetProtocolOnInterface(DWORD dwIfIndex,DWORD dwIfNextHopAddr,PDWORD pdwIfProtocolId,PDWORD pdwIfComponentId);
DWORD MgmAddGroupMembershipEntry(HANDLE hProtocol,DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,DWORD dwIfIndex,DWORD dwIfNextHopIPAddr,DWORD dwFlags);
DWORD MgmDeleteGroupMembershipEntry(HANDLE hProtocol,DWORD dwSourceAddr,DWORD dwSourceMask,DWORD dwGroupAddr,DWORD dwGroupMask,DWORD dwIfIndex,DWORD dwIfNextHopIPAddr,DWORD dwFlags);
DWORD MgmGetMfe(PMIB_IPMCAST_MFE pimm,PDWORD pdwBufferSize,PBYTE pbBuffer);
DWORD MgmGetFirstMfe(PDWORD pdwBufferSize,PBYTE pbBuffer,PDWORD pdwNumEntries);
DWORD MgmGetNextMfe(PMIB_IPMCAST_MFE pimmStart,PDWORD pdwBufferSize,PBYTE pbBuffer,PDWORD pdwNumEntries);
DWORD MgmGetMfeStats(PMIB_IPMCAST_MFE pimm,PDWORD pdwBufferSize,PBYTE pbBuffer,DWORD dwFlags);
DWORD MgmGetFirstMfeStats(PDWORD pdwBufferSize,PBYTE pbBuffer,PDWORD pdwNumEntries,DWORD dwFlags);
DWORD MgmGetNextMfeStats(PMIB_IPMCAST_MFE pimmStart,PDWORD pdwBufferSize,PBYTE pbBuffer,PDWORD pdwNumEntries,DWORD dwFlags);
DWORD MgmGroupEnumerationStart(HANDLE hProtocol,MGM_ENUM_TYPES metEnumType,HANDLE *phEnumHandle);
DWORD MgmGroupEnumerationGetNext(HANDLE hEnum,PDWORD pdwBufferSize,PBYTE pbBuffer,PDWORD pdwNumEntries);
DWORD MgmGroupEnumerationEnd(HANDLE hEnum);
DWORD MgmSetMfe(HANDLE hProtocol,PMIB_IPMCAST_MFE pmimm);

#endif
