#ifndef __wasilibc___struct_sockaddr_in6_h
#define __wasilibc___struct_sockaddr_in6_h

#include <__typedef_sa_family_t.h>
#include <__typedef_in_port_t.h>
#include <__struct_in6_addr.h>

struct sockaddr_in6 {
    __attribute__((aligned(__BIGGEST_ALIGNMENT__))) sa_family_t sin6_family;
    in_port_t sin6_port;
    unsigned sin6_flowinfo;
    struct in6_addr sin6_addr;
    unsigned sin6_scope_id;
};

#endif
