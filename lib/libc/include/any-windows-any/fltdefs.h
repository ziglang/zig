/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _FLTDEFS_H
#define _FLTDEFS_H

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

typedef PVOID FILTER_HANDLE,*PFILTER_HANDLE;
typedef PVOID INTERFACE_HANDLE,*PINTERFACE_HANDLE;

#define PFEXPORT __declspec(dllexport)

#ifdef __cplusplus
#define EXTERNCDECL EXTERN_C
#else
#define EXTERNCDECL
#endif

#define PFAPIENTRY EXTERNCDECL DWORD PFEXPORT WINAPI

typedef enum _GlobalFilter {
  GF_FRAGMENTS = 2,GF_STRONGHOST = 8,GF_FRAGCACHE = 9
} GLOBAL_FILTER,*PGLOBAL_FILTER;

typedef enum _PfForwardAction {
  PF_ACTION_FORWARD = 0,PF_ACTION_DROP
} PFFORWARD_ACTION,*PPFFORWARD_ACTION;

typedef enum _PfAddresType {
  PF_IPV4,PF_IPV6
} PFADDRESSTYPE,*PPFADDRESSTYPE;

#define FILTER_PROTO(ProtoId) MAKELONG(MAKEWORD((ProtoId),0x00),0x00000)

#define FILTER_PROTO_ANY FILTER_PROTO(0x00)
#define FILTER_PROTO_ICMP FILTER_PROTO(0x01)
#define FILTER_PROTO_TCP FILTER_PROTO(0x06)
#define FILTER_PROTO_UDP FILTER_PROTO(0x11)

#define FILTER_TCPUDP_PORT_ANY (WORD)0x0000

#define FILTER_ICMP_TYPE_ANY (BYTE)0xff
#define FILTER_ICMP_CODE_ANY (BYTE)0xff

typedef struct _PF_FILTER_DESCRIPTOR {
  DWORD dwFilterFlags;
  DWORD dwRule;
  PFADDRESSTYPE pfatType;
  PBYTE SrcAddr;
  PBYTE SrcMask;
  PBYTE DstAddr;
  PBYTE DstMask;
  DWORD dwProtocol;
  DWORD fLateBound;
  WORD wSrcPort;
  WORD wDstPort;
  WORD wSrcPortHighRange;
  WORD wDstPortHighRange;
} PF_FILTER_DESCRIPTOR,*PPF_FILTER_DESCRIPTOR;

typedef struct _PF_FILTER_STATS {
  DWORD dwNumPacketsFiltered;
  PF_FILTER_DESCRIPTOR info;
} PF_FILTER_STATS,*PPF_FILTER_STATS;

typedef struct _PF_INTERFACE_STATS {
  PVOID pvDriverContext;
  DWORD dwFlags;
  DWORD dwInDrops;
  DWORD dwOutDrops;
  PFFORWARD_ACTION eaInAction;
  PFFORWARD_ACTION eaOutAction;
  DWORD dwNumInFilters;
  DWORD dwNumOutFilters;
  DWORD dwFrag;
  DWORD dwSpoof;
  DWORD dwReserved1;
  DWORD dwReserved2;
  LARGE_INTEGER liSYN;
  LARGE_INTEGER liTotalLogged;
  DWORD dwLostLogEntries;
  PF_FILTER_STATS FilterInfo[1];
} PF_INTERFACE_STATS,*PPF_INTERFACE_STATS;

#define FILTERSIZE (sizeof(PF_FILTER_DESCRIPTOR) - (DWORD)(&((PPF_FILTER_DESCRIPTOR)0)->SrcAddr))

#define FD_FLAGS_NOSYN 0x1

#define FD_FLAGS_ALLFLAGS FD_FLAGS_NOSYN

#define LB_SRC_ADDR_USE_SRCADDR_FLAG 0x00000001
#define LB_SRC_ADDR_USE_DSTADDR_FLAG 0x00000002
#define LB_DST_ADDR_USE_SRCADDR_FLAG 0x00000004
#define LB_DST_ADDR_USE_DSTADDR_FLAG 0x00000008
#define LB_SRC_MASK_LATE_FLAG 0x00000010
#define LB_DST_MASK_LATE_FLAG 0x00000020

