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

/* options at IPPROTO_IP level */
#define IP_OPTIONS                 1
#define IP_HDRINCL                 2
#define IP_TOS                     3
#define IP_TTL                     4
#define IP_MULTICAST_IF            9
#define IP_MULTICAST_TTL          10
#define IP_MULTICAST_LOOP         11
#define IP_ADD_MEMBERSHIP         12
#define IP_DROP_MEMBERSHIP        13
#define IP_DONTFRAGMENT           14
#define IP_ADD_SOURCE_MEMBERSHIP  15
#define IP_DROP_SOURCE_MEMBERSHIP 16
#define IP_BLOCK_SOURCE           17
#define IP_UNBLOCK_SOURCE         18
#define IP_PKTINFO                19
#define IP_HOPLIMIT               21
#define IP_RECVTTL                21
#define IP_RECEIVE_BROADCAST      22
#define IP_RECVIF                 24
#define IP_RECVDSTADDR            25
#define IP_IFLIST                 28
#define IP_ADD_IFLIST             29
#define IP_DEL_IFLIST             30
#define IP_UNICAST_IF             31
#define IP_RTHDR                  32
#define IP_GET_IFLIST             33
#define IP_RECVRTHDR              38
#define IP_TCLASS                 39
#define IP_RECVTCLASS             40
#define IP_RECVTOS                40
#define IP_ORIGINAL_ARRIVAL_IF    47
#define IP_ECN                    50
#define IP_PKTINFO_EX             51
#define IP_WFP_REDIRECT_RECORDS   60
#define IP_WFP_REDIRECT_CONTEXT   70
#define IP_MTU_DISCOVER           71
#define IP_MTU                    73
#define IP_NRT_INTERFACE          74
#define IP_RECVERR                75
#define IP_USER_MTU               76

#define IP_UNSPECIFIED_TYPE_OF_SERVICE -1
#define IP_UNSPECIFIED_USER_MTU MAXULONG

#define IPV6_ADDRESS_BITS RTL_BITS_OF(IN6_ADDR)

/* options at IPPROTO_IPV6 level */
#define IPV6_HOPOPTS              1
#define IPV6_HDRINCL              2
#define IPV6_UNICAST_HOPS         4
#define IPV6_MULTICAST_IF         9
#define IPV6_MULTICAST_HOPS       10
#define IPV6_MULTICAST_LOOP       11
#define IPV6_ADD_MEMBERSHIP       12
#define IPV6_JOIN_GROUP           IPV6_ADD_MEMBERSHIP
#define IPV6_DROP_MEMBERSHIP      13
#define IPV6_LEAVE_GROUP          IPV6_DROP_MEMBERSHIP
#define IPV6_DONTFRAG             14
#define IPV6_PKTINFO              19
#define IPV6_HOPLIMIT             21
#define IPV6_PROTECTION_LEVEL     23
#define IPV6_RECVIF               24
#define IPV6_RECVDSTADDR          25
#define IPV6_CHECKSUM             26
#define IPV6_V6ONLY               27
#define IPV6_IFLIST               28
#define IPV6_ADD_IFLIST           29
#define IPV6_DEL_IFLIST           30
#define IPV6_UNICAST_IF           31
#define IPV6_RTHDR                32
#define IPV6_GET_IFLIST           33
#define IPV6_RECVRTHDR            38
#define IPV6_TCLASS               39
#define IPV6_RECVTCLASS           40
#define IPV6_ECN                  50
#define IPV6_PKTINFO_EX           51
#define IPV6_WFP_REDIRECT_RECORDS 60
#define IPV6_WFP_REDIRECT_CONTEXT 70
#define IPV6_MTU_DISCOVER         71
#define IPV6_MTU                  72
#define IPV6_NRT_INTERFACE        74
#define IPV6_RECVERR              75
#define IPV6_USER_MTU             76

#define IP_UNSPECIFIED_HOP_LIMIT -1

#define IP_PROTECTION_LEVEL IPV6_PROTECTION_LEVEL

#define PROTECTION_LEVEL_UNRESTRICTED   10
#define PROTECTION_LEVEL_EDGERESTRICTED 20
#define PROTECTION_LEVEL_RESTRICTED     30

#if NTDDI_VERSION < NTDDI_VISTA
#define PROTECTION_LEVEL_DEFAULT PROTECTION_LEVEL_EDGERESTRICTED
#else
#define PROTECTION_LEVEL_DEFAULT ((UINT)-1)
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

typedef struct _INTERFACE_INFO_EX {
  u_long iiFlags;
  SOCKET_ADDRESS iiAddress;
  SOCKET_ADDRESS iiBroadcastAddress;
  SOCKET_ADDRESS iiNetmask;
} INTERFACE_INFO_EX, *LPINTERFACE_INFO_EX;

#define IFF_UP 0x00000001
#define IFF_BROADCAST 0x00000002
#define IFF_LOOPBACK 0x00000004
#define IFF_POINTTOPOINT 0x00000008
#define IFF_MULTICAST 0x00000010

typedef enum _PMTUD_STATE {
  IP_PMTUDISC_NOT_SET,
  IP_PMTUDISC_DO,
  IP_PMTUDISC_DONT,
  IP_PMTUDISC_PROBE,
  IP_PMTUDISC_MAX
} PMTUD_STATE, *PPMTUD_STATE;

#define MCAST_JOIN_GROUP 41
#define MCAST_LEAVE_GROUP 42
#define MCAST_BLOCK_SOURCE 43
#define MCAST_UNBLOCK_SOURCE 44
#define MCAST_JOIN_SOURCE_GROUP 45
#define MCAST_LEAVE_SOURCE_GROUP 46

typedef enum _MULTICAST_MODE_TYPE {
  MCAST_INCLUDE = 0,
  MCAST_EXCLUDE
} MULTICAST_MODE_TYPE;

typedef struct ip_mreq_source {
  IN_ADDR imr_multiaddr;
  IN_ADDR imr_sourceaddr;
  IN_ADDR imr_interface;
} IP_MREQ_SOURCE, *PIP_MREQ_SOURCE;

typedef struct ip_msfilter {
  IN_ADDR imsf_multiaddr;
  IN_ADDR imsf_interface;
  MULTICAST_MODE_TYPE imsf_fmode;
  ULONG imsf_numsrc;
  IN_ADDR imsf_slist[1];
} IP_MSFILTER, *PIP_MSFILTER;

#define IP_MSFILTER_SIZE(NumSources) (sizeof(IP_MSFILTER) - sizeof(IN_ADDR) + (NumSources) * sizeof(IN_ADDR))

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
