#ifndef __wasilibc___struct_sockaddr_in_h
#define __wasilibc___struct_sockaddr_in_h

#include <__typedef_sa_family_t.h>
#include <__typedef_in_port_t.h>
#include <__struct_in_addr.h>

struct sockaddr_in {
    __attribute__((aligned(__BIGGEST_ALIGNMENT__))) sa_family_t sin_family;
    in_port_t sin_port;
    struct in_addr sin_addr;
};

#endif
