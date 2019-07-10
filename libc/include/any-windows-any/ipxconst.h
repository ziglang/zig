/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IPXCONST_
#define _IPXCONST_

#define ADMIN_STATE_DISABLED 1
#define ADMIN_STATE_ENABLED 2

#define ADMIN_STATE_ENABLED_ONLY_FOR_NETBIOS_STATIC_ROUTING 3
#define ADMIN_STATE_ENABLED_ONLY_FOR_OPER_STATE_UP 4

#define OPER_STATE_DOWN 1
#define OPER_STATE_UP 2
#define OPER_STATE_SLEEPING 3
#define OPER_STATE_STARTING 4
#define OPER_STATE_STOPPING 5

#define IPX_STANDARD_UPDATE 1
#define IPX_NO_UPDATE 2
#define IPX_AUTO_STATIC_UPDATE 3

#define IPX_STANDARD_PACKET_TYPE 1
#define IPX_RELIABLE_DELIVERY_PACKET_TYPE 2

#define IPX_PACE_DEFVAL 18

#define IPX_UPDATE_INTERVAL_DEFVAL 60

#define R_Interface RR_InterfaceID
#define R_Protocol RR_RoutingProtocol

#define R_Network RR_Network.N_NetNumber
#define R_TickCount RR_FamilySpecificData.FSD_TickCount
#define R_HopCount RR_FamilySpecificData.FSD_HopCount
#define R_NextHopMacAddress RR_NextHopAddress.NHA_Mac

#define R_Flags RR_FamilySpecificData.FSD_Flags

#define MAX_INTERFACE_INDEX 0xFFFFFFFE
#define GLOBAL_INTERFACE_INDEX 0xFFFFFFFF

#define GLOBAL_WAN_ROUTE 0x00000001
#define DO_NOT_ADVERTISE_ROUTE 0x00000002
#endif
