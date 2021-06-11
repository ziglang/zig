#ifndef __wasilibc___header_netinet_in_h
#define __wasilibc___header_netinet_in_h

#include <__struct_in_addr.h>
#include <__struct_in6_addr.h>
#include <__struct_sockaddr_in.h>
#include <__struct_sockaddr_in6.h>

#define IPPROTO_IP 0
#define IPPROTO_ICMP 1
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17
#define IPPROTO_IPV6 41
#define IPPROTO_RAW 255

#define IN6ADDR_ANY_INIT { { \
    0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00  \
} }

#define IN6ADDR_LOOPBACK_INIT { { \
    0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x00, \
    0x00, 0x00, 0x00, 0x01  \
} }

#endif
