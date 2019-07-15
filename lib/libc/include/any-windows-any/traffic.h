/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __TRAFFIC_H
#define __TRAFFIC_H

#include <_mingw_unicode.h>
#include <ntddndis.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CURRENT_TCI_VERSION 0x0002

#define TC_NOTIFY_IFC_UP 1
#define TC_NOTIFY_IFC_CLOSE 2
#define TC_NOTIFY_IFC_CHANGE 3
#define TC_NOTIFY_PARAM_CHANGED 4
#define TC_NOTIFY_FLOW_CLOSE 5
#define TC_INVALID_HANDLE ((HANDLE)0)

#define MAX_STRING_LENGTH 256

#ifndef CALLBACK
#if defined(_ARM_)
#define CALLBACK
#else
#define CALLBACK __stdcall
#endif
#endif

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#ifndef APIENTRY
#define APIENTRY WINAPI
#endif

  typedef VOID (CALLBACK *TCI_NOTIFY_HANDLER)(HANDLE ClRegCtx,HANDLE ClIfcCtx,ULONG Event,HANDLE SubCode,ULONG BufSize,PVOID Buffer);
  typedef VOID (CALLBACK *TCI_ADD_FLOW_COMPLETE_HANDLER)(HANDLE ClFlowCtx,ULONG Status);
  typedef VOID (CALLBACK *TCI_MOD_FLOW_COMPLETE_HANDLER)(HANDLE ClFlowCtx,ULONG Status);
  typedef VOID (CALLBACK *TCI_DEL_FLOW_COMPLETE_HANDLER)(HANDLE ClFlowCtx,ULONG Status);

  typedef struct _TCI_CLIENT_FUNC_LIST {
    TCI_NOTIFY_HANDLER ClNotifyHandler;
    TCI_ADD_FLOW_COMPLETE_HANDLER ClAddFlowCompleteHandler;
    TCI_MOD_FLOW_COMPLETE_HANDLER ClModifyFlowCompleteHandler;
    TCI_DEL_FLOW_COMPLETE_HANDLER ClDeleteFlowCompleteHandler;
  } TCI_CLIENT_FUNC_LIST,*PTCI_CLIENT_FUNC_LIST;

  typedef struct _ADDRESS_LIST_DESCRIPTOR {
    ULONG MediaType;
    NETWORK_ADDRESS_LIST AddressList;
  } ADDRESS_LIST_DESCRIPTOR,*PADDRESS_LIST_DESCRIPTOR;

  typedef struct _TC_IFC_DESCRIPTOR {
    ULONG Length;
    LPWSTR pInterfaceName;
    LPWSTR pInterfaceID;
    ADDRESS_LIST_DESCRIPTOR AddressListDesc;
  } TC_IFC_DESCRIPTOR,*PTC_IFC_DESCRIPTOR;

  typedef struct _TC_SUPPORTED_INFO_BUFFER {
    USHORT InstanceIDLength;
    WCHAR InstanceID[MAX_STRING_LENGTH];
    ADDRESS_LIST_DESCRIPTOR AddrListDesc;
  } TC_SUPPORTED_INFO_BUFFER,*PTC_SUPPORTED_INFO_BUFFER;

  typedef struct _TC_GEN_FILTER {
    USHORT AddressType;
    ULONG PatternSize;
    PVOID Pattern;
    PVOID Mask;
  } TC_GEN_FILTER,*PTC_GEN_FILTER;

  typedef struct _TC_GEN_FLOW {
    FLOWSPEC SendingFlowspec;
    FLOWSPEC ReceivingFlowspec;
    ULONG TcObjectsLength;
    QOS_OBJECT_HDR TcObjects[1];
  } TC_GEN_FLOW,*PTC_GEN_FLOW;

  typedef struct _IP_PATTERN {
    ULONG Reserved1;
    ULONG Reserved2;
    ULONG SrcAddr;
    ULONG DstAddr;
    union {
      struct { USHORT s_srcport,s_dstport; } S_un_ports;
      struct { UCHAR s_type,s_code; USHORT filler; } S_un_icmp;
      ULONG S_Spi;
    } S_un;
    UCHAR ProtocolId;
    UCHAR Reserved3[3];
  } IP_PATTERN,*PIP_PATTERN;

#define tcSrcPort S_un.S_un_ports.s_srcport
#define tcDstPort S_un.S_un_ports.s_dstport
#define tcIcmpType S_un.S_un_icmp.s_type
#define tcIcmpCode S_un.S_un_icmp.s_code
#define tcSpi S_un.S_Spi

  typedef struct _IPX_PATTERN {
    struct {
      ULONG NetworkAddress;
      UCHAR NodeAddress[6];
      USHORT Socket;
    } Src,Dest;
  } IPX_PATTERN,*PIPX_PATTERN;

  typedef struct _ENUMERATION_BUFFER {
    ULONG Length;
    ULONG OwnerProcessId;
    USHORT FlowNameLength;
    WCHAR FlowName[MAX_STRING_LENGTH];
    PTC_GEN_FLOW pFlow;
    ULONG NumberOfFilters;
    TC_GEN_FILTER GenericFilter[1];
  } ENUMERATION_BUFFER,*PENUMERATION_BUFFER;

