#ifndef __wasilibc___struct_tms_h
#define __wasilibc___struct_tms_h

#include <__typedef_clock_t.h>

struct tms {
    clock_t tms_utime;
    clock_t tms_stime;
    clock_t tms_cutime;
    clock_t tms_cstime;
};

#endif
