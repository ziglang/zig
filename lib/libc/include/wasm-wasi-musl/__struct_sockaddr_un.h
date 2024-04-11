#ifndef __wasilibc___struct_sockaddr_un_h
#define __wasilibc___struct_sockaddr_un_h

#include <__typedef_sa_family_t.h>

struct sockaddr_un {
    __attribute__((aligned(__BIGGEST_ALIGNMENT__))) sa_family_t sun_family;
};

#endif