#define QOS_TRAFFIC_GENERAL_ID_BASE 4000
#define QOS_OBJECT_DS_CLASS (0x00000001 + QOS_TRAFFIC_GENERAL_ID_BASE)
#define QOS_OBJECT_TRAFFIC_CLASS (0x00000002 + QOS_TRAFFIC_GENERAL_ID_BASE)
#define QOS_OBJECT_DIFFSERV (0x00000003 + QOS_TRAFFIC_GENERAL_ID_BASE)
#define QOS_OBJECT_TCP_TRAFFIC (0x00000004 + QOS_TRAFFIC_GENERAL_ID_BASE)
#define QOS_OBJECT_FRIENDLY_NAME (0x00000005 + QOS_TRAFFIC_GENERAL_ID_BASE)

  typedef struct _QOS_FRIENDLY_NAME {
    QOS_OBJECT_HDR ObjectHdr;
    WCHAR FriendlyName[MAX_STRING_LENGTH];
  } QOS_FRIENDLY_NAME,*LPQOS_FRIENDLY_NAME;

  typedef struct _QOS_TRAFFIC_CLASS {
    QOS_OBJECT_HDR ObjectHdr;
    ULONG TrafficClass;
  } QOS_TRAFFIC_CLASS,*LPQOS_TRAFFIC_CLASS;

  typedef struct _QOS_DS_CLASS {
    QOS_OBJECT_HDR ObjectHdr;
    ULONG DSField;
  } QOS_DS_CLASS,*LPQOS_DS_CLASS;

  typedef struct _QOS_DIFFSERV {
    QOS_OBJECT_HDR ObjectHdr;
    ULONG DSFieldCount;
    UCHAR DiffservRule[1];
  } QOS_DIFFSERV,*LPQOS_DIFFSERV;

  typedef struct _QOS_DIFFSERV_RULE {
    UCHAR InboundDSField;
    UCHAR ConformingOutboundDSField;
    UCHAR NonConformingOutboundDSField;
    UCHAR ConformingUserPriority;
    UCHAR NonConformingUserPriority;
  } QOS_DIFFSERV_RULE,*LPQOS_DIFFSERV_RULE;

  typedef struct _QOS_TCP_TRAFFIC {
    QOS_OBJECT_HDR ObjectHdr;
  } QOS_TCP_TRAFFIC,*LPQOS_TCP_TRAFFIC;

#define TcOpenInterface __MINGW_NAME_AW(TcOpenInterface)
#define TcQueryFlow __MINGW_NAME_AW(TcQueryFlow)
#define TcSetFlow __MINGW_NAME_AW(TcSetFlow)
#define TcGetFlowName __MINGW_NAME_AW(TcGetFlowName)

  ULONG WINAPI TcRegisterClient(ULONG TciVersion,HANDLE ClRegCtx,PTCI_CLIENT_FUNC_LIST ClientHandlerList,PHANDLE pClientHandle);
  ULONG WINAPI TcEnumerateInterfaces(HANDLE ClientHandle,PULONG pBufferSize,PTC_IFC_DESCRIPTOR InterfaceBuffer);
  ULONG WINAPI TcOpenInterfaceA(LPSTR pInterfaceName,HANDLE ClientHandle,HANDLE ClIfcCtx,PHANDLE pIfcHandle);
  ULONG WINAPI TcOpenInterfaceW(LPWSTR pInterfaceName,HANDLE ClientHandle,HANDLE ClIfcCtx,PHANDLE pIfcHandle);
  ULONG WINAPI TcCloseInterface(HANDLE IfcHandle);
  ULONG WINAPI TcQueryInterface(HANDLE IfcHandle,LPGUID pGuidParam,BOOLEAN NotifyChange,PULONG pBufferSize,PVOID Buffer);
  ULONG WINAPI TcSetInterface(HANDLE IfcHandle,LPGUID pGuidParam,ULONG BufferSize,PVOID Buffer);
  ULONG WINAPI TcQueryFlowA(LPSTR pFlowName,LPGUID pGuidParam,PULONG pBufferSize,PVOID Buffer);
  ULONG WINAPI TcQueryFlowW(LPWSTR pFlowName,LPGUID pGuidParam,PULONG pBufferSize,PVOID Buffer);
  ULONG WINAPI TcSetFlowA(LPSTR pFlowName,LPGUID pGuidParam,ULONG BufferSize,PVOID Buffer);
  ULONG WINAPI TcSetFlowW(LPWSTR pFlowName,LPGUID pGuidParam,ULONG BufferSize,PVOID Buffer);
  ULONG WINAPI TcAddFlow(HANDLE IfcHandle,HANDLE ClFlowCtx,ULONG Flags,PTC_GEN_FLOW pGenericFlow,PHANDLE pFlowHandle);
  ULONG WINAPI TcGetFlowNameA(HANDLE FlowHandle,ULONG StrSize,LPSTR pFlowName);
  ULONG WINAPI TcGetFlowNameW(HANDLE FlowHandle,ULONG StrSize,LPWSTR pFlowName);
  ULONG WINAPI TcModifyFlow(HANDLE FlowHandle,PTC_GEN_FLOW pGenericFlow);
  ULONG WINAPI TcAddFilter(HANDLE FlowHandle,PTC_GEN_FILTER pGenericFilter,PHANDLE pFilterHandle);
  ULONG WINAPI TcDeregisterClient(HANDLE ClientHandle);
  ULONG WINAPI TcDeleteFlow(HANDLE FlowHandle);
  ULONG WINAPI TcDeleteFilter(HANDLE FilterHandle);
  ULONG WINAPI TcEnumerateFlows(HANDLE IfcHandle,PHANDLE pEnumHandle,PULONG pFlowCount,PULONG pBufSize,PENUMERATION_BUFFER Buffer);

#ifdef __cplusplus
}
#endif
#endif
