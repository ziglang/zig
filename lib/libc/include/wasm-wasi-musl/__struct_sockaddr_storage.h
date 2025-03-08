#ifndef __wasilibc___struct_sockaddr_storage_h
#define __wasilibc___struct_sockaddr_storage_h

#include <__typedef_sa_family_t.h>

struct sockaddr_storage {
    __attribute__((aligned(__BIGGEST_ALIGNMENT__))) sa_family_t ss_family;
    char __ss_data[32];
};

#endif
