#ifndef __wasilibc___struct_in6_addr_h
#define __wasilibc___struct_in6_addr_h

struct in6_addr {
    _Alignas(int32_t) unsigned char s6_addr[16];
};

#endif
