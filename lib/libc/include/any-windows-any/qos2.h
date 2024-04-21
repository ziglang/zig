/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_QOS2
#define _INC_QOS2
#if (_WIN32_WINNT >= 0x0600)

#include <ws2tcpip.h>
#include <mstcpip.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef ULONG QOS_FLOWID, *PQOS_FLOWID;

typedef enum _QOS_SHAPING {
  QOSShapeOnly                  = 0,
  QOSShapeAndMark               = 1,
  QOSUseNonConformantMarkings   = 2 
} QOS_SHAPING, *PQOS_SHAPING;

#define QOS_OUTGOING_DEFAULT_MINIMUM_BANDWIDTH 0xffffffff

typedef enum _QOS_FLOWRATE_REASON {
  QOSFlowRateNotApplicable           = 0,
  QOSFlowRateContentChange           = 1,
  QOSFlowRateCongestion              = 2,
  QOSFlowRateHigherContentEncoding   = 3,
  QOSFlowRateUserCaused              = 4 
} QOS_FLOWRATE_REASON, *PQOS_FLOWRATE_REASON;

typedef enum _QOS_NOTIFY_FLOW {
  QOSNotifyCongested     = 0,
  QOSNotifyUncongested   = 1,
  QOSNotifyAvailable     = 2 
} QOS_NOTIFY_FLOW, *PQOS_NOTIFY_FLOW;

typedef enum _QOS_QUERY_FLOW {
  QOSQueryFlowFundamentals   = 0,
  QOSQueryPacketPriority     = 1,
  QOSQueryOutgoingRate       = 2 
} QOS_QUERY_FLOW;

typedef enum _QOS_SET_FLOW {
  QOSSetTrafficType         = 0,
  QOSSetOutgoingRate        = 1,
  QOSSetOutgoingDSCPValue   = 2 
} QOS_SET_FLOW, *PQOS_SET_FLOW;

typedef enum _QOS_TRAFFIC_TYPE {
  QOSTrafficTypeBestEffort,
  QOSTrafficTypeBackground,
  QOSTrafficTypeExcellentEffort,
  QOSTrafficTypeAudioVideo,
  QOSTrafficTypeVoice,
  QOSTrafficTypeControl 
} QOS_TRAFFIC_TYPE, *PQOS_TRAFFIC_TYPE;

typedef struct _QOS_FLOW_FUNDAMENTALS {
  BOOL   BottleneckBandwidthSet;
  UINT64 BottleneckBandwidth;
  BOOL   AvailableBandwidthSet;
  UINT64 AvailableBandwidth;
  BOOL   RTTSet;
  UINT32 RTT;
} QOS_FLOW_FUNDAMENTALS, *PQOS_FLOW_FUNDAMENTALS;

typedef struct _QOS_FLOWRATE_OUTGOING {
  UINT64              Bandwidth;
  QOS_SHAPING         ShapingBehavior;
  QOS_FLOWRATE_REASON Reason;
} QOS_FLOWRATE_OUTGOING, *PQOS_FLOWRATE_OUTGOING;

typedef struct _QOS_PACKET_PRIORITY {
  ULONG ConformantDSCPValue;
  ULONG NonConformantDSCPValue;
  ULONG ConformantL2Value;
  ULONG NonConformantL2Value;
} QOS_PACKET_PRIORITY, *PQOS_PACKET_PRIORITY;

typedef struct _QOS_VERSION {
  USHORT MajorVersion;
  USHORT MinorVersion;
} QOS_VERSION, *PQOS_VERSION;

#define QOS_QUERYFLOW_FRESH 0x00000001
#define QOS_NON_ADAPTIVE_FLOW 0x00000002

WINBOOL WINAPI QOSAddSocketToFlow(
  HANDLE QOSHandle,
  SOCKET Socket,
  PSOCKADDR DestAddr,
  QOS_TRAFFIC_TYPE TrafficType,
  DWORD Flags,
  PQOS_FLOWID FlowId
);

WINBOOL WINAPI QOSCancel(
  HANDLE QOSHandle,
  LPOVERLAPPED Overlapped
);

WINBOOL WINAPI QOSCloseHandle(
  HANDLE QOSHandle
);

WINBOOL WINAPI QOSCreateHandle(
  PQOS_VERSION Version,
  PHANDLE QOSHandle
);

WINBOOL WINAPI QOSEnumerateFlows(
  HANDLE QOSHandle,
  PULONG Size,
  PVOID Buffer
);

WINBOOL WINAPI QOSNotifyFlow(
  HANDLE QOSHandle,
  QOS_FLOWID FlowId,
  QOS_NOTIFY_FLOW Operation,
  PULONG Size,
  PVOID Buffer,
  DWORD Flags,
  LPOVERLAPPED Overlapped
);

WINBOOL WINAPI QOSQueryFlow(
  HANDLE QOSHandle,
  QOS_FLOWID FlowId,
  QOS_QUERY_FLOW Operation,
  PULONG Size,
  PVOID Buffer,
  DWORD Flags,
  LPOVERLAPPED Overlapped
);

WINBOOL WINAPI QOSRemoveSocketFromFlow(
  HANDLE QOSHandle,
  SOCKET Socket,
  QOS_FLOWID FlowId,
  DWORD Flags
);

WINBOOL WINAPI QOSSetFlow(
  HANDLE QOSHandle,
  QOS_FLOWID FlowId,
  QOS_SET_FLOW Operation,
  ULONG Size,
  PVOID Buffer,
  DWORD Flags,
  LPOVERLAPPED Overlapped
);

WINBOOL WINAPI QOSStartTrackingClient(
  HANDLE QOSHandle,
  PSOCKADDR DestAddr,
  DWORD Flags
);

WINBOOL WINAPI QOSStopTrackingClient(
  HANDLE QOSHandle,
  PSOCKADDR DestAddr,
  DWORD Flags
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_QOS2*/