typedef struct _PF_LATEBIND_INFO {
  PBYTE SrcAddr;
  PBYTE DstAddr;
  PBYTE Mask;
} PF_LATEBIND_INFO,*PPF_LATEBIND_INFO;

typedef enum _PfFrameType {
  PFFT_FILTER = 1,PFFT_FRAG = 2,PFFT_SPOOF = 3
} PFFRAMETYPE,*PPFFRAMETYPE;

typedef struct _pfLogFrame {
  LARGE_INTEGER Timestamp;
  PFFRAMETYPE pfeTypeOfFrame;
  DWORD dwTotalSizeUsed;
  DWORD dwFilterRule;
  WORD wSizeOfAdditionalData;
  WORD wSizeOfIpHeader;
  DWORD dwInterfaceName;
  DWORD dwIPIndex;
  BYTE bPacketData[1];
} PFLOGFRAME,*PPFLOGFRAME;

#define ERROR_BASE 23000

#define PFERROR_NO_PF_INTERFACE (ERROR_BASE + 0)
#define PFERROR_NO_FILTERS_GIVEN (ERROR_BASE + 1)
#define PFERROR_BUFFER_TOO_SMALL (ERROR_BASE + 2)
#define ERROR_IPV6_NOT_IMPLEMENTED (ERROR_BASE + 3)

PFAPIENTRY PfCreateInterface(DWORD dwName,PFFORWARD_ACTION inAction,PFFORWARD_ACTION outAction,WINBOOL bUseLog,WINBOOL bMustBeUnique,INTERFACE_HANDLE *ppInterface);
PFAPIENTRY PfDeleteInterface(INTERFACE_HANDLE pInterface);
PFAPIENTRY PfAddFiltersToInterface(INTERFACE_HANDLE ih,DWORD cInFilters,PPF_FILTER_DESCRIPTOR pfiltIn,DWORD cOutFilters,PPF_FILTER_DESCRIPTOR pfiltOut,PFILTER_HANDLE pfHandle);
PFAPIENTRY PfRemoveFiltersFromInterface(INTERFACE_HANDLE ih,DWORD cInFilters,PPF_FILTER_DESCRIPTOR pfiltIn,DWORD cOutFilters,PPF_FILTER_DESCRIPTOR pfiltOut);
PFAPIENTRY PfRemoveFilterHandles(INTERFACE_HANDLE pInterface,DWORD cFilters,PFILTER_HANDLE pvHandles);
PFAPIENTRY PfUnBindInterface(INTERFACE_HANDLE pInterface);
PFAPIENTRY PfBindInterfaceToIndex(INTERFACE_HANDLE pInterface,DWORD dwIndex,PFADDRESSTYPE pfatLinkType,PBYTE LinkIPAddress);
PFAPIENTRY PfBindInterfaceToIPAddress(INTERFACE_HANDLE pInterface,PFADDRESSTYPE pfatType,PBYTE IPAddress);
PFAPIENTRY PfRebindFilters(INTERFACE_HANDLE pInterface,PPF_LATEBIND_INFO pLateBindInfo);
PFAPIENTRY PfAddGlobalFilterToInterface(INTERFACE_HANDLE pInterface,GLOBAL_FILTER gfFilter);
PFAPIENTRY PfRemoveGlobalFilterFromInterface(INTERFACE_HANDLE pInterface,GLOBAL_FILTER gfFilter);
PFAPIENTRY PfMakeLog(HANDLE hEvent);
PFAPIENTRY PfSetLogBuffer(PBYTE pbBuffer,DWORD dwSize,DWORD dwThreshold,DWORD dwEntries,PDWORD pdwLoggedEntries,PDWORD pdwLostEntries,PDWORD pdwSizeUsed);
PFAPIENTRY PfDeleteLog(VOID);
PFAPIENTRY PfGetInterfaceStatistics(INTERFACE_HANDLE pInterface,PPF_INTERFACE_STATS ppfStats,PDWORD pdwBufferSize,WINBOOL fResetCounters);
PFAPIENTRY PfTestPacket(INTERFACE_HANDLE pInInterface,INTERFACE_HANDLE pOutInterface,DWORD cBytes,PBYTE pbPacket,PPFFORWARD_ACTION ppAction);

#endif /* WINAPI_PARTION_DESKTOP.  */

#endif
