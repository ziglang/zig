#ifndef __wasilibc___struct_tm_h
#define __wasilibc___struct_tm_h

struct tm {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
    int __tm_gmtoff;
    const char *__tm_zone;
    int __tm_nsec;
};

#endif
