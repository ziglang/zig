/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ROUTING_RTM_H__
#define __ROUTING_RTM_H__

#ifdef __cplusplus
extern "C" {
#endif

#define RTM_PROTOCOL_FAMILY_IPX 0
#define RTM_PROTOCOL_FAMILY_IP 1

#define ERROR_MORE_MESSAGES ERROR_MORE_DATA
#define ERROR_CLIENT_ALREADY_EXISTS ERROR_ALREADY_EXISTS
#define ERROR_NO_MESSAGES ERROR_NO_MORE_ITEMS

#define ERROR_NO_MORE_ROUTES ERROR_NO_MORE_ITEMS
#define ERROR_NO_ROUTES ERROR_NO_MORE_ITEMS
#define ERROR_NO_SUCH_ROUTE ERROR_NO_MORE_ITEMS

  typedef struct _IPX_NETWORK {
    DWORD N_NetNumber;
  } IPX_NETWORK,*PIPX_NETWORK;

  typedef struct _IP_NETWORK {
    DWORD N_NetNumber;
    DWORD N_NetMask;
  } IP_NETWORK,*PIP_NETWORK;

  typedef struct _IPX_NEXT_HOP_ADDRESS {
    BYTE NHA_Mac[6];
  } IPX_NEXT_HOP_ADDRESS,*PIPX_NEXT_HOP_ADDRESS;

  typedef IP_NETWORK IP_NEXT_HOP_ADDRESS,*PIP_NEXT_HOP_ADDRESS;

  typedef struct _IPX_SPECIFIC_DATA {
    DWORD FSD_Flags;
    USHORT FSD_TickCount;
    USHORT FSD_HopCount;
  } IPX_SPECIFIC_DATA,*PIPX_SPECIFIC_DATA;

#define IPX_GLOBAL_CLIENT_WAN_ROUTE 0x00000001

  typedef struct _IP_SPECIFIC_DATA {
    DWORD FSD_Type;
    DWORD FSD_Policy;
    DWORD FSD_NextHopAS;
    DWORD FSD_Priority;
    DWORD FSD_Metric;
    DWORD FSD_Metric1;
    DWORD FSD_Metric2;
    DWORD FSD_Metric3;
    DWORD FSD_Metric4;
    DWORD FSD_Metric5;
    DWORD FSD_Flags;
  } IP_SPECIFIC_DATA,*PIP_SPECIFIC_DATA;

#define IP_VALID_ROUTE 0x00000001
#define ClearRouteFlags(pRoute) ((pRoute)->RR_FamilySpecificData.FSD_Flags = 0x00000000)
#define IsRouteValid(pRoute) ((pRoute)->RR_FamilySpecificData.FSD_Flags & IP_VALID_ROUTE)
#define SetRouteValid(pRoute) ((pRoute)->RR_FamilySpecificData.FSD_Flags |= IP_VALID_ROUTE)
#define ClearRouteValid(pRoute) ((pRoute)->RR_FamilySpecificData.FSD_Flags &= ~IP_VALID_ROUTE)
#define IsRouteNonUnicast(pRoute) (((DWORD)((pRoute)->RR_Network.N_NetNumber & 0x000000FF)) >= ((DWORD)0x000000E0))
#define IsRouteLoopback(pRoute) ((((pRoute)->RR_Network.N_NetNumber & 0x000000FF)==0x0000007F) || ((pRoute)->RR_NextHopAddress.N_NetNumber==0x0100007F))

  typedef struct _PROTOCOL_SPECIFIC_DATA {
    DWORD PSD_Data[4];
  } PROTOCOL_SPECIFIC_DATA,*PPROTOCOL_SPECIFIC_DATA;

#define DWORD_ALIGN(type,field) union { type field; DWORD field##Align; }

#define ROUTE_HEADER DWORD_ALIGN (FILETIME,RR_TimeStamp); DWORD RR_RoutingProtocol; DWORD RR_InterfaceID; DWORD_ALIGN (PROTOCOL_SPECIFIC_DATA,RR_ProtocolSpecificData)

  typedef struct _RTM_IPX_ROUTE {
    ROUTE_HEADER;
    DWORD_ALIGN (IPX_NETWORK,RR_Network);
    DWORD_ALIGN (IPX_NEXT_HOP_ADDRESS,RR_NextHopAddress);
    DWORD_ALIGN (IPX_SPECIFIC_DATA,RR_FamilySpecificData);
  } RTM_IPX_ROUTE,*PRTM_IPX_ROUTE;

  typedef struct _RTM_IP_ROUTE {
    ROUTE_HEADER;
    DWORD_ALIGN (IP_NETWORK,RR_Network);
    DWORD_ALIGN (IP_NEXT_HOP_ADDRESS,RR_NextHopAddress);
    DWORD_ALIGN (IP_SPECIFIC_DATA,RR_FamilySpecificData);
  } RTM_IP_ROUTE,*PRTM_IP_ROUTE;

#define RTM_CURRENT_BEST_ROUTE 0x00000001
#define RTM_PREVIOUS_BEST_ROUTE 0x00000002

#define RTM_NO_CHANGE 0
#define RTM_ROUTE_ADDED RTM_CURRENT_BEST_ROUTE
#define RTM_ROUTE_DELETED RTM_PREVIOUS_BEST_ROUTE
#define RTM_ROUTE_CHANGED (RTM_CURRENT_BEST_ROUTE|RTM_PREVIOUS_BEST_ROUTE)

#define RTM_ONLY_THIS_NETWORK 0x00000001
#define RTM_ONLY_THIS_INTERFACE 0x00000002
#define RTM_ONLY_THIS_PROTOCOL 0x00000004
#define RTM_ONLY_BEST_ROUTES 0x00000008

#define RTM_PROTOCOL_SINGLE_ROUTE 0x00000001

  HANDLE WINAPI RtmRegisterClient(DWORD ProtocolFamily,DWORD RoutingProtocol,HANDLE ChangeEvent,DWORD Flags);
  DWORD WINAPI RtmDeregisterClient(HANDLE ClientHandle);
  DWORD WINAPI RtmDequeueRouteChangeMessage(HANDLE ClientHandle,DWORD *Flags,PVOID CurBestRoute,PVOID PrevBestRoute);
  DWORD WINAPI RtmAddRoute(HANDLE ClientHandle,PVOID Route,DWORD TimeToLive,DWORD *Flags,PVOID CurBestRoute,PVOID PrevBestRoute);
  DWORD WINAPI RtmDeleteRoute(HANDLE ClientHandle,PVOID Route,DWORD *Flags,PVOID CurBestRoute);
  WINBOOL WINAPI RtmIsRoute(DWORD ProtocolFamily,PVOID Network,PVOID BestRoute);
  ULONG WINAPI RtmGetNetworkCount(DWORD ProtocolFamily);
  ULONG WINAPI RtmGetRouteAge(PVOID Route);
  HANDLE WINAPI RtmCreateEnumerationHandle(DWORD ProtocolFamily,DWORD EnumerationFlags,PVOID CriteriaRoute);
  DWORD WINAPI RtmEnumerateGetNextRoute(HANDLE EnumerationHandle,PVOID Route);
  DWORD WINAPI RtmCloseEnumerationHandle(HANDLE EnumerationHandle);
  DWORD WINAPI RtmBlockDeleteRoutes(HANDLE ClientHandle,DWORD EnumerationFlags,PVOID CriteriaRoute);
  DWORD WINAPI RtmGetFirstRoute(DWORD ProtocolFamily,DWORD EnumerationFlags,PVOID Route);

#define RtmGetSpecificRoute(ProtocolFamily,Route) RtmGetFirstRoute(ProtocolFamily,RTM_ONLY_THIS_NETWORK | RTM_ONLY_THIS_PROTOCOL | RTM_ONLY_THIS_INTERFACE,Route)

  DWORD WINAPI RtmGetNextRoute(DWORD ProtocolFamily,DWORD EnumerationFlags,PVOID Route);
  WINBOOL WINAPI RtmLookupIPDestination(DWORD dwDestAddr,PRTM_IP_ROUTE prir);

#ifdef __cplusplus
}
#endif
#endif
