/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _WS2IPDEF_
#define _WS2IPDEF_

#include <_mingw_unicode.h>
#include <winapifamily.h>

#ifdef __LP64__
#pragma push_macro("u_long")
#undef u_long
#define u_long __ms_u_long
#endif

#include <in6addr.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ipv6_mreq {
  struct in6_addr ipv6mr_multiaddr;
  unsigned int ipv6mr_interface;
} IPV6_MREQ;

struct sockaddr_in6_old {
  short sin6_family;
  u_short sin6_port;
  u_long sin6_flowinfo;
  struct in6_addr sin6_addr;
};

typedef union sockaddr_gen {
  struct sockaddr Address;
  struct sockaddr_in AddressIn;
  struct sockaddr_in6_old AddressIn6;
} sockaddr_gen;

struct sockaddr_in6 {
  short sin6_family;
  u_short sin6_port;
  u_long sin6_flowinfo;
  struct in6_addr sin6_addr;
  __C89_NAMELESS union {
    u_long sin6_scope_id;
    SCOPE_ID sin6_scope_struct;
  };
};

typedef struct sockaddr_in6 SOCKADDR_IN6;
typedef struct sockaddr_in6 *PSOCKADDR_IN6;
typedef struct sockaddr_in6 *LPSOCKADDR_IN6;

typedef struct _INTERFACE_INFO {
  u_long iiFlags;
  sockaddr_gen iiAddress;
  sockaddr_gen iiBroadcastAddress;
  sockaddr_gen iiNetmask;
} INTERFACE_INFO,*LPINTERFACE_INFO;

typedef enum _MULTICAST_MODE_TYPE {
  MCAST_INCLUDE   = 0,
  MCAST_EXCLUDE
} MULTICAST_MODE_TYPE;

typedef struct _sockaddr_in6_pair {
  PSOCKADDR_IN6 SourceAddress;
  PSOCKADDR_IN6 DestinationAddress;
} SOCKADDR_IN6_PAIR, *PSOCKADDR_IN6_PAIR;

typedef union _SOCKADDR_INET {
  SOCKADDR_IN    Ipv4;
  SOCKADDR_IN6   Ipv6;
  ADDRESS_FAMILY si_family;
} SOCKADDR_INET, *PSOCKADDR_INET;

typedef struct group_filter {
  ULONG               gf_interface;
  SOCKADDR_STORAGE    gf_group;
  MULTICAST_MODE_TYPE gf_fmode;
  ULONG               gf_numsrc;
  SOCKADDR_STORAGE    gf_slist[1];
} GROUP_FILTER, *PGROUP_FILTER;

typedef struct group_req {
  ULONG            gr_interface;
  SOCKADDR_STORAGE gr_group;
} GROUP_REQ, *PGROUP_REQ;

typedef struct group_source_req {
  ULONG            gsr_interface;
  SOCKADDR_STORAGE gsr_group;
  SOCKADDR_STORAGE gsr_source;
} GROUP_SOURCE_REQ, *PGROUP_SOURCE_REQ;

#define IPV6_HOPOPTS           1
#define IPV6_HDRINCL           2
#define IPV6_UNICAST_HOPS      4
#define IPV6_MULTICAST_IF      9
#define IPV6_MULTICAST_HOPS    10
#define IPV6_MULTICAST_LOOP    11
#define IPV6_ADD_MEMBERSHIP    12
#define IPV6_JOIN_GROUP        IPV6_ADD_MEMBERSHIP
#define IPV6_DROP_MEMBERSHIP   13
#define IPV6_LEAVE_GROUP       IPV6_DROP_MEMBERSHIP
#define IPV6_DONTFRAG          14
#define IPV6_PKTINFO           19
#define IPV6_HOPLIMIT          21
#define IPV6_PROTECTION_LEVEL  23
#define IPV6_RECVIF            24
#define IPV6_RECVDSTADDR       25
#define IPV6_CHECKSUM          26
#define IPV6_V6ONLY            27
#define IPV6_IFLIST            28
#define IPV6_ADD_IFLIST        29
#define IPV6_DEL_IFLIST        30
#define IPV6_UNICAST_IF        31
#define IPV6_RTHDR             32
#define IPV6_RECVRTHDR         38
#define IPV6_TCLASS            39
#define IPV6_RECVTCLASS        40

#define WS2TCPIP_INLINE __CRT_INLINE

int IN6_ADDR_EQUAL(const struct in6_addr *,const struct in6_addr *);
WS2TCPIP_INLINE int IN6_ADDR_EQUAL(const struct in6_addr *a, const struct in6_addr *b) {
    return !memcmp(a, b, sizeof(struct in6_addr));
}

#define IN6_ARE_ADDR_EQUAL IN6_ADDR_EQUAL

#ifdef __cplusplus
}
#endif

#ifdef __LP64__
#pragma pop_macro("u_long")
#endif

#endif /*_WS2IPDEF_ */
