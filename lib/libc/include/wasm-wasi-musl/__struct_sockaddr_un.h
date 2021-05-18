#ifndef __wasilibc___struct_sockaddr_un_h
#define __wasilibc___struct_sockaddr_un_h

#define __need_STDDEF_H_misc
#include <stddef.h>

#include <__typedef_sa_family_t.h>

struct sockaddr_un {
    _Alignas(max_align_t) sa_family_t sun_family;
};

#endif
