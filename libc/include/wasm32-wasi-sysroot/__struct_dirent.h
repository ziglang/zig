#ifndef __wasilibc___struct_dirent_h
#define __wasilibc___struct_dirent_h

#include <__typedef_ino_t.h>

struct dirent {
    ino_t d_ino;
    unsigned char d_type;
    char d_name[];
};

#endif
